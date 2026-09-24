import 'package:dev_build/build_support.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';
import 'package:tekartik_common_build/common_app_builder.dart';
import 'package:tekartik_common_build/serve_dir.dart';
import 'package:tekartik_deploy/fs_deploy.dart';
import 'package:tekartik_flutter_build/src/controller.dart';
import 'package:tekartik_flutter_build/src/web_build_size.dart';
import 'package:tekartik_web_publish/web_publish.dart';

String _fixFolder(String path, String folder) {
  if (isAbsolute(folder)) {
    return folder;
  }

  return join(path, folder);
}

/// Which web renderer `flutter build web` should use, for
/// [FlutterWebAppBuildOptions.renderer].
enum FlutterWebRenderer {
  /// The HTML renderer. No longer supported by the Flutter tool.
  @Deprecated('no longer supported')
  html,

  /// The CanvasKit renderer (the default).
  canvasKit,
}

/// Options controlling `flutter build web`, for
/// [FlutterWebAppOptions.buildOptions].
class FlutterWebAppBuildOptions {
  /// The main entry-point file of the application, passed as `--target`.
  ///
  /// If omitted (`null`), Flutter defaults to `lib/main.dart`.
  final String? target;

  /// Web renderer to build with, or `null` for the Flutter tool's default.
  final FlutterWebRenderer? renderer;

  /// Whether to compile to WebAssembly (passes `--wasm`). Defaults to
  /// `false` when `null`.
  final bool? wasm;

  /// Creates build options with the given [renderer], [wasm] flag and
  /// [target] entry point, each defaulting to `null` (tool defaults).
  FlutterWebAppBuildOptions({this.renderer, this.wasm, this.target});
}

/// Options for building, serving and deploying a Flutter web app, used by
/// [FlutterWebAppBuilder].
class FlutterWebAppOptions {
  /// Absolute, normalized path to the Flutter project.
  late final String path;

  /// Directory the built web app is copied to before deploy/serve.
  late final String deployDir;

  /// Local port used by [FlutterWebAppBuilder.run] and
  /// [FlutterWebAppBuilder.serve].
  late final int webPort;

  /// Options controlling `flutter build web`, or `null` for defaults.
  final FlutterWebAppBuildOptions? buildOptions;

  /// Creates options for the Flutter project at [path] (defaults to the
  /// current directory). [deployDir] defaults to `webAppDeployDirDefault`
  /// and [webPort] to `webAppServeWebPortDefault` when omitted.
  FlutterWebAppOptions({
    String? path,
    String? deployDir,
    int? webPort,
    this.buildOptions,
  }) {
    this.path = normalize(absolute(path ?? '.'));
    this.deployDir = deployDir ?? webAppDeployDirDefault;
    this.webPort = webPort ?? webAppServeWebPortDefault;
  }

  /// Returns a copy of these options, overriding [path], [deployDir]
  /// and/or [buildOptions] while keeping the rest unchanged.
  FlutterWebAppOptions copyWith({
    String? path,
    String? deployDir,
    FlutterWebAppBuildOptions? buildOptions,
  }) {
    return FlutterWebAppOptions(
      path: path ?? this.path,
      deployDir: deployDir ?? this.deployDir,
      buildOptions: buildOptions ?? this.buildOptions,
    );
  }
}

/// Builds, serves and deploys a Flutter web app: wraps `flutter build web`
/// / `flutter run` / a local static server, plus copy-to-deploy and
/// optional [WebAppDeployer] deployment.
class FlutterWebAppBuilder implements CommonAppBuilder {
  /// Informational build/deploy target name (e.g. `'dev'`, `'prod'`), not
  /// passed to Flutter itself; purely for the caller's own bookkeeping.
  final String? target;

  /// Options controlling build/serve/deploy behavior.
  final FlutterWebAppOptions options;

  /// Deployer used by [deploy], or `null` if this builder doesn't support
  /// deploying (calling [deploy] then throws).
  final WebAppDeployer? deployer;

  /// If set, shell commands are run through this controller (letting
  /// callers observe/cancel them) instead of a plain [Shell].
  BuildShellController? controller;

  /// Absolute path to the Flutter project, i.e. `options.path`.
  @override
  String get path => options.path;

