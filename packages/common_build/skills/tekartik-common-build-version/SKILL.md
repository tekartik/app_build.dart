---
name: tekartik-common-build-version
description: >-
  Use when a Dart build script, tool/ menu, CI step or app builder needs to
  expose the pubspec.yaml version to the app as a generated
  lib/src/version.dart, bump the version, or wire version generation into a
  builder with package:tekartik_common_build: generateVersion,
  hasGeneratedVersionFile, pathAppVersionBumpAndGenerate, packageVersionText,
  packageVersion, CommonAppBuilder, CommonAppBuilderExt (generateVersion,
  generateVersionIfNeeded, bumpVersion).
---

# tekartik_common_build: generated version file and version bump

`package:tekartik_common_build/version_io.dart` writes a small
`lib/src/version.dart` from the `version:` of `pubspec.yaml`, so runtime code
(an about screen, a log line, a `--version` flag) reports the version that was
actually built. It is opt-in per package: only packages that already have the
generated file get it refreshed. `pathAppVersionBumpAndGenerate` bumps the
pubspec version and refreshes the file in one call, and `CommonAppBuilder`
gives any builder class the same operations relative to its `path`. VM only.

```dart
// tool/version.dart — run with: dart run tool/version.dart
import 'package:tekartik_common_build/version_io.dart';

Future<void> main() async {
  // Rewrites lib/src/version.dart when it exists and is out of date.
  await generateVersion();
}
```

## Guidelines

### Setup

* The package is not on pub.dev, depend on it through git:

  ```yaml
  dependencies:
    tekartik_common_build:
      git:
        url: https://github.com/tekartik/app_build.dart
        path: packages/common_build
  ```

* `package:tekartik_common_build/version_io.dart` exports `generateVersion`,
  `hasGeneratedVersionFile` and `pathAppVersionBumpAndGenerate`.
  `package:tekartik_common_build/common_app_builder.dart` exports
  `CommonAppBuilder` and `CommonAppBuilderExt`. Both need `dart:io`: use them
  from `tool/*.dart`, `bin/*.dart` and tests, never from app or web code.
* Add `pub_semver` to the `dependencies:` of every package that gets a
  generated version file (a `dev_dependencies:` entry is not enough). Without
  it the generated file carries a
  `// ignore: depend_on_referenced_packages` line above its import.

### The generated file

* Path: `lib/src/version.dart` under the package root. Content:

  ```dart
  /// Generated - do not edit
  library;

  import 'package:pub_semver/pub_semver.dart';

  /// Package version text
  const packageVersionText = '1.2.3+4';

  /// Package version
  final packageVersion = Version.parse(packageVersionText);
  ```

* Opt a package in once with `generateVersion(force: true)` (or a
  `tool/version_force.dart` script) and commit the file. From then on every
  `generateVersion()` call rewrites it when the pubspec version changed.
  Packages without the file are skipped, so calling `generateVersion()`
  unconditionally before builds and in CI is safe.
* Never edit the file by hand: it is overwritten, and `dart format` runs on it
  after each generation.
* Read it from the package's own code with
  `import 'package:my_app/src/version.dart';` (`packageVersionText` is a
  `String`, `packageVersion` a `pub_semver` `Version` with `major`, `minor`,
  `patch`, `build`, `preRelease` and comparison operators). Re-export it from
  a public library if other packages need it.
* `hasGeneratedVersionFile(path:)` is content based: the file exists, is under
  1000 characters and contains `const packageVersionText = ` and
  `final packageVersion = `. A hand-written file with those markers counts as
  generated and gets replaced.

### generateVersion

* `generateVersion({String path = '.', bool? force, bool? verbose})` reads
  `pubspec.yaml` under `path` and returns silently when it has no `version:`
  (a workspace root). It throws when `pubspec.yaml` is missing.
