@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_flutter_build/app_icon.dart';
import 'package:test/test.dart';

/// The `Contents.json` of the icon set `flutter create` makes for macos, cut
/// to four entries (two of them the same file).
const _macosContentsJson = '''
{
  "images" : [
    {"size" : "16x16", "idiom" : "mac", "filename" : "app_icon_16.png", "scale" : "1x"},
    {"size" : "16x16", "idiom" : "mac", "filename" : "app_icon_32.png", "scale" : "2x"},
    {"size" : "32x32", "idiom" : "mac", "filename" : "app_icon_32.png", "scale" : "1x"},
    {"size" : "512x512", "idiom" : "mac", "filename" : "app_icon_1024.png", "scale" : "2x"}
  ],
  "info" : {"version" : 1, "author" : "xcode"}
}
''';

/// The start of the `linux/CMakeLists.txt` `flutter create` makes.
const _linuxCMakeLists = '''
# Project-level configuration.
cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "my_app")
# The unique GTK application identifier for this application. See:
# https://wiki.gnome.org/HowDoI/ChooseApplicationID
set(APPLICATION_ID "com.example.my_app")
''';

/// A [width] x [height] image of one colour.
img.Image _solid(int width, int height, int r, int g, int b, int a) =>
    img.Image(width: width, height: height, numChannels: 4)
      ..clear(img.ColorRgba8(r, g, b, a));

/// The red, green, blue and alpha of the pixel of [image] at [x], [y].
List<int> _rgba(img.Image image, int x, int y) {
  var pixel = image.getPixel(x, y);
  return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), pixel.a.toInt()];
}

/// The images of the ico [bytes], by the size its directory gives them.
Map<int, img.Image> _icoImages(Uint8List bytes) {
  var data = ByteData.sublistView(bytes);
  var count = data.getUint16(4, Endian.little);
  var images = <int, img.Image>{};
  for (var i = 0; i < count; i++) {
    var entry = 6 + 16 * i;
    var width = data.getUint8(entry);
    var length = data.getUint32(entry + 8, Endian.little);
    var offset = data.getUint32(entry + 12, Endian.little);
    // 0 is 256 in an ico.
    images[width == 0 ? 256 : width] = img.decodePng(
      Uint8List.sublistView(bytes, offset, offset + length),
    )!;
  }
  return images;
}

