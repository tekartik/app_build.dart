import 'dart:convert';

import 'package:tekartik_jaspr_build/jaspr_build.dart';
import 'package:test/test.dart';

import 'src/site_fixture.dart';

const _dev = JasprSiteFlavor(
  target: 'dev',
  projectId: 'my-project',
  hostingId: 'my-site-dev',
  url: 'https://my-site-dev.web.app',
  noIndex: true,
);
const _prod = JasprSiteFlavor(
  target: 'prod',
  projectId: 'my-project',
  hostingId: 'my-site',
  url: 'https://my.youpi.app',
  noIndex: false,
);

Map<String, Object?> _cache(String value) => {
  'key': 'Cache-Control',
  'value': value,
};

final _commonHeaders = [
  {
    'regex': r'^(.*/|.*\.html)$',
    'headers': [_cache('public, max-age=300')],
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
];

const _noIndexHeader = {
  'source': '**',
  'headers': [
    {'key': 'X-Robots-Tag', 'value': 'noindex, nofollow'},
  ],
};

const _ignore = ['firebase.json', '**/.*', '**/node_modules/**'];

void main() {
  group('firebase.json', () {
    test('the hand written one of the first sites', () {
      // What sondelio_site, buzzerelio_site and chordelio_site (minus its
      // /audio/ rule) committed by hand, dev noindex, prod indexed.
      expect(jasprSiteFirebaseJson([_dev, _prod]), {
        'hosting': [
          {
            'target': 'dev',
            'public': 'public',
            'ignore': _ignore,
            'headers': [_noIndexHeader, ..._commonHeaders],
          },
          {
            'target': 'prod',
            'public': 'public',
            'ignore': _ignore,
            'headers': _commonHeaders,
          },
        ],
      });
    });

    test('noindex follows the flavor', () {
      var json = jsonEncode(
        jasprSiteFirebaseJson([
          const JasprSiteFlavor(
            target: 'prod',
            projectId: 'p',
            hostingId: 'h',
            url: 'https://h.web.app',
            noIndex: true,
          ),
        ]),
      );
      expect(json, contains('X-Robots-Tag'));
    });

    test('i18n, site headers and redirects', () {
      var redirect = {
        'source': '/confidentialite/',
        'destination': '/fr/confidentialite/',
        'type': 301,
      };
      var audio = {
        'source': '/audio/**',
        'headers': [_cache('public, max-age=31536000, immutable')],
      };
      var json = jasprSiteFirebaseJson(
        [_dev, _prod],
        i18n: true,
        hosting: JasprSiteHosting(headers: [audio], redirects: [redirect]),
      );
      expect(json, {
        'hosting': [
          {
            'target': 'dev',
            'public': 'public',
            'ignore': _ignore,
            'i18n': {'root': '/i18n'},
            // Already noindex everywhere: no i18n rule.
            'headers': [_noIndexHeader, ..._commonHeaders, audio],
            'redirects': [redirect],
          },
          {
            'target': 'prod',
            'public': 'public',
            'ignore': _ignore,
            'i18n': {'root': '/i18n'},
            'headers': [
              ..._commonHeaders,
              audio,
              {
                'source': '/i18n/**',
                'headers': [
                  {'key': 'X-Robots-Tag', 'value': 'noindex, nofollow'},
                ],
              },
            ],
            'redirects': [redirect],
          },
        ],
      });
    });

    test('written with 2 spaces and a final new line', () async {
      var site = await SiteFixture.create();
      try {
        await jasprSiteWriteFirebaseJson(
          site.path,
          jasprSiteFirebaseJson([_dev]),
        );
        var content = site.read('firebase.json');
        expect(content, startsWith('{\n  "hosting": [\n    {\n'));
        expect(content, endsWith('}\n'));
        expect(jsonDecode(content), jasprSiteFirebaseJson([_dev]));
      } finally {
        await site.delete();
      }
    });
  });
}
