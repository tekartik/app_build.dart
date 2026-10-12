import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

import 'build_steps.dart';
import 'html_scan.dart';

/// What [jasprSiteCheck] found in a build.
class JasprSiteCheckResult {
  /// One line per problem, starting with the file or the url concerned.
  final List<String> issues;

  /// The pages checked (the i18n copies aside).
  final int pageCount;

  /// The external urls requested, 0 unless asked.
  final int externalCount;

  /// A result.
  JasprSiteCheckResult({
    required this.issues,
    required this.pageCount,
    required this.externalCount,
  });

  /// No issue.
  bool get ok => issues.isEmpty;

  @override
  String toString() {
    var checked =
        '$pageCount pages'
        '${externalCount > 0 ? ', $externalCount external urls' : ''}';
    if (ok) {
      return 'ok ($checked)';
    }
    return '${issues.length} issue${issues.length > 1 ? 's' : ''} '
        '($checked):\n${issues.map((issue) => '- $issue').join('\n')}';
  }
}

final _skippedScheme = RegExp(
  r'^(mailto|tel|sms|data|javascript|blob):',
  caseSensitive: false,
);

const _skippedRels = {'preconnect', 'dns-prefetch'};

bool _isHeadLink(HtmlTag tag) {
  var rels = (tag['rel'] ?? '').toLowerCase().split(RegExp(r'\s+'));
  return rels.contains('alternate') || rels.contains('canonical');
}

