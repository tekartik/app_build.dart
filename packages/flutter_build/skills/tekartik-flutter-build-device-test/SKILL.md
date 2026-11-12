---
name: tekartik-flutter-build-device-test
description: >-
  Use when the tests of a Flutter app (integration_test) must run from a Dart
  tool script or a UI on a device of a target, the device found or launched
  for the run (an Android emulator, an iOS simulator shown in DeviceHub, the
  host desktop), with package:tekartik_flutter_build/device_test.dart:
  FlutterDeviceTarget (hostTargets, host, isSupportedOnHost),
  withFlutterTargetDevice, FlutterTargetDeviceOptions (serial, avd,
  simulator, keep, noWindow), listFlutterTargetDeviceCandidates,
  FlutterTargetDeviceCandidate.select, FlutterTargetDeviceException,
  flutterCreatePlatformsIfMissing, runFlutterDeviceTest, runTestJsonCommand,
  TestJsonSummary, TestJsonReporterParser.
---

# Flutter tests on a device with tekartik_flutter_build

`flutter test integration_test -d <id>` needs a running device.
`withFlutterTargetDevice` finds or launches one for a target, runs an
action with its id, then stops what it launched.

## Guidelines

* Targets: `FlutterDeviceTarget.android`, `ios`, `linux`, `macos`,
  `windows`. `FlutterDeviceTarget.hostTargets` lists the ones this host
  supports (android, ios on macOS, the host desktop);
  `FlutterDeviceTarget.host` is the desktop one.
* The device: android, the `serial` or `avd` of
  `FlutterTargetDeviceOptions`, else the first online emulator or device,
  else the only AVD launched (tekartik_android_utils `withAndroidDevice`,
  call order: `initAndroidBuildEnvironment` is done for you); ios, the
  `simulator` (UDID or name), else the booted one, else the first iPhone of
  the latest runtime booted (tekartik_apple_build `withIosSimulator`,
  `simctl bootstatus -b`, DeviceHub opened unless `noWindow`); desktop, the
  host (`device.id` is `macos`...).
* `keep: true` leaves a launched device running (the next run reuses it, a
  booted simulator or an online emulator being preferred).
* Several apps on one device: run them all inside the same action, not one
  `withFlutterTargetDevice` per app (each would launch and stop the
  emulator).
* No device chosen (several AVDs and nothing online, an unknown simulator,
  a target not supported on the host): a `FlutterTargetDeviceException`
  with `message` and `candidates`. A CLI prints the message (it names the
  option to give); a UI shows `listFlutterTargetDeviceCandidates(target)`
  and runs again with `candidate.select(options)`.
* Create the platform folders before launching a device (not to keep it
  waiting): `flutterCreatePlatformsIfMissing(path, [target.platform],
  arguments: ['--org', 'com.tekartik', '--empty'])`. It keeps `.metadata`
  and removes the counter sample `test/widget_test.dart` flutter create adds
  to a project without tests.
* `runFlutterDeviceTest(path, deviceId:, test:, plainName:)` runs
  `flutter test <test> -d <id> -r json`: the failures are printed as they
  come, the build output as is; its `summary` (`TestJsonSummary`) has the
  passed, skipped and failed counts, the failures, and `done` false when the
  command failed before the end (a build error). `isSuccess` needs at least
  one test passed. `runTestJsonCommand` does the same for any command (a
  `dart test -p chrome -r json`).

## Example

```dart
import 'package:tekartik_flutter_build/device_test.dart';

Future<void> main() async {
  var apps = ['app1', 'app2'];
  for (var target in FlutterDeviceTarget.hostTargets) {
    for (var app in apps) {
      await flutterCreatePlatformsIfMissing(app, [target.platform]);
    }
    try {
      await withFlutterTargetDevice(target, (device) async {
        for (var app in apps) {
          var result = await runFlutterDeviceTest(app, deviceId: device.id);
          print('$app ${target.name}: ${result.summary}');
        }
      });
    } on FlutterTargetDeviceException catch (e) {
      print('$e, choose: ${e.candidates.join(', ')}');
    }
  }
}
```

## Pitfalls

* ios and macos need a macOS host with Xcode; ios uses the simulators
  (`xcrun simctl`), not the phones.
* An old tracked `ios/` (CocoaPods era) can fail the build with "Unable to
  start the app on the device": the platform folders are best generated and
  git ignored.
* A test timing out shows as a failure with a `TimeoutException` error, the
  run goes on.
