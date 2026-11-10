# tekartik_web_publish

Publish a built web app from a Dart build script: copy the build output
(`build/web`) into a deploy folder following its `deploy.yaml` rules, then
deploy that folder, for example to [surge.sh](https://surge.sh). Dart VM only
(`tool/` scripts and app builders).

## Getting started

Not on pub.dev, add it as a git dev dependency:

```yaml
dev_dependencies:
  tekartik_web_publish:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/web_publish
```

`tool/deploy_surge.dart`, after `flutter build web` (or `webdev build`):

```dart
import 'package:path/path.dart';
import 'package:tekartik_web_publish/surge_web_publish.dart';
import 'package:tekartik_web_publish/web_publish.dart';

Future<void> main() async {
  var deployDir = surgeWebAppDeployDirDefault; // deploy/surge

  // Needs build/web/deploy.yaml (put it in web/deploy.yaml).
  await webAppBuildToDeploy(
    '.',
    buildDir: join('build', 'web'),
    deployDir: deployDir,
  );

  // Runs `surge . --domain my-app.surge.sh` in deploy/surge.
  await SurgeWebAppDeployer(
    options: SurgeWebAppDeployOptions(domain: 'my-app.surge.sh'),
  ).deploy(path: deployDir);
}
```

A minimal `web/deploy.yaml` (the
[tekartik_deploy](https://github.com/tekartik/deploy.dart) format: the listed
files and folders are copied, everything when `files:` is absent):

```yaml
files:
  - index.html
  - main.dart.js
  - flutter_bootstrap.js
  - manifest.json
  - assets/
  - icons/
```

Surge needs its command line on the `PATH` and a logged in account
(`npm install -g surge`, then `surge login`).

## Entry points

* `package:tekartik_web_publish/web_publish.dart`: `webAppBuildToDeploy`,
  `WebAppDeployer` (the interface, `WebAppDeployer()` is a no-op deployer),
  `WebAppDeployOptions`, `webAppDeployDirDefault` (`deploy/web`),
  `webAppServeWebPortDefault` (8080).
* `package:tekartik_web_publish/surge_web_publish.dart`:
  `SurgeWebAppDeployer`, `SurgeWebAppDeployOptions`,
  `surgeWebAppDeployDirDefault` (`deploy/surge`),
  `firebaseWebAppDeployDirDefault` (`deploy/firebase`).

Firebase hosting is in `tekartik_firebase_build` (same repository).

## Common pitfalls

* The deploy folder is deleted before the copy: never give a folder that
  holds the build (`deployDir: 'build'`) or anything else to keep.
* `webAppBuildToDeploy` throws a `StateError` when `<buildDir>/deploy.yaml`
  is missing: build first.
* `SurgeWebAppDeployer.deploy(path: ...)` deploys `path`, the constructor
  `path` is only the default.
* A failing `surge` throws (`ShellException`): let it fail the script.

Agent skill: [skills/tekartik-web-publish-deploy](skills/tekartik-web-publish-deploy/SKILL.md).
