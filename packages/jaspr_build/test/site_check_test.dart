import 'package:tekartik_jaspr_build/jaspr_build.dart';
import 'package:test/test.dart';

import 'src/site_fixture.dart';

const _url = 'https://example.youpi.app';

/// A valid two language site: home and legal (different slugs), a 404 per
/// language, the i18n copies, sitemap and robots.
void _validSite(SiteFixture site, {bool noIndex = false}) {
  var homeAlternates = {
    'en': '$_url/',
    'fr': '$_url/fr/',
    'x-default': '$_url/',
  };
  var legalAlternates = {
    'en': '$_url/legal/',
    'fr': '$_url/fr/mentions-legales/',
  };
  site.page(
    'index.html',
    canonical: '$_url/',
    alternates: homeAlternates,
    noIndex: noIndex,
    links: ['/legal/', '/fr/', 'https://tekartik.com/', '#top', 'mailto:a@b'],
  );
  site.page(
    'legal/index.html',
    canonical: '$_url/legal/',
    alternates: legalAlternates,
    noIndex: noIndex,
    links: ['/', '/fr/mentions-legales/'],
  );
  site.page(
    'fr/index.html',
    lang: 'fr',
    canonical: '$_url/fr/',
    alternates: homeAlternates,
    noIndex: noIndex,
    links: ['/fr/mentions-legales/', '/'],
  );
  site.page(
    'fr/mentions-legales/index.html',
    lang: 'fr',
    canonical: '$_url/fr/mentions-legales/',
    alternates: legalAlternates,
    noIndex: noIndex,
  );
  // 404 pages: always noindex, no canonical.
  site.page('404.html', noIndex: true, links: ['/']);
  site.page('i18n/fr/404.html', lang: 'fr', noIndex: true, links: ['/fr/']);
  site.file('main.client.dart.js', '');
  site.file('i18n/fr/index.html', site.read('fr/index.html'));
  site.file(
    'i18n/fr/legal/index.html',
    site.read('fr/mentions-legales/index.html'),
  );
  for (var file in ['index.html', 'legal/index.html', '404.html']) {
    site.file('i18n/en/$file', site.read(file));
  }
  site.sitemap([
    '$_url/',
    '$_url/legal/',
    '$_url/fr/',
    '$_url/fr/mentions-legales/',
  ]);
  site.file(
    'robots.txt',
    noIndex
        ? 'User-agent: *\nDisallow: /\n'
        : 'User-agent: *\nAllow: /\n\nSitemap: $_url/sitemap.xml\n',
  );
}

