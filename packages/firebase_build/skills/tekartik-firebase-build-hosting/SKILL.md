---
name: tekartik-firebase-build-hosting
description: >-
  Use when a Dart tool/ script or dev menu must build a Flutter web app and
  deploy it to Firebase Hosting (or serve it with the hosting emulator) with
  package:tekartik_firebase_build: FlutterFirebaseWebAppBuilder (build,
  deploy, serve, buildAndDeploy, buildAndServe, copyBuildToDeploy, clean,
  webAppBuilder), FlutterFirebaseWebAppOptions, FirebaseDeployOptions
  (projectId, hostingId, target), FirebaseWebAppActionController, the
  firebaseWebAppDeploy / firebaseWebAppServe / firebaseWebAppBuildToDeploy /
  flutterWebAppBuildAndDeploy / flutterWebAppBuildAndServe functions,
  firebaseDefaultDeployDir and the deploy/firebase/hosting folder with its
  firebase.json, .firebaserc and public/ layout.
---

# tekartik_firebase_build: Flutter web app on Firebase Hosting

`package:tekartik_firebase_build/app_build.dart` and `firebase_deploy.dart`
put a Flutter web build on Firebase Hosting: `flutter build web` (through
`FlutterWebAppBuilder` of `tekartik_flutter_build`, re-exported), copy of
`build/web` into the `public/` folder of a hosting folder holding
`firebase.json`, then `firebase deploy --only hosting:<target>` or
`firebase emulators:start` from that folder. The `firebase` cli must be
installed and logged in. Dart VM only.

## Guidelines

### Setup

* Dependency (git, not on pub.dev), a dev dependency of the flutter app or
  a dependency of its `*_tools` package:
  ```yaml
  dev_dependencies:
    tekartik_firebase_build:
      git:
        url: https://github.com/tekartik/app_build.dart
        path: packages/firebase_build
  ```
  It depends on `tekartik_flutter_build` (same repo, `packages/flutter_build`)
  and re-exports its `app_build.dart`, so `FlutterWebAppBuildOptions`,
  `FlutterWebAppBuilder`, `FlutterWebAppOptions` and `CommonAppBuilderExt`
  come with `package:tekartik_firebase_build/app_build.dart`.
* Imports: `package:tekartik_firebase_build/app_build.dart` for
  `FlutterFirebaseWebAppBuilder`, `FlutterFirebaseWebAppOptions`,
  `flutterWebAppBuild`, `flutterWebAppBuildAndDeploy`,
  `flutterWebAppBuildAndServe`;
  `package:tekartik_firebase_build/firebase_deploy.dart` for
  `FirebaseDeployOptions`, `firebaseWebAppDeploy`, `firebaseWebAppServe`,
  `firebaseWebAppBuildToDeploy`, `firebaseDefaultDeployDir`,
  `FirebaseWebAppActionController`. A build script imports both.
* Tools: `firebase` cli (`npm install -g firebase-tools`, `firebase login`)
  with access to the project, `flutter` on the PATH.

### The hosting folder

* Default hosting folder: `deploy/firebase/hosting` inside the app
  (`FlutterFirebaseWebAppOptions.deployDir` when null); the web build is
  copied to its `public/` subfolder (`firebaseDefaultDeployDir` is
  `deploy/firebase/hosting/public`). Commit `firebase.json` and
  `.firebaserc` there, git-ignore `public/`.
* `firebase.json` of that folder: a `hosting` entry with `"public":
  "public"`, `"target": "<target>"`, the usual
  `rewrites: [{"source": "**", "destination": "/index.html"}]` and, for
  wasm builds, the `Cross-Origin-Embedder-Policy: credentialless` /
  `Cross-Origin-Opener-Policy: same-origin` headers. A second hosting folder
  (`deploy/firebase/hosting_wasm`) with its own `firebase.json` is how you
  switch between hosting configurations: pass it as `deployDir`.
* A firebase folder shared with the functions and the rules of the project
  (its `firebase.json` declaring them all) is a `deployDir` outside the app
  (`../../packages/my_firebase`); give each app hosted there its own
  `publicDir` (`public/admin_app`, the `"public"` of its target), the
  default being `public` (`firebaseDefaultPublicDir`).
* `FirebaseDeployOptions(projectId:, hostingId:, target:)`: `projectId` is
  the firebase project (`--project`), `hostingId` the hosting site id (the
  default site is the project id; extra sites have their own), `target` the
  hosting target name (`dev`, `prod`, `beta`) `firebase.json` refers to.
  Before every deploy/serve the package reads `.firebaserc` and, when
  `targets.<projectId>.hosting.<target>[0]` is not `hostingId`, runs
  `firebase target:clear` then `firebase target:apply hosting <target>
  <hostingId>`, which updates `.firebaserc`. `copyWith(...)` derives
  variants (one per flavor).
* `build/web/deploy.yaml` (from the app `web/deploy.yaml`), when present,
  selects the files copied to `public/` (`files:`/`exclude:` rules of
  `tekartik_deploy`); otherwise the whole `build/web` is copied.

### The builder

* `FlutterFirebaseWebAppOptions({path, deployDir, publicDir, deployOptions, buildOptions})`:
  `path` is the flutter app (default `'.'`, made absolute), `deployOptions`
  is required, `buildOptions` is the `FlutterWebAppBuildOptions` (`wasm:`,
  `target:`) of the underlying flutter build, `deployDir` the hosting
  folder (relative to `path` unless absolute), `publicDir` the `public`
  folder of the target, relative to `deployDir`. `copyWith(...)` on all
  five.
