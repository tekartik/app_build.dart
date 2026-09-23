import 'package:path/path.dart';
import 'package:tekartik_firebase_build/app_build.dart';
import 'package:tekartik_firebase_build/firebase_deploy.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterFirebaseWebAppBuilder', () {
    var deployOptions = FirebaseDeployOptions(
      projectId: 'my-project',
      hostingId: 'my-app',
      target: 'dev',
    );

    test('copies to deploy/firebase/hosting/public by default', () {
      var builder = FlutterFirebaseWebAppBuilder(
        options: FlutterFirebaseWebAppOptions(deployOptions: deployOptions),
      );
      expect(
        builder.webAppBuilder.options.deployDir,
        join('deploy', 'firebase', 'hosting', 'public'),
      );
    });

    test('a firebase folder shared by several apps', () {
      var options = FlutterFirebaseWebAppOptions(
        deployOptions: deployOptions,
        deployDir: join('..', 'my_firebase'),
        publicDir: join('public', 'my_app'),
      );
      var builder = FlutterFirebaseWebAppBuilder(options: options);
      expect(
        builder.webAppBuilder.options.deployDir,
        join('..', 'my_firebase', 'public', 'my_app'),
      );
      expect(options.copyWith().publicDir, join('public', 'my_app'));
      expect(options.copyWith(publicDir: 'www').publicDir, 'www');
    });
  });
}
