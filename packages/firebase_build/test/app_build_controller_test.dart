@TestOn('vm')
library;

import 'package:tekartik_firebase_build/app_build.dart';
import 'package:tekartik_firebase_build/firebase_deploy.dart';
import 'package:tekartik_firebase_build/src/app_build.dart'
    show firebaseWebAppBuilderWithController;
import 'package:tekartik_firebase_build/src/firebase_deploy.dart'
    show FirebaseWebAppActionControllerPrvExt;
import 'package:test/test.dart';

void main() {
  group('firebaseWebAppBuilderWithController', () {
    var builder = FlutterFirebaseWebAppBuilder(
      options: FlutterFirebaseWebAppOptions(
        deployOptions: FirebaseDeployOptions(
          projectId: 'my-project',
          hostingId: 'my-app',
          target: 'dev',
        ),
      ),
    ).webAppBuilder;

    test('no controller', () {
      expect(firebaseWebAppBuilderWithController(builder, null), same(builder));
    });

    test('the controller cancels the shell the builder runs in', () {
      var controller = FirebaseWebAppActionController();
      var webAppBuilder = firebaseWebAppBuilderWithController(
        builder,
        controller,
      );
      expect(webAppBuilder, isNot(same(builder)));
      expect(webAppBuilder.options, same(builder.options));
      expect(builder.controller, isNull);
      expect(controller.shell, isNotNull);
      expect(webAppBuilder.controller!.shell, same(controller.shell));
    });
  });
}
