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

/// Build a web app
Future<void> flutterWebAppBuildAndDeployFirebaseDev(String directory,
    {required FirebaseDeployOptions firebaseDeployOptions}) async {
  await flutterWebAppBuild(directory);
  await firebaseWepAppBuildToDeploy(directory);
  await firebaseWebAppDeploy(directory, firebaseDeployOptions);
}
