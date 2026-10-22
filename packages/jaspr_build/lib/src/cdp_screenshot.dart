/// Screenshots of a static site with headless Chrome, driven through the
/// DevTools protocol: a local server for the build (and other folders), the
/// views (size, scale, phone, light or dark), full page captures, and an
/// optional script run in the page before the capture.
///
/// Chrome runs in a process_run [Shell]; the DevTools connection is a
/// dart:io [WebSocket].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dev_build/shell.dart';
import 'package:path/path.dart';

import 'html_scan.dart' show jasprBuildFileOfPath;

/// A browser window to capture a page in.
class ScreenshotView {
  /// The suffix of the file names: `desktop`, `mobile`...
  final String name;

  /// The width, in css pixels.
  final int width;

  /// The height of the window, in css pixels.
  final int height;

  /// The device pixel ratio.
  final num scale;

  /// A phone: the page's viewport meta tag applies, touch events.
  final bool mobile;

  /// `prefers-color-scheme: dark`.
  final bool dark;

  /// A window of [width] by [height] css pixels.
  const ScreenshotView(
    this.name, {
    required this.width,
    required this.height,
    this.scale = 1,
    this.mobile = false,
    this.dark = false,
  });
}

/// A laptop screen.
const screenshotDesktop = ScreenshotView('desktop', width: 1440, height: 900);

/// A phone (iPhone 12 to 15 size), at its pixel ratio.
const screenshotMobile = ScreenshotView(
  'mobile',
  width: 390,
  height: 844,
  scale: 2,
  mobile: true,
);

/// A laptop screen at night.
const screenshotDesktopDark = ScreenshotView(
  'desktop_dark',
  width: 1440,
  height: 900,
  dark: true,
);

/// A static file server on a free local port: [root] at `/`, and other
/// folders at their url prefix ([mounts], `/prefix/` to folder). A folder
/// url serves its `index.html`, a missing file the root's `404.html`.
///
/// With [spa] (a single page app, a Flutter web build with the path url
/// strategy), a missing url without an extension serves the root's
/// `index.html` instead, as the Hosting rewrite of the app does.
class StaticSiteServer {
  final HttpServer _server;
  final Map<String, String> _mounts;

  /// A single page app: the unknown paths serve the root's `index.html`.
  final bool spa;

  StaticSiteServer._(this._server, this._mounts, {required this.spa});

  /// Starts serving [root] and [mounts], as a single page app when [spa].
  static Future<StaticSiteServer> start(
    String root, {
    Map<String, String> mounts = const {},
    bool spa = false,
  }) async {
    var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var siteServer = StaticSiteServer._(server, {
      // The longest prefix first.
      for (var prefix
          in mounts.keys.toList()..sort((a, b) => b.length - a.length))
        prefix: mounts[prefix]!,
      '/': root,
    }, spa: spa);
    server.listen(siteServer._serve);
    return siteServer;
  }

  /// The server url, without a trailing slash.
  Uri get uri => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> _serve(HttpRequest request) async {
    var response = request.response;
    try {
      var path = request.uri.path;
      var prefix = _mounts.keys.firstWhere(path.startsWith);
      var file = _file(_mounts[prefix]!, '/${path.substring(prefix.length)}');
      if (file == null && spa && extension(path).isEmpty) {
        file = _file(_mounts['/']!, '/index.html');
      }
      if (file == null) {
        response.statusCode = HttpStatus.notFound;
        file = _file(_mounts['/']!, '/404.html');
      }
      if (file != null) {
        response.headers.contentType = _contentType(file.path);
        await response.addStream(file.openRead());
      }
    } catch (e) {
      response.statusCode = HttpStatus.internalServerError;
    }
    await response.close();
  }

  /// The file Hosting serves for the url [path] of [folder].
  static File? _file(String folder, String path) {
    var file = jasprBuildFileOfPath(folder, path);
    return file == null ? null : File(file);
  }

  static ContentType _contentType(String path) =>
      switch (extension(path).toLowerCase()) {
        '.html' => ContentType.html,
        '.css' => ContentType('text', 'css', charset: 'utf-8'),
        '.js' || '.mjs' => ContentType('text', 'javascript', charset: 'utf-8'),
        '.json' => ContentType.json,
        '.svg' => ContentType('image', 'svg+xml'),
        '.png' => ContentType('image', 'png'),
        '.webp' => ContentType('image', 'webp'),
        '.jpg' || '.jpeg' => ContentType('image', 'jpeg'),
        '.ico' => ContentType('image', 'x-icon'),
        '.woff2' => ContentType('font', 'woff2'),
        '.xml' => ContentType('application', 'xml', charset: 'utf-8'),
        '.txt' || '.md' => ContentType.text,
        _ => ContentType.binary,
      };

