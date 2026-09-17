// Build the web app (javascript, no wasm) and serve it locally with the
// firebase hosting emulator, using the deploy/firebase_no_wasm hosting config,
// the one not setting the cross origin isolation headers.
//
// This is the regular deployed setup.
//
// dart run tool/app_build_no_wasm_serve_firebase_no_wasm.dart
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

import 'app_build_no_wasm_serve_firebase.dart';
import 'app_build_serve_firebase.dart';

/// Same as [appDevNoWasmServeFirebaseBuilder] but served from the no wasm
/// hosting config, copying the build to
/// `deploy/firebase_no_wasm/hosting/public`.
var appDevNoWasmServeFirebaseNoWasmBuilder = FlutterFirebaseWebAppBuilder(
  options: appDevNoWasmServeFirebaseBuilder.options.copyWith(
    deployDir: appDevNoWasmHostingDir,
  ),
);

/// Build and serve using `firebase emulators:start --only hosting:dev`
Future<void> main() async {
  await appDevNoWasmServeFirebaseNoWasmBuilder.buildAndServe();
}
