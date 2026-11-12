---
name: tekartik-apple-build
description: >-
  Use when a Dart tool script must list, boot, show (DeviceHub on Xcode
  27+) or shut down iOS simulators, find the selected Xcode (developer
  folder, simulator app, version) or the macOS host version, or open a
  macOS app, with package:tekartik_apple_build: ios_simulator.dart
  (listIosSimulators, iosSimulatorChooseTarget, bootIosSimulator,
  shutdownIosSimulator, showIosSimulatorApp, withIosSimulator), xcode.dart
  (getXcodeDeveloperPath, getXcodeSimulatorAppPath, getXcodeVersion),
  macos.dart (getMacosVersion, openMacosApp).
---

# iOS simulators, Xcode and the macOS host with tekartik_apple_build

io only, macOS hosts (the getters return `null` elsewhere). To run flutter
tests on a simulator, prefer `withFlutterTargetDevice` of
`tekartik_flutter_build/device_test.dart`, which uses this package.

## Guidelines

* `listIosSimulators()` reads `xcrun simctl list devices available -j`, the
  latest iOS runtime first; `IosSimulator.udid` is the `flutter -d` id.
* `iosSimulatorChooseTarget(simulators, simulator:)` (pure): a UDID, else a
  name (booted first, else the latest runtime), else the booted one, else the
  first iPhone of the latest runtime; a `StateError` when none matches.
* `withIosSimulator(action, simulator:, keep:, noWindow:)` boots the chosen
  simulator when needed (`simctl bootstatus -b`, which waits for the end of
  the boot), opens DeviceHub unless `noWindow` (headless works the same),
  runs `action`, then shuts down the simulator it booted unless `keep`.
* Xcode 27 has no `Simulator.app`: `getXcodeSimulatorAppPath()` returns
  `<Xcode.app>/Contents/Applications/DeviceHub.app`, `Simulator.app` on an
  older Xcode.
* The macOS project of a flutter app (entitlements, sandbox) is
  `MacosProject` of tekartik_build_flutter, not here.
