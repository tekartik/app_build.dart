import 'package:path/path.dart';
import 'package:tekartik_firebase_build/flutterfire_configure.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseFlutterProjectOptions', () {
    test('defaults', () {
      var options = FirebaseFlutterProjectOptions(
        projectId: 'my-project',
        path: '/tmp/my_app',
      );
      expect(options.projectId, 'my-project');
      expect(options.path, '/tmp/my_app');
      expect(options.platforms, isEmpty);
      expect(options.firebaseOptionsFile, 'lib/firebase_options.dart');
    });

    test('path defaults to the current directory', () {
      expect(
        FirebaseFlutterProjectOptions(projectId: 'p').path,
        normalize(absolute('.')),
      );
    });

    test('copyWith', () {
      var options = FirebaseFlutterProjectOptions(
        projectId: 'my-project',
        path: '/tmp/my_app',
        platforms: ['web'],
      ).copyWith(firebaseOptionsFile: 'lib/firebase_options_dev.dart');
      expect(options.projectId, 'my-project');
      expect(options.path, '/tmp/my_app');
      expect(options.platforms, ['web']);
      expect(options.firebaseOptionsFile, 'lib/firebase_options_dev.dart');
    });
  });

  group('FirebaseFlutterProjectBuilder', () {
    test('flavor', () {
      expect(
        FirebaseFlutterProjectBuilder.flavorFirebaseOptionsFile('dev'),
        'lib/firebase_options_dev.dart',
      );
      var builder = FirebaseFlutterProjectBuilder.flavor(
        projectId: 'my-project-dev',
        flavor: 'dev',
        path: '/tmp/my_app',
        platforms: ['web'],
      );
      expect(builder.path, '/tmp/my_app');
      expect(builder.options.projectId, 'my-project-dev');
      expect(builder.options.platforms, ['web']);
      expect(
        builder.options.firebaseOptionsFile,
        'lib/firebase_options_dev.dart',
      );
      expect(
        builder.configureCommand(),
        'flutterfire configure --project=my-project-dev --platforms=web'
        ' --out=lib/firebase_options_dev.dart --overwrite-firebase-options',
      );
    });

    test('path comes from the options', () {
      var builder = FirebaseFlutterProjectBuilder(
        options: FirebaseFlutterProjectOptions(
          projectId: 'my-project',
          path: '/tmp/my_app',
        ),
      );
      expect(builder.path, '/tmp/my_app');
    });

    test('configure command, every platform, default file', () {
      expect(
        FirebaseFlutterProjectBuilder(
          options: FirebaseFlutterProjectOptions(projectId: 'my-project'),
        ).configureCommand(),
        'flutterfire configure --project=my-project'
        ' --out=lib/firebase_options.dart --overwrite-firebase-options',
      );
    });

    test('configure command, one flavor file, web only, no prompt', () {
      expect(
        FirebaseFlutterProjectBuilder(
          options: FirebaseFlutterProjectOptions(
            projectId: 'my-project-prod',
            platforms: ['web'],
            firebaseOptionsFile: 'lib/firebase_options_prod.dart',
          ),
        ).configureCommand(yes: true),
        'flutterfire configure --project=my-project-prod --platforms=web'
        ' --out=lib/firebase_options_prod.dart --overwrite-firebase-options'
        ' --yes',
      );
    });

    test('configure command, several platforms, no overwrite', () {
      expect(
        FirebaseFlutterProjectBuilder(
          options: FirebaseFlutterProjectOptions(
            projectId: 'p',
            platforms: ['android', 'ios', 'web'],
          ),
        ).configureCommand(overwrite: false),
        'flutterfire configure --project=p --platforms=android,ios,web'
        ' --out=lib/firebase_options.dart',
      );
    });
  });
}
