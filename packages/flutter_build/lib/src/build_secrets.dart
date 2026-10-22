import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart';
import 'package:process_run/stdio.dart';

/// A value a client build must never contain: a credential or a password
/// held in server code, that a client app could link by mistake (an import
/// of the wrong file is enough).
///
/// [name] is what a report shows, never [value].
class BuildSecret {
  /// The name shown in a report (`awsSecretAccessKey`).
  final String name;

  /// The searched value, at least [buildSecretMinLength] characters (a
  /// shorter one would match by chance).
  final String value;

  /// A secret [name] of [value].
  BuildSecret(this.name, this.value) {
    if (value.length < buildSecretMinLength) {
      throw ArgumentError.value(
        name,
        'value',
        'secret shorter than $buildSecretMinLength characters',
      );
    }
  }

  /// The secrets of [values], by name: the values come from the code that
  /// holds them, so the list follows a change of credentials.
  static List<BuildSecret> fromMap(Map<String, String> values) => [
    for (var entry in values.entries) BuildSecret(entry.key, entry.value),
  ];

  /// Never shows [value].
  @override
  String toString() => 'BuildSecret($name)';
}

/// The shortest [BuildSecret.value].
const buildSecretMinLength = 8;

/// A [BuildSecret] found in a build.
class BuildSecretMatch {
  /// The secret found.
  final BuildSecret secret;

  /// The file, `archive.apk!lib/arm64-v8a/libapp.so` for an entry of an
  /// archive.
  final String path;

  /// How it was written: `utf8` (javascript, wasm, one byte strings of a
  /// Dart AOT snapshot) or `utf16le` (two byte strings of a snapshot).
  final String encoding;

  /// A match of [secret] in [path].
  BuildSecretMatch({
    required this.secret,
    required this.path,
    required this.encoding,
  });

  /// Never shows the value.
  @override
  String toString() => '${secret.name} in $path ($encoding)';
}

/// Thrown by [buildCheckNoSecrets].
class BuildSecretsFoundException implements Exception {
  /// What was found.
  final List<BuildSecretMatch> matches;

  /// The [matches] of a check.
  BuildSecretsFoundException(this.matches);

  @override
  String toString() =>
      'BuildSecretsFoundException: ${matches.length} secret(s) found in the '
      'build:\n${matches.map((match) => '  $match').join('\n')}';
}

/// The extensions of the archives searched entry by entry (android apk and
/// app bundle, ios ipa, zip and jar).
const buildSecretsArchiveExtensions = ['.apk', '.aab', '.ipa', '.zip', '.jar'];

/// Searches [path] for [secrets]: every file of a directory (`build/web`, a
/// `Runner.app`), a file, or every entry of an archive
/// ([buildSecretsArchiveExtensions], an apk holds the Dart AOT snapshot in
/// `lib/<abi>/libapp.so`, an ipa in `App.framework/App`), archives in an
/// archive included.
///
/// A value is searched as UTF-8 and as UTF-16LE bytes, which covers the
/// javascript, the WebAssembly and the strings of a Dart AOT snapshot. A
/// value computed at run time (decrypted) is not in the build as such: list
/// what the code writes (the encrypted value and its password) too.
Future<List<BuildSecretMatch>> buildFindSecrets(
  String path,
  Iterable<BuildSecret> secrets,
) async {
  var patterns = <({BuildSecret secret, String encoding, Uint8List bytes})>[
    for (var secret in secrets) ...[
      (
        secret: secret,
        encoding: 'utf8',
        bytes: Uint8List.fromList(utf8.encode(secret.value)),
      ),
      (secret: secret, encoding: 'utf16le', bytes: _utf16le(secret.value)),
    ],
  ];
  var matches = <BuildSecretMatch>[];

  void searchBytes(String path, Uint8List data) {
    if (_isArchivePath(path)) {
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(data);
      } catch (_) {
        // Not a zip after all, searched as is.
        archive = Archive();
      }
      if (archive.isNotEmpty) {
        for (var entry in archive) {
          if (entry.isFile) {
            searchBytes('$path!${entry.name}', entry.content);
          }
        }
        return;
      }
    }
    for (var pattern in patterns) {
      if (_indexOf(data, pattern.bytes) >= 0) {
        matches.add(
          BuildSecretMatch(
            secret: pattern.secret,
            path: path,
            encoding: pattern.encoding,
          ),
        );
      }
    }
  }

  var type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type == FileSystemEntityType.directory) {
    var files =
        Directory(path)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (var file in files) {
      searchBytes(relative(file.path, from: path), await file.readAsBytes());
    }
  } else if (type == FileSystemEntityType.file) {
    searchBytes(basename(path), await File(path).readAsBytes());
  } else {
    throw ArgumentError.value(path, 'path', 'no such build');
  }
  return matches;
}

/// Throws a [BuildSecretsFoundException] when [path] contains one of
/// [secrets] (see [buildFindSecrets]); logs the check otherwise.
Future<void> buildCheckNoSecrets(
  String path,
  Iterable<BuildSecret> secrets,
) async {
  var secretList = secrets.toList();
  var matches = await buildFindSecrets(path, secretList);
  if (matches.isNotEmpty) {
    throw BuildSecretsFoundException(matches);
  }
  stdout.writeln('No secret in $path (${secretList.length} checked)');
}

bool _isArchivePath(String path) =>
    buildSecretsArchiveExtensions.contains(extension(path).toLowerCase());

Uint8List _utf16le(String value) {
  var bytes = Uint8List(value.length * 2);
  for (var i = 0; i < value.length; i++) {
    var unit = value.codeUnitAt(i);
    bytes[i * 2] = unit & 0xff;
    bytes[i * 2 + 1] = unit >> 8;
  }
  return bytes;
}

/// The first index of [pattern] in [data], -1 if none.
int _indexOf(Uint8List data, Uint8List pattern) {
  var length = pattern.length;
  if (length == 0) {
    return 0;
  }
  var first = pattern[0];
  var last = data.length - length;
  for (var i = 0; i <= last; i++) {
    if (data[i] != first) {
      continue;
    }
    var j = 1;
    while (j < length && data[i + j] == pattern[j]) {
      j++;
    }
    if (j == length) {
      return i;
    }
  }
  return -1;
}
