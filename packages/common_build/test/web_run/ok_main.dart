// A web entry point for web_run_test.dart: prints its args, completes
// after a delay.
// ignore_for_file: avoid_print

Future<void> main(List<String> args) async {
  print('hello ${args.join(',')}');
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('done');
}
