---
name: tekartik-firebase-build-menu-flutter-setup
description: >-
  Use when writing the tool/ build menu of a Flutter app deployed to Firebase
  Hosting with package:tekartik_firebase_build_menu_flutter/app_build_menu.dart:
  mainMenuConsole plus menuFirebaseAppContent / menuFirebaseWebAppBuilderContent
  over FlutterFirebaseWebAppBuilder, FlutterFirebaseWebAppOptions,
  FirebaseDeployOptions, FlutterWebAppBuildOptions (wasm, target), the
  re-exported dev_build menu primitives (menu, item, enter, write, prompt,
  command, showMenu, initMenuConsole), the plain flutter web items
  (menuFlutterWebAppContent, BuildShellController) and getFlutterDevices /
  FlutterDevice of tekartik_build_flutter.
---

# tekartik_firebase_build_menu_flutter: the app build menu

`package:tekartik_firebase_build_menu_flutter/app_build_menu.dart` is the
single import of a `tool/build_menu.dart`: it re-exports the `dev_build`
console menu, `tekartik_firebase_build` (`app_build.dart`,
`firebase_deploy.dart`), `tekartik_flutter_build/app_build_menu.dart` and
`tekartik_build_flutter/flutter_devices.dart`, and adds the two menu
declarations for firebase hosting builders. Dart VM only (`dart run`).

## Guidelines

* Dependency, in `dev_dependencies` of the flutter app (git, not on
  pub.dev):
  ```yaml
  dev_dependencies:
    tekartik_firebase_build_menu_flutter:
      git:
        url: https://github.com/tekartik/app_build.dart
        path: packages/firebase_build_menu_flutter
  ```
  Everything else (`dev_build`, `tekartik_firebase_build`,
  `tekartik_flutter_build`, `tekartik_build_flutter`) comes with it and is
  re-exported; keep the single import unless you use another library of
  those packages (`firebase_project_menu.dart` for the firestore rules
  menu, `flutterfire_configure.dart`).
* Layout: `tool/build_menu.dart` (or `tool/fbm.dart`) with `Future<void>
  main(List<String> arguments)` calling `mainMenuConsole(arguments, () {
  ... })`; declarations inside are synchronous (`menu`, `item`, `enter`,
  `write`), actions are async. `dart run tool/build_menu.dart` is
  interactive; `dart run tool/build_menu.dart <item number or cmd>` runs
  one item and exits (CI, shell aliases).
* Builders: one `FlutterFirebaseWebAppBuilder(options:
  FlutterFirebaseWebAppOptions(path:, deployOptions:
  FirebaseDeployOptions(projectId:, hostingId:, target:), buildOptions:
  FlutterWebAppBuildOptions(wasm:, target:), deployDir:))` per flavor or
  hosting target, with distinct `target`s. See the
  `tekartik-firebase-build-hosting` skill for the hosting folder
  (`deploy/firebase/hosting`, `firebase.json`, `.firebaserc`).
* `menuFirebaseWebAppBuilderContent(builder:)` declares, in the current
  menu: an `enter` banner (path, target, project id, hosting id), `cancel
  build/serve/deploy`, `build and deploy`, `build`, `serve` (hosting
  emulator), `deploy`, `build and serve`, `clean`, and a `web` submenu with
  the plain flutter web items (`run` in chrome, `serve` with dhttpd,
  `generateVersion`, `bumpVersion`, `Js size`...). Actions cancel the
  previous firebase action first through a shared
  `FirebaseWebAppActionController`.
* `menuFirebaseAppContent(builders:)` declares a `target <target>` submenu
  per builder (each with the content above) plus an `all` submenu:
  `build`, `build and deploy`, `deploy`, `clean` over every builder in
  order. Always submenus, even with one builder.