  /// Stops serving.
  Future<void> close() => _server.close(force: true);
}

/// A DevTools protocol error.
class CdpException implements Exception {
  /// What went wrong.
  final String message;

  /// A DevTools protocol error.
  CdpException(this.message);

  @override
  String toString() => 'CdpException: $message';
}

/// A DevTools protocol event: its method and its params.
typedef CdpEvent = ({String method, Map<String, Object?> params});

/// A DevTools protocol connection to one page.
class CdpSession {
  final WebSocket _socket;
  var _lastId = 0;
  final _pending = <int, Completer<Map<String, Object?>>>{};
  final _events = StreamController<CdpEvent>.broadcast();

  CdpSession._(this._socket) {
    _socket.listen(
      (data) => _onMessage(jsonDecode(data as String) as Map<String, Object?>),
      onDone: () {
        for (var completer in _pending.values) {
          completer.completeError(CdpException('connection closed'));
        }
        _pending.clear();
        _events.close();
      },
    );
  }

  /// Connects to the DevTools web socket [url] of a page.
  static Future<CdpSession> connect(String url) async =>
      CdpSession._(await WebSocket.connect(url));

  /// The events (after their domain is enabled, as `Page.enable`).
  Stream<CdpEvent> get events => _events.stream;

  void _onMessage(Map<String, Object?> message) {
    var id = message['id'];
    if (id is int) {
      var completer = _pending.remove(id);
      var error = message['error'];
      if (error != null) {
        completer?.completeError(CdpException(jsonEncode(error)));
      } else {
        completer?.complete(
          (message['result'] as Map?)?.cast<String, Object?>() ?? {},
        );
      }
    } else if (message['method'] case String method) {
      _events.add((
        method: method,
        params: (message['params'] as Map?)?.cast<String, Object?>() ?? {},
      ));
    }
  }

  /// Calls [method] with [params], returns its result.
  Future<Map<String, Object?>> call(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    var id = ++_lastId;
    var completer = _pending[id] = Completer<Map<String, Object?>>();
    _socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    return completer.future;
  }

  /// Evaluates the JavaScript [expression] in the page, returns its value
  /// (json), awaited first when [awaitPromise].
  Future<Object?> evaluate(
    String expression, {
    bool awaitPromise = false,
  }) async {
    var result = await call('Runtime.evaluate', {
      'expression': expression,
      'awaitPromise': awaitPromise,
      'returnByValue': true,
    });
    var exception = result['exceptionDetails'];
    if (exception != null) {
      throw CdpException('evaluate: ${jsonEncode(exception)}');
    }
    return (result['result'] as Map?)?['value'];
  }

  /// Closes the connection.
  Future<void> close() => _socket.close();
}

/// The Chrome executable: `CHROME_EXECUTABLE` (environment or the
/// process_run user env file), else the first Chrome or Chromium found on
/// the path, else the usual macOS location.
String findChromeExecutable() {
  var executable = userEnvironment['CHROME_EXECUTABLE'];
  if (executable != null) {
    return executable;
  }
  for (var command in const [
    'google-chrome',
    'google-chrome-stable',
    'chromium',
    'chromium-browser',
    'chrome',
  ]) {
    var path = whichSync(command);
    if (path != null) {
      return path;
    }
  }
  const mac = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  if (Platform.isMacOS && File(mac).existsSync()) {
    return mac;
  }
  throw StateError('Chrome not found: set CHROME_EXECUTABLE');
}

/// Headless Chrome with its DevTools port open, in a temporary profile,
/// run by a process_run [Shell] until [close].
class HeadlessChrome {
  final Shell _shell;
  final Process _process;
  final Future<void> _done;
  final Directory _profile;

  /// The DevTools port.
  final int port;

  HeadlessChrome._(
    this._shell,
    this._process,
    this._done,
    this._profile,
    this.port,
  );