* Without `force` it skips when `lib/src/version.dart` does not exist, or when
  it already contains the current version (no rewrite, no `dart format`).
  `verbose: true` prints the skip reason to stdout.
* `force: true` creates `lib/src/` if needed and writes the file even when it
  is missing or already up to date. Use it for the initial opt-in only.
* The `dart format` step runs through `package:process_run`, which puts the
  SDK running the script first on the shell `PATH`, so the formatter is the
  one of the current Dart or Flutter SDK and needs no extra setup.

### Bumping the version

* `pathAppVersionBumpAndGenerate({String? path, bool? patch, bool? minor,
  bool? major, bool? ext})` rewrites the `version:` line of `pubspec.yaml`
  (nothing else in the file changes), prints the old and new version, then
  regenerates `lib/src/version.dart` if the package has one.
* With no flag it applies the app default `patch: true, ext: true`: the patch
  number and the build number both move (`1.0.2+1` becomes `1.0.3+2`,
  `1.0.2` becomes `1.0.3+0`). For a library without a build number pass
  `patch: true` (or `minor`/`major`) explicitly.
* Flag semantics: `major` resets minor and patch, `minor` resets patch,
  `patch` increments the patch. Any of them without `ext` drops the
  pre-release and build parts (`1.0.2+1` with `patch: true` becomes `1.0.3`).
  `ext` keeps them and increments their last numeric segment, appending `.0`
  when there is none (`1.0.2+1` becomes `1.0.2+2`, `1.0.0-dev.3` becomes
  `1.0.0-dev.4`, `1.0.0-dev` becomes `1.0.0-dev.0`).
* Bumping alone, without touching the version file, is `pathVersionBump` from
  `package:tekartik_prj_tktools/version.dart` (a dependency of this package);
  call `generateVersion()` afterwards yourself if you use it.
* Commit the bumped `pubspec.yaml` together with the regenerated
  `lib/src/version.dart`.

### Builders

* `CommonAppBuilder` is an abstract class with a single `String get path`.
  Declare `implements CommonAppBuilder` on a builder class (a web app builder,
  a Flutter flavor builder, a Firebase project, a Cloud Run project) and
  `CommonAppBuilderExt` adds `generateVersion()`,
  `generateVersionIfNeeded()` and
  `bumpVersion({bool? patch, bool? minor, bool? major, bool? ext})`, all
  relative to `path`.
* Call `await generateVersionIfNeeded()` at the start of every build, run
  and deploy method so the artifact reports the pubspec version. It is a no-op
  for packages that did not opt in, so builders stay usable on any package.
* `bumpVersion()` without flags is the app default (`patch` and `ext`), like
  `pathAppVersionBumpAndGenerate()`.
* The builders of the `app_build.dart` and `build_flutter.dart` repositories
  (`FlutterWebAppBuilder`, `FlutterAppBuilder`, `FlutterAppFlavorBuilder`,
  `FirebaseProjectBuilder`) already implement `CommonAppBuilder`; the same
  methods are available on them without extra code.

## Examples

### Opt a package in

```dart
// tool/version_force.dart — run once, then commit lib/src/version.dart
import 'package:tekartik_common_build/version_io.dart';

Future<void> main() async {
  await generateVersion(force: true, verbose: true);
}
```

### Refresh before a build

```dart
// tool/build.dart
import 'package:process_run/shell.dart';
import 'package:tekartik_common_build/version_io.dart';

Future<void> main() async {
  await generateVersion();
  await run('dart compile exe bin/main.dart -o build/main');
}
```

### Show the version at runtime

```dart
import 'package:my_app/src/version.dart';

String get aboutText => 'My app $packageVersionText';

bool get isPreRelease => packageVersion.isPreRelease;
```

### Bump script for an app

