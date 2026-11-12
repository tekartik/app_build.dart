# tekartik_apple_build

Apple build and run helpers, from Dart `tool/` scripts (io only, macOS
hosts):

- `ios_simulator.dart`: the iOS simulators of `xcrun simctl`, listed (latest
  runtime first), chosen (a UDID or a name, the booted one, the first iPhone
  of the latest runtime), booted (`simctl bootstatus -b`, shown in DeviceHub
  on Xcode 27+ unless headless) and shut down; `withIosSimulator` runs an
  action on one, shutting down the one it booted.
- `xcode.dart`: the selected Xcode developer folder (`xcode-select -p`), its
  simulator app (`DeviceHub.app` on Xcode 27+, `Simulator.app` before) and
  its version (`xcodebuild -version`).
- `macos.dart`: the macOS host version (`sw_vers`), opening an app
  (`open -a`).

The agent skill: `skills/tekartik-apple-build`. The Android twin is
[tekartik_android_utils](https://github.com/tekartik/android_utils.dart)
(`emulator_utils.dart`, `withAndroidDevice`). Both are used by the target
devices of `tekartik_flutter_build` (`device_test.dart`).

## Getting started

```yaml
dev_dependencies:
  tekartik_apple_build:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/apple_build
```

```dart
import 'package:process_run/shell.dart';
import 'package:tekartik_apple_build/ios_simulator.dart';

Future<void> main() async {
  // The booted simulator, or the iPhone 17 booted then shut down.
  await withIosSimulator((simulator) async {
    await run('flutter test integration_test -d ${simulator.udid}');
  }, simulator: 'iPhone 17');
}
```

`listIosSimulators()` gives the simulators to pick from (a UI), their UDID
being the `simulator` of `withIosSimulator` and the `-d` of `flutter`.

## Manual test

`test/ios_simulator_test_manual.dart` runs `withIosSimulator` on a real
simulator: the booted one, else one booted then shut down, its information
printed. Not a `_test.dart` file, so `dart test` and the CI never run it:

```bash
dart test test/ios_simulator_test_manual.dart
# A given simulator (a name or a UDID)
TK_APPLE_BUILD_SIMULATOR="iPhone 17" dart test test/ios_simulator_test_manual.dart
```
