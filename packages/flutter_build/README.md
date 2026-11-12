# tekartik_flutter_build

Build helpers for Flutter apps, from Dart `tool/` scripts and `dev_build`
console menus:

- a web app: `flutter build web` (`--wasm`, `--target`), the copy of
  `build/web` to a deploy folder, a local server, `flutter run -d chrome`,
  a deploy through a `WebAppDeployer`, the js and wasm size report;
- a check that a client build (web, apk, aab, ipa) holds none of the
  secrets of the server code;
- a desktop app installed as a global command (`dart install`), built from
  its sources on the first run;
- the tests of an app on a device of a target (android, ios, the host
  desktop), the device found or launched for the run.

Dart VM only (Linux, macOS, Windows): it runs the `flutter` command. The app
itself never imports it. The Firebase hosting variant is
`tekartik_firebase_build` (same repository).

## Getting started

A git dependency (not on pub.dev), a dev dependency of the app (a regular
one for the desktop launcher, which runs with the app dependencies):

```yaml
dev_dependencies:
  tekartik_flutter_build:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/flutter_build
```

Build the web app of the current folder and copy it to `deploy/web`:

```dart
// tool/build_web.dart
import 'package:tekartik_flutter_build/app_build.dart';

Future<void> main() async {
  var builder = FlutterWebAppBuilder(
    options: FlutterWebAppOptions(
      buildOptions: FlutterWebAppBuildOptions(wasm: true),
    ),
  );
  // flutter build web --wasm, then build/web copied to deploy/web.
  await builder.build();
}
```

The entry point is `lib/main_web.dart` when the app has one, `lib/main.dart`
otherwise (`FlutterWebAppBuildOptions.target` to choose).

## What to use

| Api | Does |
| --- | --- |
| `FlutterWebAppBuilder` | `buildOnly`, `build` (+ copy to `deployDir`), `serve`, `run`, `deploy`, `clean`, `reportJsSize` |
| `menuFlutterWebAppContent(builders:)` (`app_build_menu.dart`) | the menu items of one or several web builders |
| `buildFindSecrets`, `buildCheckNoSecrets` (`build_secrets.dart`) | searches a build folder, an apk, an aab or an ipa for `BuildSecret` values |
| `flutterWebAppsBuildSize`, `flutterWebBuildSizeWriteReport` | builds several apps and writes a markdown size report |
| `flutterAppLauncherMain`, `FlutterAppHostLauncher` (`app_launcher.dart`) | the desktop app as a global command, below |
| `withFlutterTargetDevice`, `runFlutterDeviceTest` (`device_test.dart`) | the tests of an app on a device found or launched, below |

A web build failing when it holds a server secret
(`FlutterWebAppBuildOptions.secrets`, checked after each `buildOnly`):

```dart
import 'package:tekartik_flutter_build/app_build.dart';

// In practice the map comes from the server code holding the values.
var serverSecrets = {'apiKey': 'my-server-only-api-key'};

Future<void> main() async {
  var builder = FlutterWebAppBuilder(
    options: FlutterWebAppOptions(
      buildOptions: FlutterWebAppBuildOptions(
        secrets: BuildSecret.fromMap(serverSecrets),
      ),
    ),
  );
  // Throws a BuildSecretsFoundException before anything is copied.
  await builder.build();
  // An android build: await buildCheckNoSecrets(apkPath, secrets);
}
```

A value is searched as UTF-8, as the escaped literal dart2js writes (a
newline, a quote, a backslash, a non ASCII character), as Latin-1 and
UTF-16LE (the strings of an AOT snapshot). A value decrypted at run time is
not in the build as such: list what the code writes too.

## Desktop app as a global command

`package:tekartik_flutter_build/app_launcher.dart` turns a flutter desktop
app into a command installed with `dart install` or `dart pub global
activate`: `bin/<app>.dart` builds the release of the app sources
(`deploy/<platform>`) on the first run and launches it.

```dart
// bin/my_app.dart, with `executables: my_app:` in pubspec.yaml
import 'package:tekartik_flutter_build/app_launcher.dart';

Future<void> main(List<String> arguments) => flutterAppLauncherMain(
  arguments,
  packageName: 'my_app',
  appArgumentsUsage: '[folder]',
);
```

```bash
dart install "my_app@{path: $PWD}"     # or dart pub global activate --source path .
my_app .                  # the arguments go to the app
my_app -- --upgrade       # kill the running app, rebuild it, then run it
my_app -- --kill          # kill the running app first, then run it
```

`--kill` and `--upgrade` kill the processes the app started too; an app
whose processes must outlive it (sessions held by `dtach`) passes `killTree:
false` to `flutterAppLauncherMain`: only the app is killed, as if closed.

`FlutterAppHostLauncher` builds (`build`) and runs (`run`,
`buildIfNeededAndRun`) the deployed release from `tool/` scripts, runs the
debug version (`runDebug`) and installs the command (`install`, `dart install
.` of the sources). `menuFlutterAppHostLauncherContent` (`app_build_menu.dart`)
adds these to a dev menu:

```dart
// tool/build_menu.dart
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

On macos the app is sandboxed (the flutter default) and cannot open a folder
given on the command line: `macosSandbox: false` (both
`flutterAppLauncherMain` and `FlutterAppHostLauncher`) disables the sandbox
in the entitlements of the (git ignored) `macos/` project before each build.

## Tests on a device

`package:tekartik_flutter_build/device_test.dart` runs `flutter test` on a
device of a `FlutterDeviceTarget`:

- android: the online device or emulator, else an AVD launched then stopped
  (`withAndroidDevice` of tekartik_android_utils);
- ios (macOS hosts): the booted simulator, else the first iPhone of the
  latest runtime booted then shut down, shown in DeviceHub on Xcode 27+
  (`withIosSimulator` of tekartik_apple_build);
- linux, macos, windows: the host.

```dart
import 'package:tekartik_flutter_build/device_test.dart';

Future<void> main() async {
  var path = '.';
  for (var target in FlutterDeviceTarget.hostTargets) {
    await flutterCreatePlatformsIfMissing(path, [target.platform]);
    var result = await withFlutterTargetDevice(
      target,
      (device) => runFlutterDeviceTest(path, deviceId: device.id),
      options: const FlutterTargetDeviceOptions(noWindow: true),
    );
    print('${target.name}: ${result.summary}');
  }
}
```

One device serves several runs when they are in the same action. When no
device can be chosen (several AVDs and nothing online, an unknown
simulator) a `FlutterTargetDeviceException` holds the `candidates`; a UI
lists them (`listFlutterTargetDeviceCandidates`) and runs again with
`candidate.select(options)`.

`flutterCreatePlatformsIfMissing` keeps the `.metadata` and removes the
counter sample test `flutter create` adds to a project without tests. The
`flutter test -r json` output is parsed as it comes (`TestJsonSummary`:
passed, skipped, failed, the failures, `done` false on a build error).

## Pitfalls

- `deployDir` (`deploy/web` by default) is deleted then filled by each copy:
  never point it at a folder holding anything else.
- `run()` without a controller forwards stdin to `flutter run` and closes
  it when it exits: make it the last step of a script.
- A `BuildShellController` must be given its shell
  (`BuildShellController(shell: Shell(workingDirectory: path))`), every
  command runs through it.
- The size report counts the dart output only (not `canvaskit/`); a build
  made with `--source-maps` counts the `.part.js.map` files as parts.

The agent skills of this package: `skills/tekartik-flutter-build-web`,
`skills/tekartik-flutter-build-app-launcher` and
`skills/tekartik-flutter-build-device-test`.
