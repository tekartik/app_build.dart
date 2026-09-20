---
name: tekartik-web-publish-deploy
description: >-
  Use when a Dart build script must copy a built web app (build/web) into a
  deploy folder following the deploy.yaml copy rules, then publish it, for
  example to surge.sh. Covers webAppBuildToDeploy, WebAppDeployer (and its
  no-op factory), WebAppDeployOptions, SurgeWebAppDeployer,
  SurgeWebAppDeployOptions, webAppDeployDirDefault,
  surgeWebAppDeployDirDefault, firebaseWebAppDeployDirDefault,
  webAppServeWebPortDefault from package:tekartik_web_publish/web_publish.dart
  and package:tekartik_web_publish/surge_web_publish.dart.
---

# Web publish: build to deploy folder and deploy (tekartik_web_publish)

`tekartik_web_publish` is the small glue between a web build output and a
hosting target: `webAppBuildToDeploy` copies `build/web` (or any build folder)
into a deploy folder using the `deploy.yaml` rules of `tekartik_deploy`, and a
`WebAppDeployer` publishes that folder — `SurgeWebAppDeployer` is the
implementation shipped here. Dart VM only (`dart:io`), meant for `tool/`
scripts and app builders.

## Guidelines

### Setup

* Not on pub.dev, depend on it from git (mono-repo, so `path:` is required):

  ```yaml
  dev_dependencies:
    tekartik_web_publish:
      git:
        url: https://github.com/tekartik/app_build.dart
        path: packages/web_publish
  ```

* Two entry points, import both in a deploy script:
  * `package:tekartik_web_publish/web_publish.dart`: `webAppBuildToDeploy`,
    `WebAppDeployer`, `WebAppDeployOptions`, `webAppDeployDirDefault`,
    `webAppServeWebPortDefault`.
  * `package:tekartik_web_publish/surge_web_publish.dart`:
    `SurgeWebAppDeployer`, `SurgeWebAppDeployOptions`,
    `surgeWebAppDeployDirDefault`, `firebaseWebAppDeployDirDefault`.

### Copying the build to the deploy folder

* `await webAppBuildToDeploy(path, deployDir: ..., buildDir: ...)`: `path` is
  the package/app directory, `buildDir` and `deployDir` are resolved against it
  when relative (absolute paths are kept as is). Typical call: `buildDir:
  join('build', 'web')`, `deployDir: 'deploy/web'`.
* It **requires** `<buildDir>/deploy.yaml` and throws
  `StateError('Missing deploy.yaml file (...)')` when it is missing — build
  first, and check the file is part of the build output. For a Flutter/webdev
  app, put the file in the app's `web/deploy.yaml`: the web build copies it to
  `build/web/deploy.yaml`.
* `deploy.yaml` is the `tekartik_deploy` format, a `files:` list (a trailing
  `/` includes a whole directory, `name: new_name` renames) and an optional
  `exclude:` list. Only the listed entries are copied, which is the point: it
  drops the source maps and the dev-only assets of a Flutter web build.

  ```yaml
  # web/deploy.yaml -> copied to build/web/deploy.yaml by the web build
  files:
    - index.html
    - main.dart.js
    - manifest.json
    - version.json
    - flutter_service_worker.js
    - assets/
    - icons/
  ```

* Symlinks are never followed (`FsDeployOptions()..noSymLink = true`), and
  files already present in the deploy folder that are not in `files:` are left
  alone: clean the deploy folder yourself when a stale file must disappear.
* Default folder names are exposed as constants, use them instead of literals:
  `webAppDeployDirDefault` (`deploy/web`), `surgeWebAppDeployDirDefault`
  (`deploy/surge`), `firebaseWebAppDeployDirDefault` (`deploy/firebase`) and
  `webAppServeWebPortDefault` (`8080`, for a local server on the deployed
  folder). Nothing here defaults to them implicitly, `deployDir` and `buildDir`
  are required parameters.

### Deploying

* `WebAppDeployer` is the abstraction: one method, `Future<void> deploy({String?
  path})`. `WebAppDeployer()` (the factory constructor) returns a **no-op**
  deployer — a safe default for a flavor with no hosting target, not an error.
* Surge: `SurgeWebAppDeployer(options: SurgeWebAppDeployOptions(domain:
  'my-app.surge.sh'), path: 'deploy/surge')` runs `surge . --domain <domain>`
  in that directory and prints `Deployed to https://<domain>`. It needs the
  `surge` cli on the PATH (`npm install -g surge`) and an already logged in
  account (`surge login`), since the command is not interactive here.
* Gotcha: `deploy({path})` uses the deployer's **own** `path` first and only
  falls back to the argument when the constructor `path` was null (`this.path
  ?? path`), despite what the doc comment suggests. Set it in one place only:
  either construct one deployer per deploy folder, or leave the constructor
  `path` null and always pass it to `deploy()`. If both are null it throws
  `StateError('Missing deploy path')`.
