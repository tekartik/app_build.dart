# tekartik_web_worker_build

Builds a Dart program into the JavaScript file that a web app loads besides
its page: a web worker, a shared worker, an AudioWorklet module. dart2js
compiles it with the package config of the app, so the script uses the same
package versions as the app.

The build is cached in `.dart_tool/<package>/<name>/` of the app. Next to it,
`meta.json` records what the build came from:

- the Dart SDK
- the compiler options
- the main
- every package of the script, with its version, plus either its pub cache
  folder (a hosted version or a git commit, which never change) or a hash of
  its `lib/` folder (a path package or a workspace member, whose code changes
  under the same version)

The script is compiled again only when one of them changed. Each run then
copies it into the web folder of the app when the bytes differ.

## Setup

```yaml
dependencies:
  tekartik_web_worker_build:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/web_worker_build
    version: '>=0.1.0'
```

It only depends on `path`. The package that ships the script depends on it
(for its setup library), and so does every app that uses that package.

## In the package providing the script

```dart
// lib/setup.dart (dart:io)
import 'package:tekartik_web_worker_build/web_worker_build.dart';

const myWorkerScript = WebWorkerScript(
  package: 'my_package',
  filename: 'my_worker.js',
  // A library declaring main()...
  entry: 'package:my_package/src/worker_main.dart',
  // ...or a generated main, for one that depends on the packages of the
  // app: mainSource: (packages) => '...',
  // A header, some JS around the dart2js output:
  // output: (js, packages) => '// my worker\n$js',
);

Future<WebWorkerScriptSetupResult> setupMyWorker({String dir = 'web'}) =>
    myWorkerScript.setup(dir: dir);
```

```dart
// bin/setup.dart: dart run my_package:setup [--dir web] [--force] [--verbose] [<app path>]
Future<void> main(List<String> arguments) => myWorkerScript.setupMain(arguments);
```

## In the app

```dart
// tool/dev_build_setup.dart: run_ci (dev_build >= 1.1.16) runs it after
// format and analyze, before the tests and the build.
import 'package:my_package/setup.dart';

Future<void> main() => setupMyWorker();
```

Add the generated file (`web/my_worker.js`) to `.gitignore`. A browser test
can load a script that `setup(dir: 'test')` wrote. The test server serves
the package folder, so the script resolves relative to the test page.
