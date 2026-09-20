---
name: tekartik-firebase-build-flutterfire
description: >-
  Use when a Dart tool/ script must (re)generate the firebase options of a
  flutter app (lib/firebase_options.dart, or one
  lib/firebase_options_<flavor>.dart per flavor) from its firebase project by
  running the flutterfire cli, with
  package:tekartik_firebase_build/flutterfire_configure.dart:
  FirebaseFlutterProjectBuilder (configure, configureCommand, flavor,
  flavorFirebaseOptionsFile, defaultFirebaseOptionsFile) and
  FirebaseFlutterProjectOptions (projectId, path, platforms,
  firebaseOptionsFile).
---

# tekartik_firebase_build: flutterfire configure per flavor

`package:tekartik_firebase_build/flutterfire_configure.dart` runs
`flutterfire configure` on a flutter app for you, with the options that make
multi-flavor apps work: one firebase project and one generated dart file per
flavor, a fixed platform list, no interactive prompt. It only builds and runs
the command line; the generated file is the standard `DefaultFirebaseOptions`
class of the flutterfire cli. Dart VM only.

## Guidelines

* Dependency: the `tekartik_firebase_build` git block
  (`url: https://github.com/tekartik/app_build.dart`, `path:
  packages/firebase_build`), typically a dev dependency of the app.
* Tools: `dart pub global activate flutterfire_cli`, the `firebase` cli
  logged in (`firebase login`) with access to the project, and the apps
  (web app, android package, ios bundle) already registered on the firebase
  project for every platform requested; `flutterfire` creates missing ones
  interactively otherwise, so register them in the console first for
  non-interactive runs.
* Import `package:tekartik_firebase_build/flutterfire_configure.dart`:
  `FirebaseFlutterProjectBuilder`, `FirebaseFlutterProjectOptions`.
* `FirebaseFlutterProjectOptions({projectId, path, platforms,
  firebaseOptionsFile})`: `projectId` is the firebase project
  (`--project`), `path` the flutter app (default `'.'`, made absolute),
  `platforms` the `--platforms` list (`['web']`, `['android', 'ios',
  'web']`; empty means every platform of the app), `firebaseOptionsFile`
  the generated file relative to the app (`--out`), default
  `FirebaseFlutterProjectBuilder.defaultFirebaseOptionsFile`
  (`lib/firebase_options.dart`).
  `FirebaseFlutterProjectOptions.flavor(projectId:, flavor:, path:,
  platforms:)` targets `lib/firebase_options_<flavor>.dart`
  (`FirebaseFlutterProjectBuilder.flavorFirebaseOptionsFile(flavor)`).
  `copyWith(...)` on all fields.
* `FirebaseFlutterProjectBuilder(options:)` or the shortcut
  `FirebaseFlutterProjectBuilder.flavor(projectId:, flavor:, path:,
  platforms:)`. `configure({overwrite = true, yes = false})` runs
  `flutterfire configure --project=<id> [--platforms=a,b] --out=<file>
  [--overwrite-firebase-options] [--yes]` in the app folder;
  `configureCommand(overwrite:, yes:)` returns that command line without
  running it (log it, test it). `overwrite: false` keeps an existing file;
  `yes: true` accepts the prompts (CI).
* One builder per flavor, each with the project of the flavor
  (`my-app-dev`, `my-app-prod`); the app then imports the file of its
  flavor (`lib/firebase_options_dev.dart` from `main_dev.dart`) and calls
  `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
  Regenerate after adding a platform or an app to the project; commit the
  generated files (they hold public api keys, not secrets).
* `flutterfire` may also touch `android/app/google-services.json`,
  `ios/Runner/GoogleService-Info.plist` and the gradle plugins for the
  native platforms; with `platforms: ['web']` nothing else is modified.
* It is a `CommonAppBuilder` (`path`), so `generateVersion()` and
  `bumpVersion()` of `package:tekartik_common_build/common_app_builder.dart`
  apply to the same builder.
* Failures are `ShellException`s of `process_run` carrying the flutterfire
  output (missing cli, no access to the project, unregistered app).

## Examples

### Regenerate the options of every flavor

```dart
// tool/flutterfire_configure.dart — dart run tool/flutterfire_configure.dart
import 'package:tekartik_firebase_build/flutterfire_configure.dart';

Future<void> main() async {
  for (var flavor in ['dev', 'prod']) {
    await FirebaseFlutterProjectBuilder.flavor(
      projectId: 'my-app-$flavor',
      flavor: flavor,
      platforms: ['android', 'ios', 'web'],
    ).configure(yes: true);
  }
}
```

### Single project, web only, custom output file, dry run

```dart
import 'package:tekartik_firebase_build/flutterfire_configure.dart';

Future<void> main(List<String> args) async {
  var builder = FirebaseFlutterProjectBuilder(
    options: FirebaseFlutterProjectOptions(
      projectId: 'my-app',
      path: '../my_app',
      platforms: ['web'],
      firebaseOptionsFile: 'lib/src/firebase/firebase_options.dart',
    ),
  );
  print(builder.configureCommand(yes: true));
  if (!args.contains('--dry-run')) {
    await builder.configure(yes: true);
  }
}
```

### Test the command line

```dart
import 'package:tekartik_firebase_build/flutterfire_configure.dart';
import 'package:test/test.dart';

void main() {
  test('flavor command', () {
    var builder = FirebaseFlutterProjectBuilder.flavor(
      projectId: 'my-app-dev',
      flavor: 'dev',
      path: '/tmp/my_app',
      platforms: ['web'],
    );
    expect(builder.path, '/tmp/my_app');
    expect(
      builder.configureCommand(),
      'flutterfire configure --project=my-app-dev --platforms=web'
      ' --out=lib/firebase_options_dev.dart --overwrite-firebase-options',
    );
  });
}
```