* Deploy the folder you copied to, not the build folder: `surge` uploads
  everything in the directory it runs in.
* `WebAppDeployOptions` is the (empty) base type of deploy options; implement
  it for a custom target so a builder can hold any deployer's options.
* Errors from `surge` surface as a `ShellException` from `process_run`; let it
  propagate in a `tool/` script so the exit code is non-zero.
* Firebase Hosting is **not** handled by this package: use
  `tekartik_firebase_build` (same repo, `packages/firebase_build`, skill
  `tekartik-firebase-build-hosting`) which has its own build-to-deploy and
  `firebase deploy` support. `firebaseWebAppDeployDirDefault` here is just the
  conventional folder name.
* The package has no test folder; keep custom deployers thin and test the code
  that computes paths/options rather than the shell call.

## Examples

### tool/deploy_surge.dart: copy the build then publish it to surge

```dart
import 'package:path/path.dart';
import 'package:tekartik_web_publish/surge_web_publish.dart';
import 'package:tekartik_web_publish/web_publish.dart';

Future<void> main() async {
  var appPath = '.'; // the flutter/web app directory
  var deployDir = surgeWebAppDeployDirDefault; // deploy/surge

  // build/web/deploy.yaml must exist (from web/deploy.yaml): the app must have
  // been built first (flutter build web / webdev build).
  await webAppBuildToDeploy(
    appPath,
    buildDir: join('build', 'web'),
    deployDir: deployDir,
  );

  var deployer = SurgeWebAppDeployer(
    path: join(appPath, deployDir),
    options: SurgeWebAppDeployOptions(domain: 'my-app.surge.sh'),
  );
  // surge . --domain my-app.surge.sh
  await deployer.deploy();
}
```

### One deployer per flavor, no-op when the flavor has no hosting

```dart
import 'package:path/path.dart';
import 'package:tekartik_web_publish/surge_web_publish.dart';
import 'package:tekartik_web_publish/web_publish.dart';

WebAppDeployer deployerFor(String flavor, String deployPath) {
  switch (flavor) {
    case 'prod':
      return SurgeWebAppDeployer(
        path: deployPath,
        options: SurgeWebAppDeployOptions(domain: 'my-app.surge.sh'),
      );
    case 'beta':
      return SurgeWebAppDeployer(
        path: deployPath,
        options: SurgeWebAppDeployOptions(domain: 'my-app-beta.surge.sh'),
      );
    default:
      // No hosting for this flavor: deploy() does nothing.
      return WebAppDeployer();
  }
}

Future<void> main(List<String> args) async {
  var flavor = args.isEmpty ? 'dev' : args.first;
  var appPath = '.';
  var deployDir = join('deploy', flavor);

  await webAppBuildToDeploy(
    appPath,
    buildDir: join('build', 'web'),
    deployDir: deployDir,
  );
  await deployerFor(flavor, join(appPath, deployDir)).deploy();
}
```

### A custom deployer (rsync) behind the same interface

```dart
import 'package:process_run/shell.dart';
import 'package:tekartik_web_publish/web_publish.dart';

class RsyncDeployOptions implements WebAppDeployOptions {
  final String target; // user@host:/var/www/my-app
  RsyncDeployOptions({required this.target});
}

class RsyncWebAppDeployer implements WebAppDeployer {
  final String? path;
  final RsyncDeployOptions options;

  RsyncWebAppDeployer({this.path, required this.options});

  @override
  Future<void> deploy({String? path}) async {
    var deployPath = this.path ?? path;
    if (deployPath == null) {
      throw StateError('Missing deploy path');
    }
    await Shell().run('rsync -az --delete $deployPath/ ${options.target}');
  }
}

Future<void> main() async {
  var deployDir = webAppDeployDirDefault; // deploy/web
  await webAppBuildToDeploy('.', buildDir: 'build/web', deployDir: deployDir);
  await RsyncWebAppDeployer(
    path: deployDir,
    options: RsyncDeployOptions(target: 'user@host:/var/www/my-app'),
  ).deploy();
}
```

### Copy only, then serve the deployed folder locally

```dart
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_web_publish/web_publish.dart';

Future<void> main() async {
  var appPath = '.';
  var deployDir = webAppDeployDirDefault; // deploy/web
  try {
    await webAppBuildToDeploy(
      appPath,
      buildDir: join('build', 'web'),
      deployDir: deployDir,
    );
  } on StateError catch (e) {
    // Missing deploy.yaml file (...): add web/deploy.yaml and build again.
    print(e.message);
    rethrow;
  }
  // Check what was published, on the default port (8080).
  await Shell(
    workingDirectory: join(appPath, deployDir),
  ).run('dhttpd --port $webAppServeWebPortDefault');
}
```
