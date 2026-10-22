@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_flutter_build/app_build.dart';
import 'package:tekartik_flutter_build/app_build_menu.dart'
    show menuBuildSecretsLine;
import 'package:tekartik_flutter_build/src/app_build_web.dart'
    show flutterWebRunCommand;
import 'package:test/test.dart';

void main() {
  group('entry point', () {
    test('lib/main_web.dart when present, the target first', () async {
      var dir = await Directory.systemTemp.createTemp('web_entry_point');
      try {
        FlutterWebAppBuilder builder({String? target}) => FlutterWebAppBuilder(
          options: FlutterWebAppOptions(
            path: dir.path,
            buildOptions: FlutterWebAppBuildOptions(target: target),
          ),
        );
        expect(flutterWebAppEntryPoint(dir.path), isNull);
        expect(builder().entryPoint, isNull);
        await File(
          join(dir.path, 'lib', 'main_web.dart'),
        ).create(recursive: true);
        expect(flutterWebAppEntryPoint(dir.path), 'lib/main_web.dart');
        expect(builder().entryPoint, 'lib/main_web.dart');
        expect(
          builder(target: 'lib/main_demo.dart').entryPoint,
          'lib/main_demo.dart',
        );
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('secrets', () {
    test('menu line', () {
      expect(menuBuildSecretsLine([]), contains('none'));
      var line = menuBuildSecretsLine([BuildSecret('awsKey', 'value1234')]);
      expect(line, contains('awsKey'));
      expect(line, isNot(contains('value1234')));
    });
  });

  group('command', () {
    test('build', () {
      expect(flutterWebBuildCommand(), 'flutter build web');
      expect(
        flutterWebBuildCommand(
          wasm: true,
          target: 'lib/main_dev.dart',
          noPub: true,
        ),
        'flutter build web --wasm --target lib/main_dev.dart --no-pub',
      );
      // The names kept in the wasm.
      expect(
        flutterWebBuildCommand(wasm: true, noStripWasm: true),
        'flutter build web --wasm --no-strip-wasm',
      );
      expect(
        flutterWebBuildCommand(wasm: true, noStripWasm: false),
        'flutter build web --wasm',
      );
      // Meaningless without wasm.
      expect(flutterWebBuildCommand(noStripWasm: true), 'flutter build web');
    });
    test('run', () {
      expect(
        flutterWebRunCommand(webPort: 8080),
        'flutter run -d chrome --web-port 8080',
      );
      expect(
        flutterWebRunCommand(
          webPort: 8063,
          wasm: true,
          target: 'lib/main_dev.dart',
          noPub: true,
          args: ['--release', '--dart-define=A=b c'],
        ),
        'flutter run -d chrome --web-port 8063 --wasm'
        ' --target lib/main_dev.dart --no-pub'
        ' --release "--dart-define=A=b c"',
      );
    });
  });
  group('options', () {
    test('copyWith keeps webPort', () {
      var buildOptions = FlutterWebAppBuildOptions(wasm: true);
      var options = FlutterWebAppOptions(
        path: '.',
        deployDir: 'deploy/dev',
        webPort: 8063,
        buildOptions: buildOptions,
      );
      var copy = options.copyWith(deployDir: 'deploy/prod');
      expect(copy.webPort, 8063);
      expect(copy.deployDir, 'deploy/prod');
      expect(copy.path, options.path);
      expect(copy.buildOptions, same(buildOptions));
      expect(options.copyWith(webPort: 8064).webPort, 8064);
      expect(FlutterWebAppOptions().webPort, 8080);
    });
    test('build options copyWith', () {
      var options = FlutterWebAppBuildOptions(target: 'lib/main_dev.dart');
      var wasm = options.copyWith(wasm: true);
      expect(wasm.wasm, isTrue);
      expect(wasm.target, 'lib/main_dev.dart');
      expect(wasm.noStripWasm, isNull);
      var named = wasm.copyWith(noStripWasm: true);
      expect(named.noStripWasm, isTrue);
      expect(named.wasm, isTrue);
      expect(named.copyWith(target: 'lib/main.dart').noStripWasm, isTrue);
      expect(options.wasm, isNull);
      expect(wasm.copyWith(target: 'lib/main.dart').wasm, isTrue);
    });
  });
}
