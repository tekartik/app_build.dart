import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'project_packages.dart';

/// A Dart program compiled with dart2js to the JavaScript file that a web app
/// loads besides its page: a web worker, a shared worker, an AudioWorklet
/// module.
///
/// The package providing the script declares it once; an app builds it with
/// [setup] (from its `tool/dev_build_setup.dart`, that `run_ci` runs before
/// the tests and the build) or with the `bin/` command of the package
/// ([setupMain]).
///
/// The build is cached in `.dart_tool/<package>/<name>/` of the app, with a
/// `meta.json` holding what it was built from: the Dart SDK, the compiler
/// options, the main, and every package of the script with its version (and
/// its pub cache folder, or a hash of its `lib/` folder for a path package).
/// It is compiled again only when one of them changed.
class WebWorkerScript {
  /// The package providing the script, a dependency of the app.
  final String package;

  /// The file written in the web folder of the app (`webp_worker.js`).
  final String filename;

  /// The name of the build folder in `.dart_tool/<package>/`, [filename]
  /// without its extension by default.
  final String? name;

  /// The `package:` uri of the library declaring `main`.
  ///
  /// Either [entry] or [mainSource] is set.
  final String? entry;

  /// The source of a generated main, for a main that depends on the
  /// packages of the app (a plugin registered when the app depends on it).
  ///
  /// It is compiled from the build folder: it can only import `package:`
  /// uris.
  final String Function(ProjectPackages packages)? mainSource;

  /// The packages whose sources make the script, their dependencies added,
  /// [package] (and the package of [entry]) by default. The ones that are
  /// not packages of the app are left out.
  final List<String>? dependencies;

  /// The dart2js options (`--no-source-maps`, `--packages` and `-o` are
  /// added).
  final List<String> compilerOptions;

  /// The file written from the dart2js output (a header added, some JS
  /// around it); the output as it is by default.
  final String Function(String js, ProjectPackages packages)? output;

  /// A script, built from [entry] or from [mainSource].
  const WebWorkerScript({
    required this.package,
    required this.filename,
    this.name,
    this.entry,
    this.mainSource,
    this.dependencies,
    this.compilerOptions = const ['-O2'],
    this.output,
  }) : assert(
         (entry == null) != (mainSource == null),
         'set either entry or mainSource',
       );

  /// The name of the build folder in `.dart_tool/<package>/`.
  String get buildName => name ?? p.basenameWithoutExtension(filename);

  /// The command running [setupMain] in the `bin/` of [package].
  String get setupCommand => 'dart run $package:setup';

