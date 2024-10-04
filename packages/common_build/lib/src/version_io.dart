import 'package:dev_build/build_support.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';

/// Generate lib/src/version.dart with a text
Future<void> generateVersion({String path = '.'}) async {
  var pubspecYamlMap = await pathGetPubspecYamlMap(path);

  var version = pubspecYamlGetVersion(pubspecYamlMap);
  var versionPackageName = 'pub_semver';
  var dependencies = pubspecYamlGetDependenciesPackageName(pubspecYamlMap);
  var file = File(join(path, 'lib', 'src', 'version.dart'));
  file.parent.createSync(recursive: true);
  await file.writeAsString('''
${dependencies.contains(versionPackageName) ? '' : '// ignore: depend_on_referenced_packages'}
import 'package:pub_semver/pub_semver.dart';

/// Package version text
const packageVersionText = '$version';
/// Package version
final packageVersion = Version.parse(packageVersionText);
''');
  await Shell(workingDirectory: path)
      .run('dart format ${shellArgument(file.path)}');
}
