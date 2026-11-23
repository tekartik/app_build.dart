import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:process_run/shell.dart';
import 'package:tekartik_app_io_launcher/launcher.dart'
    show findChromeExecutable;

import 'headless_chrome.dart';
import 'static_site_server.dart';

/// The compiler of a script run by [webRun].
enum WebRunCompiler {
  /// dart2js (`dart compile js`).
  js,

  /// dart2wasm (`dart compile wasm`).
  wasm,
}

/// A web run that failed: the compilation, the page (an uncaught error, a
/// script that did not load), the timeout.
class WebRunException implements Exception {
  /// What went wrong, the compiler output or the error and its stack trace
  /// included.
  final String message;

  /// An exception of [message].
  WebRunException(this.message);

  @override
  String toString() => 'WebRunException: $message';
}

/// The global the generated entry point sets: a promise of null (main
/// completed) or of the uncaught error.
const _doneGlobal = 'tekartikWebRunDone';

/// Runs the `main` of the Dart file [script] in a headless Chrome and
/// completes when it completes (and one more event loop turn); throws a
/// [WebRunException] when it throws
/// (or an error escapes it, an uncaught asynchronous one included), when
/// the script does not compile or load, or after [timeout].
///
/// [script] is a regular entry point (`main()` or `main(List<String> args)`,
/// sync or async) of a package with its dependencies fetched (its
/// `.dart_tool/package_config.json`, or its workspace's). A generated
/// entry point imports it, runs its `main` with [args] and reports its end;
/// it is compiled by [compiler] in `.dart_tool/tekartik_common_build/web_run`
/// of the package, served with an `index.html` on a free local port and
/// opened in Chrome ([findChromeExecutable]; not found: a [WebRunException]
/// before anything is built) with [chromeArguments] added
/// to `--autoplay-policy=no-user-gesture-required` (sound on without a user
/// gesture; add `--mute-audio` to keep the speakers quiet).
///
/// [files] are served next to the page, `{served path: local file}` (a web
/// worker script, an asset the script fetches by a relative url); a served
/// path is relative, without `..`, and not one of the generated files
/// (`index.html`, `main.*`).
///
/// The page's console goes to [onOut] (`log`, `info`, `debug`; `print`
/// writes there) and [onErr] (`error`, `warning`, uncaught exceptions), by
/// default stdout and stderr; [onStep] tells the steps (compiling,
/// running), silent by default.
Future<void> webRun(
  String script, {
  WebRunCompiler compiler = WebRunCompiler.js,
  List<String> args = const [],
  List<String> chromeArguments = const [],
  Map<String, String> files = const {},
  Duration timeout = const Duration(minutes: 5),
  void Function(String line)? onOut,
  void Function(String line)? onErr,
  void Function(String step)? onStep,
}) async {
  onOut ??= stdout.writeln;
  onErr ??= stderr.writeln;
  var file = File(p.normalize(p.absolute(script)));
  if (!file.existsSync()) {
    throw WebRunException('$script not found');
  }
  for (var MapEntry(key: served, value: local) in files.entries) {
    var segments = p.posix.split(served);
    if (served.isEmpty ||
        p.posix.isAbsolute(served) ||
        segments.contains('..') ||
        served == 'index.html' ||
        segments.first == 'main' ||
        segments.first.startsWith('main.')) {
      throw WebRunException('$served cannot be served');
    }
    if (!File(local).existsSync()) {
      throw WebRunException('$local not found (served as $served)');
    }
  }
  String executable;
  try {
    executable = findChromeExecutable();
  } on StateError catch (e) {
    throw WebRunException(e.message);
  }
  var project = _projectOf(file);
  var packageConfig = _findPackageConfigFile(project);
  var work = Directory(
    p.join(
      project,
      '.dart_tool',
      'tekartik_common_build',
      'web_run',
      '${p.basenameWithoutExtension(file.path)}_${compiler.name}',
    ),
  );
  if (work.existsSync()) {
    await work.delete(recursive: true);
  }
  await work.create(recursive: true);
  var entry = File(p.join(work.path, 'main.dart'));
  await entry.writeAsString(_entrySource(_importUri(file, project)));
  onStep?.call('compiling ${p.relative(file.path)} (${compiler.name})');
  var stopwatch = Stopwatch()..start();
  await _compile(compiler, entry, work, packageConfig);
  await File(
    p.join(work.path, 'index.html'),
  ).writeAsString(_indexHtml(compiler));
  for (var MapEntry(key: served, value: local) in files.entries) {
    var target = File(p.joinAll([work.path, ...p.posix.split(served)]));
    await target.parent.create(recursive: true);
    await File(local).copy(target.path);
  }
  onStep?.call('compiled in ${stopwatch.elapsedMilliseconds} ms, running');

  StaticSiteServer? server;
  HeadlessChrome? chrome;
  CdpSession? page;
  StreamSubscription<CdpEvent>? subscription;
  try {
    server = await StaticSiteServer.start(work.path);
    chrome = await HeadlessChrome.start(
      executable: executable,
      arguments: [
        '--autoplay-policy=no-user-gesture-required',
        ...chromeArguments,
      ],
    );
    page = await chrome.openPage();
    var failed = Completer<String>();
    subscription = page.events.listen((event) {
      switch (event.method) {
        case 'Runtime.consoleAPICalled':
          var line = _consoleLine(event.params);
          var type = event.params['type'];
          (type == 'error' || type == 'warning' ? onErr : onOut)!(line);
        case 'Runtime.exceptionThrown':
          var details = event.params['exceptionDetails'] as Map?;
          var exception = details?['exception'] as Map?;
          var text =
              exception?['description'] ?? details?['text'] ?? 'exception';
          onErr!('$text');
          if (!failed.isCompleted) {
            failed.complete('uncaught: $text');
          }
        case 'Inspector.targetCrashed':
          if (!failed.isCompleted) {
            failed.complete('the page crashed');
          }
      }
    });
    await page.call('Runtime.enable');
    await page.call('Page.enable');
    await page.call('Inspector.enable');
    var query = Uri(queryParameters: {'arg': args}).query;
    await page.call('Page.navigate', {
      'url': '${server.uri}/index.html${query.isEmpty ? '' : '?$query'}',
    });
    var done = page
        .evaluate(_waitDone, awaitPromise: true)
        .then((error) => error as String?);
    var error = await Future.any<String?>([
      done,
      failed.future,
    ]).timeout(timeout, onTimeout: () => 'timeout after $timeout');
    if (error != null) {
      throw WebRunException(error);
    }
  } finally {
    await subscription?.cancel();
    await page?.close();
    await chrome?.close();
    await server?.close();
  }
}

