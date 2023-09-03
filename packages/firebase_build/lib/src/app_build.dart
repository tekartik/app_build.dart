import 'package:process_run/shell.dart';

import 'firebase_deploy.dart';

/// Build a web app
Future<void> flutterWebAppBuild(String directory) async {
  var shell = Shell().cd(directory);
  await shell.run('flutter build web');
}

/// Clean a web app
Future<void> flutterWebAppClean(String directory) async {
  var shell = Shell().cd(directory);
  await shell.run('flutter clean');
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

enum FlutterWebRenderer { html, canvasKit }

class FlutterWebAppBuildOptions {
  FlutterWebRenderer? renderer;
  FlutterWebAppBuildOptions({this.renderer});
}

/// Web app options
class FlutterFirebaseWebAppOptions {
  final String path;
  final FlutterWebAppBuildOptions? buildOptions;
  final FirebaseDeployOptions deployOptions;

  FlutterFirebaseWebAppOptions(
      {this.path = '.', required this.deployOptions, this.buildOptions});

  FlutterFirebaseWebAppOptions copyWith(
      {String? path,
      FlutterWebAppBuildOptions? buildOptions,
      FirebaseDeployOptions? deployOptions}) {
    return FlutterFirebaseWebAppOptions(
        path: path ?? this.path,
        buildOptions: buildOptions ?? this.buildOptions,
        deployOptions: deployOptions ?? this.deployOptions);
  }
}

/// Convenient builder.
class FlutterFirebaseWebAppBuilder {
  final FlutterFirebaseWebAppOptions options;

  FlutterFirebaseWebAppBuilder({required this.options});

  Future<void> build() async {
    var shell = Shell().cd(options.path);
    var renderOptions = '';
    switch (options.buildOptions?.renderer) {
      case FlutterWebRenderer.html:
        renderOptions = ' --web-renderer html';
        break;
      case FlutterWebRenderer.canvasKit:
        renderOptions = ' --web-renderer canvaskit';
        break;
      default:
    }
    await shell.run('flutter build web$renderOptions');
    await flutterWebAppBuild(options.path);
    await firebaseWebAppBuildToDeploy(options.path);
  }

  Future<void> clean() async {
    await flutterWebAppClean(options.path);
  }

  Future<void> serve() async {
    await firebaseWebAppServe(options.path, options.deployOptions);
  }

  Future<void> deploy() async {
    await firebaseWebAppDeploy(options.path, options.deployOptions);
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
