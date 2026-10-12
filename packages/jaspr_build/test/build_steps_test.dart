import 'package:tekartik_jaspr_build/jaspr_build.dart';
import 'package:test/test.dart';

import 'src/site_fixture.dart';

const _url = 'https://example.youpi.app';

void main() {
  late SiteFixture site;
  setUp(() async {
    site = await SiteFixture.create();
  });
  tearDown(() async {
    await site.delete();
  });

  group('target marker', () {
    test('written, read and checked', () async {
      expect(jasprBuildReadTargetMarker(site.path), isNull);
      expect(
        () => jasprBuildCheckTargetMarker(site.path, 'dev'),
        throwsStateError,
      );
      await jasprBuildWriteTargetMarker(site.path, 'prod');
      expect(site.exists(jasprSiteTargetFileName), isTrue);
      expect(jasprBuildReadTargetMarker(site.path), 'prod');
      jasprBuildCheckTargetMarker(site.path, 'prod');
      expect(
        () => jasprBuildCheckTargetMarker(site.path, 'dev'),
        throwsStateError,
      );
    });
  });

  group('robots.txt', () {
    test('noindex', () async {
      await jasprBuildWriteRobots(site.path, url: _url, noIndex: true);
      expect(site.read('robots.txt'), 'User-agent: *\nDisallow: /\n');
    });
    test('indexed, with the sitemap', () async {
      await jasprBuildWriteRobots(site.path, url: _url, noIndex: false);
      expect(
        site.read('robots.txt'),
        'User-agent: *\nAllow: /\n\nSitemap: $_url/sitemap.xml\n',
      );
    });
  });

  group('404', () {
    test('moved for Hosting, per language', () async {
      site.page('404/index.html', title: 'en 404');
      site.page('fr/404/index.html', title: 'fr 404', lang: 'fr');
      site.page('de/404/index.html', title: 'de 404', lang: 'de');
      await jasprBuildMove404(site.path, otherLanguages: ['fr']);
      expect(site.read('404.html'), contains('en 404'));
      expect(site.read('i18n/fr/404.html'), contains('fr 404'));
      expect(site.exists('404'), isFalse);
      expect(site.exists('fr/404'), isFalse);
      // Not a language of the site: left alone.
      expect(site.exists('de/404/index.html'), isTrue);
    });
    test('missing pages skipped', () async {
      await jasprBuildMove404(site.path, otherLanguages: ['fr']);
      expect(site.exists('404.html'), isFalse);
    });
  });

  test('leftovers removed', () async {
    site.file('packages/jaspr/a.js', '');
    site.file('.dart_tool/x', '');
    site.file('.build.manifest', '');
    site.page('index.html');
    await jasprBuildRemoveLeftovers(site.path);
    for (var leftover in jasprBuildLeftovers) {
      expect(site.exists(leftover), isFalse, reason: leftover);
    }
    expect(site.exists('index.html'), isTrue);
  });

  test('sitemap trailing slashes', () async {
    site.sitemap(['$_url/', '$_url/faq', '$_url/fr/faq/']);
    await jasprBuildSitemapTrailingSlash(site.path);
    var sitemap = site.read('sitemap.xml');
    expect(sitemap, contains('<loc>$_url/</loc>'));
    expect(sitemap, contains('<loc>$_url/faq/</loc>'));
    expect(sitemap, contains('<loc>$_url/fr/faq/</loc>'));
    expect(sitemap, isNot(contains('<loc>$_url/faq</loc>')));
  });

  group('i18n copies', () {
    test('the french pages at the english paths', () async {
      site.page(
        'index.html',
        title: 'en home',
        alternates: {'en': '$_url/', 'fr': '$_url/fr/', 'x-default': '$_url/'},
      );
      site.page(
        'legal/index.html',
        title: 'en legal',
        alternates: {'en': '$_url/legal/', 'fr': '$_url/fr/mentions-legales/'},
      );
      // No french version.
      site.page('changelog/index.html', title: 'en changelog');
      site.page('fr/index.html', title: 'fr home', lang: 'fr');
      site.page(
        'fr/mentions-legales/index.html',
        title: 'fr legal',
        lang: 'fr',
      );
      site.page('404.html', title: 'en 404');

      var copied = await jasprBuildI18nCopies(
        site.path,
        language: 'fr',
        languages: ['fr'],
      );
      expect(copied, ['/', '/legal/']);
      expect(site.read('i18n/fr/index.html'), contains('fr home'));
      expect(site.read('i18n/fr/legal/index.html'), contains('fr legal'));
      expect(site.exists('i18n/fr/changelog'), isFalse);
      expect(site.exists('i18n/fr/fr'), isFalse);
      expect(site.exists('i18n/fr/404.html'), isFalse);
    });

    test('a french version that is not built throws', () async {
      site.page('faq/index.html', alternates: {'fr': '$_url/fr/faq/'});
      expect(
        () => jasprBuildI18nCopies(site.path, language: 'fr'),
        throwsStateError,
      );
    });

    test('regional codes match', () async {
      site.page('index.html', alternates: {'fr-FR': '$_url/fr/'});
      site.page('fr/index.html', title: 'fr home', lang: 'fr');
      expect(await jasprBuildI18nCopies(site.path, language: 'fr'), ['/']);
    });
  });
}
