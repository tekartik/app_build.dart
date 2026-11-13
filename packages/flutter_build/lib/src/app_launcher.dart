import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_build_flutter/app_builder.dart';
import 'package:yaml/yaml.dart';

/// Builds the release of the flutter app at [path] for the current host
/// (desktop) and runs it.
///
/// The build is copied to `deploy/<platform>` (`deploy/linux`) and runs from
/// there, so that a `flutter clean` or a build in progress does not break it.
class FlutterAppHostLauncher {
  /// The app package name, also the name of the built executable.
  final String packageName;

  /// The app (flutter project) path, absolute.
  final String path;

  /// The macos app sandbox, set in the entitlements of the macos project
  /// before each build. False lets the app open any file (a folder given
  /// on the command line), null leaves the project as created (sandboxed,
  /// the flutter default).
  final bool? macosSandbox;

  /// True (the default) when [kill] kills the descendants of the app too
  /// (the processes it started). False kills the app only, as if it was
  /// closed: an app whose processes must outlive it (sessions held by
  /// `dtach`, a server it detached) keeps them across an upgrade.
  final bool killTree;

  /// The app builder.
  late final appBuilder = FlutterAppBuilder(
    context: FlutterAppContext(path: path),
  );

  /// The default (no flavor) builder.
  late final flavorBuilder = appBuilder.defaultFlavorBuilder;

  /// Launcher of the app [packageName] at [path] (the current directory by
  /// default).
  FlutterAppHostLauncher({
    required this.packageName,
    String? path,
    this.macosSandbox,
    this.killTree = true,
  }) : path = normalize(absolute(path ?? '.'));

  /// The deployed release folder, `deploy/linux` on linux.
  String get deployPath => join(path, flavorBuilder.hostDeployPath);

  /// The deployed executable.
  String get deployedExePath {
    if (Platform.isMacOS) {
      return join(
        deployPath,
        '$packageName.app',
        'Contents',
        'MacOS',
        packageName,
      );
    }
    return join(
      deployPath,
      Platform.isWindows ? '$packageName.exe' : packageName,
    );
  }

  /// True when the release was built and deployed.
  bool get isDeployed => File(deployedExePath).existsSync();

  /// The pids of the running instances of the deployed release (the
  /// processes of [deployedExePath], whatever their arguments, see
  /// `ShellProcesses.findByExecutable`), empty when none is running; the
  /// current process excluded.
  Future<List<int>> runningPids() async => [
    for (var processPid in await ShellProcesses.findByExecutable(
      deployedExePath,
    ))
      if (processPid != pid) processPid,
  ];

