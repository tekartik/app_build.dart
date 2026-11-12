import 'dart:async';
import 'dart:io';

import 'package:process_run/shell.dart';

import 'test_json_reporter.dart';

/// The result of [runTestJsonCommand].
class TestJsonRunResult {
  /// The summary of the json reporter output, `done` being `false` when the
  /// command failed without a json `done` event (a build error).
  final TestJsonSummary summary;

  /// The exit code of the command.
  final int exitCode;

  /// The [summary] of a command ending with [exitCode].
  TestJsonRunResult(this.summary, this.exitCode);

  /// `true` when the run ended with success ([TestJsonSummary.isSuccess]).
  bool get isSuccess => summary.isSuccess;

  @override
  String toString() => '$summary (exit code $exitCode)';
}

/// [summary] marked as not done when the command failed ([exitCode]) without
/// a json `done` event.
TestJsonSummary testJsonSummaryCheckExitCode(
  TestJsonSummary summary,
  int exitCode,
) {
  if (exitCode != 0 && summary.done == null) {
    return TestJsonSummary(
      passed: summary.passed,
      failed: summary.failed,
      skipped: summary.skipped,
      failures: summary.failures,
      done: false,
    );
  }
  return summary;
}

/// Runs [executable] with [arguments] (a `dart test` or `flutter test` with
/// `-r json`) in [workingDirectory], parsing its json reporter output as it
/// comes.
///
/// The failures (and the test prints when [verbose]) are written to stdout
/// as they come, the other lines (the build output) as is. [onTestDone] is
/// called for each visible test done.
Future<TestJsonRunResult> runTestJsonCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool verbose = false,
  void Function(TestJsonTestDone test)? onTestDone,
}) async {
  var parser = TestJsonReporterParser();
  var output = ShellLinesController();
  var subscription = output.stream.listen((line) {
    if (TestJsonReporterParser.isJsonEvent(line)) {
      var done = parser.addLine(line);
      if (done != null) {
        onTestDone?.call(done);
        if (done.isFailure) {
          stdout.writeln('FAIL ${done.name}');
          var error = done.error;
          if (error != null) {
            stdout.writeln('  ${error.split('\n').first}');
          }
        }
      } else if (verbose && line.contains('"type":"print"')) {
        stdout.writeln(line);
      }
    } else if (line.trim().isNotEmpty) {
      stdout.writeln(line);
    }
  });
  var shell = Shell(
    workingDirectory: workingDirectory,
    stdout: output.sink,
    verbose: false,
    commandVerbose: true,
    throwOnError: false,
  );
  int exitCode;
  try {
    var result = await shell.runExecutableArguments(executable, arguments);
    exitCode = result.exitCode;
  } on ShellException catch (e) {
    stderr.writeln(e.message);
    exitCode = e.result?.exitCode ?? 1;
  } finally {
    output.close();
    await subscription.cancel();
  }
  return TestJsonRunResult(
    testJsonSummaryCheckExitCode(parser.summary, exitCode),
    exitCode,
  );
}

/// The `flutter test` arguments of [runFlutterDeviceTest].
List<String> flutterDeviceTestArguments({
  required String deviceId,
  String test = 'integration_test',
  String? plainName,
  List<String> arguments = const [],
}) => [
  'test',
  test,
  '-d',
  deviceId,
  '-r',
  'json',
  if (plainName != null) ...['--plain-name', plainName],
  ...arguments,
];

/// Runs `flutter test <test> -d <deviceId> -r json` in [projectPath] (an
/// integration test file or folder, `integration_test` by default), see
/// [runTestJsonCommand].
///
/// [plainName] runs only the tests whose name contains it, [arguments] are
/// added to the command line.
Future<TestJsonRunResult> runFlutterDeviceTest(
  String projectPath, {
  required String deviceId,
  String test = 'integration_test',
  String? plainName,
  List<String> arguments = const [],
  bool verbose = false,
  void Function(TestJsonTestDone test)? onTestDone,
}) => runTestJsonCommand(
  'flutter',
  flutterDeviceTestArguments(
    deviceId: deviceId,
    test: test,
    plainName: plainName,
    arguments: arguments,
  ),
  workingDirectory: projectPath,
  verbose: verbose,
  onTestDone: onTestDone,
);
