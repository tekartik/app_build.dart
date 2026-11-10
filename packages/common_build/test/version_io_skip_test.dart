@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_common_build/version_io.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late File versionFile;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('common_build_version');
    await File(
      join(dir.path, 'pubspec.yaml'),
    ).writeAsString('name: my_pkg\nversion: 1.2.3\n');
    versionFile = File(join(dir.path, 'lib', 'src', 'version.dart'));
    await versionFile.parent.create(recursive: true);
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('a hand-written version.dart is not replaced', () async {
    var content =
        "/// My version (kept by hand).\nconst myVersion = '1.0.0';\n";
    await versionFile.writeAsString(content);
    expect(await hasGeneratedVersionFile(path: dir.path), isFalse);
    await generateVersion(path: dir.path);
    expect(await versionFile.readAsString(), content);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a generated version.dart is refreshed', () async {
    await versionFile.writeAsString('''
/// Generated - do not edit
library;

import 'package:pub_semver/pub_semver.dart';

/// Package version text
const packageVersionText = '1.0.0';

/// Package version
final packageVersion = Version.parse(packageVersionText);
''');
    await generateVersion(path: dir.path);
    expect(
      await versionFile.readAsString(),
      contains("const packageVersionText = '1.2.3';"),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
