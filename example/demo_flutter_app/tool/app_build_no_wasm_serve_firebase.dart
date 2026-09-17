// Build the web app (javascript, no wasm) and serve it locally with the
// firebase hosting emulator, using the default hosting config in
// deploy/firebase, the one setting the cross origin isolation headers.
//
// dart run tool/app_build_no_wasm_serve_firebase.dart
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

import 'app_build_serve_firebase.dart';

/// Same as [appDevServeFirebaseBuilder] but compiled to javascript.
var appDevNoWasmServeFirebaseBuilder = FlutterFirebaseWebAppBuilder(
  options: appDevServeFirebaseBuilder.options.copyWith(
    buildOptions: FlutterWebAppBuildOptions(wasm: false),
  ),
);

/// Build and serve using `firebase emulators:start --only hosting:dev`
Future<void> main() async {
  await appDevNoWasmServeFirebaseBuilder.buildAndServe();
}
