import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';

/// The platforms of [platforms] (`android`, `ios`, `linux`, `macos`,
/// `windows`, `web`) whose folder is missing in [projectPath].
List<String> flutterMissingPlatforms(
  String projectPath,
  Iterable<String> platforms,
) => platforms
    .toSet()
    .where((platform) => !Directory(join(projectPath, platform)).existsSync())
    .toList();

/// Creates the missing platform folders of the flutter project
/// [projectPath] (generated and git ignored in test apps):
/// `flutter create --platforms <missing> <arguments> .`, [arguments] being
/// for example `--org com.tekartik --empty`.
///
/// The `.metadata` (tracked) is kept as it was, the counter sample test
/// `flutter create` adds when the project has none
/// (`test/widget_test.dart`) is removed. Returns the platforms created.
Future<List<String>> flutterCreatePlatformsIfMissing(
  String projectPath,
  Iterable<String> platforms, {
  List<String> arguments = const [],
}) async {
  var missing = flutterMissingPlatforms(projectPath, platforms);
  if (missing.isEmpty) {
    return missing;
  }
  var metadata = File(join(projectPath, '.metadata'));
  var metadataContent = metadata.existsSync()
      ? metadata.readAsStringSync()
      : null;
  var testDir = Directory(join(projectPath, 'test'));
  var testDirExisted = testDir.existsSync();
  var widgetTest = File(join(testDir.path, 'widget_test.dart'));
  var widgetTestExisted = widgetTest.existsSync();
  await Shell(workingDirectory: projectPath).runExecutableArguments('flutter', [
    'create',
    '--platforms',
    missing.join(','),
    ...arguments,
    '.',
  ]);
  if (metadataContent != null) {
    metadata.writeAsStringSync(metadataContent);
  }
  if (!widgetTestExisted && widgetTest.existsSync()) {
    widgetTest.deleteSync();
    if (!testDirExisted && testDir.listSync().isEmpty) {
      testDir.deleteSync();
    }
  }
  return missing;
}
