import 'dart:io';

import 'package:process_run/shell.dart';

/// Parses a macOS version (`sw_vers -productVersion`: `26.6`, `15.7.1`),
/// empty when not parsed.
List<int> macosVersionParse(String text) {
  var parts = text.trim().split('.').map(int.tryParse).toList();
  return parts.isEmpty || parts.contains(null)
      ? const []
      : parts.nonNulls.toList();
}

/// The version of the macOS host (`sw_vers -productVersion`, `[26, 6]`),
/// `null` when not on macOS.
Future<List<int>?> getMacosVersion() async {
  if (!Platform.isMacOS) {
    return null;
  }
  try {
    var result = await Shell(
      verbose: false,
      throwOnError: false,
    ).runExecutableArguments('sw_vers', ['-productVersion']);
    var version = macosVersionParse(result.outText);
    return result.exitCode == 0 && version.isNotEmpty ? version : null;
  } on ShellException catch (_) {
    return null;
  }
}

/// The `open` arguments of [openMacosApp].
List<String> openMacosAppArguments(
  String app, {
  bool newInstance = false,
  List<String> arguments = const [],
}) => [
  if (newInstance) '-n',
  '-a',
  app,
  if (arguments.isNotEmpty) ...['--args', ...arguments],
];

/// Opens the macOS [app] (an `.app` path or an app name, `open -a`), a new
/// instance when [newInstance], with [arguments] (`--args`).
///
/// It does not wait for the app to quit. Throws a [ShellException] when it
/// cannot be opened.
Future<void> openMacosApp(
  String app, {
  bool newInstance = false,
  List<String> arguments = const [],
}) async {
  await Shell(verbose: false, commandVerbose: true).runExecutableArguments(
    'open',
    openMacosAppArguments(app, newInstance: newInstance, arguments: arguments),
  );
}