  /// Kills the running instances of the deployed release ([runningPids]) and,
  /// when [killTree], their descendants (the processes they started):
  /// sigterm, then sigkill for the ones still running after [timeout].
  ///
  /// Returns their pids, empty when none was running.
  Future<List<int>> kill({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    var pids = await runningPids();
    if (pids.isNotEmpty) {
      await ShellProcesses.kill(pids, tree: killTree, timeout: timeout);
    }
    return pids;
  }

  /// Creates the platform project (`linux/`, git ignored) when missing, then
  /// applies [macosSandbox] on macos.
  ///
  /// Called by [build], call it before `flavorBuilder.runHost()` (debug).
  Future<void> createHostProject() async {
    await flavorBuilder.createHostProject();
    if (Platform.isMacOS && macosSandbox != null) {
      if (macosSandbox!) {
        await appBuilder.macosEnableSandbox();
      } else {
        await appBuilder.macosDisableSandbox();
      }
    }
  }

  /// Runs `flutter pub upgrade` in [path].
  Future<void> pubUpgrade() async {
    await Shell(workingDirectory: path).run('flutter pub upgrade');
  }

  /// Builds the release and copies it to [deployPath].
  ///
  /// The platform project (`linux/`, git ignored) is created when missing.
  /// When [pubUpgrade] is true, runs `flutter pub upgrade` in [path] first.
  Future<void> build({bool pubUpgrade = false}) async {
    if (pubUpgrade) {
      await this.pubUpgrade();
    }
    await createHostProject();
    await flavorBuilder.buildHost();
  }

  /// Runs the deployed release in the current directory with [arguments],
  /// returns its exit code.
  Future<int> run([List<String> arguments = const []]) async {
    var shell = Shell(
      options: ShellOptions(
        throwOnError: false,
        verbose: false,
        mode: ProcessStartMode.inheritStdio,
      ),
    );
    var result = await shell.runExecutableArguments(deployedExePath, arguments);
    return result.exitCode;
  }

  /// Runs the deployed release with [arguments] (see [run]), building it
  /// first when not deployed yet or when [rebuild] or [pubUpgrade] is true.
  Future<int> buildIfNeededAndRun({
    List<String> arguments = const [],
    bool rebuild = false,
    bool pubUpgrade = false,
  }) async {
    if (rebuild || pubUpgrade || !isDeployed) {
      stdout.writeln('Building $packageName in $path');
      await build(pubUpgrade: pubUpgrade);
    }
    return await run(arguments);
  }

  /// Runs the app in debug (`flutter run -d <platform>`), the platform
  /// project created first (see [createHostProject]).
  Future<void> runDebug() async {
    await createHostProject();
    await flavorBuilder.runHost();
  }

  /// Installs the global command (the `executables:` of the pubspec) with
  /// `dart install` of the sources at [path]. The release is built on its
  /// first run.
  Future<void> install() async {
    await Shell(workingDirectory: path).run('dart install .');
  }
}

/// Main of the global command of a flutter app (`bin/<packageName>.dart`):
/// `<packageName> [app arguments] [-- --upgrade]` runs the built app with
/// the arguments before `--`, building it first when needed. The launcher
/// options come after `--`: `--kill` kills the running app first (a single
/// instance app would show it instead of the new one), `--upgrade` kills it
/// too, then rebuilds it.
///
/// [appArgumentsUsage] (`[folder]`) and [description] are shown in the help,
/// with [commandName] (the `executables:` name, [packageName] by default).
/// [libraryPath] is a library of the app package, used to find its sources.
/// [macosSandbox] false disables the macos app sandbox, see
/// [FlutterAppHostLauncher.macosSandbox]. [killTree] false makes `--kill`
/// and `--upgrade` kill the app only, not the processes it started, see
/// [FlutterAppHostLauncher.killTree].
Future<void> flutterAppLauncherMain(
  List<String> arguments, {
  required String packageName,
  String? commandName,
  String appArgumentsUsage = '',
  String? description,
  String libraryPath = 'main.dart',
  bool? macosSandbox,
  bool killTree = true,
}) async {
  var separator = arguments.indexOf('--');
  var appArguments = separator < 0
      ? arguments
      : arguments.sublist(0, separator);
  var parser = ArgParser()
    ..addFlag(
      'upgrade',
      abbr: 'u',
      negatable: false,
      help:
          'Kill the running app, run flutter pub upgrade, rebuild it '
          '(release), then run it (implies --kill).',
    )
    ..addFlag(
      'pub-upgrade',
      negatable: false,
      help:
          'Run flutter pub upgrade in the app folder before building '
          '(implies --upgrade).',
    )
    ..addFlag(
      'kill',
      abbr: 'k',
      negatable: false,
      help: killTree
          ? 'Kill the running app (the deployed release and the processes it '
                'started) first.'
          : 'Kill the running app (the deployed release; the processes it '
                'started keep running) first.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'This help.');
  void usage(IOSink out) {
    out.writeln(
      'Usage: ${commandName ?? packageName} '
      '${appArgumentsUsage.isEmpty ? '' : '$appArgumentsUsage '}[-- options]',
    );
    out.writeln();
    if (description != null) {
      out.writeln(description);
    }
    out.writeln('Built from its sources on the first run.');
    out.writeln();
    out.writeln('Options (after --):');
    out.writeln(parser.usage);
  }

  ArgResults options;
  try {
    options = parser.parse(
      separator < 0 ? const [] : arguments.sublist(separator + 1),
    );
    if (options.rest.isNotEmpty) {
      throw FormatException('Unexpected ${options.rest.join(' ')}');
    }
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    usage(stderr);
    exitCode = 64;
    return;
  }
  if (options.flag('help')) {
    usage(stdout);
    return;
  }

  var sourcePath = await findFlutterAppLauncherSourcePath(
    packageName: packageName,
    libraryPath: libraryPath,
  );
  if (sourcePath == null) {
    stderr.writeln('$packageName sources not found');
    exitCode = 1;
    return;
  }
  var launcher = FlutterAppHostLauncher(
    packageName: packageName,
    path: sourcePath,
    macosSandbox: macosSandbox,
    killTree: killTree,
  );
  var pubUpgrade = options.flag('pub-upgrade');
  var upgrade = options.flag('upgrade') || pubUpgrade;
  // An upgrade replaces the running release: a single instance app would
  // show the old one, Windows cannot replace its files.
  if (options.flag('kill') || upgrade) {
    var killed = await launcher.kill();
    stdout.writeln(
      killed.isEmpty
          ? '$packageName is not running'
          : 'Killed $packageName (pid ${killed.join(', ')})',
    );
  }
  try {
    exitCode = await launcher.buildIfNeededAndRun(
      arguments: appArguments,
      rebuild: upgrade,
      pubUpgrade: upgrade,
    );
  } on ShellException catch (e) {
    stderr.writeln('Build failed: ${e.message}');
    exitCode = 1;
  }
}

/// Finds the sources of the running launcher of [packageName], null if not
/// found.
///
/// - `dart run`, `dart pub global activate` (path or git): from the package
///   config of the running script, resolving [libraryPath];
/// - `dart install` (AOT, no package config): from the `pubspec.lock` next to
///   the installed bundle, a local path or a git checkout in the pub cache.
Future<String?> findFlutterAppLauncherSourcePath({
  required String packageName,
  String libraryPath = 'main.dart',
}) async {
  try {
    var libUri = await Isolate.resolvePackageUri(
      Uri.parse('package:$packageName/$libraryPath'),
    );
    if (libUri != null && libUri.isScheme('file')) {
      // <package>/lib/<libraryPath>
      var libDir = dirname(libUri.toFilePath());
      for (var i = 1; i < url.split(libraryPath).length; i++) {
        libDir = dirname(libDir);
      }
      return dirname(libDir);
    }
  } catch (_) {
    // Not supported in AOT.
  }
  return dartInstallSourcePath(
    Platform.resolvedExecutable,
    packageName: packageName,
  );
}

/// The sources of a `dart install`-ed [executable]
/// (`app-bundles/<package>/<source>/bundle/bin/<executable>`), from the
/// `pubspec.lock` in `app-bundles/<package>/<source>`, null if not found.
String? dartInstallSourcePath(
  String executable, {
  required String packageName,
}) {
  var lockFile = File(
    join(dirname(dirname(dirname(executable))), 'pubspec.lock'),
  );
  if (!lockFile.existsSync()) {
    return null;
  }
  var sourcePath = pubspecLockSourcePath(
    lockFile.readAsStringSync(),
    package: packageName,
    lockDirPath: lockFile.parent.path,
    pubCachePath: pubCachePath,
  );
  if (sourcePath == null ||
      !File(join(sourcePath, 'pubspec.yaml')).existsSync()) {
    return null;
  }
  return sourcePath;
}

/// The sources of [package] locked in [lockContent] (a `pubspec.lock`): a
/// path (relative to [lockDirPath]) or a git checkout in [pubCachePath]
/// (`git/<repo>-<commit>/<path>`), null for other sources.
String? pubspecLockSourcePath(
  String lockContent, {
  required String package,
  required String lockDirPath,
  required String pubCachePath,
}) {
  var lock = loadYaml(lockContent);
  if (lock is! Map) {
    return null;
  }
  var locked = (lock['packages'] as Map?)?[package];
  if (locked is! Map) {
    return null;
  }
  var description = locked['description'];
  if (description is! Map) {
    return null;
  }
  switch (locked['source']) {
    case 'path':
      var path = description['path'] as String;
      return normalize(join(lockDirPath, path));
    case 'git':
      var gitUrl = description['url'] as String;
      var ref = description['resolved-ref'] as String;
      var path = (description['path'] as String?) ?? '.';
      return normalize(
        join(pubCachePath, 'git', '${_gitRepoName(gitUrl)}-$ref', path),
      );
  }
  return null;
}

/// The checkout folder prefix pub uses for a git [gitUrl] (pub's
/// `GitSource._repoName`: the sanitized repository name, cut to 50
/// characters).
String _gitRepoName(String gitUrl) {
  var name = url.basename(gitUrl);
  if (name.endsWith('.git')) {
    name = name.substring(0, name.length - '.git'.length);
  }
  name = name.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
  if (name.length > 50) {
    name = name.substring(0, 50);
  }
  return name;
}
