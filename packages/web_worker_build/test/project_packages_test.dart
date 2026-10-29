@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tekartik_web_worker_build/web_worker_build.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectPackages', () {
    late ProjectPackages packages;
    setUpAll(() {
      packages = ProjectPackages.load();
    });

    test('workspace package config', () {
      // In the pub workspace of the repository.
      expect(
        p.basename(p.dirname(p.dirname(packages.packageConfigFile.path))),
        isNot('web_worker_build'),
      );
      expect(packages.has('tekartik_web_worker_build'), isTrue);
      expect(packages.has('not_a_package'), isFalse);
      expect(packages.version('tekartik_web_worker_build'), isNotNull);
      expect(packages.version('path'), isNotNull);
      expect(
        packages
            .libraryFile(
              Uri.parse(
                'package:tekartik_web_worker_build/web_worker_build.dart',
              ),
            )!
            .existsSync(),
        isTrue,
      );
    });

    test('dependencies', () {
      var dependencies = packages.dependencies(['tekartik_web_worker_build']);
      expect(dependencies, containsAll(['tekartik_web_worker_build', 'path']));
      // Not the dev dependencies.
      expect(dependencies, isNot(contains('test')));
      expect(packages.dependencies(['not_a_package']), isEmpty);
    });

    test('sourceKey', () {
      var key = packages.sourceKey('tekartik_web_worker_build');
      expect(key['version'], packages.version('tekartik_web_worker_build'));
      expect(key['hash'], hasLength(16));
      if (packages.isInPubCache('path')) {
        var pathKey = packages.sourceKey('path');
        expect(
          pathKey['pubCache'],
          'hosted/pub.dev/path-${pathKey['version']}',
        );
        expect(pathKey.containsKey('hash'), isFalse);
      }
    });
  });

  test('folderHash', () async {
    var dir = await Directory.systemTemp.createTemp('folder_hash');
    try {
      var empty = folderHash(dir);
      expect(empty, hasLength(16));
      expect(folderHash(Directory(p.join(dir.path, 'missing'))), empty);
      var file = File(p.join(dir.path, 'sub', 'a.dart'));
      await file.parent.create();
      await file.writeAsString('a');
      var hash = folderHash(dir);
      expect(hash, isNot(empty));
      expect(folderHash(dir), hash);
      await file.writeAsString('b');
      expect(folderHash(dir), isNot(hash));
      await file.writeAsString('a');
      expect(folderHash(dir), hash);
      await file.rename(p.join(dir.path, 'sub', 'b.dart'));
      expect(folderHash(dir), isNot(hash));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
