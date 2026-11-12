// ignore_for_file: depend_on_referenced_packages
import 'package:path/path.dart';
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

export 'package:tekartik_flutter_build/app_build.dart';

/// The Flutter app this menu builds, next to the tool package.
var myAppPackageTop = join('..', 'my_app');

var myAppDevDeployOptions = FirebaseDeployOptions(
  projectId: 'my-project-dev',
  hostingId: 'my-app-dev',
  target: 'dev',
);

var myAppBuildOptions = FlutterWebAppBuildOptions(
  wasm: true,
  target: join('lib', 'main.dart'),
);

/// `dart run example/example_build_menu.dart` (from a tool package next to
/// `my_app`).
Future main(List<String> arguments) async {
  await exampleMenu(arguments, path: myAppPackageTop);
}

/// The build menu of the app at [path]: a `target dev` sub menu (build,
/// serve, deploy...) and an `all` sub menu.
Future exampleMenu(List<String> arguments, {String path = '.'}) async {
  var myAppDevBuilder = FlutterFirebaseWebAppBuilder(
    options: FlutterFirebaseWebAppOptions(
      buildOptions: myAppBuildOptions,
      path: path,
      deployOptions: myAppDevDeployOptions,
    ),
  );
  mainMenuConsole(arguments, () {
    menuFirebaseAppContent(builders: [myAppDevBuilder]);
  });
}