  /// Builds the script for the app at [path] (the current directory by
  /// default) when needed, and writes it as [filename] (this script's by
  /// default) in its [dir] folder (`web`) when its content changed.
  ///
  /// [force] builds again whatever the cache says. [verbose] tells what the
  /// build key is.
  Future<WebWorkerScriptSetupResult> setup({
    String? path,
    String dir = 'web',
    String? filename,
    bool force = false,
    bool verbose = false,
  }) async {
    void log(String message) {
      if (verbose) {
        stdout.writeln(message);
      }
    }

    filename ??= this.filename;
    var projectPath = p.normalize(p.absolute(path ?? '.'));
    var packages = ProjectPackages.load(path: projectPath);
    if (!packages.has(package)) {
      throw StateError(
        '$package is not a dependency of $projectPath '
        '(${packages.packageConfigFile.path}): add it, then run dart pub get',
      );
    }
    var entryUri = entry == null ? null : Uri.parse(entry!);
    var main = mainSource?.call(packages);
    var key = <String, Object?>{
      'sdk': Platform.version,
      'compiler': compilerOptions,
      'entry': ?entry,
      'main': ?main,
      'packages': {
        for (var name in packages.dependencies({
          ...(dependencies ?? [package]),
          ?entryUri?.pathSegments.first,
        }))
          name: packages.sourceKey(name),
      },
    };
    var work = Directory(p.join(projectPath, '.dart_tool', package, buildName));
    var cached = File(p.join(work.path, this.filename));
    var metaFile = File(p.join(work.path, 'meta.json'));
    var meta = const JsonEncoder.withIndent('  ').convert(key);
    var upToDate =
        !force &&
        cached.existsSync() &&
        metaFile.existsSync() &&
        metaFile.readAsStringSync() == meta;
    var version = packages.version(package);
    if (upToDate) {
      log('${this.filename} cached build up to date: ${metaFile.path}');
    } else {
      log('building ${this.filename}: $meta');
      var stopwatch = Stopwatch()..start();
      await work.create(recursive: true);
      File entryFile;
      if (main != null) {
        entryFile = File(p.join(work.path, '${buildName}_main.dart'));
        await entryFile.writeAsString(main);
      } else {
        var file = packages.libraryFile(entryUri!);
        if (file == null || !file.existsSync()) {
          throw StateError('$entry not found');
        }
        entryFile = file;
      }
      var compiled = File(p.join(work.path, '$buildName.dart.js'));
      var arguments = [
        'compile',
        'js',
        ...compilerOptions,
        '--no-source-maps',
        '--packages=${packages.packageConfigFile.path}',
        '-o',
        compiled.path,
        entryFile.path,
      ];
      var result = await Process.run(
        _dartExecutable,
        arguments,
        workingDirectory: projectPath,
      );
      if (result.exitCode != 0) {
        throw ProcessException(
          _dartExecutable,
          arguments,
          '${result.stdout}${result.stderr}',
          result.exitCode,
        );
      }
      var js = await compiled.readAsString();
      await cached.writeAsString(output?.call(js, packages) ?? js);
      await metaFile.writeAsString(meta);
      stdout.writeln(
        'built ${this.filename} ($package $version) in '
        '${stopwatch.elapsedMilliseconds} ms',
      );
    }
    var target = File(p.join(projectPath, dir, filename));
    var targetPath = p.isWithin(projectPath, target.path)
        ? p.relative(target.path, from: projectPath)
        : target.path;
    var content = await cached.readAsBytes();
    var written = false;
    if (!target.existsSync() ||
        !_sameBytes(await target.readAsBytes(), content)) {
      await target.parent.create(recursive: true);
      await target.writeAsBytes(content);
      written = true;
      stdout.writeln(
        'wrote $targetPath '
        '(${content.length} bytes)',
      );
    } else if (upToDate) {
      stdout.writeln(
        '$targetPath up to date '
        '($package $version)',
      );
    }
    return WebWorkerScriptSetupResult._(
      file: target,
      version: version,
      built: !upToDate,
      written: written,
      packages: packages,
      key: key,
    );
  }

  /// The main of the setup command of [package] (in its `bin/`, run with
  /// [command], [setupCommand] by default): `[options] [<app path>]`, with
  /// `--dir`, `--force`, `--verbose` and `--help`.
  Future<void> setupMain(
    List<String> arguments, {
    String? command,
    String dir = 'web',
  }) async {
    var usage =
        '''
Builds $filename ($package) from Dart with dart2js and writes it in the web
folder of the app, again only when the Dart SDK or a package of the script
changed since the last build.

Usage: ${command ?? setupCommand} [options] [<app path>]

Options:
  --dir <dir>     the folder of the page in the app ($dir)
  -f, --force     build again whatever the cache says
  -v, --verbose   tell what is done
  -h, --help      this help''';
    String? path;
    var force = false;
    var verbose = false;
    for (var i = 0; i < arguments.length; i++) {
      switch (arguments[i]) {
        case '-h' || '--help':
          stdout.writeln(usage);
          return;
        case '--dir' when i + 1 < arguments.length:
          dir = arguments[++i];
        case '-f' || '--force':
          force = true;
        case '-v' || '--verbose':
          verbose = true;
        case var argument when !argument.startsWith('-') && path == null:
          path = argument;
        case var argument:
          stderr.writeln('unexpected $argument\n\n$usage');
          exitCode = 64;
          return;
      }
    }
    await setup(path: path, dir: dir, force: force, verbose: verbose);
  }

  @override
  String toString() => 'WebWorkerScript($package, $filename)';
}

/// What [WebWorkerScript.setup] did.
class WebWorkerScriptSetupResult {
  /// The file written in the web folder of the app.
  final File file;

  /// The version of the package of the script.
  final String? version;

  /// True when compiled, false when the cached build was up to date.
  final bool built;

  /// True when [file] was written (missing or different).
  final bool written;

  /// The packages of the app.
  final ProjectPackages packages;

  /// What the build was made from (the content of `meta.json`).
  final Map<String, Object?> key;

  WebWorkerScriptSetupResult._({
    required this.file,
    required this.version,
    required this.built,
    required this.written,
    required this.packages,
    required this.key,
  });

  @override
  String toString() =>
      'WebWorkerScriptSetupResult(${file.path}, built: $built, '
      'written: $written)';
}

/// The dart executable running this program, `dart` (from the path) when it
/// is a compiled executable.
String get _dartExecutable {
  var executable = Platform.resolvedExecutable;
  return p.basenameWithoutExtension(executable) == 'dart' ? executable : 'dart';
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
