import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

/// Project
const appDevProjectId = 'my-project';

/// Targets
const appDevHosting = 'app-dev';
String appDevTarget = 'dev';
var appDevPath = '.';

var appDevDeployOptions = FirebaseDeployOptions(
  projectId: appDevProjectId,
  hostingId: appDevHosting,
  target: appDevTarget,
);

var appDevBuildOptions = FlutterWebAppBuildOptions(wasm: true);
var appDevBuilder = FlutterWebAppBuilder(
  options: FlutterWebAppOptions(
    buildOptions: appDevBuildOptions,
    path: appDevPath,
  ),
);

Future<void> main(List<String> arguments) async {
  mainMenuConsole(arguments, () {
    menu('fbm', () {
      menuFlutterWebAppContent(builders: [appDevBuilder]);
    });
    item('build', () async {
      await appDevBuilder.build();
    });
    item('copy', () async {
      await appDevBuilder.buildToDeploy();
    });
  });
}
