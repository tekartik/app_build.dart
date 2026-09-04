import 'package:path/path.dart';
import 'package:tekartik_firebase_build/firebase_project.dart';
import 'package:test/test.dart';

void main() {
  group('firebaseFunctionsDeployOnly', () {
    test('every function when none is named', () {
      expect(firebaseFunctionsDeployOnly(null), 'functions');
      expect(firebaseFunctionsDeployOnly([]), 'functions');
    });

    test('one entry per named function', () {
      expect(
        firebaseFunctionsDeployOnly([
          'commanddartv2dev',
          'callcommanddartv2dev',
        ]),
        'functions:commanddartv2dev,functions:callcommanddartv2dev',
      );
    });

    test('an already prefixed name is left alone', () {
      expect(
        firebaseFunctionsDeployOnly(['functions:myFn', 'other']),
        'functions:myFn,functions:other',
      );
    });
  });

  group('FirebaseProjectOptions', () {
    test('defaults', () {
      var options = FirebaseProjectOptions(
        projectId: 'my-project',
        path: '/tmp/my_dartff',
      );
      expect(options.projectId, 'my-project');
      expect(options.path, '/tmp/my_dartff');
      expect(options.functions, isNull);
      expect(options.functionsSource, 'functions');
      expect(options.functionsSourcePath, '/tmp/my_dartff/functions');
      expect(options.functionsEntryPoint, 'bin/server.dart');
      expect(options.functionsTargetOs, 'linux');
      expect(options.functionsTargetArch, 'x64');
    });

    test('path defaults to the current directory', () {
      expect(FirebaseProjectOptions(projectId: 'p').path, isNotEmpty);
    });

    test('copyWith', () {
      var options = FirebaseProjectOptions(
        projectId: 'my-project',
        path: '/tmp/my_dartff',
        functions: ['a'],
      ).copyWith(functionsSource: 'ff', functionsTargetArch: 'arm64');
      expect(options.projectId, 'my-project');
      expect(options.functions, ['a']);
      expect(options.functionsSourcePath, '/tmp/my_dartff/ff');
      expect(options.functionsTargetArch, 'arm64');
      expect(options.functionsTargetOs, 'linux');
    });
  });

  group('FirebaseProjectBuilder', () {
    test('path comes from the options', () {
      var builder = FirebaseProjectBuilder(
        options: FirebaseProjectOptions(
          projectId: 'my-project',
          path: '/tmp/my_dartff',
        ),
      );
      expect(builder.path, '/tmp/my_dartff');
    });
  });

  group('FirebaseProjectBuilderExt.firestoreFolder', () {
    test('the default firestore folder of the app', () {
      expect(
        FirebaseProjectBuilderExt.defaultFirestoreDir,
        join('deploy', 'firebase', 'firestore'),
      );
      var builder = FirebaseProjectBuilderExt.firestoreFolder(
        projectId: 'my-project',
        path: '/tmp/my_app',
      );
      expect(builder.options.projectId, 'my-project');
      expect(builder.path, '/tmp/my_app/deploy/firebase/firestore');
    });

    test('the app defaults to the current directory', () {
      expect(
        FirebaseProjectBuilderExt.firestoreFolder(projectId: 'p').path,
        normalize(absolute(FirebaseProjectBuilderExt.defaultFirestoreDir)),
      );
    });

    test('another folder, relative or absolute', () {
      expect(
        FirebaseProjectBuilderExt.firestoreFolder(
          projectId: 'p',
          path: '/tmp/my_app',
          firestoreDir: 'firebase',
        ).path,
        '/tmp/my_app/firebase',
      );
      expect(
        FirebaseProjectBuilderExt.firestoreFolder(
          projectId: 'p',
          path: '/tmp/my_app',
          firestoreDir: '/tmp/elsewhere',
        ).path,
        '/tmp/elsewhere',
      );
    });
  });
}
