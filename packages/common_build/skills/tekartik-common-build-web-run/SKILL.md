---
name: tekartik-common-build-web-run
description: >-
  Use when a Dart program meant for the web (a regular main(): a demo, a
  check, a sound example) must run in a real browser from the command line
  or from a VM test, compiled with dart2js or dart2wasm, with webRun or
  `dart run tekartik_common_build:web_run` from
  package:tekartik_common_build/web_run.dart (headless Chrome, its console
  forwarded, the run ends when main completes).
---

# tekartik_common_build: webRun

* Add `tekartik_common_build` as a dev dependency (git,
  `https://github.com/tekartik/app_build.dart`, `packages/common_build`),
  `dart pub get` (the package config is needed).
* Command line, in the package: `dart run tekartik_common_build:web_run
  example/main.dart` (`--wasm` for dart2wasm, `--mute` for
  `--mute-audio`, `--timeout <s>`, then the args of `main`); exit code 0,
  or 1 with the error on stderr.
* From a VM test: `await webRun('example/main.dart', compiler:
  WebRunCompiler.wasm, args: [...], onOut: lines.add)`; throws a
  `WebRunException` (compile error, uncaught error in or right after
  `main`, a script that did not load, the timeout, no Chrome). Skip the
  test when `findChromeExecutable()` throws a `StateError`.
* The file is any entry point (`main()` or `main(List<String> args)`, sync
  or async, may print): a generated entry point in
  `.dart_tool/tekartik_common_build/web_run/` imports it, so a file shared
  by the VM and the web runs as is; its relative imports and conditional
  imports (`if (dart.library.js_interop)`) work.
* `files: {served path: local file}` (`--file served=local`) serves more
  files next to the page: a web worker script, an asset fetched by a
  relative url.
* `print` and `console.log` go to `onOut` (stdout), `console.error` and
  uncaught exceptions to `onErr` (stderr).
* Chrome: `findChromeExecutable` (`CHROME_EXECUTABLE`, then Chrome or
  Chromium on the path, the macOS app), a temporary profile (IndexedDB
  starts empty), `--autoplay-policy=no-user-gesture-required` (Web Audio
  plays without a gesture); on Linux `PULSE_SINK=<sink>` routes its sound.
