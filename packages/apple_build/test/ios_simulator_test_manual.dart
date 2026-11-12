// Manual test on a real iOS simulator (macOS host with Xcode), not run by
// `dart test` (not a `_test.dart` file):
//
//   dart test test/ios_simulator_test_manual.dart
//
// Uses the booted simulator, else boots one then shuts it down, and prints
// its information. TK_APPLE_BUILD_SIMULATOR=<name or UDID> picks the
// simulator (read through process_run, so it can also be set in the user
// environment: `ds env var set TK_APPLE_BUILD_SIMULATOR "iPhone 17"`).
@TestOn('vm')
library;

import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:tekartik_apple_build/apple_build.dart';
import 'package:test/test.dart';

/// The simulator to use, a name or a UDID.
const _simulatorEnvKey = 'TK_APPLE_BUILD_SIMULATOR';

Future<IosSimulator> _current(String udid) async =>
    (await listIosSimulators()).firstWhere((s) => s.udid == udid);

void main() {
  var simulatorName = ShellEnvironment().vars[_simulatorEnvKey];

  test(
    'withIosSimulator: the running one, else one booted then shut down',
    () async {
      stdout.writeln('${await getXcodeVersion()}');
      stdout.writeln('macOS ${(await getMacosVersion())?.join('.')}');
      stdout.writeln('Simulator app: ${await getXcodeSimulatorAppPath()}');

      var before = await listIosSimulators();
      var booted = before.where((s) => s.isBooted).toList();
      stdout.writeln(
        'Booted before: ${booted.isEmpty ? 'none' : booted.join(', ')}',
      );
      var expected = iosSimulatorChooseTarget(before, simulator: simulatorName);
      stdout.writeln(
        'Chosen: $expected (${expected.isBooted ? 'running, reused' : 'to boot'})',
      );

      var udid = await withIosSimulator(
        (simulator) async {
          var current = await _current(simulator.udid);
          stdout.writeln('Running simulator:');
          stdout.writeln('  name:        ${current.name}');
          stdout.writeln('  udid:        ${current.udid}');
          stdout.writeln('  iOS:         ${current.iosVersion.join('.')}');
          stdout.writeln('  runtime:     ${current.runtime}');
          stdout.writeln('  device type: ${current.deviceType}');
          stdout.writeln('  state:       ${current.state}');
          stdout.writeln(
            '  launched:    ${simulator.launched} '
            '(${simulator.launched ? 'booted for the test' : 'already running'})',
          );
          var model = await Shell(verbose: false).runExecutableArguments(
            'xcrun',
            ['simctl', 'getenv', simulator.udid, 'SIMULATOR_MODEL_IDENTIFIER'],
          );
          stdout.writeln('  model:       ${model.outText.trim()}');

          expect(simulator.udid, expected.udid);
          expect(simulator.launched, !expected.isBooted);
          expect(current.isBooted, isTrue);
          return simulator.udid;
        },
        simulator: simulatorName,
        onLaunching: (simulator) => stdout.writeln('Booting $simulator...'),
      );

      var after = await _current(udid);
      stdout.writeln('After: ${after.name} ${after.state}');
      // Left as it was: shut down when booted for the test, running otherwise.
      expect(after.isBooted, expected.isBooted);
    },
    skip: Platform.isMacOS ? false : 'macOS host only',
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
