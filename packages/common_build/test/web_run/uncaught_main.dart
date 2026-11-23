// A web entry point for web_run_test.dart: completes, but an error escapes
// it (not awaited).
import 'dart:async';

void main() {
  unawaited(Future<void>.error(ArgumentError('escaped on purpose')));
  Timer(const Duration(seconds: 30), () {});
}
