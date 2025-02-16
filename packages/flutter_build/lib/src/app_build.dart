import 'package:dev_build/build_support.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';
import 'package:tekartik_common_build/common_app_builder.dart';
import 'package:tekartik_deploy/fs_deploy.dart';
import 'package:tekartik_flutter_build/src/controller.dart';
import 'package:tekartik_web_publish/web_publish.dart';

String _fixFolder(String path, String folder) {
  if (isAbsolute(folder)) {
    return folder;
  }
  return join(path, folder);
}

/// Web rendered (html deprecated
enum FlutterWebRenderer {
  /// Deprecated
  @Deprecated('no longer supported')
  html,

  /// Default
  canvasKit
}

/// Build options.
class FlutterWebAppBuildOptions {
  /// Target
  ///
  /// The main entry-point file of the application, as run on the device.
  /// If the "--target" option is omitted, but a file name is provided on the command line, then that is used
  /// instead.
  ///
  /// (defaults to "lib/main.dart")
  final String? target;

  /// Renderer
  final FlutterWebRenderer? renderer;

  /// Compile as wasm
  final bool? wasm;

  /// Build options.
  FlutterWebAppBuildOptions({this.renderer, this.wasm, this.target});
}

/// Web app options
class FlutterWebAppOptions {
  /// Project path
  late final String path;

  /// Deploy dir
  late final String deployDir;

  /// Serve web port
  late final int webPort;

  /// Build options
  final FlutterWebAppBuildOptions? buildOptions;

  /// Web app options
  FlutterWebAppOptions(
      {
      /// default to current directory
      String? path,
      String? deployDir,
      int? webPort,
      this.buildOptions}) {
    this.path = normalize(absolute(path ?? '.'));
    this.deployDir = deployDir ?? webAppDeployDirDefault;
    this.webPort = webPort ?? webAppServeWebPortDefault;
  }

  /// Copy
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

/// Convenient builder.
class FlutterWebAppBuilder implements CommonAppBuilder {
  /// Information target name (dev, prod...)
  final String? target;

  /// Options
  final FlutterWebAppOptions options;

  /// Deployer
  final WebAppDeployer? deployer;

  /// Optional controller
  BuildShellController? controller;

  /// Project path.
  @override
  String get path => options.path;

  /// Constructor
  FlutterWebAppBuilder(
      {FlutterWebAppOptions? options,
      this.deployer,
      this.controller,
      this.target})
      : options = options ?? FlutterWebAppOptions();

  /// CopyWith
  FlutterWebAppBuilder copyWith({BuildShellController? controller}) {
    return FlutterWebAppBuilder(
        controller: controller ?? this.controller,
        options: options,
        target: target,
        deployer: deployer);
  }

  Shell get _shell => controller?.shell ?? Shell(workingDirectory: path);

  /// Build
  Future<void> build() async {
    await buildOnly();
    await _webAppBuildToDeploy();
  }

  /// Build
  Future<void> buildOnly() async {
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
  }

  /// Copy to deploy using deploy.yaml
  Future<void> _webAppBuildToDeploy() async {
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
        dst: Directory(deployDir));
  }

  /// Clean
  Future<void> clean() async {
    await flutterWebAppClean(options.path);
  }

  /// Run (serve)
  Future<void> run() async {
    var shell = _shell;
    await shell.run('flutter run -d chrome --web-port ${options.webPort}');
  }

  /// Deploy
  Future<void> deploy() async {
    if (deployer == null) {
      throw StateError('Missing deployer');
    }
    await deployer!.deploy(path: options.deployDir);
  }

  /// Serve build
  Future<void> serve() async {
    await checkAndActivatePackage('dhttpd');
    stdout.writeln('http://localhost:${options.webPort}');
    var deployDir = _fixFolder(path, options.deployDir);
    var shell = _shell;
    await shell.run(
        'dart pub global run dhttpd:dhttpd --path ${shellArgument(deployDir)} --port ${options.webPort} --headers=Cross-Origin-Embedder-Policy=credentialless;Cross-Origin-Opener-Policy=same-origin');
  }

  /// Build and serve
  Future<void> buildAndServe() async {
    await build();
    await serve();
  }

  /// Build and deploy
  Future<void> buildAndDeploy() async {
    await build();
    await deploy();
  }
}

/// Clean a web app
Future<void> flutterWebAppClean(String directory) async {
  var shell = Shell().cd(directory);
  await shell.run('flutter clean');
}
