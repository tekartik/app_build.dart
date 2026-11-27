---
name: tekartik-flutter-build-app-launcher
description: >-
  Use when a Flutter desktop app (linux, macos, windows) must be installable
  as a global command with dart install or dart pub global activate, the
  dart executable building the release of the app sources on the first run
  and launching it, with package:tekartik_flutter_build/app_launcher.dart:
  flutterAppLauncherMain, FlutterAppHostLauncher (build, run,
  buildIfNeededAndRun, runDebug, install, deployPath, deployedExePath,
  isDeployed, macosSandbox), findFlutterAppLauncherSourcePath,
  pubspecLockSourcePath, and the dev menu items of
  package:tekartik_flutter_build/app_build_menu.dart
  menuFlutterAppHostLauncherContent. Also when such an app needs an icon:
  one image (img/app_icon.webp, made from the drawing img/app_icon.svg) the
  launcher turns into the icons of the git ignored macos or windows project
  (package:tekartik_flutter_build/app_icon.dart flutterAppWriteIcons,
  flutterAppIconFromSvg, dart run tekartik_flutter_build:app_icon).
---

# Flutter desktop app as a global command with tekartik_flutter_build

A flutter app cannot be compiled by `dart install`, but its package can hold a
dart executable (`bin/<app>.dart`) that builds the app release from the
package sources and starts it. `flutterAppLauncherMain` is that executable.

## Guidelines

* Add `tekartik_flutter_build` as a regular dependency of the app (the
  executable runs with the package dependencies), `executables: <app>:` in
  `pubspec.yaml`, and a `bin/<app>.dart` calling `flutterAppLauncherMain`
  with the app `packageName` (and `commandName` when the command is not
  named after the package, for the help). The flutter executable built is
  named after the package (the default of `flutter create`).
* Never import `app_launcher.dart` from the app code: it is io only and
  pulls the build tools.
* The arguments before `--` go to the app, the launcher options come after:
  `<app> -- --kill` (`-k`) first kills the running instances of the
  deployed release and their descendants (`ShellProcesses` of process_run:
  sigterm, sigkill after 5s; a single instance app would show the old one),
  `<app> -- --upgrade` (`-u`, or `--pub-upgrade`) kills them too, runs
  `flutter pub upgrade` in the app folder, then rebuilds the release
  before running it (a restart on new sources and dependencies), `<app> -- --help` shows the
  usage. `killTree: false` (`flutterAppLauncherMain`,
  `FlutterAppHostLauncher`, 0.2.5) kills the app only, as if it was closed:
  for an app whose processes must outlive it (sessions held by `dtach`).
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
  other build commands): `buildIfNeededAndRun(arguments:, rebuild:)` builds
  when not deployed, `runDebug()` runs `flutter run` on the host,
  `install()` runs `dart install .` in the sources, `runningPids()` and
  `kill()` find and stop the running deployed release (`ShellProcesses` of
  process_run 1.4.2, the descendants too unless `killTree` is false).
* In `tool/build_menu.dart`, `menuFlutterAppHostLauncherContent(launcher:,
  runArguments: {label: arguments})` adds build and run, build, run, one run
  item per `runArguments` entry, debug run and install; follow it with
  `menuFlutterAppContent(builder: launcher.appBuilder)` of
  tekartik_build_menu_flutter for the other build commands.
* macos: the app is sandboxed by default (`PathAccessException`, `Operation
  not permitted` on any folder not picked by the user). Pass
  `macosSandbox: false` to `flutterAppLauncherMain` and
  `FlutterAppHostLauncher` for a tool opening arbitrary paths; `build`
  applies it to the entitlements of the `macos/` project, call
  `launcher.createHostProject()` before `flavorBuilder.runHost()` for a
  debug run. The release must be rebuilt (`<app> -- -u`).