```dart
// tool/bump_version.dart
// dart run tool/bump_version.dart          -> 1.0.2+1 becomes 1.0.3+2
// dart run tool/bump_version.dart --minor  -> 1.0.2+1 becomes 1.1.0
import 'package:tekartik_common_build/version_io.dart';

Future<void> main(List<String> args) async {
  await pathAppVersionBumpAndGenerate(
    major: args.contains('--major'),
    minor: args.contains('--minor'),
    patch: args.contains('--patch'),
    ext: args.contains('--ext'),
  );
}
```

### Bump a library, commit and push

```dart
// tool/bump_and_push.dart
import 'package:process_run/shell.dart';
import 'package:tekartik_common_build/version_io.dart';

Future<void> main() async {
  // Libraries have no build number: bump the patch only.
  await pathAppVersionBumpAndGenerate(patch: true);
  var shell = Shell();
  await shell.run('''
git commit -a -m "bump version"
git push
''');
}
```

### A builder with version generation

```dart
import 'package:process_run/shell.dart';
import 'package:tekartik_common_build/common_app_builder.dart';

class NodeAppBuilder implements CommonAppBuilder {
  @override
  final String path;

  NodeAppBuilder({required this.path});

  Future<void> build() async {
    // No-op for packages without lib/src/version.dart.
    await generateVersionIfNeeded();
    await Shell(workingDirectory: path).run('dart run build_runner build');
  }
}

Future<void> main() async {
  var builder = NodeAppBuilder(path: '../my_node_app');
  await builder.bumpVersion(); // patch + build number
  await builder.build();
}
```

### Version items in a dev_build menu

```dart
// tool/menu.dart
import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_common_build/common_app_builder.dart';

class AppBuilder implements CommonAppBuilder {
  @override
  final String path;
  AppBuilder(this.path);
}

void main(List<String> arguments) {
  var builder = AppBuilder('../my_app');
  mainMenuConsole(arguments, () {
    menu('version', () {
      item('generate', () => builder.generateVersion());
      item('bump patch + build', () => builder.bumpVersion());
      item('bump minor', () => builder.bumpVersion(minor: true));
    });
  });
}
```

### Refresh every package of a repository

```dart
import 'package:dev_build/package.dart';
import 'package:tekartik_common_build/version_io.dart';

Future<void> main() async {
  for (var dir in await recursivePubPath(['.'])) {
    // Skipped for packages without a generated file or without a version.
    await generateVersion(path: dir, verbose: true);
  }
}
```

### Test that the generated file is in sync

```dart
@TestOn('vm')
library;

import 'package:dev_build/build_support.dart';
import 'package:my_app/src/version.dart';
import 'package:tekartik_common_build/version_io.dart';
import 'package:test/test.dart';

void main() {
  test('version.dart matches pubspec.yaml', () async {
    expect(await hasGeneratedVersionFile(), isTrue);
    var pubspec = await pathGetPubspecYamlMap('.');
    expect(packageVersion, pubspecYamlGetVersion(pubspec));
  });
}
```

## Common mistakes

* Calling `generateVersion()` on a package that never had the file and
  expecting one: generation is opt-in, run it once with `force: true`.
* Editing `lib/src/version.dart` by hand, or adding code to it: the next
  generation replaces the whole file.
* Leaving `pub_semver` out of `dependencies:`: the generated file needs the
  `depend_on_referenced_packages` ignore and the analyzer complains as soon as
  the ignore is removed.
* Importing `version_io.dart` or `common_app_builder.dart` from Flutter or
  web code: they need `dart:io`. Only the generated `version.dart` belongs in
  app code.
* Using `pathAppVersionBumpAndGenerate()` without flags on a library: it adds
  or increments a build number (`1.2.3` becomes `1.2.4+0`). Pass
  `patch: true`.
* Bumping with `pathVersionBump` and forgetting `generateVersion()`: the app
  keeps reporting the previous version.
* Committing the bumped `pubspec.yaml` without the regenerated
  `lib/src/version.dart` (or the other way round): a later
  `generateVersion()` fixes the file, but the intermediate commit is
  inconsistent.
