// Build the web app (wasm) and serve it locally with dhttpd (no firebase
// needed).
//
// dhttpd is always started with the cross origin isolation headers, so the
// multi-threaded wasm renderer is used.
//
// dart run tool/app_build_serve_dhttpd.dart
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

import 'fbm_build_menu.dart';

/// Wasm build, the default.
var appDevServeDhttpdBuildOptions = FlutterWebAppBuildOptions(wasm: true);

/// Plain web app builder, copying the build to `deploy/web`.
var appDevServeDhttpdBuilder = FlutterWebAppBuilder(
  options: FlutterWebAppOptions(
    buildOptions: appDevServeDhttpdBuildOptions,
    path: appDevPath,
  ),
);

/// Build and serve on http://localhost:8080
Future<void> main() async {
  await appDevServeDhttpdBuilder.buildAndServe();
}
