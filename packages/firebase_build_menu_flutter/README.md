# tekartik_firebase_build_menu_flutter

A console menu (`tool/build_menu.dart`) to build, serve and deploy a Flutter
web app to Firebase Hosting: one sub menu per hosting target (build, build
and deploy, serve in the Hosting emulator, deploy, run in Chrome, clean,
check the build secrets) and an `all` sub menu over every target.

One import brings the menu (`dev_build`), the Firebase builders
(`tekartik_firebase_build`), the Flutter web items (`tekartik_flutter_build`)
and the device list (`tekartik_build_flutter`).

## Getting started

Git dependency (not on pub.dev), in the Flutter app (or a tool package next
to it):

```yaml
dev_dependencies:
  tekartik_firebase_build_menu_flutter:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/firebase_build_menu_flutter
```

`tool/build_menu.dart`:

```dart
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

final devBuilder = FlutterFirebaseWebAppBuilder(
  options: FlutterFirebaseWebAppOptions(
    deployOptions: FirebaseDeployOptions(
      projectId: 'my-project-dev',
      hostingId: 'my-app-dev',
      target: 'dev',
    ),
    buildOptions: FlutterWebAppBuildOptions(wasm: true),
  ),
);

Future<void> main(List<String> arguments) async {
  mainMenuConsole(arguments, () {
    menuFirebaseAppContent(builders: [devBuilder]);
  });
}
```

`dart run tool/build_menu.dart`, then type an item number (`.` goes back,
`?` lists the items). Arguments are input lines run first: `dart run
tool/build_menu.dart 0 .` runs item 0 and exits.

Dart VM only. Needs the Flutter SDK and the `firebase` cli (logged in); the
hosting folder (`deploy/firebase/hosting` with its `firebase.json`) is
described in the `tekartik-firebase-build-hosting` skill of
`tekartik_firebase_build`.

## More

- [package skill](skills/tekartik-firebase-build-menu-flutter-setup/SKILL.md):
  what each item does, extra items, several targets, plain Flutter web.
- [example/example_build_menu.dart](example/example_build_menu.dart).
