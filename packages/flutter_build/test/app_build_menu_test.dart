@TestOn('vm')
library;

import 'package:tekartik_flutter_build/app_build.dart';
import 'package:tekartik_flutter_build/src/app_build_menu.dart'
    show FlutterWebAppAllBuilders;
import 'package:tekartik_web_publish/web_publish.dart';
import 'package:test/test.dart';

class _FakeController extends BuildShellController {
  var cancelCount = 0;

  @override
  void cancel() {
    cancelCount++;
  }
}

FlutterWebAppBuilder _builder(String path, {WebAppDeployer? deployer}) =>
    FlutterWebAppBuilder(
      options: FlutterWebAppOptions(path: path),
      deployer: deployer,
      target: path,
    );

void main() {
  group('FlutterWebAppAllBuilders', () {
    test('a controller per builder, cancel cancels all', () {
      var builders = [_builder('a'), _builder('b')];
      var controllers = <_FakeController>[];
      var all = FlutterWebAppAllBuilders(
        builders,
        newController: (_) {
          var controller = _FakeController();
          controllers.add(controller);
          return controller;
        },
      );
      expect(all.builders.map((builder) => builder.target), ['a', 'b']);
      expect(all.builders.map((builder) => builder.controller), controllers);
      expect(controllers, hasLength(2));
      // The given builders are left alone.
      expect(builders.map((builder) => builder.controller), [null, null]);
      all.cancel();
      expect(controllers.map((controller) => controller.cancelCount), [1, 1]);
    });

    test('default controllers', () {
      var all = FlutterWebAppAllBuilders([_builder('a'), _builder('b')]);
      var a = all.builders[0].controller!;
      var b = all.builders[1].controller!;
      expect(a, isNot(same(b)));
      expect(a.shell, isNot(same(b.shell)));
      // Nothing running, nothing to kill.
      all.cancel();
    });

    test('canDeploy', () {
      var deployer = WebAppDeployer();
      expect(
        FlutterWebAppAllBuilders([
          _builder('a', deployer: deployer),
          _builder('b', deployer: deployer),
        ]).canDeploy,
        isTrue,
      );
      expect(
        FlutterWebAppAllBuilders([
          _builder('a', deployer: deployer),
          _builder('b'),
        ]).canDeploy,
        isFalse,
      );
    });
  });
}
