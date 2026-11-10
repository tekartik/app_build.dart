@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart' show runExecutableArguments;
import 'package:tekartik_flutter_build/build_secrets.dart';
import 'package:test/test.dart';

const _secretValue = 'S3cretAccessKey/With+Base64=';
const _passwordValue = 'YTSGCk3EgcDUvEuV26B2TNcb6Cw7YgCZ';

Uint8List _utf16le(String value) => Uint8List.fromList([
  for (var unit in value.codeUnits) ...[unit & 0xff, unit >> 8],
]);

Uint8List _zip(Map<String, List<int>> files) {
  var archive = Archive();
  for (var entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  late Directory dir;
  var secrets = BuildSecret.fromMap({
    'secretAccessKey': _secretValue,
    'password': _passwordValue,
  });
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('build_secrets_test');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  String file(String path, List<int> bytes) {
    var file = File(join(dir.path, path))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return file.path;
  }

  test('clean web build', () async {
    file('web/main.dart.js', utf8.encode('var a = "nothing to see";'));
    file('web/assets/data.bin', [0, 1, 2, 3]);
    expect(await buildFindSecrets(join(dir.path, 'web'), secrets), isEmpty);
    await buildCheckNoSecrets(join(dir.path, 'web'), secrets);
  });

  test('javascript and two byte strings', () async {
    file('web/main.dart.js', utf8.encode('x="$_secretValue";'));
    file('web/main.dart.wasm', [9, ..._utf16le(_passwordValue), 9]);
    var matches = await buildFindSecrets(join(dir.path, 'web'), secrets);
    expect(matches.map((match) => '$match'), [
      'secretAccessKey in main.dart.js (utf8)',
      'password in main.dart.wasm (utf16le)',
    ]);
    try {
      await buildCheckNoSecrets(join(dir.path, 'web'), secrets);
      fail('should fail');
    } on BuildSecretsFoundException catch (e) {
      expect(e.matches, hasLength(2));
      // The values are never shown.
      expect('$e', isNot(contains(_secretValue)));
      expect('$e', isNot(contains(_passwordValue)));
    }
  });

  test('apk entries and an archive in an archive', () async {
    var apk = file(
      'app-release.apk',
      _zip({
        'lib/arm64-v8a/libapp.so': [0, ...latin1.encode(_secretValue), 0],
        'assets/inner.zip': _zip({
          'deep.txt': utf8.encode('k=$_passwordValue'),
        }),
        'AndroidManifest.xml': [1, 2, 3],
      }),
    );
    var matches = await buildFindSecrets(apk, secrets);
    expect(matches.map((match) => '$match'), [
      'secretAccessKey in app-release.apk!lib/arm64-v8a/libapp.so (utf8)',
      'password in app-release.apk!assets/inner.zip!deep.txt (utf8)',
    ]);
    // A compressed entry is searched once inflated.
    var plain = file(
      'other.ipa',
      _zip({
        'Payload/Runner.app/Frameworks/App.framework/App': [0, 1],
      }),
    );
    expect(await buildFindSecrets(plain, secrets), isEmpty);
  });

  group('escaped and one byte strings', () {
    // Values a plain utf8 search misses in a dart2js build, the escaped
    // literal being what `dart compile js` writes (checked with dart 3.13).
    var specialSecrets = BuildSecret.fromMap({
      'pem': '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkq\n-----END',
      'quoted': 'pass"word\\with\\backslash',
      'bothQuotes': 'both"quotes\'inside-secret',
      'latin': 'motdepasse-éàü-secret',
      'euro': 'price-in-euro-€-secret',
      'emoji': 'emoji-😀-secret-value',
      'controls': 'tab\there-nul\x00-del\x7f-secret',
    });

    test('dart2js string literals', () async {
      file(
        'web/main.dart.js',
        utf8.encode(
          [
            r'a="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkq\n-----END"',
            r"""b='pass"word\\with\\backslash'""",
            r'''c="both\"quotes'inside-secret"''',
            r'd="motdepasse-\xe9\xe0\xfc-secret"',
            r'e="price-in-euro-\u20ac-secret"',
            r'f="emoji-\ud83d\ude00-secret-value"',
            r'g="tab\there-nul\x00-del\x7f-secret"',
          ].join(';'),
        ),
      );
      var matches = await buildFindSecrets(
        join(dir.path, 'web'),
        specialSecrets,
      );
      expect(matches.map((match) => '$match'), [
        'pem in main.dart.js (js)',
        'quoted in main.dart.js (js)',
        'bothQuotes in main.dart.js (js)',
        'latin in main.dart.js (js)',
        'euro in main.dart.js (js)',
        'emoji in main.dart.js (js)',
        'controls in main.dart.js (js)',
      ]);
    });

    test('one byte string of an AOT snapshot', () async {
      // A Dart AOT snapshot keeps a string whose characters are all
      // <= U+00FF as one byte (Latin-1) characters.
      var apk = file(
        'app-release.apk',
        _zip({
          'lib/arm64-v8a/libapp.so': [
            0,
            ...latin1.encode('motdepasse-éàü-secret'),
            0,
          ],
        }),
      );
      expect((await buildFindSecrets(apk, specialSecrets)).map((m) => '$m'), [
        'latin in app-release.apk!lib/arm64-v8a/libapp.so (latin1)',
      ]);
    });

    test('dart compile js', () async {
      var source = file(
        'src/main.dart',
        utf8.encode('''
void main() {
${[for (var secret in specialSecrets) '  print(${jsonEncode(secret.value)});'].join('\n')}
}
'''),
      );
      var out = join(dir.path, 'web', 'main.dart.js');
      await runExecutableArguments('dart', [
        'compile',
        'js',
        '-O2',
        '-o',
        out,
        source,
      ], verbose: false);
      var matches = await buildFindSecrets(
        join(dir.path, 'web'),
        specialSecrets,
      );
      expect(
        matches.map((match) => match.secret.name).toSet(),
        specialSecrets.map((secret) => secret.name).toSet(),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  test('a secret is long and its value is never shown', () {
    expect(() => BuildSecret('short', '1234567'), throwsArgumentError);
    expect('${secrets.first}', 'BuildSecret(secretAccessKey)');
  });

  test('missing build', () async {
    expect(
      () => buildFindSecrets(join(dir.path, 'none'), secrets),
      throwsArgumentError,
    );
  });
}
