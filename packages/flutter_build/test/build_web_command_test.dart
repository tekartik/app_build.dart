import 'package:tekartik_flutter_build/app_build.dart';
import 'package:tekartik_flutter_build/src/app_build_web.dart'
    show flutterWebBuildCommand, flutterWebRunCommand;
import 'package:test/test.dart';

void main() {
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
      expect(options.wasm, isNull);
      expect(wasm.copyWith(target: 'lib/main.dart').wasm, isTrue);
    });
  });
}
