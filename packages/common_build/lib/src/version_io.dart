import 'package:dev_build/build_support.dart';
import 'package:fs_shim/utils/io/read_write.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';
import 'package:pub_semver/pub_semver.dart';

String _generateContent({
  bool? ignoreDependOnReferencedPackages,
  required Version version,
}) {
  ignoreDependOnReferencedPackages ??= false;
  return '''
${ignoreDependOnReferencedPackages ? '// ignore: depend_on_referenced_packages' : ''}
import 'package:pub_semver/pub_semver.dart';

/// Package version text
const packageVersionText = '$version';
/// Package version
final packageVersion = Version.parse(packageVersionText);
''';
}

/// Generate lib/src/version.dart with a text
Future<void> generateVersion({String path = '.'}) async {
  var pubspecYamlMap = await pathGetPubspecYamlMap(path);

  var version = pubspecYamlGetVersion(pubspecYamlMap);
  var versionPackageName = 'pub_semver';
  var dependencies = pubspecYamlGetDependenciesPackageName(pubspecYamlMap);
  var file = File(join(path, 'lib', 'src', 'version.dart'));
  file.parent.createSync(recursive: true);
  var ignoreDependOnReferencedPackages = !dependencies.contains(
    versionPackageName,
  );
  await file.writeAsString(
    stringToIoString(
      _generateContent(
        ignoreDependOnReferencedPackages: ignoreDependOnReferencedPackages,
        version: version,
      ),
    ),
  );
  await Shell(
    workingDirectory: path,
  ).run('dart format ${shellArgument(file.path)}');
}

/// Current around 227 characters
bool _checkGeneratedContent(String content) {
  return content.length < 1000 &&
      content.contains('const packageVersionText = ') &&
      content.contains('final packageVersion = ');
}

/// Returns true if the provided content matches the generated version file content
@visibleForTesting
bool checkGeneratedVersionFileContent(String content) {
  return _checkGeneratedContent(content);
}

/// Returns the generated version file content
@visibleForTesting
String generateVersionFileContent({
  bool? ignoreDependOnReferencedPackages,
  required Version version,
}) {
  return _generateContent(
    ignoreDependOnReferencedPackages: ignoreDependOnReferencedPackages,
    version: version,
  );
}

/// Returns true if lib/src/version.dart has been generated
Future<bool> hasGeneratedVersionFile({String path = '.'}) async {
  var file = File(join(path, 'lib', 'src', 'version.dart'));
  if (!file.existsSync()) {
    return false;
  }
  var content = await file.readAsString();
  return _checkGeneratedContent(content);
}
