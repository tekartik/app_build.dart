---
name: tekartik-firebase-build-project
description: >-
  Use when a Dart tool/ script or dev menu must drive the firebase cli on a
  firebase folder of an app: deploy firestore rules and indexes, storage
  rules or cloud functions, start the emulators, read the project id of a
  .firebaserc, with package:tekartik_firebase_build/firebase_project.dart:
  FirebaseProjectBuilder (deployFirestore, deployFirestoreRules,
  deployFirestoreIndexes, deployStorageRules, deployFunctions, deployOnly,
  deploy, serve, compileFunctions), FirebaseProjectBuilderExt.firestoreFolder
  and defaultFirestoreDir (deploy/firebase/firestore), FirebaseProjectOptions,
  FirebaseProjectActionController, firebaseFunctionsDeployOnly,
  firebaseFolderProjectId, firebaseRcContentProjectId and the
  menuFirebaseProjectContent / menuFirebaseProjectBuilderContent menu items.
---

# tekartik_firebase_build: firebase project folders (firestore, functions)

`package:tekartik_firebase_build/firebase_project.dart` is the app-side
entry to `FirebaseProjectBuilder` of `tekartik_firebase_tools_common`: a
`firebase deploy`/`firebase emulators:start` runner for a folder holding a
`firebase.json`. It redeclares the builder as a `CommonAppBuilder` and adds
`FirebaseProjectBuilderExt.firestoreFolder`, the firestore folder of an app
(`deploy/firebase/firestore`, next to the hosting one). Dart VM only, needs
the `firebase` cli logged in.

## Guidelines

### Setup and layout

* Dependency: the same git block as the hosting skill
  (`url: https://github.com/tekartik/app_build.dart`, `path:
  packages/firebase_build`). Nothing here needs the firebase admin sdk.
* Imports: `package:tekartik_firebase_build/firebase_project.dart` exports
  `FirebaseProjectBuilder`, `FirebaseProjectBuilderExt`,
  `FirebaseProjectOptions`, `FirebaseProjectActionController`,
  `firebaseFunctionsDeployOnly`, `firebaseFolderProjectId`,
  `firebaseRcContentProjectId`.
  `package:tekartik_firebase_build/firebase_project_menu.dart` re-exports
  it and adds `menuFirebaseProjectBuilderContent`,
  `menuFirebaseProjectContent`. `firebaseDeployCommand` and
  `CommonAppBuilderExt` (`generateVersion`, `bumpVersion`) are not
  re-exported: import
  `package:tekartik_firebase_tools_common/firebase_project.dart` for them.
* App layout: firestore rules and indexes live in
  `deploy/firebase/firestore` (`FirebaseProjectBuilderExt.defaultFirestoreDir`)
  with a `firebase.json` naming `firestore.rules` and
  `firestore.indexes.json`, and nothing else; hosting lives in
  `deploy/firebase/hosting`. Each folder has its own `.firebaserc`. An app
  without a backend deploys its whole security model from the firestore
  folder.
* A backend (`*_dartff` package) is a firebase folder of its own:
  `firebase.json` with `functions.source: functions` (a dart package with
  `bin/server.dart`) and possibly firestore/storage entries; build a
  `FirebaseProjectBuilder(options: FirebaseProjectOptions(projectId:,
  path:))` on it.

### Options and builder

* `FirebaseProjectOptions({projectId, path, functions, functionsSource,
  functionsEntryPoint, functionsTargetOs, functionsTargetArch})`: `path` is
  the firebase folder (default `'.'`, absolute), `functions` the default
  list of function names `deployFunctions` deploys (null/empty: all),
  `functionsSource` (`'functions'`), `functionsEntryPoint`
  (`'bin/server.dart'`), `functionsTargetOs`/`functionsTargetArch`
  (`linux`/`x64`) describe the dart cloud functions package for
  `compileFunctions`. `FirebaseProjectOptions.firebaseFolder(path:)` reads
  `projectId` from the `.firebaserc` default project
  (`firebaseFolderProjectId`), throwing `StateError` when the folder is not
  a firebase folder or has no default project. `copyWith(...)`,
  `functionsSourcePath`.
* `FirebaseProjectBuilderExt.firestoreFolder(projectId:, path:, firestoreDir:)`
  builds the `FirebaseProjectBuilder` of the firestore folder of the app at
  `path` (default `'.'`); `firestoreDir` (default `defaultFirestoreDir`) is
  relative to `path` unless absolute. Static members: call them on the
  extension name.
* Deploys (`firebase deploy --project <id> --only ...` in `path`):
  `deployFirestoreRules()` (`firestore:rules`), `deployFirestoreIndexes()`
  (`firestore:indexes`), `deployFirestore()` (both), `deployStorageRules()`
  (`storage`), `deployFunctions(functions:)` (`functions` or
  `functions:a,functions:b`, `firebaseFunctionsDeployOnly` builds the
  filter; regenerates the version files first),
  `deployOnly('hosting,firestore:rules')` (raw filter), `deploy()`
  (everything in `firebase.json`). All take `controller:` (a
  `FirebaseProjectActionController`, `cancel()` kills the running command)
  and `force:` (`--force`: deletes functions and indexes no longer in the
  source without asking, needed in CI).
