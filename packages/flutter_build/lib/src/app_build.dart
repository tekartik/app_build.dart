import 'package:dev_build/build_support.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';
import 'package:tekartik_common_build/common_app_builder.dart';
import 'package:tekartik_deploy/fs_deploy.dart';
import 'package:tekartik_web_publish/web_publish.dart';

String _fixFolder(String path, String folder) {
  if (isAbsolute(folder)) {
    return folder;
  }
  return join(path, folder);
}

enum FlutterWebRenderer { html, canvasKit }

/// Build options.
class FlutterWebAppBuildOptions {
  /// Renderer
  FlutterWebRenderer? renderer;

  /// Compile as wasm
  bool? wasm;

  /// Build options.
  FlutterWebAppBuildOptions({this.renderer, this.wasm});
}

/// Web app options
class FlutterWebAppOptions {
  late final String path;
  late final String deployDir;
  late final int webPort;
  final FlutterWebAppBuildOptions? buildOptions;

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
  final FlutterWebAppOptions options;
  final WebAppDeployer? deployer;

  /// Project path.
  @override
  String get path => options.path;

  FlutterWebAppBuilder({required this.options, this.deployer});

  Future<void> build() async {
    var shell = Shell().cd(options.path);
    var renderOptions = '';
    var wasm = options.buildOptions?.wasm ?? false;
    if (!wasm) {
      // not compatible with wasm
      switch (options.buildOptions?.renderer) {
        case FlutterWebRenderer.html:
          renderOptions = ' --web-renderer html';
          break;
        case FlutterWebRenderer.canvasKit:
          renderOptions = ' --web-renderer canvaskit';
          break;
        default:
      }
    }
    var wasmOptions = wasm ? ' --wasm' : '';
    await shell.run('flutter build web$renderOptions$wasmOptions');
    await _webAppBuildToDeploy();
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

  Future<void> clean() async {
    await flutterWebAppClean(options.path);
  }

  Future<void> run() async {
    var shell = Shell().cd(options.path);
    await shell.run('flutter run -d chrome');
  }

  Future<void> deploy() async {
    if (deployer == null) {
      throw StateError('Missing deployer');
    }
    await deployer!.deploy(path: options.deployDir);
  }

  Future<void> serve() async {
    await checkAndActivatePackage('dhttpd');
    print('http://localhost:${options.webPort}');
    var deployDir = _fixFolder(path, options.deployDir);
    var shell = Shell().cd(deployDir);
    await shell.run(
        'dart pub global run dhttpd:dhttpd . --port ${options.webPort} --headers=Cross-Origin-Embedder-Policy=credentialless;Cross-Origin-Opener-Policy=same-origin');
  }

  Future<void> buildAndServe() async {
    await build();
    await serve();
  }

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
