/// A static file server on a free local port, serving a folder as a static
/// host (Firebase Hosting) does.
library;

import 'dart:io';

import 'package:path/path.dart';

/// A static file server on a free local port: [root] at `/`, and other
/// folders at their url prefix ([mounts], `/prefix/` to folder). A folder
/// url serves its `index.html`, a missing file the root's `404.html`.
/// Listens on 127.0.0.1; only the files within the folders are served
/// (see [staticSiteFileOfPath]: no `..`, no encoded `/` in a segment).
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
    var file = staticSiteFileOfPath(folder, path);
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
        // CanvasKit and skwasm only compile a wasm served as such.
        '.wasm' => ContentType('application', 'wasm'),
        '.xml' => ContentType('application', 'xml', charset: 'utf-8'),
        '.txt' || '.md' => ContentType.text,
        _ => ContentType.binary,
      };

  /// Stops serving.
  Future<void> close() => _server.close(force: true);
}

/// The file of the folder [root] that a static host (Firebase Hosting)
/// serves for the url [path] (`/faq/` or `/faq` give `faq/index.html`), null
/// when there is none.
///
/// [path] is percent encoded (`Uri.path`). Only a file within [root] is
/// returned: a `..` segment, a segment that decodes to a `/` or a `\`
/// (`..%2F`) and an invalid encoding give null.
String? staticSiteFileOfPath(String root, String path) {
  var segments = <String>[];
  for (var segment in path.split('/')) {
    if (segment.isEmpty) {
      continue;
    }
    String decoded;
    try {
      decoded = Uri.decodeComponent(segment);
    } on ArgumentError {
      return null;
    }
    if (decoded == '..' || decoded.contains('/') || decoded.contains(r'\')) {
      return null;
    }
    segments.add(decoded);
  }
  var base = joinAll([root, ...segments]);
  if (!equals(root, base) && !isWithin(root, base)) {
    return null;
  }
  if (!path.endsWith('/') && File(base).existsSync()) {
    return base;
  }
  var index = join(base, 'index.html');
  if (File(index).existsSync()) {
    return index;
  }
  return null;
}
