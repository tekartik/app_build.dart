import 'dart:io';

import 'package:path/path.dart';

/// The `version:` of the pubspec of [packagePath] without its build number
/// (`1.0.24+63` gives `1.0.24`), for a site describing an app.
String pubspecVersion(String packagePath) {
  var lines = File(join(packagePath, 'pubspec.yaml')).readAsLinesSync();
  var line = lines.firstWhere(
    (line) => line.startsWith('version:'),
    orElse: () => throw StateError('no version in $packagePath/pubspec.yaml'),
  );
  var version = line.substring('version:'.length).trim();
  if (version.length >= 2 &&
      (version.startsWith('"') || version.startsWith("'")) &&
      version.endsWith(version[0])) {
    version = version.substring(1, version.length - 1);
  }
  return version.split('+').first;
}
