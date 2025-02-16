@TestOn('vm')
library;

import 'dart:io';

import 'package:dev_build/shell.dart';
import 'package:path/path.dart';
import 'package:tekartik_flutter_build/app_build.dart';
import 'package:test/test.dart';

var _createdOnce = false;
Future<void> main() async {
  var path = join('.dart_tool', 'tekartik_build_flutter', 'test', 'app1');
  group('flutter_build', () {
    Future<void> createProject({bool? force}) async {
      if (!_createdOnce && (force == true || !Directory(path).existsSync())) {
        var shell = Shell(workingDirectory: path);
        Directory(path).createSync(recursive: true);
        await shell.run('flutter create .');
        _createdOnce = true;
      }
    }

    setUpAll(() async {
      await createProject();
    });
    test('build web', () async {
      var builder = FlutterWebAppBuilder(
          options: FlutterWebAppOptions(
              path: path,
              buildOptions: FlutterWebAppBuildOptions(
                  renderer: FlutterWebRenderer.canvasKit)));
      await builder.buildOnly();
    });
    test('build wasm', () async {
      var builder = FlutterWebAppBuilder(
          options: FlutterWebAppOptions(
              path: path, buildOptions: FlutterWebAppBuildOptions(wasm: true)));
      await builder.buildOnly();
    });
  }, skip: !isFlutterSupportedSync);
}
