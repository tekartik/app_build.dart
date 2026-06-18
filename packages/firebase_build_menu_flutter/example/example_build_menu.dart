// ignore_for_file: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart'
    as ffbm;
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

export 'package:tekartik_flutter_build/app_build.dart';

var userPlusAppPackageTop = join(
  '..',
  '..',
  'packages_flutter',
  'festenaoprv_user_plus_app',
);

var userPlusAppDevDeployOptions = FirebaseDeployOptions(
  projectId: 'test-project-id',
  hostingId: 'test-project',
  target: 'dev',
);

var userPlusAppBuildOptions = FlutterWebAppBuildOptions(
  wasm: true,
  target: join('lib', 'main.dart'),
);

var userPlusAppShell = Shell().cd(userPlusAppPackageTop);

Future main(List<String> arguments) async {
  await exampleMenu(arguments, path: userPlusAppPackageTop);
}

Future exampleMenu(List<String> arguments, {String path = '.'}) async {
  final userPlusAppFirebaseWebAppDevOptions = FlutterFirebaseWebAppOptions(
    buildOptions: userPlusAppBuildOptions,
    path: path,
    deployOptions: userPlusAppDevDeployOptions,
  );
  // FlutterWebAppBuildOptions(renderer: FlutterWebRenderer.canvasKit);
  var userPlusAppDevBuilder = FlutterFirebaseWebAppBuilder(
    options: userPlusAppFirebaseWebAppDevOptions,
  );
  mainMenuConsole(arguments, () {
    ffbm.menuFirebaseAppContent(builders: [userPlusAppDevBuilder]);
    menu('configure', () {});
  });
}