/// Checks the build in [buildPath], made for the site at [url] (no trailing
/// slash), [noIndex] or not, in [languages] (the first one is the default,
/// at the root, the others under `/<language>/`):
/// - every internal link (`href`, `src`, `srcset`) resolves to a built file,
///   and none goes into `/i18n/`;
/// - every page but the 404 ones has one canonical link on [url];
/// - every page but the 404 ones carries a robots noindex meta exactly when
///   [noIndex];
/// - hreflang links come in pairs: the page an alternate points to points
///   back;
/// - with several languages, every page of the default language has an
///   alternate in each other language, unless its path matches one of
///   [monolingualPaths] (regular expressions), and its i18n copy is built;
/// - the sitemap lists built pages on [url] only (no 404, no i18n copy);
/// - robots.txt matches [noIndex].
///
/// With [external], every absolute http(s) link to another site is also
/// requested (HEAD, then GET when refused) and must answer 2xx or 3xx.
Future<JasprSiteCheckResult> jasprSiteCheck(
  String buildPath, {
  required String url,
  required bool noIndex,
  List<String> languages = const ['en'],
  List<String> monolingualPaths = const [],
  bool external = false,
}) async {
  var issues = <String>[];
  var origin = Uri.parse(url);
  var otherLanguages = languages.skip(1).toList();
  var monolingual = monolingualPaths.map(RegExp.new).toList();
  var i18nPrefix = '$jasprSiteI18nFolder/';
  bool is404(String file) => file == '404.html' || file.endsWith('/404.html');
  bool isSameSite(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host == origin.host &&
      uri.port == origin.port;

  var pages = [
    for (var file in jasprBuildHtmlFiles(buildPath))
      // The i18n copies are the pages of the other languages again; the
      // 404 pages moved there are not copies.
      if (!file.startsWith(i18nPrefix) || is404(file)) file,
  ];
  if (pages.isEmpty) {
    issues.add('$buildPath: no page, build first');
  }
  var tagsByPath = <String, List<HtmlTag>>{};
  var externalLinks = <String, String>{};

  void checkLink(String file, Uri pageUri, String value) {
    if (value.isEmpty ||
        value.startsWith('#') ||
        _skippedScheme.hasMatch(value)) {
      return;
    }
    Uri resolved;
    try {
      resolved = pageUri.resolve(value.trim());
    } on FormatException {
      issues.add('$file: unreadable link $value');
      return;
    }
    if (isSameSite(resolved)) {
      var path = resolved.path;
      if (path.startsWith('/$i18nPrefix') || path == '/$jasprSiteI18nFolder') {
        issues.add('$file: links into /$jasprSiteI18nFolder/ ($value)');
      } else if (jasprBuildFileOfPath(buildPath, path) == null) {
        issues.add('$file: broken link $value');
      }
    } else if (resolved.scheme == 'http' || resolved.scheme == 'https') {
      externalLinks.putIfAbsent(
        resolved.removeFragment().toString(),
        () => file,
      );
    }
  }

  for (var file in pages) {
    var tags = htmlScanTags(await File(join(buildPath, file)).readAsString());
    var path = jasprBuildPathOfFile(file);
    var notFound = is404(file);
    // A 404 page is served at any missing url: its canonical and hreflang
    // links mean nothing, and the other language's 404 is moved into
    // /i18n/ where no link can reach it.
    if (!notFound) {
      tagsByPath[path] = tags;
    }
    var pageUri = origin.replace(path: path);
    // Relative links resolve against `<base href>` (jaspr writes `/`).
    var baseHref = htmlBaseHref(tags);
    if (baseHref != null) {
      pageUri = pageUri.resolve(baseHref);
    }

    for (var tag in tags) {
      if (tag.name == 'link' &&
          _skippedRels.contains((tag['rel'] ?? '').toLowerCase())) {
        continue;
      }
      if (notFound && tag.name == 'link' && _isHeadLink(tag)) {
        continue;
      }
      for (var attribute in const ['href', 'src']) {
        var value = tag[attribute];
        if (value != null) {
          checkLink(file, pageUri, value);
        }
      }
      var srcset = tag['srcset'];
      if (srcset != null) {
        for (var candidate in srcset.split(',')) {
          var value = candidate.trim().split(RegExp(r'\s+')).first;
          checkLink(file, pageUri, value);
        }
      }
    }

    if (notFound) {
      continue;
    }
    var canonicals = htmlCanonicals(tags);
    if (canonicals.length != 1) {
      issues.add('$file: ${canonicals.length} canonical links');
    } else if (!isSameSite(Uri.parse(canonicals.first))) {
      issues.add('$file: canonical ${canonicals.first} is not on $url');
    }
    var pageNoIndex = htmlHasNoIndex(tags);
    if (pageNoIndex != noIndex) {
      issues.add(
        '$file: robots noindex meta ${pageNoIndex ? 'present' : 'missing'}',
      );
    }
  }

  String normalizedPath(String path) =>
      path.endsWith('/') || extension(path).isNotEmpty ? path : '$path/';

  for (var MapEntry(key: path, value: tags) in tagsByPath.entries) {
    var alternates = htmlAlternates(tags);
    for (var MapEntry(key: language, value: href) in alternates.entries) {
      if (language == 'x-default') {
        continue;
      }
      var uri = Uri.parse(href);
      if (!isSameSite(uri)) {
        issues.add('$path: hreflang $language $href is not on $url');
        continue;
      }
      var target = normalizedPath(uri.path);
      if (target == path) {
        continue;
      }
      var targetTags = tagsByPath[target];
      if (targetTags == null) {
        // Not built: reported as a broken link.
        continue;
      }
      var back = htmlAlternates(
        targetTags,
      ).values.map((href) => normalizedPath(Uri.parse(href).path));
      if (!back.contains(path)) {
        issues.add('$path: its $language version $target does not link back');
      }
    }
  }

  if (otherLanguages.isNotEmpty) {
    for (var file in pages) {
      var path = jasprBuildPathOfFile(file);
      if (is404(file) ||
          otherLanguages.contains(file.split('/').first) ||
          monolingual.any((regExp) => regExp.hasMatch(path))) {
        continue;
      }
      var alternates = htmlAlternates(tagsByPath[path]!);
      for (var language in otherLanguages) {
        var has = alternates.keys.any(
          (code) => code == language || code.startsWith('$language-'),
        );
        if (!has) {
          issues.add('$file: no $language version (hreflang)');
        } else if (!File(
          join(buildPath, jasprSiteI18nFolder, language, file),
        ).existsSync()) {
          issues.add('$file: no $language copy in /$jasprSiteI18nFolder/');
        }
      }
    }
  }

  var sitemap = File(join(buildPath, 'sitemap.xml'));
  if (!sitemap.existsSync()) {
    issues.add('sitemap.xml: missing');
  } else {
    var content = await sitemap.readAsString();
    for (var match in RegExp(r'<loc>([^<]*)</loc>').allMatches(content)) {
      var loc = match.group(1)!.trim();
      var uri = Uri.tryParse(loc);
      if (uri == null || !isSameSite(uri)) {
        issues.add('sitemap.xml: $loc is not on $url');
        continue;
      }
      var path = uri.path;
      if (path.startsWith('/$i18nPrefix') ||
          RegExp(r'(^|/)404(/|\.html)?$').hasMatch(path)) {
        issues.add('sitemap.xml: lists $loc');
      } else if (jasprBuildFileOfPath(buildPath, path) == null) {
        issues.add('sitemap.xml: $loc is not built');
      }
    }
  }

  var robots = File(join(buildPath, 'robots.txt'));
  if (!robots.existsSync()) {
    issues.add('robots.txt: missing');
  } else {
    var content = await robots.readAsString();
    var disallowAll = RegExp(r'^Disallow:\s*/\s*$', multiLine: true);
    if (noIndex && !disallowAll.hasMatch(content)) {
      issues.add('robots.txt: no "Disallow: /" on a noindex site');
    } else if (!noIndex) {
      if (disallowAll.hasMatch(content)) {
        issues.add('robots.txt: "Disallow: /" on an indexed site');
      }
      if (!content.contains('Sitemap: $url/sitemap.xml')) {
        issues.add('robots.txt: no "Sitemap: $url/sitemap.xml" line');
      }
    }
  }

  var externalCount = 0;
  if (external) {
    var urls = externalLinks.keys.toList()..sort();
    externalCount = urls.length;
    var client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      var pending = [...urls];
      Future<void> worker() async {
        while (pending.isNotEmpty) {
          var link = pending.removeLast();
          var status = await _status(client, Uri.parse(link));
          if (status == null || status < 200 || status >= 400) {
            issues.add(
              '${externalLinks[link]}: $link answers ${status ?? 'nothing'}',
            );
          }
        }
      }

      await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    } finally {
      client.close(force: true);
    }
  }
  return JasprSiteCheckResult(
    issues: issues,
    pageCount: pages.length,
    externalCount: externalCount,
  );
}

/// The status of [uri], HEAD first then GET when HEAD is refused, null on a
/// network error or a timeout.
Future<int?> _status(HttpClient client, Uri uri) async {
  Future<int> request(String method) async {
    var request = await client.openUrl(method, uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (compatible; tekartik_jaspr_build link check)',
    );
    var response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  try {
    var status = await request('HEAD').timeout(const Duration(seconds: 20));
    if (status == 405 || status == 403 || status == 501) {
      status = await request('GET').timeout(const Duration(seconds: 20));
    }
    return status;
  } on Object {
    return null;
  }
}
