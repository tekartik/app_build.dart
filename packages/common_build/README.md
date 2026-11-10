# tekartik_common_build

Small helpers for the build scripts of a Dart or Flutter package
(`tool/*.dart`, `bin/*.dart`, a builder class):

| Library | What |
|---|---|
| `version_io.dart` | `generateVersion`: writes `lib/src/version.dart` from the `pubspec.yaml` version; `pathAppVersionBumpAndGenerate`: bumps the version and refreshes that file |
| `common_app_builder.dart` | `CommonAppBuilder` + `CommonAppBuilderExt`: the same version operations on any builder class with a `path` |
| `formatter.dart` | `formatSize(bytes)`: `1.177 MB` (1024 based, 3 decimals) |
| `serve_dir.dart` | `DirServeBuilder`: serves a local folder over HTTP with `dhttpd` |

## Getting started

Not on pub.dev, add it as a git dependency (a dev dependency when only your
tools use it):

```yaml
dev_dependencies:
  tekartik_common_build:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/common_build
```

Let your app or package report the version it was built from:

```dart
// tool/version.dart: dart run tool/version.dart
import 'package:tekartik_common_build/version_io.dart';

Future<void> main() async {
  // First time only: force creates lib/src/version.dart.
  await generateVersion(force: true);
}
```

Commit the generated `lib/src/version.dart`, then read it from your code:

```dart
import 'package:my_app/src/version.dart';

String get aboutText => 'My app $packageVersionText';
```

From then on, call `generateVersion()` (no `force`) before each build: it
rewrites the file when the `pubspec.yaml` version changed, and skips packages
without a generated file. `pathAppVersionBumpAndGenerate()` bumps the
version (`1.2.3+4` becomes `1.2.4+5` by default) and refreshes the file.

A runnable tour on a throw-away package: [example/main.dart](example/main.dart)
(`dart run example/main.dart`).

## Platforms

`version_io.dart`, `common_app_builder.dart` and `serve_dir.dart` use
`dart:io` and processes: Dart VM only (tool scripts, CI), never in app or web
code. `formatter.dart` is pure Dart. The generated `lib/src/version.dart` runs
everywhere (it only needs `pub_semver`).

## Pitfalls

* Generation is opt-in: `generateVersion()` without `force` does nothing when
  `lib/src/version.dart` is missing, and keeps a file it did not write
  (hand-written, build_version...). Run it once with `force: true`.
* Add `pub_semver` to the `dependencies:` of a package with a generated file;
  without it the file carries a `// ignore: depend_on_referenced_packages`.
* The default bump is the app one (patch and build number). For a library
  without a build number pass `patch: true` (`1.2.3` becomes `1.2.4`).
* Never edit the generated file by hand: it is rewritten (and formatted).
* `DirServeBuilder.serve()` activates `dhttpd` globally the first time and
  runs until the process is killed; `ServeDirOptions(secure: true)` adds the
  cross-origin isolation headers a wasm build with threads needs:

  ```dart
  import 'package:tekartik_common_build/serve_dir.dart';

  Future<void> main() async {
    await DirServeBuilder(ServeDirOptions(path: 'build/web')).serve();
  }
  ```

## Agent skills

The package ships agent skills in `skills/`:

- `tekartik-common-build-version`: generated `lib/src/version.dart`, version
  bump, `CommonAppBuilder` helpers.
- `tekartik-common-build-formatter`: `formatSize`.

In a project that depends on this package, install them with:

```sh
dart run skills@ get
```
