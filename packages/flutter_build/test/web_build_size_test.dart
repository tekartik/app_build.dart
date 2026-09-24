@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_common_build/formatter.dart';
import 'package:tekartik_flutter_build/app_build.dart';
import 'package:test/test.dart';

void main() {
  var top = join('.dart_tool', 'tekartik_flutter_build', 'test', 'size');

  /// Creates an app folder named [name] with [files] (path to size) in its
  /// `build/web`.
  String createApp(String name, Map<String, int> files) {
    var path = join(top, name);
    var webDir = Directory(join(path, 'build', 'web'));
    if (webDir.existsSync()) {
      webDir.deleteSync(recursive: true);
    }
    for (var entry in files.entries) {
      File(join(webDir.path, entry.key))
        ..createSync(recursive: true)
        ..writeAsBytesSync(List.filled(entry.value, 65));
    }
    return path;
  }

  group('FlutterWebBuildSize', () {
    test('js', () async {
      var path = createApp('js', {
        'main.dart.js': 1000,
        'main.dart.js_1.part.js': 200,
        'flutter.js': 50,
        'flutter_bootstrap.js': 50,
        'canvaskit/canvaskit.wasm': 5000,
      });
      var size = await FlutterWebBuildSize.read(path);
      expect(size.name, 'js');
      expect(size.isBuilt, isTrue);
      expect(size.hasWasm, isFalse);
      expect(size.jsFiles.map((file) => file.name), [
        'main.dart.js',
        'main.dart.js_1.part.js',
      ]);
      expect(size.jsSize, 1200);
      expect(size.jsPartCount, 1);
      expect(size.jsGzipSize, lessThan(1200));
      expect(size.wasmSize, 0);
      expect(size.toLines(), [
        'main.dart.js (1.172 KB, gzip ${formatSize(size.jsGzipSize)}, 1 part)',
      ]);
    });

    test('wasm', () async {
      var path = createApp('wasm', {
        'main.dart.js': 1000,
        'main.dart.mjs': 30,
        'main.dart.wasm': 800,
        'canvaskit/skwasm.wasm': 5000,
        'canvaskit/skwasm.js': 60,
      });
      var size = await FlutterWebBuildSize.read(path, name: 'my_app');
      expect(size.name, 'my_app');
      expect(size.hasWasm, isTrue);
      expect(size.wasmFiles.map((file) => file.name), [
        'main.dart.wasm',
        'main.dart.mjs',
      ]);
      expect(size.wasmSize, 830);
      expect(size.jsSize, 1000);
      expect(size.toLines(), hasLength(2));
    });

    test('not built', () async {
      var size = await FlutterWebBuildSize.read(join(top, 'none'));
      expect(size.isBuilt, isFalse);
      expect(size.toLines(), ['none: not built']);
    });

    test('js in a sub folder', () async {
      var path = createApp('sub', {'sub/main.dart.js': 100});
      var size = await FlutterWebBuildSize.read(path);
      expect(size.jsFiles.single.name, 'sub/main.dart.js');
    });
  });

  group('report', () {
    late List<FlutterWebBuildSize> sizes;
    setUpAll(() async {
      sizes = [
        await FlutterWebBuildSize.read(
          createApp('app1', {'main.dart.js': 2048}),
          buildDuration: const Duration(seconds: 12),
        ),
        await FlutterWebBuildSize.read(
          createApp('app2', {
            'main.dart.js': 1024,
            'main.dart.wasm': 4096,
            'main.dart.mjs': 1024,
          }),
        ),
        await FlutterWebBuildSize.read(join(top, 'app3')),
      ];
    });

    test('table', () {
      var lines = flutterWebBuildSizeMarkdownTable(sizes).split('\n');
      expect(lines, hasLength(5));
      expect(
        lines[0],
        '| app  |        js | js gzip | js parts |     wasm | wasm gzip | build |',
      );
      expect(lines[1], startsWith('|------|-----------|'));
      expect(lines[2], startsWith('| app1 |  2.000 KB |'));
      expect(lines[2], endsWith('|          |           |   12s |'));
      expect(lines[3], startsWith('| app2 |  1.000 KB |'));
      expect(lines[3], contains('| 5.000 KB |'));
      expect(lines[3], endsWith('|       |'));
      expect(lines[4], startsWith('| app3 | not built |'));
    });

    test('table without wasm nor duration', () {
      var table = flutterWebBuildSizeMarkdownTable(
        [sizes.first]
            .map(
              (size) => FlutterWebBuildSize(
                name: size.name,
                jsFiles: size.jsFiles,
                wasmFiles: size.wasmFiles,
              ),
            )
            .toList(),
      );
      expect(
        table.split('\n').first,
        '| app  |       js | js gzip | js parts |',
      );
    });

    test('write', () async {
      var file = await flutterWebBuildSizeWriteReport(
        sizes,
        dir: join(top, 'report'),
        name: 'size',
        now: DateTime(2026, 9, 4, 8, 5),
      );
      expect(basename(file.path), 'size_2026_09_04.md');
      var content = file.readAsStringSync();
      expect(
        content,
        startsWith('# Web build size report\n\n2026-09-04 08:05\n\n'),
      );
      expect(content, contains(flutterWebBuildSizeMarkdownTable(sizes)));
    });
  });
}
