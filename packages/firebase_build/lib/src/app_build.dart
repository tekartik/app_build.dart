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
  await firebaseWepAppBuildToDeploy(directory, deployDir: deployDir);
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
  await firebaseWepAppBuildToDeploy(directory, deployDir: deployDir);
  await firebaseWebAppServe(directory, firebaseDeployOptions,
      deployDir: deployDir);
}
