// Build the web app (wasm) and serve it locally with the firebase hosting
// emulator, using the default hosting config in deploy/firebase.
//
// That config sets the cross origin isolation headers, so the multi-threaded
// wasm renderer is used.
//
// dart run tool/app_build_serve_firebase.dart
import 'package:path/path.dart';
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

import 'fbm_build_menu.dart';

/// Hosting config setting the cross origin isolation headers needed by wasm,
/// the default.
var appDevHostingDir = join('deploy', 'firebase', 'hosting');

/// Hosting config not setting them, i.e. the regular deployed headers.
var appDevNoWasmHostingDir = join('deploy', 'firebase_no_wasm', 'hosting');

/// Wasm build, the default.
var appDevServeFirebaseBuildOptions = FlutterWebAppBuildOptions(wasm: true);

/// Firebase hosting builder, copying the build to
/// `deploy/firebase/hosting/public`.
var appDevServeFirebaseBuilder = FlutterFirebaseWebAppBuilder(
  options: FlutterFirebaseWebAppOptions(
    buildOptions: appDevServeFirebaseBuildOptions,
    path: appDevPath,
    deployOptions: appDevDeployOptions,
    deployDir: appDevHostingDir,
  ),
);

/// Build and serve using `firebase emulators:start --only hosting:dev`
Future<void> main() async {
  await appDevServeFirebaseBuilder.buildAndServe();
}
