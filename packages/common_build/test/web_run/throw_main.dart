// A web entry point for web_run_test.dart: throws after an await.

Future<void> main() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  throw StateError('failed on purpose');
}
