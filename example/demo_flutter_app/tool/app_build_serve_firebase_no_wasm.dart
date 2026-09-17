// Build the web app (wasm) and serve it locally with the firebase hosting
// emulator, using the deploy/firebase_no_wasm hosting config.
//
// That config does not set the cross origin isolation headers, so the wasm
// renderer runs single-threaded, like on a hosting that has to keep regular
// headers (oauth popups...).
//
// dart run tool/app_build_serve_firebase_no_wasm.dart
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

import 'app_build_serve_firebase.dart';

/// Same as [appDevServeFirebaseBuilder] but served from the no wasm hosting
/// config, copying the build to `deploy/firebase_no_wasm/hosting/public`.
var appDevServeFirebaseNoWasmBuilder = FlutterFirebaseWebAppBuilder(
  options: appDevServeFirebaseBuilder.options.copyWith(
    deployDir: appDevNoWasmHostingDir,
  ),
);

/// Build and serve using `firebase emulators:start --only hosting:dev`
Future<void> main() async {
  await appDevServeFirebaseNoWasmBuilder.buildAndServe();
}
