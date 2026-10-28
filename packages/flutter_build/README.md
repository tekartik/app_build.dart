# tekartik_flutter_build.dart

Firebase build and deploy helpers

## Setup

```yaml
dependencies:
  tekartik_flutter_build:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/flutter_build
```

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
my_app -- --upgrade       # rebuild the app, then run it
```

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
