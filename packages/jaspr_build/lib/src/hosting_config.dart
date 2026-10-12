import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

import 'build_steps.dart';
import 'jaspr_site_flavor.dart';

Map<String, Object?> _cache(String value) => {
  'key': 'Cache-Control',
  'value': value,
};

const _noIndexValue = 'noindex, nofollow';

/// The `firebase.json` of a jaspr static site, one Hosting entry per flavor
/// of [flavors]:
/// - nothing hidden (`firebase.json`, dot files such as the target marker,
///   `node_modules`) is published;
/// - `X-Robots-Tag: noindex, nofollow` on every file exactly when the flavor
///   is [JasprSiteFlavor.noIndex];
/// - 5 minutes of cache for the pages and the scripts, a year for `/fonts/`
///   (immutable), a day for the images; with [i18n] the browsers revalidate
///   the pages each time (`max-age=0`), the CDN keeps them 5 minutes
///   (`s-maxage=300`);
/// - with [i18n], the `i18n` root of the Hosting language rewrites, its
///   folder kept out of search engines when reached directly;
/// - then the site's own [hosting] headers and redirects.
Map<String, Object?> jasprSiteFirebaseJson(
  List<JasprSiteFlavor> flavors, {
  bool i18n = false,
  JasprSiteHosting hosting = const JasprSiteHosting(),
}) => {
  'hosting': [
    for (var flavor in flavors)
      {
        'target': flavor.target,
        'public': 'public',
        'ignore': ['firebase.json', '**/.*', '**/node_modules/**'],
        if (i18n) 'i18n': {'root': '/$jasprSiteI18nFolder'},
        'headers': [
          if (flavor.noIndex)
            {
              'source': '**',
              'headers': [
                {'key': 'X-Robots-Tag', 'value': _noIndexValue},
              ],
            },
          {
            // Directory indexes (`/`, `/faq/`) and html files: a glob
            // such as `**/*.html` does not match `/` or `/faq/`.
            'regex': r'^(.*/|.*\.html)$',
            'headers': [
              // With i18n a url serves one page per language, chosen by
              // Accept-Language or the language cookie: the browser must
              // revalidate (it does not key its cache on the cookie), the
              // CDN keeps caching (it does).
              _cache(
                i18n
                    ? 'public, max-age=0, s-maxage=300'
                    : 'public, max-age=300',
              ),
            ],
          },
          {
            'source': '**/*.js',
            'headers': [_cache('public, max-age=300')],
          },
          {
            'source': '/fonts/**',
            'headers': [_cache('public, max-age=31536000, immutable')],
          },
          {
            'source': '**/*.@(webp|png|svg|ico)',
            'headers': [_cache('public, max-age=86400')],
          },
          ...hosting.headers,
          // The copies are served at the urls of the default language; the
          // folder itself is a third url that must not be indexed. The
          // header follows the request path, so the copies served at `/`
          // do not get it.
          if (i18n && !flavor.noIndex)
            {
              'source': '/$jasprSiteI18nFolder/**',
              'headers': [
                {'key': 'X-Robots-Tag', 'value': _noIndexValue},
              ],
            },
        ],
        if (hosting.redirects.isNotEmpty) 'redirects': hosting.redirects,
      },
  ],
};

/// Writes [firebaseJson] ([jasprSiteFirebaseJson]) to `firebase.json` in
/// [hostingPath] (2 spaces indent, final new line).
Future<void> jasprSiteWriteFirebaseJson(
  String hostingPath,
  Map<String, Object?> firebaseJson,
) async {
  await Directory(hostingPath).create(recursive: true);
  await File(join(hostingPath, 'firebase.json')).writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(firebaseJson)}\n',
  );
}
