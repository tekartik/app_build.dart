---
name: tekartik-flutter-build-app-launcher
description: >-
  Use when a Flutter desktop app (linux, macos, windows) must be installable
  as a global command with dart install or dart pub global activate, the
  dart executable building the release of the app sources on the first run
  and launching it, with package:tekartik_flutter_build/app_launcher.dart:
  flutterAppLauncherMain, FlutterAppHostLauncher (build, run, deployPath,
  deployedExePath, isDeployed, macosSandbox), findFlutterAppLauncherSourcePath,
  pubspecLockSourcePath.
---

# Flutter desktop app as a global command with tekartik_flutter_build

A flutter app cannot be compiled by `dart install`, but its package can hold a
dart executable (`bin/<app>.dart`) that builds the app release from the
package sources and starts it. `flutterAppLauncherMain` is that executable.

## Guidelines

* Add `tekartik_flutter_build` as a regular dependency of the app (the
  executable runs with the package dependencies), `executables: <app>:` in
  `pubspec.yaml`, and a `bin/<app>.dart` calling `flutterAppLauncherMain`
  with the app `packageName`. The flutter executable built is named after the
  package (the default of `flutter create`).
* Never import `app_launcher.dart` from the app code: it is io only and
  pulls the build tools.
* The arguments before `--` go to the app, the launcher options come after:
  `<app> -- --upgrade` (`-u`) rebuilds the release before running it,
  `<app> -- --help` shows the usage.
* The release is built with `flutter build <host platform>` and copied to
  `deploy/<platform>` of the sources (git ignore `deploy/`); the platform
  project is created when missing. It runs from there so that a `flutter
  clean` in the sources does not break the installed command.
* Sources: with `dart run` or `dart pub global activate` (path or git) they
  are found from the package config, through `libraryPath` (`main.dart` by
  default, any library of the app); with `dart install` (AOT) from the
  `pubspec.lock` next to the installed bundle, a local path or the git
  checkout in the pub cache.
* `FlutterAppHostLauncher(packageName:, path:)` gives the same build and run
  to `tool/` scripts and dev menus (`appBuilder`, `flavorBuilder` for the
  other build commands).
* macos: the app is sandboxed by default (`PathAccessException`, `Operation
  not permitted` on any folder not picked by the user). Pass
  `macosSandbox: false` to `flutterAppLauncherMain` and
  `FlutterAppHostLauncher` for a tool opening arbitrary paths; `build`
  applies it to the entitlements of the `macos/` project, call
  `launcher.createHostProject()` before `flavorBuilder.runHost()` for a
  debug run. The release must be rebuilt (`<app> -- -u`).

## Examples

### bin/my_app.dart

```dart
import 'package:tekartik_flutter_build/app_launcher.dart';

/// `my_app [folder] [-- --upgrade]`.
Future<void> main(List<String> arguments) => flutterAppLauncherMain(
  arguments,
  packageName: 'my_app',
  appArgumentsUsage: '[folder]',
  description: 'Opens a folder in my app.',
);
```

### tool/build_and_run_release.dart

```dart
import 'package:tekartik_flutter_build/app_launcher.dart';

final launcher = FlutterAppHostLauncher(packageName: 'my_app');

Future<void> main(List<String> arguments) async {
  if (!launcher.isDeployed) {
    await launcher.build();
  }
  await launcher.run(arguments);
}
```
