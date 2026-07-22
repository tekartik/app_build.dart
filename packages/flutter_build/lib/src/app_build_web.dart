import 'package:dev_build/build_support.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';
import 'package:tekartik_common_build/common_app_builder.dart';
import 'package:tekartik_common_build/formatter.dart' as f;
import 'package:tekartik_deploy/fs_deploy.dart';
import 'package:tekartik_flutter_build/src/controller.dart';
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

  /// Runs [buildOnly] then copies the output to the deploy directory (see
  /// [buildToDeploy]).
  Future<void> build() async {
    await buildOnly();
    await _webAppBuildToDeploy();
  }

  /// Runs `flutter build web` (regenerating the version file first if
  /// needed), applying [FlutterWebAppOptions.buildOptions]' `wasm` and
  /// `target` settings, then logs the built JS bundle size (see
  /// [reportJsSize]).
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
    await shell.run('flutter build web$wasmOptions$targetOptions');
    await reportJsSize();
  }

  File? _findJsFile() {
    var file = File(join(path, 'build', 'web', 'main.dart.js'));
    if (file.existsSync()) return file;
    var dir = Directory(join(path, 'build', 'web'));
    if (!dir.existsSync()) return null;
    for (var entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('main.dart.js')) {
        return entity;
      }
    }
    return null;
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
  /// directory, following the copy rules in that folder's `deploy.yaml`.
  /// Does not rebuild.
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

  /// Copy to deploy using deploy.yaml
  Future<void> _webAppBuildToDeploy() async {
    _showInfoOnce();
    var buildFolder = join(path, 'build', 'web');
    var deployDir = _fixFolder(path, options.deployDir);

    var deployFile = File(join(buildFolder, 'deploy.yaml'));

    // ignore: avoid_slow_async_io
    if (!await deployFile.exists()) {
      throw StateError('Missing deploy.yaml file ($deployFile)');
    }
    await fsDeploy(
      options: FsDeployOptions()..noSymLink = true,
      yaml: deployFile,
      src: Directory(buildFolder),
      dst: Directory(deployDir),
    );
  }

  /// Logs the size of the built `main.dart.js` bundle (searched for under
  /// `build/web`) to stdout, or `0` if it can't be found.
  Future<void> reportJsSize() async {
    var file = _findJsFile();
    stdout.writeln('main.dart.js (${f.formatSize(file?.lengthSync() ?? 0)})');
  }

  /// Runs `flutter clean` in the project directory (see
  /// [flutterWebAppClean]).
  Future<void> clean() async {
    await flutterWebAppClean(options.path);
  }

  /// Runs the app in Chrome via `flutter run -d chrome`, on
  /// [FlutterWebAppOptions.webPort].
  Future<void> run() async {
    var shell = _shell;
    await shell.run('flutter run -d chrome --web-port ${options.webPort}');
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
  /// support.
  Future<void> serve() async {
    await checkAndActivatePackage('dhttpd');
    stdout.writeln('http://localhost:${options.webPort}');
    var deployDir = _fixFolder(path, options.deployDir);
    var shell = _shell;
    await shell.run(
      'dart pub global run dhttpd:dhttpd --path ${shellArgument(deployDir)} --port ${options.webPort} --headers=Cross-Origin-Embedder-Policy=credentialless;Cross-Origin-Opener-Policy=same-origin',
    );
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

/// Runs `flutter clean` in [directory].
Future<void> flutterWebAppClean(String directory) async {
  var shell = Shell().cd(directory);
  await shell.run('flutter clean');
}
