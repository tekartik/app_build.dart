# tekartik_app_build_demo_flutter_app

A new Flutter project.

## Build and serve the web app

The `tool` folder holds the app_build entry points. `_no_wasm` marks the non
default choices, for the build (javascript instead of wasm) and for the hosting
config (`deploy/firebase_no_wasm`, without the cross origin isolation headers,
instead of `deploy/firebase`):

- `dart run tool/app_build_serve_dhttpd.dart`: wasm build, served by dhttpd
- `dart run tool/app_build_no_wasm_serve_dhttpd.dart`: js build, served by dhttpd
- `dart run tool/app_build_serve_firebase.dart`: wasm build on the wasm hosting config
- `dart run tool/app_build_serve_firebase_no_wasm.dart`: wasm build on the no wasm hosting config
- `dart run tool/app_build_no_wasm_serve_firebase.dart`: js build on the wasm hosting config
- `dart run tool/app_build_no_wasm_serve_firebase_no_wasm.dart`: js build on the no wasm hosting config
- `dart run tool/fbm_build_menu.dart`: interactive web build menu
- `dart run tool/ffbm_build_menu.dart`: interactive firebase build/deploy menu

dhttpd always serves the cross origin isolation headers, so it has no hosting
variant.

The home page displays `debugEnvMap` so the build mode (debug/release) and
compilation target (js/wasm) can be checked at runtime.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