  /// Creates a builder for [options] (defaults to a fresh
  /// [FlutterWebAppOptions] for the current directory), optionally with a
  /// [deployer], [controller] and informational [target] name.
  FlutterWebAppBuilder({
    FlutterWebAppOptions? options,
    this.deployer,
    this.controller,
    this.target,
  }) : options = options ?? FlutterWebAppOptions();

  /// Returns a copy of this builder, overriding [controller] while keeping
  /// [options], [target] and [deployer] unchanged.
  FlutterWebAppBuilder copyWith({BuildShellController? controller}) {
    return FlutterWebAppBuilder(
      controller: controller ?? this.controller,
      options: options,
      target: target,
      deployer: deployer,
    );
  }

  Shell get _shell => controller?.shell ?? Shell(workingDirectory: path);

  /// Whether `pub get` (or `flutter pub get`) has already been resolved
  /// for [path], i.e. whether a `.dart_tool/package_config.json` file can
  /// be found for it.
  ///
  /// Correctly handles Dart/Flutter workspaces: for a workspace member,
  /// the workspace root's `package_config.json` is looked up instead of
  /// [path]'s own (which workspace members don't have).
  ///
  /// Useful to decide whether `--no-pub` can be safely passed to commands
  /// like `flutter build` / `flutter run` to skip a redundant (and slow)
  /// `pub get`.
  Future<bool> hasPubGetRun() async {
    try {
      await pathGetPackageConfigMap(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs [buildOnly] then copies the output to the deploy directory (see
  /// [buildToDeploy]), `deploy.yaml` is not required.
  Future<void> build() async {
    await buildOnly();
    await _webAppBuildToDeploy();
  }

  /// Runs `flutter build web` (regenerating the version file first if
  /// needed), applying [FlutterWebAppOptions.buildOptions]' `wasm` and
  /// `target` settings, then logs the built JS (and wasm) size (see
  /// [reportJsSize]). Passes `--no-pub` when [hasPubGetRun] reports `pub
  /// get` already ran for [path] (or its workspace).
  Future<void> buildOnly() async {
    await generateVersionIfNeeded();
    var buildOptions = options.buildOptions;
    var shell = _shell;
    // var renderOptions = '';
    var wasm = buildOptions?.wasm ?? false;
    /*if (!wasm) {
      // not compatible with wasm
      switch (buildOptions?.renderer) {
        case FlutterWebRenderer.html:
          renderOptions = ' --web-renderer html';
          break;
        case FlutterWebRenderer.canvasKit:
          renderOptions = ' --web-renderer canvaskit';
          break;
        default:
      }
    }*/
    var wasmOptions = wasm ? ' --wasm' : '';
    var targetOptions = '';
    if (buildOptions?.target != null) {
      targetOptions = ' --target ${buildOptions!.target}';
    }
    var noPubOptions = await hasPubGetRun() ? ' --no-pub' : '';
    await shell.run('flutter build web$wasmOptions$targetOptions$noPubOptions');

    await reportJsSize();
  }

  var _infoShownOnce = false;
  void _showInfoOnce() {
    if (_infoShownOnce) return;
    _infoShownOnce = true;
    stdout.writeln('Dir: $path');
    var deployDir = _fixFolder(path, options.deployDir);
    stdout.writeln('Deploy: $deployDir');
  }

  /// Copies the already-built web app from `build/web` into the deploy
  /// directory, following the copy rules in that folder's `deploy.yaml`
  /// when present, copying the whole folder otherwise. Does not rebuild.
  Future<void> buildToDeploy() async {
    await _webAppBuildToDeploy();
  }

  /// Checks whether `build/web/deploy.yaml` exists, i.e. whether the
  /// project has been built at least once with a deploy configuration
  /// present.
  Future<bool> hasDeployYamlFile() async {
    var buildFolder = join(path, 'build', 'web');
    var deployFile = File(join(buildFolder, 'deploy.yaml'));
    return deployFile.existsSync();
  }

  /// Copy to deploy using deploy.yaml when present, the whole build folder
  /// is copied otherwise.
  Future<void> _webAppBuildToDeploy() async {
    _showInfoOnce();
    var buildFolder = join(path, 'build', 'web');
    var deployDir = _fixFolder(path, options.deployDir);

    var buildDir = Directory(buildFolder);
    // ignore: avoid_slow_async_io
    if (!await buildDir.exists()) {
      throw StateError('Missing build folder ($buildFolder), build first');
    }

    var deployFile = File(join(buildFolder, 'deploy.yaml'));

    // ignore: avoid_slow_async_io
    var hasDeployFile = await deployFile.exists();

    await fsDeploy(
      options: FsDeployOptions()..noSymLink = true,
      // When null, the whole folder is copied.
      yaml: hasDeployFile ? deployFile : null,
      src: buildDir,
      dst: Directory(deployDir),
    );
  }

  /// Reads the size of the last build (see [FlutterWebBuildSize.read]),
  /// [buildDuration] being how long it took when known.
  Future<FlutterWebBuildSize> readBuildSize({Duration? buildDuration}) =>
      FlutterWebBuildSize.read(path, buildDuration: buildDuration);

  /// Logs the size of the built javascript (`main.dart.js` and its deferred
  /// parts) and, for a `--wasm` build, of the WebAssembly, raw and gzipped,
  /// to stdout, see [FlutterWebBuildSize.toLines].
  Future<void> reportJsSize() async {
    var size = await readBuildSize();
    for (var line in size.toLines()) {
      stdout.writeln(line);
    }
  }

  /// Runs `flutter clean` in the project directory (see
  /// [flutterWebAppClean]).
  Future<void> clean() async {
    await flutterWebAppClean(options.path);
  }

  /// Runs the app in Chrome via `flutter run -d chrome`, on
  /// [FlutterWebAppOptions.webPort]. Passes `--no-pub` when [hasPubGetRun]
  /// reports `pub get` already ran for [path] (or its workspace).
  Future<void> run() async {
    var shell = _shell;
    var noPubOptions = await hasPubGetRun() ? ' --no-pub' : '';
    await shell.run(
      'flutter run -d chrome --web-port ${options.webPort}$noPubOptions',
    );
  }

  /// Deploys the contents of the deploy directory using [deployer].
  ///
  /// Throws a [StateError] if this builder has no [deployer].
  Future<void> deploy() async {
    if (deployer == null) {
      throw StateError('Missing deployer');
    }
    var deployDir = _fixFolder(path, options.deployDir);
    await deployer!.deploy(path: deployDir);
  }

  /// Serves the deploy directory locally over HTTP on
  /// [FlutterWebAppOptions.webPort], using `dhttpd` (activating it first
  /// if needed) with cross-origin isolation headers set for WASM/threaded
  /// support. See `tekartik_common_build`'s `DirServeBuilder`.
  Future<void> serve() async {
    var deployDir = _fixFolder(path, options.deployDir);
    await DirServeBuilder(
      ServeDirOptions(path: deployDir, port: options.webPort, secure: true),
      shell: _shell,
    ).serve();
  }

  /// Runs [build] followed by [serve].
  Future<void> buildAndServe() async {
    await build();

    await serve();
  }

  /// Runs [build] followed by [deploy].
  Future<void> buildAndDeploy() async {
    await build();

    await deploy();
  }
}

/// Builds, unless [build] is false, then reads the build size of the flutter
/// apps at [paths], in order.
///
/// Each app is built with [FlutterWebAppBuilder.buildOnly] and
/// [buildOptions] (`FlutterWebAppBuildOptions(wasm: true)` for the wasm size
/// too). Without building, the last build of each app is read. Print or save
/// the result with [flutterWebBuildSizeMarkdownTable] or
/// [flutterWebBuildSizeWriteReport].
Future<List<FlutterWebBuildSize>> flutterWebAppsBuildSize(
  List<String> paths, {
  bool build = true,
  FlutterWebAppBuildOptions? buildOptions,
}) async {
  var sizes = <FlutterWebBuildSize>[];
  for (var path in paths) {
    var builder = FlutterWebAppBuilder(
      options: FlutterWebAppOptions(path: path, buildOptions: buildOptions),
    );
    Duration? buildDuration;
    if (build) {
      var stopwatch = Stopwatch()..start();
      await builder.buildOnly();
      buildDuration = stopwatch.elapsed;
    }
    sizes.add(await builder.readBuildSize(buildDuration: buildDuration));
  }
  return sizes;
}

/// Runs `flutter clean` in [directory].
Future<void> flutterWebAppClean(String directory) async {
  var shell = Shell().cd(directory);
  await shell.run('flutter clean');
}