* `FlutterFirebaseWebAppBuilder(options:)`: `build()` (flutter build +
  copy to `public/`), `copyBuildToDeploy()` (copy only), `deploy()`,
  `serve()` (hosting emulator, `firebase emulators:start --only
  hosting:<target>`, blocks), `buildAndDeploy()`, `buildAndServe()`,
  `clean()` (`flutter clean`). `deploy`/`serve` copy the existing build to
  `public/` again first, so one `build()` then `deploy()` on several targets
  sharing the build works. `target` is `options.deployOptions.target`;
  `webAppBuilder` is the inner `FlutterWebAppBuilder` (for `run()`,
  `reportJsSize()`, the dhttpd `serve()`); `generateVersion()`,
  `generateVersionIfNeeded()`, `bumpVersion()` apply (`CommonAppBuilder`).
* Cancelling: `FirebaseWebAppActionController()` passed as `controller:` to
  `build`, `deploy`, `serve`, `buildAndDeploy`, `buildAndServe`;
  `controller.cancel()` kills the running `firebase` command (the flutter
  build itself is not covered). One controller can serve several calls.
* Function style, same behaviour without a builder object:
  `flutterWebAppBuild(dir)` (plain `flutter build web`),
  `firebaseWebAppBuildToDeploy(dir, deployDir:, publicDir:, folder:)`
  (`folder` is the
  `build/` subfolder, `'web'`), `firebaseWebAppDeploy(dir, options,
  deployDir:, controller:)`, `firebaseWebAppServe(...)`,
  `flutterWebAppBuildAndDeploy(dir, firebaseDeployOptions:, deployDir:)`,
  `flutterWebAppBuildAndServe(...)`. `firebaseWepAppBuildToDeploy` (typo)
  is deprecated.
* Menus: `tekartik_firebase_build_menu_flutter` provides
  `menuFirebaseAppContent(builders:)` for these builders; this package has
  no hosting menu itself (its `firebase_project_menu.dart` is about the
  firebase project folder, see the `tekartik-firebase-build-project` skill).
* Failures are `ShellException`s from `process_run` (`firebase` exit code)
  or `StateError('Missing build folder ...')` when deploying before
  building.

## Examples

### tool/deploy_web.dart: one flavor per firebase project

```dart
// dart run tool/deploy_web.dart [dev|prod]
import 'package:tekartik_firebase_build/app_build.dart';
import 'package:tekartik_firebase_build/firebase_deploy.dart';

final devDeployOptions = FirebaseDeployOptions(
  projectId: 'my-app-dev',
  hostingId: 'my-app-dev',
  target: 'dev',
);
final prodDeployOptions = devDeployOptions.copyWith(
  projectId: 'my-app-prod',
  hostingId: 'my-app-prod',
  target: 'prod',
);

FlutterFirebaseWebAppBuilder builderFor(String flavor) {
  return FlutterFirebaseWebAppBuilder(
    options: FlutterFirebaseWebAppOptions(
      deployOptions: flavor == 'prod' ? prodDeployOptions : devDeployOptions,
      buildOptions: FlutterWebAppBuildOptions(
        target: 'lib/main_$flavor.dart',
        wasm: true,
      ),
      // deploy/firebase/hosting/firebase.json; public/ receives the build
    ),
  );
}

Future<void> main(List<String> args) async {
  var flavor = args.isEmpty ? 'dev' : args.first;
  await builderFor(flavor).buildAndDeploy();
}
```

### Build once, deploy to two sites, cancel on Ctrl-C

```dart
import 'dart:io';

import 'package:tekartik_firebase_build/app_build.dart';
import 'package:tekartik_firebase_build/firebase_deploy.dart';

Future<void> main() async {
  var options = FlutterFirebaseWebAppOptions(
    path: '../my_app',
    deployOptions: FirebaseDeployOptions(
      projectId: 'my-app-prod',
      hostingId: 'my-app-prod',
      target: 'prod',
    ),
  );
  var prod = FlutterFirebaseWebAppBuilder(options: options);
  var beta = FlutterFirebaseWebAppBuilder(
    options: options.copyWith(
      deployOptions: options.deployOptions.copyWith(
        hostingId: 'my-app-beta',
        target: 'beta',
      ),
    ),
  );
  var controller = FirebaseWebAppActionController();
  var subscription = ProcessSignal.sigint.watch().listen((_) {
    controller.cancel();
  });
  try {
    await prod.build();
    await beta.deploy(controller: controller); // copies the build again
    await prod.deploy(controller: controller);
  } finally {
    await subscription.cancel();
  }
}
```

### Function style: wasm build served by the hosting emulator

```dart
import 'package:tekartik_firebase_build/app_build.dart';
import 'package:tekartik_firebase_build/firebase_deploy.dart';

Future<void> main() async {
  var appDir = '.';
  var hostingDir = 'deploy/firebase/hosting_wasm'; // sets COOP/COEP headers
  var deployOptions = FirebaseDeployOptions(
    projectId: 'my-app-dev',
    hostingId: 'my-app-dev',
    target: 'dev',
  );
  // flutterWebAppBuild(appDir) is a plain build; wasm needs the builder.
  await FlutterWebAppBuilder(
    options: FlutterWebAppOptions(
      path: appDir,
      buildOptions: FlutterWebAppBuildOptions(wasm: true),
    ),
  ).buildOnly();
  await firebaseWebAppBuildToDeploy(appDir, deployDir: hostingDir);
  await firebaseWebAppServe(appDir, deployOptions, deployDir: hostingDir);
}
```
