import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_jaspr_build/jaspr_screenshot.dart';
import 'package:tekartik_jaspr_build/src/html_scan.dart';
import 'package:test/test.dart';

import 'src/site_fixture.dart';

void main() {
  late SiteFixture site;
  late String root;
  setUp(() async {
    site = await SiteFixture.create();
    // The served folder, a secret next to it.
    root = join(site.path, 'build');
    site.page('build/index.html', title: 'home');
    site.page('build/faq/index.html', title: 'faq');
    site.page('build/404.html', title: 'not found');
    site.file('build/a b.txt', 'space');
    site.file('secret.txt', 'SECRET');
    site.file('build/sub/secret.txt', 'in root');
  });
  tearDown(() => site.delete());

  test('jasprBuildFileOfPath', () {
    expect(jasprBuildFileOfPath(root, '/'), join(root, 'index.html'));
    expect(
      jasprBuildFileOfPath(root, '/faq/'),
      join(root, 'faq', 'index.html'),
    );
    expect(jasprBuildFileOfPath(root, '/faq'), join(root, 'faq', 'index.html'));
    expect(jasprBuildFileOfPath(root, '/a%20b.txt'), join(root, 'a b.txt'));
    expect(jasprBuildFileOfPath(root, '/missing/'), isNull);
  });

  test('jasprBuildFileOfPath stays in its folder', () {
    for (var path in [
      '/..',
      '/../secret.txt',
      '/%2E%2E/secret.txt',
      // A decoded `%2F` is a `/` within one segment.
      '/..%2Fsecret.txt',
      '/sub%2F..%2F..%2Fsecret.txt',
      '/sub/..%2F..%2Fsecret.txt',
      // A `/` inside a segment, even within the folder.
      '/sub%2Fsecret.txt',
      '/..%5Csecret.txt',
      // Not a valid percent encoding.
      '/%zz',
    ]) {
      expect(jasprBuildFileOfPath(root, path), isNull, reason: path);
    }
  });

  test('StaticSiteServer serves its folder only', () async {
    var server = await StaticSiteServer.start(root);
    var client = HttpClient();
    try {
      Future<(int, String)> get(String path) async {
        var response = await (await client.getUrl(
          Uri.parse('${server.uri}$path'),
        )).close();
        var body = await response.transform(systemEncoding.decoder).join();
        return (response.statusCode, body);
      }

      expect((await get('/faq/')).$1, 200);
      for (var path in ['/..%2Fsecret.txt', '/sub%2F..%2F..%2Fsecret.txt']) {
        var (status, body) = await get(path);
        expect(body, isNot(contains('SECRET')), reason: path);
        expect(status, 404, reason: path);
      }
    } finally {
      client.close(force: true);
      await server.close();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