void main() {
  late Directory app;
  late String iconSet;
  late String ico;

  setUp(() async {
    app = await Directory.systemTemp.createTemp('app_icon_test');
    iconSet = join(
      app.path,
      'macos',
      'Runner',
      'Assets.xcassets',
      'AppIcon.appiconset',
    );
    ico = join(app.path, 'windows', 'runner', 'resources', 'app_icon.ico');
  });
  tearDown(() => app.delete(recursive: true));

  /// The macos project of the app, as far as its icons go.
  void createMacosProject() {
    File(join(iconSet, 'Contents.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(_macosContentsJson);
  }

  /// The windows project of the app, as far as its icon goes.
  void createWindowsProject() {
    File(ico)
      ..createSync(recursive: true)
      ..writeAsStringSync('the icon of flutter create');
  }

  /// The file [name] of the `img` folder of the app, the folder created.
  File imgFile(String name) =>
      File(join(app.path, 'img', name))..parent.createSync(recursive: true);

  /// Writes [image] as the icon of the app, a PNG.
  void writeIcon(img.Image image) {
    imgFile('app_icon.png').writeAsBytesSync(img.encodePng(image));
  }

  img.Image macosIcon(int size) => img.decodePng(
    File(join(iconSet, 'app_icon_$size.png')).readAsBytesSync(),
  )!;

  group('findFlutterAppIconPath', () {
    test('no image: null', () {
      expect(findFlutterAppIconPath(app.path), isNull);
    });

    test('img/app_icon.png of the app', () {
      writeIcon(_solid(8, 8, 255, 0, 0, 255));
      expect(
        findFlutterAppIconPath(app.path),
        join(app.path, 'img', 'app_icon.png'),
      );
    });

    test('img/app_icon.webp comes before img/app_icon.png', () {
      writeIcon(_solid(8, 8, 255, 0, 0, 255));
      imgFile('app_icon.webp').writeAsBytesSync([0]);
      expect(
        findFlutterAppIconPath(app.path),
        join(app.path, 'img', 'app_icon.webp'),
      );
    });

    test('an image at the top of the app is not its icon', () {
      File(
        join(app.path, 'app_icon.png'),
      ).writeAsBytesSync(img.encodePng(_solid(8, 8, 255, 0, 0, 255)));
      expect(findFlutterAppIconPath(app.path), isNull);
    });
  });

  group('flutterAppWriteIcons macos', () {
    test('each file of the icon set at its size in pixels', () async {
      createMacosProject();
      writeIcon(_solid(64, 64, 255, 0, 0, 255));

      var written = await flutterAppWriteIcons(
        appPath: app.path,
        platform: 'macos',
      );

      expect(written.map(basename).toSet(), {
        'app_icon_16.png',
        'app_icon_32.png',
        'app_icon_1024.png',
      });
      for (var size in [16, 32, 1024]) {
        var icon = macosIcon(size);
        expect([icon.width, icon.height], [size, size]);
      }
    });

    test('the image takes 824 of 1024, a clear margin around it', () async {
      createMacosProject();
      writeIcon(_solid(64, 64, 255, 0, 0, 255));

      await flutterAppWriteIcons(appPath: app.path, platform: 'macos');

      var icon = macosIcon(1024);
      expect(_rgba(icon, 512, 512), [255, 0, 0, 255]);
      // (1024 - 824) / 2: the image starts at 100 and ends before 924.
      expect(_rgba(icon, 99, 512)[3], 0);
      expect(_rgba(icon, 100, 512), [255, 0, 0, 255]);
      expect(_rgba(icon, 923, 512), [255, 0, 0, 255]);
      expect(_rgba(icon, 924, 512)[3], 0);
      expect(_rgba(icon, 512, 99)[3], 0);
      expect(_rgba(icon, 512, 100), [255, 0, 0, 255]);
    });

    test('no macos project: nothing written', () async {
      writeIcon(_solid(64, 64, 255, 0, 0, 255));

      var written = await flutterAppWriteIcons(
        appPath: app.path,
        platform: 'macos',
      );

      expect(written, isEmpty);
      expect(Directory(join(app.path, 'macos')).existsSync(), isFalse);
    });
  });

  group('flutterAppWriteIcons windows', () {
    test(
      'the ico holds the sizes Windows shows, filled by the image',
      () async {
        createWindowsProject();
        writeIcon(_solid(64, 64, 255, 0, 0, 255));

        var written = await flutterAppWriteIcons(
          appPath: app.path,
          platform: 'windows',
        );

        expect(written, [ico]);
        var images = _icoImages(File(ico).readAsBytesSync());
        expect(images.keys, [16, 20, 24, 32, 40, 48, 64, 128, 256]);
        for (var MapEntry(key: size, value: image) in images.entries) {
          expect([image.width, image.height], [size, size]);
          expect(_rgba(image, 0, 0), [255, 0, 0, 255]);
          expect(_rgba(image, size - 1, size - 1), [255, 0, 0, 255]);
        }
      },
    );

    test('a pixel partly over the image keeps its colour', () async {
      createWindowsProject();
      // 25 columns of red, then 23 clear ones whose hidden colour is green.
      var image = _solid(48, 48, 0, 255, 0, 0);
      for (var y = 0; y < 48; y++) {
        for (var x = 0; x < 25; x++) {
          image.setPixelRgba(x, y, 255, 0, 0, 255);
        }
      }
      writeIcon(image);

      await flutterAppWriteIcons(appPath: app.path, platform: 'windows');

      // 48 to 16: the pixel 8 is the columns 24 to 26, one of them red.
      var small = _icoImages(File(ico).readAsBytesSync())[16]!;
      expect(_rgba(small, 7, 8), [255, 0, 0, 255]);
      expect(_rgba(small, 8, 8), [255, 0, 0, 85]);
      expect(_rgba(small, 9, 8)[3], 0);
    });

    test('an image that is not square is fitted, not stretched', () async {
      createWindowsProject();
      writeIcon(_solid(64, 32, 255, 0, 0, 255));

      await flutterAppWriteIcons(appPath: app.path, platform: 'windows');

      // 64 x 32 in 16 x 16: 16 x 8, 4 clear rows above and below.
      var small = _icoImages(File(ico).readAsBytesSync())[16]!;
      expect(_rgba(small, 0, 3)[3], 0);
      expect(_rgba(small, 0, 4), [255, 0, 0, 255]);
      expect(_rgba(small, 15, 11), [255, 0, 0, 255]);
      expect(_rgba(small, 15, 12)[3], 0);
    });

    test('up to date: nothing written, until the image changes', () async {
      createWindowsProject();
      writeIcon(_solid(64, 64, 255, 0, 0, 255));
      await flutterAppWriteIcons(appPath: app.path, platform: 'windows');

      expect(
        await flutterAppWriteIcons(appPath: app.path, platform: 'windows'),
        isEmpty,
      );

      writeIcon(_solid(64, 64, 0, 0, 255, 255));
      expect(
        await flutterAppWriteIcons(appPath: app.path, platform: 'windows'),
        [ico],
      );
      expect(_rgba(_icoImages(File(ico).readAsBytesSync())[16]!, 8, 8), [
        0,
        0,
        255,
        255,
      ]);
    });

    test('no image: the icon of flutter create stays', () async {
      createWindowsProject();

      var written = await flutterAppWriteIcons(
        appPath: app.path,
        platform: 'windows',
      );

      expect(written, isEmpty);
      expect(File(ico).readAsStringSync(), 'the icon of flutter create');
    });

    test('a webp image', () async {
      createWindowsProject();
      imgFile(
        'app_icon.webp',
      ).writeAsBytesSync(img.encodeWebP(_solid(64, 64, 0, 0, 255, 255)));

      await flutterAppWriteIcons(appPath: app.path, platform: 'windows');

      expect(_rgba(_icoImages(File(ico).readAsBytesSync())[256]!, 128, 128), [
        0,
        0,
        255,
        255,
      ]);
    });

    test('an image elsewhere, given by its path', () async {
      createWindowsProject();
      var elsewhere = join(app.path, 'doc', 'logo.png');
      File(elsewhere)
        ..createSync(recursive: true)
        ..writeAsBytesSync(img.encodePng(_solid(64, 64, 0, 0, 255, 255)));

      await flutterAppWriteIcons(
        appPath: app.path,
        iconPath: elsewhere,
        platform: 'windows',
      );

      expect(_rgba(_icoImages(File(ico).readAsBytesSync())[16]!, 8, 8), [
        0,
        0,
        255,
        255,
      ]);
    });

    test('a file that is no image: a FormatException naming it', () async {
      createWindowsProject();
      imgFile('app_icon.png').writeAsStringSync('not an image');

      await expectLater(
        flutterAppWriteIcons(appPath: app.path, platform: 'windows'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('app_icon.png'),
          ),
        ),
      );
      expect(File(ico).readAsStringSync(), 'the icon of flutter create');
    });
  });

  group('flutterAppWriteIcons linux', () {
    // The data folder of the user (~/.local/share), its icon theme, the icon
    // and the menu entry of the app.
    late String dataHome;
    late String theme;
    late File themeIcon;
    late File desktopFile;

    setUp(() {
      dataHome = join(app.path, 'data_home');
      theme = join(dataHome, 'icons', 'hicolor');
      themeIcon = File(
        join(theme, '256x256', 'apps', 'com.example.my_app.png'),
      );
      desktopFile = File(
        join(dataHome, 'applications', 'com.example.my_app.desktop'),
      );
    });

    /// The linux project of the app, as far as its application id goes.
    void createLinuxProject() {
      File(join(app.path, 'linux', 'CMakeLists.txt'))
        ..createSync(recursive: true)
        ..writeAsStringSync(_linuxCMakeLists);
    }

    /// The keys of the menu entry written.
    Map<String, String> desktopEntry() => {
      for (var line in desktopFile.readAsLinesSync())
        if (line.contains('='))
          line.substring(0, line.indexOf('=')): line.substring(
            line.indexOf('=') + 1,
          ),
    };

    Future<List<String>> write({String? executable}) => flutterAppWriteIcons(
      appPath: app.path,
      platform: 'linux',
      linuxDataHome: dataHome,
      linuxDesktopEntry: executable == null
          ? null
          : FlutterAppLinuxDesktopEntry(name: 'my_app', executable: executable),
    );

    test('the image in the icon theme of the user, named by the application '
        'id', () async {
      createLinuxProject();
      writeIcon(_solid(64, 64, 255, 0, 0, 255));

      var written = await write();

      expect(written, [themeIcon.path]);
      var icon = img.decodePng(themeIcon.readAsBytesSync())!;
      expect([icon.width, icon.height], [256, 256]);
      expect(_rgba(icon, 0, 0), [255, 0, 0, 255]);
      expect(_rgba(icon, 255, 255), [255, 0, 0, 255]);
      // No menu entry unless asked.
      expect(Directory(join(dataHome, 'applications')).existsSync(), isFalse);
    });

    test('its menu entry: the app by its name, with that icon, its windows '
        'matched by the application id', () async {
      createLinuxProject();
      writeIcon(_solid(64, 64, 255, 0, 0, 255));

      var written = await write(executable: '/opt/my_app/my_app');

      expect(written, unorderedEquals([themeIcon.path, desktopFile.path]));
      expect(desktopFile.readAsLinesSync().first, '[Desktop Entry]');
      var entry = desktopEntry();
      expect(entry['Type'], 'Application');
      expect(entry['Name'], 'my_app');
      expect(entry['Exec'], '/opt/my_app/my_app');
      expect(entry['Icon'], 'com.example.my_app');
      expect(entry['StartupWMClass'], 'com.example.my_app');
      expect(entry['Terminal'], 'false');
    });

    test('an executable in a folder with a space is quoted', () async {
      createLinuxProject();
      writeIcon(_solid(64, 64, 255, 0, 0, 255));

      await write(executable: '/opt/my apps/my_app');

      expect(desktopEntry()['Exec'], '"/opt/my apps/my_app"');
    });

    test('its menu entry follows the app: up to date, then moved', () async {
      createLinuxProject();
      writeIcon(_solid(64, 64, 255, 0, 0, 255));
      await write(executable: '/opt/my_app/my_app');

      expect(await write(executable: '/opt/my_app/my_app'), isEmpty);

      expect(await write(executable: '/home/me/my_app/my_app'), [
        desktopFile.path,
      ]);
      expect(desktopEntry()['Exec'], '/home/me/my_app/my_app');
    });

    test('a menu entry it did not write is left as it is', () async {
      createLinuxProject();
      writeIcon(_solid(64, 64, 255, 0, 0, 255));
      desktopFile
        ..createSync(recursive: true)
        ..writeAsStringSync('[Desktop Entry]\nName=Mine\n');

      var written = await write(executable: '/opt/my_app/my_app');

      expect(written, [themeIcon.path]);
      expect(desktopFile.readAsStringSync(), '[Desktop Entry]\nName=Mine\n');
    });

    test('a new icon in a theme that had some: the folder of the theme '
        'changes, a running desktop reads it again', () async {
      createLinuxProject();
      writeIcon(_solid(64, 64, 255, 0, 0, 255));
      themeIcon.parent.createSync(recursive: true);
      await Shell(
        verbose: false,
      ).runExecutableArguments('touch', ['-t', '202001010000', theme]);
      expect(Directory(theme).statSync().modified.year, 2020);

      await write();

      expect(Directory(theme).statSync().modified.year, greaterThan(2020));
    }, testOn: '!windows');

    test('no linux project: nothing written', () async {
      writeIcon(_solid(64, 64, 255, 0, 0, 255));

      expect(await write(executable: '/opt/my_app/my_app'), isEmpty);
      expect(Directory(dataHome).existsSync(), isFalse);
    });

    test('no image: nothing written', () async {
      createLinuxProject();

      expect(await write(executable: '/opt/my_app/my_app'), isEmpty);
      expect(Directory(dataHome).existsSync(), isFalse);
    });
  });

  group('flutterAppIconFromSvg', () {
    // The top half red, the bottom half clear.
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" '
        'viewBox="0 0 16 16"><rect width="16" height="8" fill="#ff0000"/>'
        '</svg>';

    // What draws an svg on this host.
    var drawer = Platform.isMacOS
        ? 'sips'
        : ['rsvg-convert', 'inkscape'].where((name) {
            return whichSync(name) != null;
          }).firstOrNull;
    var noDrawer = drawer == null
        ? 'Needs rsvg-convert or inkscape (sips on macOS)'
        : false;

    test('img/app_icon.svg drawn into img/app_icon.webp', () async {
      imgFile('app_icon.svg').writeAsStringSync(svg);

      var path = await flutterAppIconFromSvg(appPath: app.path, size: 64);

      expect(path, join(app.path, 'img', 'app_icon.webp'));
      var image = img.decodeWebP(File(path).readAsBytesSync())!;
      expect([image.width, image.height], [64, 64]);
      expect(_rgba(image, 32, 8), [255, 0, 0, 255]);
      expect(_rgba(image, 32, 56)[3], 0);
      // The image the icons of the app are then made of.
      expect(findFlutterAppIconPath(app.path), path);
    }, skip: noDrawer);

    test('1024 pixels wide unless told', () async {
      imgFile('app_icon.svg').writeAsStringSync(svg);

      var path = await flutterAppIconFromSvg(appPath: app.path);

      var image = img.decodeWebP(File(path).readAsBytesSync())!;
      expect([image.width, image.height], [1024, 1024]);
      // Drawn at that size, not enlarged from the 16 pixels of the svg: the
      // edge of the red half is sharp.
      expect(_rgba(image, 512, 511), [255, 0, 0, 255]);
      expect(_rgba(image, 512, 512)[3], 0);
    }, skip: noDrawer);

    test('a drawing and an image elsewhere, given by their paths', () async {
      var drawing = File(join(app.path, 'doc', 'logo.svg'))
        ..createSync(recursive: true)
        ..writeAsStringSync(svg);
      var image = join(app.path, 'doc', 'logo.webp');

      var path = await flutterAppIconFromSvg(
        appPath: app.path,
        svgPath: drawing.path,
        iconPath: image,
        size: 32,
      );

      expect(path, image);
      expect(img.decodeWebP(File(image).readAsBytesSync())!.width, 32);
      expect(Directory(join(app.path, 'img')).existsSync(), isFalse);
    }, skip: noDrawer);

    test('no drawing: a StateError naming it, no image written', () async {
      await expectLater(
        flutterAppIconFromSvg(appPath: app.path),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(join('img', 'app_icon.svg')),
          ),
        ),
      );
      expect(Directory(join(app.path, 'img')).existsSync(), isFalse);
    });

    test('a drawing that is no svg: a StateError, no image written', () async {
      imgFile('app_icon.svg').writeAsStringSync('not a drawing');

      await expectLater(
        flutterAppIconFromSvg(appPath: app.path),
        throwsStateError,
      );
      expect(imgFile('app_icon.webp').existsSync(), isFalse);
    }, skip: noDrawer);

    // dart run tekartik_flutter_build:app_icon, from the folder of an app.
    Future<ProcessResult> runBin({String? workingDirectory}) =>
        Shell(
          verbose: false,
          throwOnError: false,
          workingDirectory: workingDirectory,
        ).runExecutableArguments(Platform.resolvedExecutable, [
          absolute(join('bin', 'app_icon.dart')),
        ]);

    test(
      'bin/app_icon.dart: the drawing of the app of the current folder',
      () async {
        imgFile('app_icon.svg').writeAsStringSync(svg);

        var result = await runBin(workingDirectory: app.path);

        expect(result.exitCode, 0, reason: result.errText);
        expect(result.outText, contains(join('img', 'app_icon.webp')));
        var image = img.decodeWebP(imgFile('app_icon.webp').readAsBytesSync())!;
        expect([image.width, image.height], [1024, 1024]);
      },
      skip: noDrawer,
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('bin/app_icon.dart: no drawing, told, exit code 1', () async {
      var result = await runBin(workingDirectory: app.path);

      expect(result.exitCode, 1);
      expect(result.errText, contains(join('img', 'app_icon.svg')));
      expect(result.errText, isNot(contains('#0')));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
