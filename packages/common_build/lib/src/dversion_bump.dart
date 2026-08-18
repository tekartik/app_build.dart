import 'dart:io';

import 'package:args/args.dart';
import 'package:dev_build/build_support.dart';
import 'package:tekartik_common_build/version_io.dart';
import 'package:tekartik_prj_tktools/version.dart';

Future<void> main(List<String> arguments) async {
  var parser = ArgParser(allowTrailingOptions: true)
    ..addOption('path', help: 'path to the package', defaultsTo: '.')
    ..addFlag('patch')
    ..addFlag('minor')
    ..addFlag('major')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'show this help')
    ..addFlag('ext', help: 'next pre-release or build');
  var results = parser.parse(arguments);
  var help = results.flag('help');
  if (help) {
    stdout.writeln(
      'Default update low and bump patch version for flutter apps',
    );
    stdout.writeln('Usage: dversion_bump.dart [options]');
    stdout.writeln(parser.usage);
    return;
  }
  var patch = results.flag('patch');
  var minor = results.flag('minor');
  var major = results.flag('major');
  var ext = results.flag('ext');
  var path = results['path'] as String;

  var pubspecYaml = await pathGetPubspecYamlMap(path);
  var isFlutter = pubspecYamlSupportsFlutter(pubspecYaml);
  var couldBeApp = pubspecYamlHasAnyDependencies(pubspecYaml, [
    'cupertino_icons',
  ]);
  if (isFlutter && couldBeApp) {
    if (!patch && !minor && !major && !ext) {
      // Default for apps
      patch = true;
      ext = true;
    }
  }
  await _versionBumpAndGenerate(
    path: path,
    patch: patch,
    minor: minor,
    major: major,
    ext: ext,
  );
}

/// Bump the version then regenerate the version file if any.
Future<void> _versionBumpAndGenerate({
  String? path,
  required bool patch,
  required bool minor,
  required bool major,
  required bool ext,
}) async {
  await pathVersionBump(
    path: path,
    patch: patch,
    minor: minor,
    major: major,
    ext: ext,
  );
  if (await hasGeneratedVersionFile()) {
    stdout.writeln('Updating generated version.dart file');
    await generateVersion();
  }
}

/// Default for apps
Future<void> pathAppVersionBumpAndGenerate({
  String? path,
  bool? patch,
  bool? minor,
  bool? major,
  bool? ext,
}) async {
  major ??= false;
  minor ??= false;
  patch ??= false;
  ext ??= false;

  if (!patch && !minor && !major && !ext) {
    // Default for apps
    patch = true;
    ext = true;
  }
  await _versionBumpAndGenerate(
    path: path,
    patch: patch,
    minor: minor,
    major: major,
    ext: ext,
  );
}
