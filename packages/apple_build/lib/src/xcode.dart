import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';

Shell _quietShell() => Shell(verbose: false, throwOnError: false);

/// The developer folder of the selected Xcode (`xcode-select -p`,
/// `/Applications/Xcode.app/Contents/Developer`), `null` when there is none
/// (not macOS, no Xcode selected).
Future<String?> getXcodeDeveloperPath() async {
  if (!Platform.isMacOS) {
    return null;
  }
  try {
    var result = await _quietShell().runExecutableArguments('xcode-select', [
      '-p',
    ]);
    var path = result.outText.trim();
    return result.exitCode == 0 && path.isNotEmpty ? path : null;
  } on ShellException catch (_) {
    return null;
  }
}

/// The simulator app paths of the Xcode of [developerPath], in preference
/// order: `DeviceHub.app` (Xcode 27+, next to the `Developer` folder), then
/// `Simulator.app` (before Xcode 27).
List<String> xcodeSimulatorAppPaths(String developerPath) => [
  join(dirname(developerPath), 'Applications', 'DeviceHub.app'),
  join(developerPath, 'Applications', 'Simulator.app'),
];

/// The simulator app of the selected Xcode: `DeviceHub.app` (Xcode 27+) or
/// `Simulator.app`, `null` when not found.
Future<String?> getXcodeSimulatorAppPath() async {
  var developerPath = await getXcodeDeveloperPath();
  if (developerPath == null) {
    return null;
  }
  for (var path in xcodeSimulatorAppPaths(developerPath)) {
    if (Directory(path).existsSync()) {
      return path;
    }
  }
  return null;
}

/// The version of Xcode, see [getXcodeVersion].
class XcodeVersion {
  /// `[27, 2]`.
  final List<int> version;

  /// The build version (`27B52`), `null` when not known.
  final String? build;

  /// The Xcode [version] and its [build].
  XcodeVersion(this.version, {this.build});

  /// The major version (`27`).
  int get major => version.first;

  @override
  String toString() =>
      'Xcode ${version.join('.')}${build == null ? '' : ' ($build)'}';
}

/// Parses the output of `xcodebuild -version`
/// (`Xcode 27.2\nBuild version 27B52`), `null` when not parsed.
XcodeVersion? xcodeVersionParse(String output) {
  var match = RegExp(
    r'^Xcode (\d+(?:\.\d+)*)',
    multiLine: true,
  ).firstMatch(output);
  if (match == null) {
    return null;
  }
  var build = RegExp(
    r'^Build version (\S+)',
    multiLine: true,
  ).firstMatch(output)?.group(1);
  return XcodeVersion(
    match.group(1)!.split('.').map(int.parse).toList(),
    build: build,
  );
}

/// The version of the selected Xcode (`xcodebuild -version`), `null` when
/// there is none.
Future<XcodeVersion?> getXcodeVersion() async {
  if (!Platform.isMacOS) {
    return null;
  }
  try {
    var result = await _quietShell().runExecutableArguments('xcodebuild', [
      '-version',
    ]);
    return result.exitCode == 0 ? xcodeVersionParse(result.outText) : null;
  } on ShellException catch (_) {
    return null;
  }
}