* `serve(only:, controller:)`: `firebase emulators:start --project <id>
  [--only hosting,firestore]`, blocks until cancelled.
* `compileFunctions()`: local `dart compile exe` of the functions entry
  point for linux/x64, a compile check only (firebase deploys from source).
  `generateFunctionsVersionIfNeeded()` refreshes `lib/src/version.dart` of
  the firebase folder and of the functions package when they have one.
* `firebaseRcContentProjectId(content, context:)` parses the
  `projects.default` of a `.firebaserc` text (pure Dart, testable).
* Menu: `menuFirebaseProjectBuilderContent(builder:)` registers `cancel
  action`, `serve emulators`, `deploy functions`, `deploy firestore rules`,
  `deploy firestore indexes`, `deploy storage rules`, `deploy all`;
  `menuFirebaseProjectContent(builders:)` adds a `project <projectId>`
  submenu per builder when there are several. Declare them inside
  `mainMenuConsole(arguments, () { ... })` of
  `package:dev_build/menu/menu_io.dart`.
* Deploying rules is fast and safe to repeat; index deploys can take
  minutes and `--force` drops the indexes removed from
  `firestore.indexes.json`. Never point a dev tool at the prod project by
  default: pass the project explicitly, one builder per flavor.

## Examples

### Deploy the firestore rules and indexes of an app

```dart
// tool/deploy_firestore.dart — dart run tool/deploy_firestore.dart [dev|prod]
import 'package:tekartik_firebase_build/firebase_project.dart';

Future<void> main(List<String> args) async {
  var flavor = args.isEmpty ? 'dev' : args.first;
  var builder = FirebaseProjectBuilderExt.firestoreFolder(
    projectId: 'my-app-$flavor',
    // path: '.', firestoreDir: deploy/firebase/firestore
  );
  await builder.deployFirestore();
}
```

### A backend folder: functions, rules, emulators

```dart
import 'package:tekartik_firebase_build/firebase_project.dart';

final backend = FirebaseProjectBuilder(
  options: FirebaseProjectOptions(
    projectId: 'my-app-dev',
    path: '../my_app_dartff',
    functions: ['commandv1dev', 'callcommandv1dev'],
  ),
);

Future<void> main(List<String> args) async {
  switch (args.firstOrNull) {
    case 'functions':
      await backend.deployFunctions(force: true);
    case 'one':
      await backend.deployFunctions(functions: ['commandv1dev']);
    case 'rules':
      await backend.deployFirestoreRules();
      await backend.deployStorageRules();
    case 'compile':
      await backend.compileFunctions();
    case 'serve':
      await backend.serve(only: 'functions,firestore');
    default:
      await backend.deploy();
  }
}
```

### Project id from .firebaserc, cancellable emulators

```dart
import 'dart:io';

import 'package:tekartik_firebase_build/firebase_project.dart';

Future<void> main() async {
  var folder = 'deploy/firebase/firestore';
  var projectId = firebaseFolderProjectId(path: folder);
  print('serving $projectId');
  var builder = FirebaseProjectBuilder(
    options: FirebaseProjectOptions.firebaseFolder(path: folder),
  );
  var controller = FirebaseProjectActionController();
  ProcessSignal.sigint.watch().first.then((_) => controller.cancel());
  await builder.serve(only: 'firestore', controller: controller);
}
```

### Dev menu, one submenu per flavor

```dart
// tool/firebase_menu.dart — dart run tool/firebase_menu.dart
import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_firebase_build/firebase_project_menu.dart';

Future<void> main(List<String> arguments) async {
  var builders = [
    for (var flavor in ['dev', 'prod'])
      FirebaseProjectBuilderExt.firestoreFolder(projectId: 'my-app-$flavor'),
  ];
  mainMenuConsole(arguments, () {
    menuFirebaseProjectContent(builders: builders);
  });
}
```

### Unit test of the pure helpers

```dart
import 'package:tekartik_firebase_build/firebase_project.dart';
import 'package:test/test.dart';

void main() {
  test('functions filter', () {
    expect(firebaseFunctionsDeployOnly(null), 'functions');
    expect(
      firebaseFunctionsDeployOnly(['a', 'functions:b']),
      'functions:a,functions:b',
    );
  });
  test('.firebaserc', () {
    expect(
      firebaseRcContentProjectId('{"projects": {"default": "my-app-dev"}}'),
      'my-app-dev',
    );
    expect(() => firebaseRcContentProjectId('{}'), throwsStateError);
  });
  test('firestore folder', () {
    var builder = FirebaseProjectBuilderExt.firestoreFolder(
      projectId: 'p',
      path: '/tmp/my_app',
    );
    expect(builder.path, '/tmp/my_app/deploy/firebase/firestore');
  });
}
```
