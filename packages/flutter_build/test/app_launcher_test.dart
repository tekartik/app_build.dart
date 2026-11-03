@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_flutter_build/app_launcher.dart';
import 'package:test/test.dart';

void main() {
  group('pubspecLockSourcePath', () {
    String? sourcePath(String lock) => pubspecLockSourcePath(
      lock,
      package: 'tkassetexplorer',
      lockDirPath: join('install', 'local'),
      pubCachePath: 'pub_cache',
    );

    test('path', () {
      expect(
        sourcePath('''
packages:
  tkassetexplorer:
    dependency: "direct main"
    description:
      path: "/src/tools_flutter/packages/tkassetexplorer/."
      relative: false
    source: path
    version: "0.1.0+1"
'''),
        normalize('/src/tools_flutter/packages/tkassetexplorer'),
      );
      expect(
        sourcePath('''
packages:
  tkassetexplorer:
    description:
      path: "../tkassetexplorer"
      relative: true
    source: path
'''),
        join('install', 'tkassetexplorer'),
      );
    });

    test('git', () {
      expect(
        sourcePath('''
packages:
  tkassetexplorer:
    dependency: "direct main"
    description:
      path: "packages/tkassetexplorer"
      ref: HEAD
      resolved-ref: c7c8fab79818417b5a4931cb9ef51618b5412724
      url: "git@github.com:tekartikprv/tools_flutter.git"
    source: git
'''),
        join(
          'pub_cache',
          'git',
          'tools_flutter-c7c8fab79818417b5a4931cb9ef51618b5412724',
          'packages',
          'tkassetexplorer',
        ),
      );
      expect(
        sourcePath('''
packages:
  tkassetexplorer:
    description:
      ref: HEAD
      resolved-ref: abc
      url: "https://github.com/tekartikprv/tools_flutter"
    source: git
'''),
        join('pub_cache', 'git', 'tools_flutter-abc'),
      );
    });

    test('other', () {
      expect(sourcePath('packages:\n'), isNull);
      expect(sourcePath('packages:\n  path:\n    source: hosted\n'), isNull);
      expect(
        sourcePath('''
packages:
  tkassetexplorer:
    description:
      name: tkassetexplorer
      url: "https://pub.dev"
    source: hosted
'''),
        isNull,
      );
    });
  });

  test('FlutterAppHostLauncher', () {
    var launcher = FlutterAppHostLauncher(
      packageName: 'tkassetexplorer',
      path: 'app',
    );
    expect(launcher.path, normalize(absolute('app')));
    expect(
      isWithin(join(launcher.path, 'deploy'), launcher.deployPath),
      isTrue,
    );
    expect(
      basenameWithoutExtension(launcher.deployedExePath),
      'tkassetexplorer',
    );
    expect(launcher.macosSandbox, isNull);
    expect(
      FlutterAppHostLauncher(
        packageName: 'tkassetexplorer',
        macosSandbox: false,
      ).macosSandbox,
      isFalse,
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
    } finally {
      await dir.delete(recursive: true);
    }
  }, testOn: '!windows');

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
