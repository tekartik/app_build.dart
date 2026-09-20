---
name: tekartik-flutter-build-web
description: >-
  Use when a Dart tool/ script, dev menu or CI step must build a Flutter web
  app (flutter build web, --wasm, --target), copy the build to a deploy
  folder, serve it locally, run it in Chrome, report the main.dart.js size
  or deploy it with a WebAppDeployer, with package:tekartik_flutter_build:
  FlutterWebAppBuilder (build, buildOnly, buildToDeploy, serve, run, deploy,
  buildAndServe, buildAndDeploy, clean, reportJsSize, generateVersion,
  bumpVersion), FlutterWebAppOptions, FlutterWebAppBuildOptions,
  FlutterWebRenderer, flutterWebAppClean, BuildShellController, the
  menuFlutterWebAppBuilderContent / menuFlutterWebAppContent dev menu items
  and the build/web/deploy.yaml copy rules.
---

# tekartik_flutter_build: build, serve and deploy a Flutter web app

`package:tekartik_flutter_build/app_build.dart` wraps the `flutter` command
line for the web target in a `FlutterWebAppBuilder`: `flutter build web`
(with `--wasm`/`--target`), copy of `build/web` to a deploy folder honouring
an optional `deploy.yaml`, a local `dhttpd` server, `flutter run -d chrome`,
and deployment through a pluggable `WebAppDeployer`. `app_build_menu.dart`
adds the `dev_build` console menu items on top of it. Dart VM only; the
firebase hosting variant lives in `tekartik_firebase_build`.

## Guidelines

### Setup

* Dependency (git, not on pub.dev), a dev dependency of the flutter app or a
  dependency of a separate `*_tools` package:
  ```yaml
  dev_dependencies:
    tekartik_flutter_build:
      git:
        url: https://github.com/tekartik/app_build.dart
        path: packages/flutter_build
  ```
  Declare `tekartik_web_publish` (same repo, `path: packages/web_publish`)
  too when you name a `WebAppDeployer`, and `dev_build` for the menus.
* Imports: `package:tekartik_flutter_build/app_build.dart` exports
  `FlutterWebAppBuilder`, `FlutterWebAppOptions`,
  `FlutterWebAppBuildOptions`, `FlutterWebRenderer`, `flutterWebAppClean`
  and re-exports `CommonAppBuilder`/`CommonAppBuilderExt` of
  `tekartik_common_build`. `package:tekartik_flutter_build/app_build_menu.dart`
  re-exports it and adds `menuFlutterWebAppBuilderContent`,
  `menuFlutterWebAppContent` and `BuildShellController`.
* Needs the `flutter` command on the PATH (`isFlutterSupportedSync` from
  `package:process_run/shell.dart` tells) and, for `serve`, `dart pub
  global` access to activate `dhttpd`.

### Options

* `FlutterWebAppOptions({path, deployDir, webPort, buildOptions})`: `path`
  is the flutter app folder (default `'.'`, stored absolute and
  normalized); `deployDir` (default `deploy/web`, `webAppDeployDirDefault`)
  is where `build/web` is copied, relative to `path` unless absolute;
  `webPort` (default 8080, `webAppServeWebPortDefault`) is used by `run` and
  `serve`. `copyWith(path:, deployDir:, buildOptions:)` (not `webPort`)
  derives a variant.
* `FlutterWebAppBuildOptions({renderer, wasm, target})`: `wasm: true` adds
  `--wasm`; `target` is the entry point passed as `--target`
  (`lib/main_prod.dart`), `lib/main.dart` when null. `renderer`
  (`FlutterWebRenderer.canvasKit`; `html` is deprecated) is accepted for
  compatibility but no longer passed to flutter, which dropped
  `--web-renderer`.
