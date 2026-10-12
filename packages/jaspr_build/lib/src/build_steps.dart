/// The steps run on `build/jaspr` after `jaspr build`: what jaspr does not
/// write or writes in a way Firebase Hosting does not serve well.
library;

import 'dart:io';

import 'package:path/path.dart';

import 'html_scan.dart';

/// The file of a build naming the target it was built for. A dot file:
/// Hosting does not publish it (`**/.*` is ignored).
const jasprSiteTargetFileName = '.jaspr_site_target';

/// The folder of the build holding the per language copies served by
/// Firebase Hosting i18n rewrites (`"i18n": {"root": "/i18n"}`).
const jasprSiteI18nFolder = 'i18n';

/// The leftovers of `jaspr build` (build_runner) that no page uses.
const jasprBuildLeftovers = ['packages', '.dart_tool', '.build.manifest'];

/// Writes the target marker of the build in [buildPath].
Future<void> jasprBuildWriteTargetMarker(
  String buildPath,
  String target,
) async {
  await File(join(buildPath, jasprSiteTargetFileName)).writeAsString(target);
}

/// The target the build in [buildPath] was made for, null when unknown.
String? jasprBuildReadTargetMarker(String buildPath) {
  var file = File(join(buildPath, jasprSiteTargetFileName));
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// Throws when the build in [buildPath] was not made for [target]: its pages
/// carry the urls and the noindex flag of another site.
void jasprBuildCheckTargetMarker(String buildPath, String target) {
  var built = jasprBuildReadTargetMarker(buildPath);
  if (built != target) {
    throw StateError(
      'The last site build is for ${built ?? 'no known target'}, '
      'not $target: build for $target first',
    );
  }
}

/// Writes `robots.txt`: everything disallowed when [noIndex], otherwise
/// allowed with the sitemap of [url].
Future<void> jasprBuildWriteRobots(
  String buildPath, {
  required String url,
  required bool noIndex,
}) async {
  var robots = noIndex
      ? 'User-agent: *\nDisallow: /\n'
      : 'User-agent: *\nAllow: /\n\nSitemap: $url/sitemap.xml\n';
  await File(join(buildPath, 'robots.txt')).writeAsString(robots);
}

/// Moves the `/404` page to `404.html`, the page Firebase Hosting serves for
/// a missing file, and the `/<language>/404` page of each of
/// [otherLanguages] to `i18n/<language>/404.html`, its 404 for the browsers
/// asking for that language. A missing page is skipped.
Future<void> jasprBuildMove404(
  String buildPath, {
  List<String> otherLanguages = const [],
}) async {
  Future<void> move(String from, String to) async {
    var page = File(join(buildPath, from, 'index.html'));
    if (!page.existsSync()) {
      return;
    }
    var target = File(join(buildPath, to));
    await target.parent.create(recursive: true);
    await page.copy(target.path);
    await page.parent.delete(recursive: true);
  }

  await move('404', '404.html');
  for (var language in otherLanguages) {
    await move(
      join(language, '404'),
      join(jasprSiteI18nFolder, language, '404.html'),
    );
  }
}

/// Deletes the build_runner leftovers ([jasprBuildLeftovers]).
Future<void> jasprBuildRemoveLeftovers(String buildPath) async {
  for (var leftover in jasprBuildLeftovers) {
    var path = join(buildPath, leftover);
    switch (FileSystemEntity.typeSync(path)) {
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      case FileSystemEntityType.file || FileSystemEntityType.link:
        await File(path).delete();
      default:
    }
  }
}

/// Adds the trailing slash to the `<loc>`s of `sitemap.xml` that have none:
/// Hosting serves the pages at their url with a trailing slash.
Future<void> jasprBuildSitemapTrailingSlash(String buildPath) async {
  var sitemap = File(join(buildPath, 'sitemap.xml'));
  if (!sitemap.existsSync()) {
    return;
  }
  await sitemap.writeAsString(
    (await sitemap.readAsString()).replaceAllMapped(
      RegExp(r'<loc>([^<]*[^/])</loc>'),
      (match) => '<loc>${match.group(1)}/</loc>',
    ),
  );
}

/// Copies the pages of [language] to `i18n/<language>/` at the paths of
/// their default language version, for Firebase Hosting to serve them there
/// to the browsers asking for [language].
///
/// The pages of the default language are the html pages outside the
/// [languages] folders (`/fr/...`) and outside `i18n/`, `404.html` aside.
/// Each one names its [language] version with
/// `<link rel="alternate" hreflang="<language>" href="...">`: that page's
/// file is copied, so the urls of the two languages may differ (`/legal/`
/// and `/fr/mentions-legales/`). A page without such link gets no copy.
///
/// Returns the url paths copied, sorted.
Future<List<String>> jasprBuildI18nCopies(
  String buildPath, {
  required String language,
  List<String> languages = const [],
}) async {
  var copied = <String>[];
  var languageFolders = {...languages, language};
  for (var file in jasprBuildHtmlFiles(buildPath)) {
    var first = file.split('/').first;
    if (file == '404.html' ||
        first == jasprSiteI18nFolder ||
        languageFolders.contains(first) ||
        !file.endsWith('index.html')) {
      continue;
    }
    var tags = htmlScanTags(await File(join(buildPath, file)).readAsString());
    var href = _alternateFor(htmlAlternates(tags), language);
    if (href == null) {
      continue;
    }
    var source = jasprBuildFileOfPath(buildPath, Uri.parse(href).path);
    if (source == null) {
      throw StateError('$file: its $language version $href is not built');
    }
    var path = jasprBuildPathOfFile(file);
    var target = File(join(buildPath, jasprSiteI18nFolder, language, file));
    await target.parent.create(recursive: true);
    await File(source).copy(target.path);
    copied.add(path);
  }
  return copied..sort();
}

String? _alternateFor(Map<String, String> alternates, String language) {
  for (var entry in alternates.entries) {
    var code = entry.key.toLowerCase();
    if (code == language || code.startsWith('$language-')) {
      return entry.value;
    }
  }
  return null;
}