* App icon (0.2.10): one image in the app package, `img/app_icon.webp` (or
  `img/app_icon.png`; square, 1024 px, the picture filling it, clear corners
  when rounded: 22.5 % of the width is the macOS shape).
  `createHostProject` (so `build` and `runDebug`) makes the icons of the git
  ignored host project from it, in pure Dart, written only when they change:
  the `AppIcon.appiconset` of `macos/` (the picture at 824 of 1024, the
  macOS margin), the `app_icon.ico` of `windows/` (16 to 256 px). On linux
  (0.2.11) a project holds no icon: the launcher writes, in the data folder
  of the user (`~/.local/share`, `FlutterAppHostLauncher.linuxDataHome`),
  `icons/hicolor/256x256/apps/<application id>.png` and the menu entry
  `applications/<application id>.desktop` (the `APPLICATION_ID` of
  `linux/CMakeLists.txt`: the desktop matches the windows to it), replaced
  later only if the launcher wrote it. An app writing its own menu entry
  gives it `Icon=<application id>`. In a test, always pass a
  `linuxDataHome` of the test: the default is the real home of the user.
  Never commit generated icons, nor a platform folder for them.
  A new image needs a rebuild (`<app> -- -u`, or a version bump). Alone:
  `flutterAppWriteIcons(appPath:, iconPath:, platform:)` and
  `findFlutterAppIconPath(appPath)` of
  `package:tekartik_flutter_build/app_icon.dart`.
* The drawing of the icon is kept next to it, `img/app_icon.svg` (square,
  any size). After changing it, run `dart run tekartik_flutter_build:app_icon`
  in the app folder (`flutterAppIconFromSvg(appPath:)`): the svg drawn at
  1024 px into `img/app_icon.webp`, lossless, by `sips` on macOS, else
  `rsvg-convert` or `inkscape`. Commit both files; a build reads the image
  only and never needs a program drawing svg.
* Download packages (Linux): `package:tekartik_flutter_build/linux_package.dart`,
  `flutterLinuxPackage(bundleDir: flutterLinuxReleaseBundleDir(dir), info:
  FlutterLinuxPackageInfo(name:, displayName:, version:, executable:,
  summary:, maintainer:, wmClass:, debDepends:), outputDir:)` after `flutter
  build linux --release`: a `.tar.gz` with `install.sh` (no root) and a
  `.deb` (`/opt/<name>`), each with its sha256. `wmClass` is the
  `APPLICATION_ID` of `linux/CMakeLists.txt` (the menu entry finds the
  window by it). Built on the machine's glibc: older systems need an older
  build machine.
* Download package (Windows): `package:tekartik_flutter_build/windows_package.dart`,
  `flutterWindowsPackage(bundleDir: flutterWindowsReleaseBundleDir(dir),
  info: FlutterWindowsPackageInfo(name:, version:, executable:),
  outputDir:)` after `flutter build windows --release`: the folder
  `<name>-<version>-windows-<arch>` (the bundle and the Visual C++ runtime
  libraries of `flutterWindowsRuntimeDir()`, so it runs without the
  redistributable; `FlutterWindowsPackage.folder` is what an installer
  packs) and its `.zip` with its sha256. `flutterWindowsFileVersion`
  gives the `1.2.3.4` of a `1.2.3+4`. Not signed.

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

### tool/run_release.dart

```dart
import 'package:tekartik_flutter_build/app_launcher.dart';

final launcher = FlutterAppHostLauncher(packageName: 'my_app');

Future<void> main(List<String> arguments) async {
  await launcher.buildIfNeededAndRun(arguments: arguments);
}
```

### tool/build_menu.dart

```dart
import 'package:tekartik_build_menu_flutter/app_build_menu.dart';
import 'package:tekartik_flutter_build/app_build_menu.dart'
    show menuFlutterAppHostLauncherContent;
import 'package:tekartik_flutter_build/app_launcher.dart';

var appLauncher = FlutterAppHostLauncher(packageName: 'my_app');

Future<void> main(List<String> arguments) async {
  mainMenuConsole(arguments, () {
    menuFlutterAppHostLauncherContent(
      launcher: appLauncher,
      runArguments: {'on the current folder': ['.']},
    );
    menuFlutterAppContent(builder: appLauncher.appBuilder);
  });
}
```
