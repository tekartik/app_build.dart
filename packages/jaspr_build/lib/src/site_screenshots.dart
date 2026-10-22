import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart';

import 'build_steps.dart' show jasprSiteI18nFolder;
import 'cdp_screenshot.dart';
import 'html_scan.dart';

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

/// The pages of the jaspr build [buildPath] (`build/jaspr`), each language
/// version next to the others, numbered by page: the home first, the 404
/// last, the others in url order; `01_home_en` for `/`, `01_home_fr` for
/// `/fr/`, `02_faq_en` for `/faq/`...
///
/// The versions of a page are paired through their hreflang links, on the
/// `x-default` one or else the one of the language of the home
/// (`/fr/confidentialite/` goes with `/privacy/`), the 404 of the
/// other languages is the `i18n/<lang>/404.html` Hosting serves; the other
/// `i18n/` copies are left out (the same pages again).
List<SiteScreenshotPage> jasprBuildScreenshotPages(String buildPath) {
  const notFound = '/404.html';
  var pages = <({String group, String path, String? lang})>[];
  String? notFoundLang;
  var i18nNotFound = <String>[];
  var homeFile = File(join(buildPath, 'index.html'));
  var defaultLang = homeFile.existsSync()
      ? htmlLang(homeFile.readAsStringSync())
      : null;
  for (var file in jasprBuildHtmlFiles(buildPath)) {
    if (file.startsWith('$jasprSiteI18nFolder/')) {
      if (file.endsWith('/404.html')) {
        i18nNotFound.add(file);
      }
      continue;
    }
    var html = File(join(buildPath, file)).readAsStringSync();
    var path = jasprBuildPathOfFile(file);
    var group = path;
    if (path == notFound) {
      notFoundLang = htmlLang(html);
    } else {
      var alternates = htmlAlternates(htmlScanTags(html));
      var main = alternates['x-default'] ?? alternates[defaultLang];
      if (main != null) {
        group = Uri.parse(main).path;
      }
    }
    pages.add((group: group, path: path, lang: htmlLang(html)));
  }
  for (var file in i18nNotFound) {
    var lang = htmlLang(File(join(buildPath, file)).readAsStringSync());
    if (lang != notFoundLang) {
      pages.add((group: notFound, path: '/$file', lang: lang));
    }
  }
  int rank(String group) => switch (group) {
    '/' => 0,
    notFound => 2,
    _ => 1,
  };
  var groups = {for (var page in pages) page.group}.toList()
    ..sort((a, b) {
      var order = rank(a) - rank(b);
      return order != 0 ? order : a.compareTo(b);
    });
  String groupName(String group) => switch (group) {
    '/' => 'home',
    notFound => '404',
    _ =>
      group
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .join('_')
          .replaceAll(RegExp(r'\.html$'), '')
          .replaceAll(RegExp('[^A-Za-z0-9_]'), '_'),
  };
  return [
    for (var (index, group) in groups.indexed)
      // The page itself first (the default language), then the others.
      for (var page
          in pages.where((page) => page.group == group).toList()..sort((a, b) {
            var order = (a.path == group ? 0 : 1).compareTo(
              b.path == group ? 0 : 1,
            );
            return order != 0 ? order : a.path.compareTo(b.path);
          }))
        SiteScreenshotPage(
          [
            (index + 1).toString().padLeft(2, '0'),
            groupName(group),
            ?page.lang,
          ].join('_'),
          page.path,
          lang: page.lang,
        ),
  ];
}

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

/// Captures every page of the jaspr build [buildPath] (see
/// [jasprBuildScreenshotPages]) on a desktop and a phone, the night view
/// too when [dark], into [out]: the screenshots of a site for a review.
Future<List<File>> jasprSiteScreenshots({
  required String buildPath,
  required String out,
  bool dark = false,
  List<String> only = const [],
}) {
  if (!File(join(buildPath, 'index.html')).existsSync()) {
    throw StateError('no build in $buildPath: build the site first');
  }
  return captureSiteScreenshots(
    root: buildPath,
    pages: jasprBuildScreenshotPages(buildPath),
    out: out,
    views: [
      screenshotDesktop,
      screenshotMobile,
      if (dark) screenshotDesktopDark,
    ],
    only: only,
  );
}
