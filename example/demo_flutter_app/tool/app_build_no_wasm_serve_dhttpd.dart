// Build the web app (javascript, no wasm) and serve it locally with dhttpd
// (no firebase needed).
//
// dart run tool/app_build_no_wasm_serve_dhttpd.dart
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

import 'app_build_serve_dhttpd.dart';

/// Same as [appDevServeDhttpdBuilder] but compiled to javascript.
var appDevNoWasmServeDhttpdBuilder = FlutterWebAppBuilder(
  options: appDevServeDhttpdBuilder.options.copyWith(
    buildOptions: FlutterWebAppBuildOptions(wasm: false),
  ),
);

/// Build and serve on http://localhost:8080
Future<void> main() async {
  await appDevNoWasmServeDhttpdBuilder.buildAndServe();
}
