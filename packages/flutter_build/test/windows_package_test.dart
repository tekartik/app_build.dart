@TestOn('vm')
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart';
import 'package:tekartik_flutter_build/windows_package.dart';
import 'package:test/test.dart';

void main() {
  group('windows package', () {
    late Directory work;
    late String bundle;
    late String runtime;
    setUp(() async {
      work = await Directory.systemTemp.createTemp('windows_package_test');
      // A fake bundle: the executable, a library, data, what a build leaves.
      bundle = join(work.path, 'Release');
      await Directory(
        join(bundle, 'data', 'flutter_assets'),
      ).create(recursive: true);
      await File(join(bundle, 'my_app.exe')).writeAsString('exe');
      await File(join(bundle, 'flutter_windows.dll')).writeAsString('dll');
      await File(join(bundle, 'my_native.lib')).writeAsString('lib');
      await File(join(bundle, 'my_app.pdb')).writeAsString('pdb');
      await File(join(bundle, 'data', 'icudtl.dat')).writeAsString('dat');
      await File(
        join(bundle, 'data', 'flutter_assets', 'AssetManifest.bin'),
      ).writeAsString('assets');
      // A fake runtime folder.
      runtime = join(work.path, 'crt');
      await Directory(runtime).create();
      for (var dll in flutterWindowsRuntimeDllNames) {
        await File(join(runtime, dll)).writeAsString('runtime $dll');
      }
    });
    tearDown(() async {
      await work.delete(recursive: true);
    });

    var info = const FlutterWindowsPackageInfo(
      name: 'my-app',
      version: '1.2.3+4',
      executable: 'my_app',
    );
    var folderName = 'my-app-1.2.3+4-windows-x64';

    test('the folder and its zip', () async {
      var output = join(work.path, 'out');
      // A file of a former run: gone.
      await Directory(join(output, folderName)).create(recursive: true);
      await File(join(output, folderName, 'old.txt')).writeAsString('old');
      // The bundle brings one of the runtime libraries: kept.
      await File(join(bundle, 'msvcp140.dll')).writeAsString('its own');

      var package = await flutterWindowsPackage(
        bundleDir: bundle,
        info: info,
        outputDir: output,
        arch: 'x64',
        runtimeDir: runtime,
      );
      expect(package.folder, join(output, folderName));
      var names = [
        await for (var entity in Directory(
          package.folder,
        ).list(recursive: true))
          if (entity is File)
            posix.joinAll(split(relative(entity.path, from: package.folder))),
      ]..sort();
      expect(names, [
        'data/flutter_assets/AssetManifest.bin',
        'data/icudtl.dat',
        'flutter_windows.dll',
        'msvcp140.dll',
        'my_app.exe',
        'vcruntime140.dll',
        'vcruntime140_1.dll',
      ]);
      expect(
        File(join(package.folder, 'msvcp140.dll')).readAsStringSync(),
        'its own',
      );
      expect(
        File(join(package.folder, 'vcruntime140.dll')).readAsStringSync(),
        'runtime vcruntime140.dll',
      );

      var zip = package.files.single;
      expect(zip.name, '$folderName.zip');
      expect(zip.sha256, hasLength(64));
      expect(zip.size, File(zip.path).lengthSync());
      var archive = ZipDecoder().decodeBytes(File(zip.path).readAsBytesSync());
      expect(archive.files.map((file) => file.name), [
        for (var name in names) '$folderName/$name',
      ]);
      expect(
        String.fromCharCodes(
          archive.findFile('$folderName/my_app.exe')!.content as List<int>,
        ),
        'exe',
      );
      // What is published is what is on the disk.
      expect((await FlutterWindowsPackageFile.of(zip.path)).sha256, zip.sha256);
    });

    test('no zip, no runtime', () async {
      var package = await flutterWindowsPackage(
        bundleDir: bundle,
        info: info,
        outputDir: join(work.path, 'out'),
        arch: 'arm64',
        zip: false,
        runtime: false,
      );
      expect(package.files, isEmpty);
      expect(basename(package.folder), 'my-app-1.2.3+4-windows-arm64');
      expect(File(join(package.folder, 'my_app.exe')).existsSync(), isTrue);
      expect(
        File(join(package.folder, 'vcruntime140.dll')).existsSync(),
        isFalse,
      );
    });

    test('a missing executable', () async {
      expect(
        () => flutterWindowsPackage(
          bundleDir: join(work.path, 'nothing'),
          info: info,
          outputDir: join(work.path, 'out'),
          runtime: false,
        ),
        throwsArgumentError,
      );
    });

    test('names', () {
      expect(
        flutterWindowsReleaseBundleDir('/p', arch: 'x64'),
        join('/p', 'build', 'windows', 'x64', 'runner', 'Release'),
      );
      expect(flutterWindowsFileVersion('1.2.3+4'), '1.2.3.4');
      expect(flutterWindowsFileVersion('1.2.3'), '1.2.3.0');
      expect(flutterWindowsFileVersion('1.2.3-beta.1+4'), '1.2.3.4');
      expect(flutterWindowsFileVersion('2.0'), '2.0.0.0');
      expect(flutterWindowsFileVersion('2.0+7'), '2.0.0.7');
    });

    test('the runtime of this machine', () async {
      var dir = await flutterWindowsRuntimeDir();
      for (var dll in flutterWindowsRuntimeDllNames) {
        expect(File(join(dir, dll)).existsSync(), isTrue, reason: dll);
      }
    }, skip: Platform.isWindows ? false : 'Windows only');
  });
}
