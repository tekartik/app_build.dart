import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart'
    as ffbm;

import 'fbm_build_menu.dart';

var appDevFirebaseDeployOptions = FirebaseDeployOptions(
  projectId: appDevProjectId,
  hostingId: appDevHosting,
  target: appDevTarget,
);

var appDevFirebaseWebAppBuilder = FlutterFirebaseWebAppBuilder(
  options: FlutterFirebaseWebAppOptions(
    buildOptions: appDevBuildOptions,
    path: appDevPath,
    deployOptions: appDevFirebaseDeployOptions,
  ),
);

Future<void> main(List<String> arguments) async {
  mainMenuConsole(arguments, () {
    menu('ffbm', () {
      ffbm.menuFirebaseAppContent(builders: [appDevFirebaseWebAppBuilder]);
    });
    item('build', () async {
      await appDevFirebaseWebAppBuilder.build();
    });
    item('copy', () async {
      await appDevFirebaseWebAppBuilder.copyBuildToDeploy();
    });
  });
}
