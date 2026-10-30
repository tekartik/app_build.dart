@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tekartik_web_worker_build/web_worker_build.dart';
import 'package:test/test.dart';

const _script = WebWorkerScript(
  package: 'tekartik_web_worker_build',
  filename: 'hello_worker.js',
  name: 'test_hello_worker',
  mainSource: _helloMain,
  dependencies: ['path'],
  output: _helloOutput,
);

String _helloMain(ProjectPackages packages) =>
    "void main() {\n  print('hello ${packages.version('path')}');\n}\n";

String _helloOutput(String js, ProjectPackages packages) =>
    '// hello worker\n$js';

void main() {
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('web_worker_build');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('setup builds once, writes when changed', () async {
    var result = await _script.setup(dir: dir.path, force: true);
    expect(result.built, isTrue);
    expect(result.written, isTrue);
    expect(result.file.path, p.join(dir.path, 'hello_worker.js'));
    var js = await result.file.readAsString();
    expect(js, startsWith('// hello worker\n'));
    expect(js, contains('hello '));
    expect(js, isNot(contains('sourceMappingURL')));

    // What it was built from.
    var meta =
        jsonDecode(
              await File(
                p.join(
                  '.dart_tool',
                  'tekartik_web_worker_build',
                  'test_hello_worker',
                  'meta.json',
                ),
              ).readAsString(),
            )
            as Map;
    expect(meta, result.key);
    // The generated main, named after the script.
    expect(
      File(
        p.join(
          '.dart_tool',
          'tekartik_web_worker_build',
          'test_hello_worker',
          'hello_worker_main.dart',
        ),
      ).readAsStringSync(),
      meta['main'],
    );
    expect(meta['sdk'], Platform.version);
    expect(meta['compiler'], ['-O2']);
    expect((meta['packages'] as Map).keys, containsAll(['path']));

    var again = await _script.setup(dir: dir.path);
    expect(again.built, isFalse);
    expect(again.written, isFalse);

    // Written again from the cache.
    await result.file.writeAsString('changed');
    again = await _script.setup(dir: dir.path);
    expect(again.built, isFalse);
    expect(again.written, isTrue);
    expect(await again.file.readAsString(), js);

    again = await _script.setup(dir: dir.path, filename: 'other.js');
    expect(again.built, isFalse);
    expect(again.file.path, p.join(dir.path, 'other.js'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('setupMain', () async {
    await _script.setupMain(['--help']);
    await _script.setupMain(['--dir', dir.path]);
    expect(File(p.join(dir.path, 'hello_worker.js')).existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('not a dependency', () async {
    const script = WebWorkerScript(
      package: 'not_a_package',
      filename: 'none.js',
      entry: 'package:not_a_package/main.dart',
    );
    await expectLater(script.setup(dir: dir.path), throwsStateError);
  });
}
