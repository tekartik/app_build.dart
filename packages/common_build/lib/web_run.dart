/// Runs a Dart web entry point (a regular `main`) in a headless Chrome from
/// the VM: [webRun] compiles it (dart2js or dart2wasm) behind a generated
/// page, forwards the page's console and completes when `main` completes
/// (a [WebRunException] when it fails). Dart VM only.
///
/// Command line: `dart run tekartik_common_build:web_run [--wasm] file.dart
/// [args...]`.
library;

export 'src/web_run.dart' show WebRunCompiler, WebRunException, webRun;
