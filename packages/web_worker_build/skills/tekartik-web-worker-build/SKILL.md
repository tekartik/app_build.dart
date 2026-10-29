---
name: tekartik-web-worker-build
description: >-
  Use when a Dart package ships a web worker, shared worker or AudioWorklet
  script written in Dart that an app must build into its web/ folder with
  package:tekartik_web_worker_build: WebWorkerScript (package, filename,
  entry or mainSource, dependencies, compilerOptions, output), setup (a
  dart2js build cached in .dart_tool/<package>/<name>/ with a meta.json
  of the Dart SDK and the versions of every dependency, rebuilt only when
  needed, copied when different), setupMain (the bin/setup.dart command),
  ProjectPackages (package config and package graph of a project or pub
  workspace, versions, dependency closure, sourceKey, folderHash), and the
  tool/dev_build_setup.dart that run_ci runs before tests and build.
license: BSD-2-Clause
metadata:
  package: tekartik_web_worker_build
  author: tekartik
---

# Building a Dart web worker script

`WebWorkerScript` declares a Dart program that dart2js compiles into a
JavaScript file loaded besides the page (a `Worker`, a `SharedWorker`, an
`audioWorklet.addModule`). The package that ships the script declares it
once. The app builds it with `setup()`, which only depends on `path`.

```dart
import 'package:tekartik_web_worker_build/web_worker_build.dart';

const script = WebWorkerScript(
  package: 'my_package',              // a dependency of the app
  filename: 'my_worker.js',           // written in <app>/web/
  entry: 'package:my_package/src/worker_main.dart', // declares main()
);

var result = await script.setup();    // path: '.', dir: 'web'
result.built;   // compiled now (false: the cache was up to date)
result.written; // web/my_worker.js changed
result.key;     // the content of meta.json
```

## Rules

- Set exactly one of `entry` and `mainSource`. Use `mainSource:
  (packages) => '...'` when the main depends on the app, e.g. to register a
  plugin only `if (packages.has('my_plugin'))`. The generated file is
  compiled from `.dart_tool`, so it can only import `package:` uris.
- `dependencies` lists the packages whose code goes into the script, plus
  their dependencies. It defaults to `[package]` and the package of `entry`.
  Packages that the app does not have are skipped, so optional plugins can
  be listed.
- `output: (js, packages) => ...` wraps the dart2js output (a header with
  `packages.version(package)`, JS around it).
- `compilerOptions` defaults to `['-O2']`. `--no-source-maps`,
  `--packages=<config of the app>` and `-o` are always added.
- The build key holds the Dart SDK, the compiler options, the main, and for
  each package its version plus either its pub cache folder (hosted or git:
  immutable) or a hash of its `lib/` folder (path or workspace packages).
  `force: true` rebuilds anyway.
- Ship a `bin/setup.dart`: `main(args) => script.setupMain(args)`. It handles
  `--dir`, `-f/--force`, `-v/--verbose`, `-h` and an optional app path.
- In the app, `tool/dev_build_setup.dart` calls the setup. run_ci (dev_build
  >= 1.1.16) runs it after format/analyze and before test/build, and ignores
  its errors. Git-ignore the generated `web/*.js`.
- For browser tests in the package itself, have `tool/dev_build_setup.dart`
  (and a VM test) call `setup(dir: 'test')`, then load the file relative to
  the test page. run_ci only runs browser tests when `build_web_compilers`
  is a dev dependency.
- dart2js in a worklet: only the typed data classes the program creates are
  registered, so create one of each kind you receive from JS at start.
