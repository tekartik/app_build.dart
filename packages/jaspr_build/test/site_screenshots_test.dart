import 'dart:io';

import 'package:tekartik_jaspr_build/jaspr_screenshot.dart';
import 'package:test/test.dart';

import 'src/site_fixture.dart';

const _url = 'https://example.youpi.app';

void main() {
  late SiteFixture site;
  setUp(() async {
    site = await SiteFixture.create();
  });
  tearDown(() => site.delete());

  test('jasprBuildScreenshotPages', () {
    var home = {'en': '$_url/', 'fr': '$_url/fr/', 'x-default': '$_url/'};
    // No x-default: paired on the language of the home.
    var privacy = {'en': '$_url/privacy/', 'fr': '$_url/fr/confidentialite/'};
    site.page('index.html', alternates: home);
    site.page('fr/index.html', lang: 'fr', alternates: home);
    site.page('privacy/index.html', alternates: privacy);
    site.page('fr/confidentialite/index.html', lang: 'fr', alternates: privacy);
    site.page('faq/index.html');
    site.page('404.html');
    site.page('i18n/en/404.html');
    site.page('i18n/fr/404.html', lang: 'fr');
    site.page('i18n/fr/index.html', lang: 'fr', alternates: home);
    expect(
      jasprBuildScreenshotPages(site.path).map((page) => '$page').toList(),
      [
        '01_home_en /',
        '01_home_fr /fr/',
        '02_faq_en /faq/',
        '03_privacy_en /privacy/',
        '03_privacy_fr /fr/confidentialite/',
        '04_404_en /404.html',
        '04_404_fr /i18n/fr/404.html',
      ],
    );
  });

  test('StaticSiteServer', () async {
    site.page('index.html', title: 'home');
    site.page('faq/index.html', title: 'faq');
    site.page('404.html', title: 'not found');
    var server = await StaticSiteServer.start(site.path);
    var client = HttpClient();
    try {
      Future<(int, String)> get(String path) async {
        var response = await (await client.getUrl(
          server.uri.replace(path: path),
        )).close();
        var body = await response.transform(systemEncoding.decoder).join();
        return (response.statusCode, body);
      }

      var (status, body) = await get('/faq/');
      expect(status, 200);
      expect(body, contains('<title>faq</title>'));
      (status, body) = await get('/faq');
      expect(body, contains('<title>faq</title>'));
      (status, body) = await get('/missing/');
      expect(status, 404);
      expect(body, contains('<title>not found</title>'));
    } finally {
      client.close();
      await server.close();
    }
  });

  test('StaticSiteServer spa', () async {
    site.page('index.html', title: 'app');
    site.page('404.html', title: 'not found');
    var server = await StaticSiteServer.start(site.path, spa: true);
    var client = HttpClient();
    try {
      Future<(int, String)> get(String path) async {
        var response = await (await client.getUrl(
          screenshotPageUrl(server.uri, path),
        )).close();
        var body = await response.transform(systemEncoding.decoder).join();
        return (response.statusCode, body);
      }

      // A deep link of the app, its query too.
      var (status, body) = await get('/p/847-2-3?l=9');
      expect(status, 200);
      expect(body, contains('<title>app</title>'));
      // A missing file.
      (status, body) = await get('/missing.js');
      expect(status, 404);
      expect(body, contains('<title>not found</title>'));
    } finally {
      client.close();
      await server.close();
    }
  });

  test('screenshotPageUrl', () {
    expect(
      screenshotPageUrl(Uri.parse('https://a.web.app/'), '/c?n=4&ops=as'),
      Uri.parse('https://a.web.app/c?n=4&ops=as'),
    );
    expect(
      screenshotPageUrl(Uri.parse('http://127.0.0.1:8080'), '/'),
      Uri.parse('http://127.0.0.1:8080/'),
    );
  });
}
