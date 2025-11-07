@TestOn('vm')
library;

import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_common_build/src/common_version_io.dart';
import 'package:test/test.dart';

void main() {
  test('Generate Version', () async {
    await generateVersion(force: true);
    var content = File('lib/src/version.dart').readAsStringSync();
    expect(content, startsWith('/// Generated - do not edit'));
  });
  test('check gnerate version in example', () async {
    expect(Version.parse('1.0.0').toString(), '1.0.0');
    expect(checkGeneratedVersionFileContent(''), isFalse);
    expect(
      checkGeneratedVersionFileContent(
        generateVersionFileContent(version: Version(1, 0, 0)),
      ),
      isTrue,
    );
  });
}