  /// Starts Chrome ([executable], [findChromeExecutable] by default), with
  /// [arguments] added to the defaults.
  static Future<HeadlessChrome> start({
    String? executable,
    List<String> arguments = const [],
  }) async {
    executable ??= findChromeExecutable();
    var profile = await Directory.systemTemp.createTemp('cdp_screenshot_');
    // Quiet (no command line, no output) and nothing kept of Chrome's logs.
    var shell = Shell(
      options: ShellOptions(
        verbose: false,
        noStdoutResult: true,
        noStderrResult: true,
      ),
    );
    var exited = false;
    Process? process;
    var done = shell
        .runExecutableArguments(executable, [
          '--headless=new',
          // Chrome picks the port and writes it in DevToolsActivePort.
          '--remote-debugging-port=0',
          '--user-data-dir=${profile.path}',
          '--no-first-run',
          '--no-default-browser-check',
          '--hide-scrollbars',
          ...arguments,
          'about:blank',
        ], onProcess: (started) => process = started)
        .then<void>((_) {}, onError: (Object _) {})
        .whenComplete(() => exited = true);
    var portFile = File(join(profile.path, 'DevToolsActivePort'));
    for (var i = 0; i < 200 && !exited; i++) {
      if (portFile.existsSync()) {
        var port = int.tryParse(
          (await portFile.readAsLines()).firstOrNull ?? '',
        );
        if (port != null && process != null) {
          return HeadlessChrome._(shell, process!, done, profile, port);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    shell.kill();
    await done;
    await profile.delete(recursive: true);
    throw StateError('$executable did not open its DevTools port');
  }

  /// The page Chrome opened, ready for [PageScreenshotter].
  Future<CdpSession> openPage() async {
    var client = HttpClient();
    try {
      var request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/json/list'),
      );
      var response = await request.close();
      var targets =
          (jsonDecode(await response.transform(utf8.decoder).join()) as List)
              .cast<Map<String, Object?>>();
      var page = targets.firstWhere((target) => target['type'] == 'page');
      return await CdpSession.connect(page['webSocketDebuggerUrl'] as String);
    } finally {
      client.close();
    }
  }

  /// Stops Chrome and deletes its profile.
  Future<void> close() async {
    _shell.kill();
    await _done;
    // The run ends at the kill, the profile is free once Chrome has exited.
    await _process.exitCode;
    try {
      await _profile.delete(recursive: true);
    } catch (_) {
      // Chrome may still hold a file for a moment: a temp folder left.
    }
  }
}

/// Captures pages in one Chrome tab.
class PageScreenshotter {
  /// The tab.
  final CdpSession page;

  PageScreenshotter._(this.page);

  /// Enables the page events [capture] waits for.
  static Future<PageScreenshotter> open(CdpSession page) async {
    await page.call('Page.enable');
    return PageScreenshotter._(page);
  }

  /// A png of [url] in [view]: the whole page when [fullPage], the window
  /// otherwise, or its top [clipHeight] css pixels when given.
  ///
  /// After the load and the fonts, [script] runs in the page (awaited when
  /// it returns a promise) and its images are decoded, then the capture
  /// waits [settle] (animations, client code).
  Future<Uint8List> capture(
    Uri url,
    ScreenshotView view, {
    String? script,
    bool fullPage = true,
    int? clipHeight,
    Duration settle = const Duration(milliseconds: 1600),
  }) async {
    await _setSize(view, view.height);
    await page.call('Emulation.setEmulatedMedia', {
      'features': [
        {'name': 'prefers-color-scheme', 'value': view.dark ? 'dark' : 'light'},
      ],
    });
    var loaded = page.events.firstWhere(
      (event) => event.method == 'Page.loadEventFired',
    );
    await page.call('Page.navigate', {'url': url.toString()});
    await loaded.timeout(const Duration(seconds: 60));
    await page.evaluate(
      'document.fonts.ready.then(() => true)',
      awaitPromise: true,
    );
    if (script != null) {
      await page.evaluate(script, awaitPromise: true);
      await page.evaluate(
        'Promise.all([...document.images].map((i) => i.decode().catch(() => 0)))',
        awaitPromise: true,
      );
    }
    await Future<void>.delayed(settle);
    if (fullPage && clipHeight == null) {
      var height =
          await page.evaluate(
                'Math.ceil(document.documentElement.scrollHeight)',
              )
              as num;
      await _setSize(view, max(view.height, height.toInt()));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    var shot = await page.call('Page.captureScreenshot', {
      'format': 'png',
      if (clipHeight != null)
        'clip': {
          'x': 0,
          'y': 0,
          'width': view.width,
          'height': clipHeight,
          'scale': 1,
        },
    });
    return base64Decode(shot['data'] as String);
  }

  Future<void> _setSize(ScreenshotView view, int height) =>
      page.call('Emulation.setDeviceMetricsOverride', {
        'width': view.width,
        'height': height,
        'deviceScaleFactor': view.scale,
        'mobile': view.mobile,
      });
}

/// The width and height of a png, from its header.
(int width, int height) pngSize(Uint8List png) {
  var data = ByteData.sublistView(png);
  return (data.getUint32(16), data.getUint32(20));
}