/// Waits for the promise the entry point sets once its script runs.
const _waitDone =
    '''
new Promise((resolve) => {
  const wait = () => window.$_doneGlobal
    ? window.$_doneGlobal.then(resolve, (e) => resolve(String(e)))
    : setTimeout(wait, 20);
  wait();
})''';

String _consoleLine(Map<String, Object?> params) {
  var args = (params['args'] as List?) ?? const [];
  return args
      .map((arg) {
        var object = arg as Map;
        return '${object['value'] ?? object['description'] ?? object['type']}';
      })
      .join(' ');
}

/// The package (the folder of the nearest `pubspec.yaml`) of [file].
String _projectOf(File file) {
  var directory = file.parent;
  while (true) {
    if (File(p.join(directory.path, 'pubspec.yaml')).existsSync()) {
      return directory.path;
    }
    var parent = directory.parent;
    if (parent.path == directory.path) {
      throw WebRunException('no pubspec.yaml above ${file.path}');
    }
    directory = parent;
  }
}

/// The package config file of the package at [path] or of its workspace.
File _findPackageConfigFile(String path) {
  var directory = Directory(path);
  while (true) {
    var file = File(
      p.join(directory.path, '.dart_tool', 'package_config.json'),
    );
    if (file.existsSync()) {
      return file;
    }
    var parent = directory.parent;
    if (parent.path == directory.path) {
      throw WebRunException(
        'no .dart_tool/package_config.json in $path or above: '
        'run dart pub get',
      );
    }
    directory = parent;
  }
}

/// [file] as the generated entry point imports it: a `package:` uri under
/// `lib/` (the same library as the package's own imports), else its file
/// uri.
String _importUri(File file, String project) {
  var lib = p.join(project, 'lib');
  if (p.isWithin(lib, file.path)) {
    var name = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(File(p.join(project, 'pubspec.yaml')).readAsStringSync());
    if (name != null) {
      return 'package:${name.group(1)}/'
          '${p.posix.joinAll(p.split(p.relative(file.path, from: lib)))}';
    }
  }
  return file.uri.toString();
}

String _entrySource(String importUri) =>
    '''
// Generated by tekartik_common_build webRun: runs the main of
// $importUri and reports its end (null or the error) in a promise.
import 'dart:async';
import 'dart:js_interop';

import '$importUri' as script;

@JS('$_doneGlobal')
external set _done(JSPromise<JSString?> value);

Future<String?> _run() {
  var done = Completer<String?>();
  runZonedGuarded(() async {
    var args = Uri.base.queryParametersAll['arg'] ?? const <String>[];
    dynamic main = script.main;
    Object? result = main is Function(List<String>) ? main(args) : main();
    if (result is Future) {
      await result;
    }
    // One more event loop turn: an error main left unawaited fails the run.
    await Future<void>.delayed(Duration.zero);
    if (!done.isCompleted) {
      done.complete(null);
    }
  }, (error, stackTrace) {
    if (!done.isCompleted) {
      done.complete('\$error\\n\$stackTrace');
    }
  });
  return done.future;
}

void main() {
  _done = _run().then((error) => error?.toJS).toJS;
}
''';

String _indexHtml(WebRunCompiler compiler) {
  var script = switch (compiler) {
    WebRunCompiler.js => '<script src="main.dart.js"></script>',
    WebRunCompiler.wasm =>
      '''
<script type="module">
import { compileStreaming } from './main.mjs';
const app = await compileStreaming(fetch('main.wasm'));
const instance = await app.instantiate({});
instance.invokeMain();
</script>''',
  };
  return '<!doctype html>\n<html><head><meta charset="utf-8">'
      '<title>web run</title></head>\n<body>\n$script\n</body></html>\n';
}

Future<void> _compile(
  WebRunCompiler compiler,
  File entry,
  Directory work,
  File packageConfig,
) async {
  var arguments = [
    'compile',
    compiler.name,
    '--packages=${packageConfig.path}',
    '--no-source-maps',
    '-o',
    p.join(
      work.path,
      compiler == WebRunCompiler.js ? 'main.dart.js' : 'main.wasm',
    ),
    entry.path,
  ];
  var result = await Shell(
    workingDirectory: work.path,
    stdin: const Stream<List<int>>.empty(),
    verbose: false,
    throwOnError: false,
  ).runExecutableArguments(_dartExecutable, arguments);
  if (result.exitCode != 0) {
    throw WebRunException(
      'dart ${arguments.join(' ')} failed:\n${result.stdout}${result.stderr}'
          .trim(),
    );
  }
}

/// The dart executable running this program, `dart` (from the path) when it
/// is a compiled executable.
String get _dartExecutable {
  var executable = Platform.resolvedExecutable;
  return p.basenameWithoutExtension(executable) == 'dart' ? executable : 'dart';
}
