@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_common_build/static_site_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late String root;
  void file(String path, String content) {
    var file = File(join(dir.path, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('static_site_server_test_');
    // The served folder, a secret next to it.
    root = join(dir.path, 'build');
    file('build/index.html', 'home');
    file('build/faq/index.html', 'faq');
    file('build/404.html', 'not found');
    file('build/a b.txt', 'space');
    file('build/app.wasm', 'wasm');
    file('secret.txt', 'SECRET');
    file('build/sub/secret.txt', 'in root');
  });
  tearDown(() => dir.delete(recursive: true));

  test('staticSiteFileOfPath', () {
    expect(staticSiteFileOfPath(root, '/'), join(root, 'index.html'));
    expect(
      staticSiteFileOfPath(root, '/faq/'),
      join(root, 'faq', 'index.html'),
    );
    expect(staticSiteFileOfPath(root, '/faq'), join(root, 'faq', 'index.html'));
    expect(staticSiteFileOfPath(root, '/a%20b.txt'), join(root, 'a b.txt'));
    expect(staticSiteFileOfPath(root, '/missing/'), isNull);
  });

  test('staticSiteFileOfPath stays in its folder', () {
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
      expect(staticSiteFileOfPath(root, path), isNull, reason: path);
    }
  });

  test('StaticSiteServer', () async {
    var server = await StaticSiteServer.start(root);
    var client = HttpClient();
    try {
      Future<(int, String, String?)> get(String path) async {
        var response = await (await client.getUrl(
          Uri.parse('${server.uri}$path'),
        )).close();
        var body = await response.transform(systemEncoding.decoder).join();
        return (
          response.statusCode,
          body,
          response.headers.contentType?.mimeType,
        );
      }

      expect(await get('/faq/'), (200, 'faq', 'text/html'));
      expect(await get('/app.wasm'), (200, 'wasm', 'application/wasm'));
      expect(await get('/missing'), (404, 'not found', 'text/html'));
      for (var path in ['/..%2Fsecret.txt', '/sub%2F..%2F..%2Fsecret.txt']) {
        var (status, body, _) = await get(path);
        expect(body, isNot(contains('SECRET')), reason: path);
        expect(status, 404, reason: path);
      }
    } finally {
      client.close(force: true);
      await server.close();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