* `FlutterWebAppBuilder({options, deployer, controller, target})`: `target`
  is a free label (`'dev'`, `'prod'`) used by the menus, not a flutter
  option; `deployer` is a `WebAppDeployer` (`tekartik_web_publish`:
  `SurgeWebAppDeployer` from `surge_web_publish.dart`, or the no-op
  `WebAppDeployer()`), without one `deploy()` throws `StateError`;
  `controller` is a `BuildShellController` whose `shell` runs the commands.
  `copyWith(controller:)` keeps the rest.

### Building, serving, deploying

* `buildOnly()`: `generateVersionIfNeeded()` (rewrites `lib/src/version.dart`
  only if it already exists, see `tekartik_common_build`), then
  `flutter build web [--wasm] [--target x]`, then `reportJsSize()` (prints
  `main.dart.js (1.234 MB)`, `0 B` when not found; the file may sit in a
  subfolder with wasm builds).
* `build()`: `buildOnly()` then the copy to `deployDir`, also available
  alone as `buildToDeploy()`: when `build/web/deploy.yaml` exists its
  `files:`/`exclude:` rules (`fsDeploy` of `tekartik_deploy`) select what is
  copied, else the whole `build/web`; symlinks are never created. Put
  `deploy.yaml` in the app `web/` folder, flutter copies it to `build/web`.
  `hasDeployYamlFile()` tells whether the built tree carries one. The copy
  throws `StateError('Missing build folder ...')` before any build.
* `serve()`: activates `dhttpd` if needed then serves `deployDir` on
  `webPort` with `Cross-Origin-Embedder-Policy: credentialless` and
  `Cross-Origin-Opener-Policy: same-origin` headers (needed for wasm and
  multi-threading), blocks until killed. `run()`: `flutter run -d chrome
  --web-port <webPort>` on the source, blocks. `buildAndServe()` and
  `buildAndDeploy()` chain `build()` with `serve()`/`deploy()`.
* `deploy()`: `deployer.deploy(path: <absolute deployDir>)`.
* `clean()` / `flutterWebAppClean(directory)`: `flutter clean`.
* Versioning (from `CommonAppBuilderExt`): `generateVersion()`,
  `generateVersionIfNeeded()`, `bumpVersion(patch:, minor:, major:, ext:)`
  (defaults to patch plus build number for apps) act on `options.path`.
* Cancelling: `BuildShellController(shell: Shell(workingDirectory: path))`
  and `builder.copyWith(controller: controller)`; `controller.cancel()`
  sends SIGKILL to the running `flutter`/`dhttpd` process. `controller.shell`
  throws until a shell was set. One controller per builder.
* Every step runs a shell and throws `ShellException` on failure; the
  flutter output goes to stdout as it happens.

### Dev menu

* In a `tool/build_menu.dart`, `mainMenuConsole(arguments, () { ... })` from
  `package:dev_build/menu/menu_io.dart` then
  `menuFlutterWebAppBuilderContent(builder: builder)` registers the items
  `cancel current build/server`, `build and deploy` (only with a deployer),
  `build`, `build only (no copy to deploy)`, `run`, `serve`, `deploy`
  (with a deployer), `build and serve`, `clean`, `generateVersion`,
  `bumpVersion`, `Js size`; each action cancels the previous one first.
* `menuFlutterWebAppContent(builders: [...])`: one builder gives the items
  directly; two or more give a `target <target>` submenu each plus an `all`
  submenu (`build`, `build and deploy`, `deploy`, `clean` over every
  builder). Give each builder a distinct `target`.
* `dart run tool/build_menu.dart` shows the menu; `dart run
  tool/build_menu.dart <item number or cmd>` runs one item and exits, handy
  in CI.

### Testing

* The package test creates a throw-away app with `flutter create --platforms
  web` under `.dart_tool/` and calls `buildOnly()` (canvasKit and wasm),
  skipped when flutter is missing (`skip: !isFlutterSupportedSync`) with a
  five minutes timeout. Do the same in your own tests; nothing here is
  mockable.

## Examples