void main() {
  late SiteFixture site;
  setUp(() async {
    site = await SiteFixture.create();
  });
  tearDown(() async {
    await site.delete();
  });

  Future<JasprSiteCheckResult> check({
    bool noIndex = false,
    List<String> monolingualPaths = const [],
  }) => jasprSiteCheck(
    site.path,
    url: _url,
    noIndex: noIndex,
    languages: ['en', 'fr'],
    monolingualPaths: monolingualPaths,
  );

  test('a valid site', () async {
    _validSite(site);
    var result = await check();
    expect(result.issues, isEmpty);
    expect(result.ok, isTrue);
    // The i18n copies are not counted, the french 404 is.
    expect(result.pageCount, 6);
    expect(result.toString(), 'ok (6 pages)');
  });

  test('a valid noindex site', () async {
    _validSite(site, noIndex: true);
    expect((await check(noIndex: true)).issues, isEmpty);
  });

  test('an empty build', () async {
    var result = await check();
    expect(result.ok, isFalse);
    expect(result.issues.first, contains('no page'));
  });

  test('404 pages: their head links are not checked', () async {
    _validSite(site);
    // As a site renders them: hreflang pairs between /404.html and /fr/404/,
    // the french one then moved to /i18n/fr/404.html.
    site.file(
      '404.html',
      site
          .read('404.html')
          .replaceFirst(
            '</head>',
            '<link rel="canonical" href="$_url/404.html"/>'
                '<link hreflang="en" href="$_url/404.html" rel="alternate"/>'
                '<link hreflang="fr" href="$_url/fr/404/" rel="alternate"/>'
                '</head>',
          ),
    );
    expect((await check()).issues, isEmpty);
    // Body links still are.
    site.page('404.html', noIndex: true, links: ['/missing/']);
    expect((await check()).issues, ['404.html: broken link /missing/']);
  });

  test('broken link', () async {
    _validSite(site);
    site.page(
      'legal/index.html',
      canonical: '$_url/legal/',
      alternates: {'en': '$_url/legal/', 'fr': '$_url/fr/mentions-legales/'},
      links: ['/faq/', 'img/missing.webp'],
    );
    expect((await check()).issues, [
      'legal/index.html: broken link /faq/',
      'legal/index.html: broken link img/missing.webp',
    ]);
  });

  test('srcset', () async {
    _validSite(site);
    site.file(
      'fr/index.html',
      site
          .read('fr/index.html')
          .replaceFirst(
            '</body>',
            '<img src="/a.webp" srcset="/a.webp 1x, /a@2x.webp 2x"/></body>',
          ),
    );
    site.file('a.webp', '');
    expect((await check()).issues, ['fr/index.html: broken link /a@2x.webp']);
  });

  test('link into i18n', () async {
    _validSite(site);
    site.page(
      'legal/index.html',
      canonical: '$_url/legal/',
      alternates: {'en': '$_url/legal/', 'fr': '$_url/fr/mentions-legales/'},
      links: ['/i18n/fr/'],
    );
    expect((await check()).issues, [
      'legal/index.html: links into /i18n/ (/i18n/fr/)',
    ]);
  });

  test('canonical and noindex', () async {
    _validSite(site);
    site.page(
      'legal/index.html',
      alternates: {'en': '$_url/legal/', 'fr': '$_url/fr/mentions-legales/'},
      noIndex: true,
    );
    site.page(
      'fr/mentions-legales/index.html',
      lang: 'fr',
      canonical: 'https://other.web.app/fr/mentions-legales/',
      alternates: {'en': '$_url/legal/', 'fr': '$_url/fr/mentions-legales/'},
    );
    var otherCanonical = 'https://other.web.app/fr/mentions-legales/';
    expect((await check()).issues, [
      'fr/mentions-legales/index.html: canonical $otherCanonical is not on $_url',
      'legal/index.html: 0 canonical links',
      'legal/index.html: robots noindex meta present',
    ]);
  });

  test('hreflang without link back', () async {
    _validSite(site);
    site.page(
      'fr/mentions-legales/index.html',
      lang: 'fr',
      canonical: '$_url/fr/mentions-legales/',
      alternates: {'fr': '$_url/fr/mentions-legales/'},
    );
    expect((await check()).issues, [
      '/legal/: its fr version /fr/mentions-legales/ does not link back',
    ]);
  });

  test('a page without french version', () async {
    _validSite(site);
    site.page(
      'changelog/index.html',
      canonical: '$_url/changelog/',
      links: ['/'],
    );
    site.file(
      'i18n/en/changelog/index.html',
      site.read('changelog/index.html'),
    );
    expect((await check()).issues, [
      'changelog/index.html: no fr version (hreflang)',
    ]);
    expect((await check(monolingualPaths: ['^/changelog/'])).issues, isEmpty);
  });

  test('a missing i18n copy', () async {
    _validSite(site);
    site.remove('i18n/fr/legal/index.html');
    expect((await check()).issues, ['legal/index.html: no fr copy in /i18n/']);
  });

  test('a missing default language copy', () async {
    _validSite(site);
    site.remove('i18n/en/legal/index.html');
    site.remove('i18n/en/404.html');
    expect((await check()).issues, [
      '404.html: no en copy in /i18n/',
      'legal/index.html: no en copy in /i18n/',
    ]);
  });

  test('a language with no version at all', () async {
    _validSite(site);
    var result = await jasprSiteCheck(
      site.path,
      url: _url,
      noIndex: false,
      languages: ['en', 'fr', 'de'],
    );
    expect(result.issues, [
      'index.html: no de version (hreflang)',
      'legal/index.html: no de version (hreflang)',
    ]);
  });

  test('sitemap and robots', () async {
    _validSite(site);
    site.sitemap([
      '$_url/',
      '$_url/404.html',
      '$_url/faq/',
      'https://other.web.app/',
      '$_url/i18n/fr/',
    ]);
    site.file('robots.txt', 'User-agent: *\nDisallow: /\n');
    expect((await check()).issues, [
      'sitemap.xml: lists $_url/404.html',
      'sitemap.xml: $_url/faq/ is not built',
      'sitemap.xml: https://other.web.app/ is not on $_url',
      'sitemap.xml: lists $_url/i18n/fr/',
      'robots.txt: "Disallow: /" on an indexed site',
      'robots.txt: no "Sitemap: $_url/sitemap.xml" line',
    ]);
  });
}
