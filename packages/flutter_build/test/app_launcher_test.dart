@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_flutter_build/app_launcher.dart';
import 'package:test/test.dart';

void main() {
  group('pubspecLockSourcePath', () {
    String? sourcePath(String lock) => pubspecLockSourcePath(
      lock,
      package: 'my_app',
      lockDirPath: join('install', 'local'),
      pubCachePath: 'pub_cache',
    );

    test('path', () {
      expect(
        sourcePath('''
packages:
  my_app:
    dependency: "direct main"
    description:
      path: "/src/my_tools/packages/my_app/."
      relative: false
    source: path
    version: "0.1.0+1"
'''),
        normalize('/src/my_tools/packages/my_app'),
      );
      expect(
        sourcePath('''
packages:
  my_app:
    description:
      path: "../my_app"
      relative: true
    source: path
'''),
        join('install', 'my_app'),
      );
    });

    test('git', () {
      expect(
        sourcePath('''
packages:
  my_app:
    dependency: "direct main"
    description:
      path: "packages/my_app"
      ref: HEAD
      resolved-ref: c7c8fab79818417b5a4931cb9ef51618b5412724
      url: "git@github.com:example/my_tools.git"
    source: git
'''),
        join(
          'pub_cache',
          'git',
          'my_tools-c7c8fab79818417b5a4931cb9ef51618b5412724',
          'packages',
          'my_app',
        ),
      );
      expect(
        sourcePath('''
packages:
  my_app:
    description:
      ref: HEAD
      resolved-ref: abc
      url: "https://github.com/example/my_tools"
    source: git
'''),
        join('pub_cache', 'git', 'my_tools-abc'),
      );
    });

    test('git repository name of more than 50 characters', () {
      // pub cuts the repository name of its checkout folder to 50
      // characters (lib/src/source/git.dart `_repoName`).
      var repoName = 'a_repository_name_that_is_longer_than_fifty_characters';
      expect(repoName.length, greaterThan(50));
      expect(
        sourcePath('''
packages:
  my_app:
    description:
      path: "."
      ref: HEAD
      resolved-ref: abc
      url: "https://github.com/someone/$repoName.git"
    source: git
'''),
        join('pub_cache', 'git', '${repoName.substring(0, 50)}-abc'),
      );
    });

    test('other', () {
      expect(sourcePath('packages:\n'), isNull);
      expect(sourcePath('packages:\n  path:\n    source: hosted\n'), isNull);
      expect(
        sourcePath('''
packages:
  my_app:
    description:
      name: my_app
      url: "https://pub.dev"
    source: hosted
'''),
        isNull,
      );
    });
  });

  group('bin install', () {
    const pathLock = '''
packages:
  my_app:
    dependency: "direct main"
    description:
      path: "/src/my_tools/packages/my_app/."
      relative: false
    source: path
    version: "0.1.0+1"
''';
    const gitLock = '''
packages:
  my_app:
    dependency: "direct main"
    description:
      path: "packages/my_app"
      ref: HEAD
      resolved-ref: c7c8fab79818417b5a4931cb9ef51618b5412724
      url: "git@github.com:example/my_tools.git"
    source: git
''';
    test('pubspecLockDescriptor', () {
      Map<String, Object?>? descriptor(String lock) => pubspecLockDescriptor(
        lock,
        package: 'my_app',
        lockDirPath: join('install', 'local'),
      );
      expect(descriptor(pathLock), {
        'path': normalize(absolute('/src/my_tools/packages/my_app')),
      });
      expect(
        descriptor('''
packages:
  my_app:
    description:
      path: "../my_app"
      relative: true
    source: path
'''),
        {'path': normalize(absolute(join('install', 'my_app')))},
      );
      expect(descriptor(gitLock), {
        'git': {
          'url': 'git@github.com:example/my_tools.git',
          'path': 'packages/my_app',
          'ref': 'HEAD',
        },
      });
      expect(
        descriptor('''
packages:
  my_app:
    description:
      name: my_app
      url: "https://pub.dev"
    source: hosted
'''),
        {'hosted': 'https://pub.dev'},
      );
      expect(descriptor('packages:\n'), isNull);
    });

    test('dartInstallArguments, pubGlobalActivateArguments', () {
      expect(dartInstallArguments('tkx', {'path': '/src/tkx'}), [
        'install',
        'tkx@{"path":"/src/tkx"}',
      ]);
      expect(dartInstallArguments('tkx', {}), ['install', 'tkx']);
      expect(pubGlobalActivateArguments('tkx', {'path': '/src/tkx'}), [
        'pub',
        'global',
        'activate',
        '--source',
        'path',
        '/src/tkx',
      ]);
      expect(
        pubGlobalActivateArguments('tkx', {
          'git': {
            'url': 'git@github.com:o/r.git',
            'path': 'p/tkx',
            'ref': 'HEAD',
          },
        }),
        [
          'pub',
          'global',
          'activate',
          '--source',
          'git',
          'git@github.com:o/r.git',
          '--git-path',
          'p/tkx',
          '--git-ref',
          'HEAD',
        ],
      );
      expect(pubGlobalActivateArguments('tkx', {'hosted': 'https://pub.dev'}), [
        'pub',
        'global',
        'activate',
        'tkx',
        '--hosted-url',
        'https://pub.dev',
      ]);
    });

    test('flutterAppLauncherBinInstallArguments', () async {
      var dir = await Directory.systemTemp.createTemp('bin_install');
      addTearDown(() => dir.delete(recursive: true));
      var pubCache = join(dir.path, 'pub_cache');
      var sdkDart = join(dir.path, 'sdk', 'bin', 'dart');
      List<String>? arguments({
        String executable = '',
        String? sourcePath = '/src/my_app',
      }) => flutterAppLauncherBinInstallArguments(
        packageName: 'my_app',
        sourcePath: sourcePath,
        executable: executable.isEmpty ? sdkDart : executable,
        pubCachePath: pubCache,
      );

      // dart run in the sources.
      expect(
        arguments(),
        dartInstallArguments('my_app', {'path': '/src/my_app'}),
      );
      expect(arguments(sourcePath: null), isNull);

      // pub global activate: the lock of its global package (a path
      // activation runs from the sources, as dart run).
      var global = join(pubCache, 'global_packages', 'my_app');
      await Directory(global).create(recursive: true);
      await File(join(global, 'pubspec.lock')).writeAsString(pathLock);
      expect(
        arguments(),
        pubGlobalActivateArguments('my_app', {
          'path': normalize(absolute('/src/my_tools/packages/my_app')),
        }),
      );

      // dart install (aot): the lock of the bundle, even when activated too.
      var bundle = join(dir.path, 'app-bundles', 'my_app', 'local');
      await Directory(join(bundle, 'bundle', 'bin')).create(recursive: true);
      await File(join(bundle, 'pubspec.lock')).writeAsString(gitLock);
      expect(
        arguments(executable: join(bundle, 'bundle', 'bin', 'my_app')),
        dartInstallArguments('my_app', {
          'git': {
            'url': 'git@github.com:example/my_tools.git',
            'path': 'packages/my_app',
            'ref': 'HEAD',
          },
        }),
      );
    });
  });

  test('FlutterAppHostLauncher', () {
    var launcher = FlutterAppHostLauncher(packageName: 'my_app', path: 'app');
    expect(launcher.path, normalize(absolute('app')));
    expect(
      isWithin(join(launcher.path, 'deploy'), launcher.deployPath),
      isTrue,
    );
    expect(basenameWithoutExtension(launcher.deployedExePath), 'my_app');
    expect(launcher.macosSandbox, isNull);
    expect(
      FlutterAppHostLauncher(
        packageName: 'my_app',
        macosSandbox: false,
      ).macosSandbox,
      isFalse,
    );
  });

  group('createHostProject app icon', () {
    late Directory dir;
    late FlutterAppHostLauncher launcher;

    /// A file of the icon of the host project.
    late File hostIcon;

    /// The image of the sources the icons are made of.
    late File appIcon;

    /// The data folder of the user on linux (`~/.local/share`), here a
    /// folder of the test.
    late String dataHome;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('app_launcher_test');
      appIcon = File(join(dir.path, 'img', 'app_icon.png'))
        ..parent.createSync();
      dataHome = join(dir.path, 'data_home');
      launcher = FlutterAppHostLauncher(
        packageName: 'my_app',
        path: dir.path,
        linuxDataHome: dataHome,
      );
      // The host project as far as its icon goes: it exists, so that it is
      // not created (no flutter here).
      if (Platform.isMacOS) {
        var iconSet = join(
          dir.path,
          'macos',
          'Runner',
          'Assets.xcassets',
          'AppIcon.appiconset',
        );
        hostIcon = File(join(iconSet, 'app_icon_16.png'));
        File(join(iconSet, 'Contents.json'))
          ..createSync(recursive: true)
          ..writeAsStringSync(
            '{"images": [{"size": "16x16", "scale": "1x", '
            '"filename": "app_icon_16.png"}]}',
          );
      } else if (Platform.isLinux) {
        // No icon in a linux project: in the icon theme of the user, named
        // by the application id of the project.
        File(join(dir.path, 'linux', 'CMakeLists.txt'))
          ..createSync(recursive: true)
          ..writeAsStringSync('set(APPLICATION_ID "com.example.my_app")\n');
        hostIcon = File(
          join(
            dataHome,
            'icons',
            'hicolor',
            '256x256',
            'apps',
            'com.example.my_app.png',
          ),
        );
      } else {
        hostIcon = File(
          join(dir.path, 'windows', 'runner', 'resources', 'app_icon.ico'),
        );
      }
      hostIcon
        ..createSync(recursive: true)
        ..writeAsStringSync('the icon of flutter create');
    });
    tearDown(() => dir.delete(recursive: true));

    test('made from the img/app_icon.png of the sources', () async {
      appIcon.writeAsBytesSync(
        img.encodePng(
          img.Image(width: 64, height: 64, numChannels: 4)
            ..clear(img.ColorRgba8(255, 0, 0, 255)),
        ),
      );

      await launcher.createHostProject();

      var icon = img.decodeImage(hostIcon.readAsBytesSync())!;
      var middle = icon.getPixel(icon.width ~/ 2, icon.height ~/ 2);
      expect([middle.r, middle.g, middle.b, middle.a], [255, 0, 0, 255]);
      if (Platform.isLinux) {
        // Its menu entry: the app by its name, starting the deployed release.
        var entry = File(
          join(dataHome, 'applications', 'com.example.my_app.desktop'),
        ).readAsStringSync();
        expect(entry, contains('Name=my_app\n'));
        expect(entry, contains('Exec=${launcher.deployedExePath}\n'));
        expect(entry, contains('Icon=com.example.my_app\n'));
      }
    });

    test(
      'an img/app_icon.png that is no image: the icon stays, no error',
      () async {
        appIcon.writeAsStringSync('not an image');

        await launcher.createHostProject();

        expect(hostIcon.readAsStringSync(), 'the icon of flutter create');
      },
    );
  });

  test('buildIfNeededAndRun deployed', () async {
    var dir = await Directory.systemTemp.createTemp('app_launcher_test');
    try {
      var launcher = FlutterAppHostLauncher(
        packageName: 'my_app',
        path: dir.path,
      );
      expect(launcher.isDeployed, isFalse);
      // A deployed release exiting with 3, no build.
      var exe = File(launcher.deployedExePath);
      await exe.parent.create(recursive: true);
      await exe.writeAsString('#!/bin/sh\nexit 3\n');
      await Shell(verbose: false).run('chmod +x ${shellArgument(exe.path)}');
      expect(launcher.isDeployed, isTrue);
      expect(await launcher.buildIfNeededAndRun(arguments: ['.']), 3);

      // The version of the pubspec, the one of the release: still no build.
      await File(
        join(dir.path, 'pubspec.yaml'),
      ).writeAsString('name: my_app\nversion: 0.1.0+1\n');
      var versionJson = File(launcher.deployedVersionJsonPath);
      await versionJson.parent.create(recursive: true);
      await versionJson.writeAsString(
        '{"app_name":"my_app","version":"0.1.0","build_number":"1",'
        '"package_name":"my_app"}',
      );
      expect(launcher.isOutdated, isFalse);
      expect(await launcher.buildIfNeededAndRun(arguments: ['.']), 3);
    } finally {
      await dir.delete(recursive: true);
    }
  }, testOn: '!windows');

  test('deployedVersion, sourceVersion, isOutdated', () async {
    var dir = await Directory.systemTemp.createTemp('app_launcher_test');
    try {
      var launcher = FlutterAppHostLauncher(
        packageName: 'my_app',
        path: dir.path,
      );
      var pubspec = File(join(dir.path, 'pubspec.yaml'));
      var versionJson = File(launcher.deployedVersionJsonPath);
      await versionJson.parent.create(recursive: true);
      Future<void> deploy(String version, [String? buildNumber]) =>
          versionJson.writeAsString(
            jsonEncode({
              'app_name': 'my_app',
              'version': version,
              'build_number': ?buildNumber,
              'package_name': 'my_app',
            }),
          );
      Future<void> source(String? version) => pubspec.writeAsString(
        'name: my_app\n${version == null ? '' : 'version: $version\n'}',
      );

      // Neither known: not outdated.
      expect(launcher.deployedVersion, isNull);
      expect(launcher.sourceVersion, isNull);
      expect(launcher.isOutdated, isFalse);

      await deploy('0.1.0', '1');
      await source('0.1.0+1');
      expect(launcher.deployedVersion, '0.1.0+1');
      expect(launcher.sourceVersion, '0.1.0+1');
      expect(launcher.isOutdated, isFalse);

      // A version bump.
      await source('0.2.0+2');
      expect(launcher.isOutdated, isTrue);
      // The build number alone.
      await source('0.1.0+2');
      expect(launcher.isOutdated, isTrue);

      // No build number in the pubspec: the name only.
      await source('0.1.0');
      expect(launcher.isOutdated, isFalse);
      await deploy('0.1.0', '0.1.0');
      expect(launcher.deployedVersion, '0.1.0');
      expect(launcher.isOutdated, isFalse);
      await deploy('0.1.0');
      expect(launcher.deployedVersion, '0.1.0');
      await source('0.1.1');
      expect(launcher.isOutdated, isTrue);

      // No version in the pubspec, an unreadable version.json: unknown.
      await source(null);
      expect(launcher.isOutdated, isFalse);
      await source('0.2.0');
      await versionJson.writeAsString('not json');
      expect(launcher.deployedVersion, isNull);
      expect(launcher.isOutdated, isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test(
    'runningPids and kill',
    () async {
      var dir = await Directory.systemTemp.createTemp('app_launcher_test');
      try {
        var launcher = FlutterAppHostLauncher(
          packageName: 'my_app',
          path: dir.path,
        );
        expect(await launcher.runningPids(), isEmpty);
        expect(await launcher.kill(), isEmpty);
        // A real executable as the deployed release, a compiled sleeper (a
        // copy of sleep fails: coreutils multi-call binary) starting a child,
        // another executable (sleep): only found as its descendant.
        var exe = File(launcher.deployedExePath);
        await exe.parent.create(recursive: true);
        // The fixture program spawns a raw child on purpose (Process.start).
        var source = File(join(dir.path, 'sleeper.dart'));
        await source.writeAsString(
          "import 'dart:io';\n\n"
          'Future<void> main() async {\n'
          "  await Process.start('sleep', ['30']);\n"
          '  await Future<void>.delayed(const Duration(seconds: 30));\n'
          '}\n',
        );
        var shell = Shell(verbose: false, throwOnError: false);
        var compile = await shell.runExecutableArguments('dart', [
          'compile',
          'exe',
          source.path,
          '-o',
          exe.path,
        ]);
        expect(compile.exitCode, 0, reason: compile.errText);
        var started = Completer<Process>();
        var run = shell.runExecutableArguments(exe.path, [
          '--any',
        ], onProcess: started.complete);
        try {
          var process = await started.future;
          expect(await launcher.runningPids(), [process.pid]);
          var descendants = <int>[];
          for (var i = 0; i < 100 && descendants.isEmpty; i++) {
            descendants = await ShellProcesses.descendantsOf(process.pid);
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          expect(descendants, hasLength(1));
          expect(await launcher.kill(), [process.pid]);
          expect((await run).exitCode, isNot(0));
          expect(await launcher.runningPids(), isEmpty);
          // Its child too.
          expect(await ShellProcesses.isRunning(descendants.single), isFalse);

          // killTree false: the app only, its child keeps running.
          var appOnly = FlutterAppHostLauncher(
            packageName: 'my_app',
            path: dir.path,
            killTree: false,
          );
          started = Completer<Process>();
          run = shell.runExecutableArguments(exe.path, [
            '--any',
          ], onProcess: started.complete);
          process = await started.future;
          descendants = [];
          for (var i = 0; i < 100 && descendants.isEmpty; i++) {
            descendants = await ShellProcesses.descendantsOf(process.pid);
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          expect(descendants, hasLength(1));
          try {
            expect(await appOnly.kill(), [process.pid]);
            expect((await run).exitCode, isNot(0));
            expect(await appOnly.runningPids(), isEmpty);
            expect(await ShellProcesses.isRunning(descendants.single), isTrue);
          } finally {
            await ShellProcesses.kill(descendants);
          }
        } finally {
          shell.kill(ProcessSignal.sigkill);
        }
      } finally {
        await dir.delete(recursive: true);
      }
    },
    testOn: '!windows',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('findFlutterAppLauncherSourcePath', () async {
    // This package (dart run), from one of its libraries.
    var path = await findFlutterAppLauncherSourcePath(
      packageName: 'tekartik_flutter_build',
      libraryPath: 'src/app_launcher.dart',
    );
    expect(path, normalize(absolute('.')));
  });
}
