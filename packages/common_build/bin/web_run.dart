import 'dart:io';

import 'package:args/args.dart';
import 'package:tekartik_common_build/web_run.dart';

/// Runs the `main` of a Dart file in a headless Chrome (sound on) and exits
/// when it completes: 0, or 1 when it fails (its error on stderr).
///
///     dart run tekartik_common_build:web_run example/main.dart
///     dart run tekartik_common_build:web_run --wasm example/main.dart arg1
Future<void> main(List<String> arguments) async {
  var parser = ArgParser()
    ..addFlag('wasm', help: 'Compile with dart2wasm (dart2js by default)')
    ..addFlag('mute', help: 'Mute the sound (--mute-audio)')
    ..addMultiOption(
      'file',
      help: 'A file served next to the page: <served path>=<local file>',
      splitCommas: false,
    )
    ..addOption('timeout', help: 'Seconds before giving up', defaultsTo: '300')
    ..addFlag('help', abbr: 'h', negatable: false);
  ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 64;
    return;
  }
  var timeout = int.tryParse(results.option('timeout')!);
  var files = <String, String>{};
  for (var file in results.multiOption('file')) {
    var equal = file.indexOf('=');
    if (equal <= 0) {
      stderr.writeln('--file $file: <served path>=<local file> expected');
      exitCode = 64;
      return;
    }
    files[file.substring(0, equal)] = file.substring(equal + 1);
  }
  if (results.flag('help') || results.rest.isEmpty || timeout == null) {
    stdout.writeln(
      'web_run [--wasm] [--mute] [--file served=local] <file.dart> [args...]',
    );
    stdout.writeln(parser.usage);
    exitCode = results.flag('help') ? 0 : 64;
    return;
  }
  try {
    await webRun(
      results.rest.first,
      compiler: results.flag('wasm') ? WebRunCompiler.wasm : WebRunCompiler.js,
      args: results.rest.sublist(1),
      chromeArguments: [if (results.flag('mute')) '--mute-audio'],
      files: files,
      timeout: Duration(seconds: timeout),
      onStep: (step) => stderr.writeln('web_run: $step'),
    );
  } on WebRunException catch (e) {
    stderr.writeln('web_run: ${e.message}');
    exitCode = 1;
  }
}
