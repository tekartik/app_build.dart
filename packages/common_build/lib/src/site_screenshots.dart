/// Screenshots of the pages of a static site (served locally or deployed)
/// with headless Chrome: [SiteScreenshotPage], [captureSiteScreenshots].
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';

import 'headless_chrome.dart';
import 'static_site_server.dart';

/// A page of a built site to capture.
class SiteScreenshotPage {
  /// The start of its file names: `01_home_en`.
  final String name;

  /// Its url path on the site: `/`, `/fr/faq/`, `/i18n/fr/404.html`.
  final String path;

  /// Its language (`<html lang>`), null when it has none.
  final String? lang;

  /// A page to capture.
  const SiteScreenshotPage(this.name, this.path, {this.lang});

  @override
  String toString() => '$name $path';
}

final _htmlLangRegExp = RegExp(
  r'''<html\b[^>]*\blang\s*=\s*["']?([^"'\s>]+)''',
  caseSensitive: false,
);

/// The `lang` attribute of the `<html>` tag of [html], null when none.
String? htmlLang(String html) => _htmlLangRegExp.firstMatch(html)?[1];

/// The url of [path] (a path, its query too: `/c?n=4`) on the site [base].
Uri screenshotPageUrl(Uri base, String path) =>
    Uri.parse('${base.toString().replaceAll(RegExp(r'/+$'), '')}$path');

/// Runs [action] with the url of the site: [url] when given (served
/// elsewhere, deployed), else the folder [root] served locally with
/// [mounts], as a single page app when [spa] ([StaticSiteServer]).
Future<T> withScreenshotSite<T>({
  String? root,
  Uri? url,
  Map<String, String> mounts = const {},
  bool spa = false,
  required Future<T> Function(Uri url) action,
}) async {
  if ((root == null) == (url == null)) {
    throw ArgumentError('one of root and url');
  }
  if (url != null) {
    return await action(url);
  }
  var server = await StaticSiteServer.start(root!, mounts: mounts, spa: spa);
  try {
    return await action(server.uri);
  } finally {
    await server.close();
  }
}

/// Captures each of [pages] in each of [views] with [capture], as
/// `<out>/<page.name>_<view.name>.png`; returns the files written.
///
/// [only] keeps the files whose name has one of its texts, [where] the
/// pairs it accepts (the dark view in one language only, for instance).
Future<List<File>> captureScreenshotFiles({
  required List<SiteScreenshotPage> pages,
  required String out,
  required List<ScreenshotView> views,
  required Future<Uint8List> Function(
    SiteScreenshotPage page,
    ScreenshotView view,
  )
  capture,
  List<String> only = const [],
  bool Function(SiteScreenshotPage page, ScreenshotView view)? where,
}) async {
  var files = <File>[];
  await Directory(out).create(recursive: true);
  for (var view in views) {
    for (var page in pages) {
      var name = '${page.name}_${view.name}.png';
      if ((only.isNotEmpty && !only.any(name.contains)) ||
          !(where?.call(page, view) ?? true)) {
        continue;
      }
      var png = await capture(page, view);
      var file = File(join(out, name));
      await file.writeAsBytes(png);
      files.add(file);
      var (width, height) = pngSize(png);
      stdout.writeln('$name ${width}x$height');
    }
  }
  return files;
}

/// Captures [pages] of the static site [root] (served locally with
/// [mounts], see [StaticSiteServer]) or at [url] in each of [views], full
/// page, as `<out>/<page.name>_<view.name>.png`; returns the files written.
///
/// [only] keeps the files whose name has one of its texts, [where] the
/// pairs it accepts (the dark view in one language only, for instance);
/// [script] runs in each page before the capture
/// ([PageScreenshotter.capture]). Chrome is [findChromeExecutable].
Future<List<File>> captureSiteScreenshots({
  String? root,
  Uri? url,
  required List<SiteScreenshotPage> pages,
  required String out,
  List<ScreenshotView> views = const [screenshotDesktop, screenshotMobile],
  List<String> only = const [],
  bool Function(SiteScreenshotPage page, ScreenshotView view)? where,
  Map<String, String> mounts = const {},
  String? script,
}) => withScreenshotSite(
  root: root,
  url: url,
  mounts: mounts,
  action: (siteUrl) async {
    var chrome = await HeadlessChrome.start();
    try {
      var screenshotter = await PageScreenshotter.open(await chrome.openPage());
      return await captureScreenshotFiles(
        pages: pages,
        out: out,
        views: views,
        only: only,
        where: where,
        capture: (page, view) => screenshotter.capture(
          screenshotPageUrl(siteUrl, page.path),
          view,
          script: script,
        ),
      );
    } finally {
      await chrome.close();
    }
  },
);