* Add your own items next to them: `item('name', () async { ... }, cmd:
  'n')` (`cmd` gives a shortcut), `menu('name', () { ... })`, `write(...)`
  to print, `prompt('question')` to ask, `command((line) { ... })` for a
  free-text command; `solo_item`/`solo_menu` are debug-only (`@doNotSubmit`).
  Typical additions: `flutterfire configure`, firestore rules deploy
  (`menuFirebaseProjectContent` of
  `package:tekartik_firebase_build/firebase_project_menu.dart`), store
  publishing, a device list from `getFlutterDevices()`
  (`List<FlutterDevice>`, `.supported`, `.android`, `.ios`, `id.v`,
  `name.v`).
* Side effects belong in actions, not in the declaration body: it runs at
  startup and again each time a menu is shown.
* Keep the builders in a shared file when several scripts (menu, CI deploy)
  need them, as the package example does (`exampleMenu(arguments, path:)`
  in `example/example_build_menu.dart`).

## Examples

### tool/build_menu.dart with dev and prod hosting targets

```dart
// dart run tool/build_menu.dart
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

final devBuilder = FlutterFirebaseWebAppBuilder(
  options: FlutterFirebaseWebAppOptions(
    deployOptions: FirebaseDeployOptions(
      projectId: 'my-app-dev',
      hostingId: 'my-app-dev',
      target: 'dev',
    ),
    buildOptions: FlutterWebAppBuildOptions(target: 'lib/main_dev.dart'),
  ),
);

final prodBuilder = FlutterFirebaseWebAppBuilder(
  options: FlutterFirebaseWebAppOptions(
    deployOptions: FirebaseDeployOptions(
      projectId: 'my-app-prod',
      hostingId: 'my-app-prod',
      target: 'prod',
    ),
    buildOptions: FlutterWebAppBuildOptions(
      target: 'lib/main_prod.dart',
      wasm: true,
    ),
    deployDir: 'deploy/firebase/hosting_wasm',
  ),
);

Future<void> main(List<String> arguments) async {
  mainMenuConsole(arguments, () {
    menuFirebaseAppContent(builders: [devBuilder, prodBuilder]);
    item('bump version', () => devBuilder.bumpVersion());
  });
}
```

### A menu for a sibling app folder, with extra items

```dart
import 'package:tekartik_firebase_build/firebase_project_menu.dart';
import 'package:tekartik_firebase_build/flutterfire_configure.dart';
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

var appPath = '../my_app';

Future<void> main(List<String> arguments) async {
  var builder = FlutterFirebaseWebAppBuilder(
    options: FlutterFirebaseWebAppOptions(
      path: appPath,
      deployOptions: FirebaseDeployOptions(
        projectId: 'my-app-dev',
        hostingId: 'my-app-dev',
        target: 'dev',
      ),
    ),
  );
  mainMenuConsole(arguments, () {
    menuFirebaseAppContent(builders: [builder]);
    menu('firestore', () {
      menuFirebaseProjectContent(
        builders: [
          FirebaseProjectBuilderExt.firestoreFolder(
            projectId: 'my-app-dev',
            path: appPath,
          ),
        ],
      );
    });
    item('flutterfire configure (web)', () async {
      await FirebaseFlutterProjectBuilder.flavor(
        projectId: 'my-app-dev',
        flavor: 'dev',
        path: appPath,
        platforms: ['web'],
      ).configure(yes: true);
    });
    item('devices', () async {
      for (var device in (await getFlutterDevices()).supported) {
        write('${device.id.v}: ${device.name.v}');
      }
    });
  });
}
```

### Plain flutter web (no firebase) inside the same menu

```dart
import 'package:tekartik_firebase_build_menu_flutter/app_build_menu.dart';

Future<void> main(List<String> arguments) async {
  var webBuilder = FlutterWebAppBuilder(
    target: 'local',
    options: FlutterWebAppOptions(
      deployDir: 'deploy/web',
      webPort: 8090,
      buildOptions: FlutterWebAppBuildOptions(wasm: true),
    ),
  );
  mainMenuConsole(arguments, () {
    menu('local web', () {
      menuFlutterWebAppContent(builders: [webBuilder]);
    });
  });
}
```