### Build and serve locally

```dart
// tool/serve_web.dart — dart run tool/serve_web.dart
import 'package:tekartik_flutter_build/app_build.dart';

Future<void> main() async {
  var builder = FlutterWebAppBuilder(
    options: FlutterWebAppOptions(
      buildOptions: FlutterWebAppBuildOptions(wasm: true),
      webPort: 8090,
    ),
  );
  // flutter build web --wasm, copy to deploy/web, dhttpd on :8090
  await builder.buildAndServe();
}
```

### Two entry points, deployed to surge

```dart
import 'package:tekartik_flutter_build/app_build.dart';
import 'package:tekartik_web_publish/surge_web_publish.dart';

FlutterWebAppBuilder builderFor(String flavor, {required String domain}) {
  return FlutterWebAppBuilder(
    target: flavor,
    options: FlutterWebAppOptions(
      path: '.',
      deployDir: 'deploy/$flavor', // relative to the app folder
      buildOptions: FlutterWebAppBuildOptions(target: 'lib/main_$flavor.dart'),
    ),
    deployer: SurgeWebAppDeployer(
      options: SurgeWebAppDeployOptions(domain: domain),
    ),
  );
}

Future<void> main(List<String> args) async {
  var builder = args.contains('prod')
      ? builderFor('prod', domain: 'my-app.surge.sh')
      : builderFor('dev', domain: 'my-app-dev.surge.sh');
  await builder.buildAndDeploy();
}
```

### Dev menu with several targets

```dart
// tool/build_menu.dart — dart run tool/build_menu.dart
import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_flutter_build/app_build_menu.dart';

Future<void> main(List<String> arguments) async {
  var dev = FlutterWebAppBuilder(
    target: 'dev',
    options: FlutterWebAppOptions(
      buildOptions: FlutterWebAppBuildOptions(target: 'lib/main_dev.dart'),
      deployDir: 'deploy/dev',
    ),
  );
  var prod = FlutterWebAppBuilder(
    target: 'prod',
    options: FlutterWebAppOptions(
      buildOptions: FlutterWebAppBuildOptions(
        target: 'lib/main_prod.dart',
        wasm: true,
      ),
      deployDir: 'deploy/prod',
    ),
  );
  mainMenuConsole(arguments, () {
    menuFlutterWebAppContent(builders: [dev, prod]);
    item('bump version', () => dev.bumpVersion());
  });
}
```

### Cancellable build in a custom flow

```dart
import 'dart:async';

import 'package:dev_build/shell.dart';
import 'package:tekartik_flutter_build/app_build_menu.dart';

Future<void> main() async {
  var controller = BuildShellController(shell: Shell(workingDirectory: '.'));
  var builder = FlutterWebAppBuilder().copyWith(controller: controller);
  // Kill the build after 10 minutes whatever happens.
  var timer = Timer(const Duration(minutes: 10), controller.cancel);
  try {
    await builder.build();
  } finally {
    timer.cancel();
  }
}
```

### Build test on a generated app

```dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:dev_build/shell.dart';
import 'package:path/path.dart';
import 'package:tekartik_flutter_build/app_build.dart';
import 'package:test/test.dart';

void main() {
  var path = join('.dart_tool', 'my_build_test', 'app1');
  group(
    'flutter web build',
    () {
      setUpAll(() async {
        if (!Directory(path).existsSync()) {
          Directory(path).createSync(recursive: true);
          await Shell(
            workingDirectory: path,
          ).run('flutter create --platforms web .');
        }
      });
      test('build wasm', () async {
        var builder = FlutterWebAppBuilder(
          options: FlutterWebAppOptions(
            path: path,
            buildOptions: FlutterWebAppBuildOptions(wasm: true),
          ),
        );
        await builder.buildOnly();
        expect(await builder.hasDeployYamlFile(), isFalse);
      });
    },
    skip: !isFlutterSupportedSync,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
```
