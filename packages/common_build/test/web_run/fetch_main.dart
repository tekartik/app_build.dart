// A web entry point for web_run_test.dart: fetches data/hello.txt, served
// next to the page.
// ignore_for_file: avoid_print
import 'dart:js_interop';

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url);

extension type _Response(JSObject _) implements JSObject {
  external JSPromise<JSString> text();
}

Future<void> main() async {
  var response = await _fetch('data/hello.txt'.toJS).toDart;
  print((await response.text().toDart).toDart.trim());
}
