@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_flutter_build/linux_package.dart';
import 'package:test/test.dart';

void main() {
  var linux = Platform.isLinux;
  group('linux package', () {
    late Directory work;
    late String bundle;
    setUp(() async {
      work = await Directory.systemTemp.createTemp('linux_package_test');
      // A fake bundle: the executable, a library, data.
      bundle = join(work.path, 'bundle');
      await Directory(join(bundle, 'lib')).create(recursive: true);
      await Directory(join(bundle, 'data')).create(recursive: true);
      await File(join(bundle, 'my_app')).writeAsString('#!/bin/sh\necho hi\n');
      await Process.run('chmod', ['755', join(bundle, 'my_app')]);
      await File(join(bundle, 'lib', 'libapp.so')).writeAsString('so');
      await File(join(bundle, 'data', 'icudtl.dat')).writeAsString('dat');
    });
    tearDown(() async {
      await work.delete(recursive: true);
    });

    var info = FlutterLinuxPackageInfo(
      name: 'my-app',
      displayName: 'My App',
      version: '1.2.3+4',
      executable: 'my_app',
      summary: 'Does things',
      description: 'A longer text, ' * 10,
      maintainer: 'Tester <tester@example.com>',
      categories: 'AudioVideo;Audio;',
      wmClass: 'com.example.my_app',
      debDepends: ['libgtk-3-0t64'],
      debRecommends: ['ffmpeg'],
    );

    test('tar.gz and deb', () async {
      var output = join(work.path, 'out');
      var files = await flutterLinuxPackage(
        bundleDir: bundle,
        info: info,
        outputDir: output,
        arch: 'x64',
        deb: whichSync('dpkg-deb') != null,
      );
      var archive = files.first;
      expect(archive.name, 'my-app-1.2.3+4-linux-x64.tar.gz');
      expect(archive.sha256, hasLength(64));
      var listing = (await Shell(
        verbose: false,
      ).runExecutableArguments('tar', ['-tvzf', archive.path])).outText;
      for (var entry in [
        'my-app-1.2.3+4-linux-x64/app/my_app',
        'my-app-1.2.3+4-linux-x64/app/lib/libapp.so',
        'my-app-1.2.3+4-linux-x64/install.sh',
        'my-app-1.2.3+4-linux-x64/uninstall.sh',
        'my-app-1.2.3+4-linux-x64/my-app.desktop',
      ]) {
        expect(listing, contains(entry));
      }
      // No group or other write, whatever the umask; scripts executable.
      expect(listing, isNot(contains('rwxrwx')));
      expect(listing, isNot(contains('rw-rw-')));
      expect(RegExp(r'-rwxr-xr-x .*install\.sh').hasMatch(listing), isTrue);
      if (files.length < 2) {
        return;
      }
      var deb = files[1];
      expect(deb.name, 'my-app_1.2.3+4_amd64.deb');
      var shell = Shell(verbose: false);
      var control = (await shell.runExecutableArguments('dpkg-deb', [
        '--info',
        deb.path,
      ])).outText;
      expect(control, contains('Package: my-app'));
      expect(control, contains('Version: 1.2.3+4'));
      expect(control, contains('Depends: libgtk-3-0t64'));
      expect(control, contains('Recommends: ffmpeg'));
      // The long description wrapped.
      expect(control.split('\n').every((line) => line.length <= 80), isTrue);
      var contents = (await shell.runExecutableArguments('dpkg-deb', [
        '--contents',
        deb.path,
      ])).outText;
      expect(contents, contains('./opt/my-app/my_app'));
      expect(contents, contains('./usr/bin/my-app -> /opt/my-app/my_app'));
      expect(contents, contains('./usr/share/applications/my-app.desktop'));
      // A link is always rwxrwxrwx: the files and folders only.
      expect(
        contents
            .split('\n')
            .where((line) => !line.startsWith('l'))
            .any((line) => line.contains('rwxrwx') || line.contains('rw-rw-')),
        isFalse,
      );
    }, skip: linux ? false : 'Linux only (GNU tar, dpkg-deb)');

    test('a missing executable', () async {
      expect(
        () => flutterLinuxPackage(
          bundleDir: join(work.path, 'nothing'),
          info: info,
          outputDir: join(work.path, 'out'),
        ),
        throwsArgumentError,
      );
    });

    test('names', () {
      expect(flutterLinuxDebVersion('1.2.3+4'), '1.2.3+4');
      expect(flutterLinuxDebVersion('1.2.3_beta'), '1.2.3.beta');
      expect(
        flutterLinuxReleaseBundleDir('/p', arch: 'arm64'),
        join('/p', 'build', 'linux', 'arm64', 'release', 'bundle'),
      );
    });
  });
}
