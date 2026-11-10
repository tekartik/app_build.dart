// Run with: dart run example/main.dart
//
// Works on a throw-away package in a temp folder: nothing of yours changes.
import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_common_build/formatter.dart';
import 'package:tekartik_common_build/version_io.dart';

Future<void> main() async {
  var dir = await Directory.systemTemp.createTemp('common_build_example');
  try {
    await File(
      join(dir.path, 'pubspec.yaml'),
    ).writeAsString('name: my_app\nversion: 1.2.3+4\n');

    // Opt in once: creates lib/src/version.dart (commit it in a real package).
    await generateVersion(path: dir.path, force: true);
    var file = File(join(dir.path, 'lib', 'src', 'version.dart'));
    stdout.writeln(await file.readAsString());

    // App default bump (patch and build number): 1.2.3+4 -> 1.2.4+5, and the
    // generated file follows.
    await pathAppVersionBumpAndGenerate(path: dir.path);
    stdout.writeln(
      (await file.readAsLines()).firstWhere((line) => line.contains("= '")),
    );

    stdout.writeln('version.dart: ${formatSize(await file.length())}');
  } finally {
    await dir.delete(recursive: true);
  }
}
