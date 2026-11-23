@TestOn('vm')
library;

import 'package:tekartik_common_build/web_run.dart';
import 'package:test/test.dart';

void main() {
  for (var compiler in WebRunCompiler.values) {
    group(compiler.name, () {
      test('main completes, its prints and args come back', () async {
        var out = <String>[];
        await webRun(
          'test/web_run/ok_main.dart',
          compiler: compiler,
          args: ['a b', r'c$'],
          chromeArguments: ['--mute-audio'],
          onOut: out.add,
        );
        expect(out, ['hello a b,c\$', 'done']);
      });

      test('main throws', () async {
        await expectLater(
          webRun(
            'test/web_run/throw_main.dart',
            compiler: compiler,
            onErr: (_) {},
          ),
          throwsA(
            isA<WebRunException>().having(
              (e) => e.message,
              'message',
              contains('failed on purpose'),
            ),
          ),
        );
      });
    }, timeout: const Timeout(Duration(minutes: 2)));
  }

  test('an error escaping main', () async {
    await expectLater(
      webRun(
        'test/web_run/uncaught_main.dart',
        onErr: (_) {},
        timeout: const Duration(seconds: 60),
      ),
      throwsA(
        isA<WebRunException>().having(
          (e) => e.message,
          'message',
          contains('escaped on purpose'),
        ),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a script that does not compile', () async {
    await expectLater(
      webRun('test/web_run/missing_main.dart'),
      throwsA(isA<WebRunException>()),
    );
  });

  test('files served next to the page', () async {
    var out = <String>[];
    await webRun(
      'test/web_run/fetch_main.dart',
      files: {'data/hello.txt': 'test/web_run/hello.txt'},
      onOut: out.add,
    );
    expect(out, ['served next to the page']);
    for (var served in [
      'index.html',
      'main.dart.js',
      'main.wasm',
      '../x',
      '/x',
    ]) {
      await expectLater(
        webRun(
          'test/web_run/fetch_main.dart',
          files: {served: 'test/web_run/hello.txt'},
        ),
        throwsA(isA<WebRunException>()),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
