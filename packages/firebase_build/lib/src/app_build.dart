import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_flutter_build/app_build.dart';

import 'firebase_deploy.dart';
import 'package:tekartik_common_build/version_io.dart' as version_io;

/// Build a web app
Future<void> flutterWebAppBuild(String directory) async {
  var shell = Shell().cd(directory);
  await shell.run('flutter build web');
}

/// Build a web app and deploy
///
/// Assume static web site in a 'public' subfolder
Future<void> flutterWebAppBuildAndDeploy(String directory,
    {required FirebaseDeployOptions firebaseDeployOptions,
    String? deployDir}) async {
  await flutterWebAppBuild(directory);
  await firebaseWebAppBuildToDeploy(directory, deployDir: deployDir);
  await firebaseWebAppDeploy(directory, firebaseDeployOptions,
      deployDir: deployDir);
}

/// Build a web app and serve
///
/// Assume static web site in a 'public' subfolder
Future<void> flutterWebAppBuildAndServe(String directory,
    {required FirebaseDeployOptions firebaseDeployOptions,
    String? deployDir}) async {
  await flutterWebAppBuild(directory);
  await firebaseWebAppBuildToDeploy(directory, deployDir: deployDir);
  await firebaseWebAppServe(directory, firebaseDeployOptions,
      deployDir: deployDir);
}

/// Web app options
class FlutterFirebaseWebAppOptions {
  late final String path;
  final String? deployDir;
  final FlutterWebAppBuildOptions? buildOptions;
  final FirebaseDeployOptions deployOptions;

  FlutterFirebaseWebAppOptions(
      {
      /// default to current directory
      String? path,
      this.deployDir,
      required this.deployOptions,
      this.buildOptions}) {
    this.path = normalize(absolute(path ?? '.'));
  }

  FlutterFirebaseWebAppOptions copyWith(
      {String? path,
      String? deployDir,
      FlutterWebAppBuildOptions? buildOptions,
      FirebaseDeployOptions? deployOptions}) {
    return FlutterFirebaseWebAppOptions(
        path: path ?? this.path,
        deployDir: deployDir ?? this.deployDir,
        buildOptions: buildOptions ?? this.buildOptions,
        deployOptions: deployOptions ?? this.deployOptions);
  }
}

/// Convenient builder.
class FlutterFirebaseWebAppBuilder {
  final FlutterFirebaseWebAppOptions options;

  /// Project path.
  String get path => options.path;

  FlutterFirebaseWebAppBuilder({required this.options});

  String get target => options.deployOptions.target;

  Future<void> build({FirebaseWebAppActionController? controller}) async {
    var shell = Shell().cd(options.path);
    controller?.shell = shell;
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
    await firebaseWebAppBuildToDeploy(options.path,
        deployDir: options.deployDir);
  }

  Future<void> clean() async {
    await flutterWebAppClean(options.path);
  }

  Future<void> generateVersion() async {
    await version_io.generateVersion(path: options.path);
  }

  Future<void> serve({FirebaseWebAppActionController? controller}) async {
    await firebaseWebAppServe(options.path, options.deployOptions,
        controller: controller);
  }

  Future<void> deploy({FirebaseWebAppActionController? controller}) async {
    await firebaseWebAppDeploy(options.path, options.deployOptions,
        deployDir: options.deployDir, controller: controller);
  }

  Future<void> buildAndServe(
      {FirebaseWebAppActionController? controller}) async {
    await build(controller: controller);
    await serve(controller: controller);
  }

  Future<void> buildAndDeploy(
      {FirebaseWebAppActionController? controller}) async {
    await build(controller: controller);
    await deploy(controller: controller);
  }
}
