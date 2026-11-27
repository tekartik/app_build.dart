import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_build_flutter/build_flutter.dart'
    show buildPlatformCurrent;

/// The folder of an app holding the image its icons are made of (and its
/// drawing), at the top of its package.
const _iconDirName = 'img';

/// The names of the image an app's icons are made of, in [_iconDirName]: the
/// first one found is used.
const _iconFileNames = ['app_icon.webp', 'app_icon.png'];

/// The part of a macos icon its picture takes (824 of 1024), the rest is the
/// clear margin every macos icon has around it.
const _macosPictureRatio = 824 / 1024;

/// The sizes of a windows icon: the title bar and the task bar at 100 to
/// 250 %, the large ones of the Explorer.
const _windowsSizes = [16, 20, 24, 32, 40, 48, 64, 128, 256];

/// The image the icons of the app at [appPath] are made of:
/// `img/app_icon.webp` of the app, else `img/app_icon.png`.
///
/// Returns its path ([appPath] joined with `img` and its name), null when
/// the app has neither.
String? findFlutterAppIconPath(String appPath) {
  for (var name in _iconFileNames) {
    var path = join(appPath, _iconDirName, name);
    if (File(path).existsSync()) {
      return path;
    }
  }
  return null;
}

/// Writes the icons of a platform project of the flutter app at [appPath]
/// from one image, in pure Dart (nothing to install on the host).
///
/// [iconPath] is the image, a WebP or a PNG, square and 1024 pixels wide or
/// more for the best result, its picture filling it (clear corners when it
/// has rounded ones); [findFlutterAppIconPath] of [appPath] when null. An
/// image that is not square is fitted and centered, never stretched.
///
/// [platform] is the project (`macos`, `windows`, `linux`), the one of the
/// current host when null:
/// - `macos`: each file of `macos/Runner/Assets.xcassets/AppIcon.appiconset`
///   named by its `Contents.json`, at its size, the image taking 824 of 1024
///   with a clear margin around it, as macos icons have;
/// - `windows`: `windows/runner/resources/app_icon.ico`, the image filling
///   each of its sizes (16 to 256 pixels);
/// - `linux`: nothing, its project has no icon.
///
/// Returns the paths of the files written: the ones whose content changed,
/// so none when the icons are up to date, when the app has no image or when
/// its platform project does not exist (it is never created here).
///
/// Throws a [FormatException] when [iconPath] cannot be read as an image.
Future<List<String>> flutterAppWriteIcons({
  required String appPath,
  String? iconPath,
  String? platform,
}) async {
  iconPath ??= findFlutterAppIconPath(appPath);
  if (iconPath == null) {
    return const [];
  }
  platform ??= buildPlatformCurrent;
  // File to write and what it holds, read only when there is one to write.
  var files = <String, Uint8List Function(_Picture picture)>{};
  if (platform == 'macos') {
    var iconSet = join(
      appPath,
      'macos',
      'Runner',
      'Assets.xcassets',
      'AppIcon.appiconset',
    );
    var contents = File(join(iconSet, 'Contents.json'));
    if (contents.existsSync()) {
      var sizes = _macosIconSetSizes(await contents.readAsString());
      for (var MapEntry(key: name, value: size) in sizes.entries) {
        files[join(iconSet, name)] = (picture) =>
            img.encodePng(picture.draw(size, ratio: _macosPictureRatio));
      }
    }
  } else if (platform == 'windows') {
    var resources = join(appPath, 'windows', 'runner', 'resources');
    if (Directory(resources).existsSync()) {
      files[join(resources, 'app_icon.ico')] = (picture) => img.IcoEncoder()
          .encodeImages([for (var size in _windowsSizes) picture.draw(size)]);
    }
  }
  if (files.isEmpty) {
    return const [];
  }
  var picture = _Picture.decode(iconPath, await File(iconPath).readAsBytes());
  var written = <String>[];
  for (var MapEntry(key: path, value: encode) in files.entries) {
    var bytes = encode(picture);
    var file = File(path);
    if (file.existsSync() && _sameBytes(await file.readAsBytes(), bytes)) {
      continue;
    }
    await file.writeAsBytes(bytes, flush: true);
    written.add(path);
  }
  return written;
}

/// Draws the drawing of the icon of the flutter app at [appPath], an svg,
/// into the image its icons are made of ([flutterAppWriteIcons]), a lossless
/// WebP [size] pixels wide and high (1024 by default).
///
/// [svgPath] is the drawing, `img/app_icon.svg` of the app when null: square,
/// of any size (it is drawn at [size], not enlarged). [iconPath] is the
/// image made, `img/app_icon.webp` of the app when null; it is written only
/// when it changes.
///
/// For whoever changes the drawing, who commits the image with it: the svg
/// is drawn by a program of the host, `sips` on macOS (part of the system),
/// else `rsvg-convert` or `inkscape` when one is installed, and a build
/// must need none of them.
///
/// Returns [iconPath]. Throws a [StateError] when the drawing does not
/// exist, when the host has no program to draw it or when that program
/// fails (a file that is no svg).
Future<String> flutterAppIconFromSvg({
  required String appPath,
  String? svgPath,
  String? iconPath,
  int size = 1024,
}) async {
  svgPath ??= join(appPath, _iconDirName, 'app_icon.svg');
  iconPath ??= join(appPath, _iconDirName, 'app_icon.webp');
  if (!File(svgPath).existsSync()) {
    throw StateError('No drawing of the app icon: $svgPath');
  }
  var work = await Directory.systemTemp.createTemp('app_icon');
  try {
    var png = join(work.path, 'app_icon.png');
    var drawer = await _drawSvg(svgPath, png, size);
    var image = img.decodePng(await File(png).readAsBytes());
    if (image == null) {
      throw StateError('$drawer made no image of $svgPath');
    }
    var bytes = img.encodeWebP(image);
    var file = File(iconPath);
    if (!file.existsSync() || !_sameBytes(await file.readAsBytes(), bytes)) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
    return iconPath;
  } finally {
    await work.delete(recursive: true);
  }
}

/// Draws the svg at [svgPath] as a PNG [size] pixels wide and high at
/// [pngPath], with the first program of the host that can.
///
/// Returns the name of that program. Throws a [StateError] when there is
/// none, or when it fails.
Future<String> _drawSvg(String svgPath, String pngPath, int size) async {
  var commands = <String, List<String>>{
    if (Platform.isMacOS)
      'sips': [
        '-s',
        'format',
        'png',
        '-z',
        '$size',
        '$size',
        svgPath,
        '--out',
        pngPath,
      ],
    'rsvg-convert': [
      '--width',
      '$size',
      '--height',
      '$size',
      '--output',
      pngPath,
      svgPath,
    ],
    'inkscape': [
      '--export-type=png',
      '--export-width=$size',
      '--export-height=$size',
      '--export-filename=$pngPath',
      svgPath,
    ],
  };
  for (var MapEntry(key: executable, value: arguments) in commands.entries) {
    if (whichSync(executable) == null) {
      continue;
    }
    var result = await Shell(
      verbose: false,
      throwOnError: false,
    ).runExecutableArguments(executable, arguments);
    if (result.exitCode != 0 || !File(pngPath).existsSync()) {
      throw StateError(
        '$executable could not draw $svgPath (exit code ${result.exitCode}): '
        '${result.errText.trim()}',
      );
    }
    return executable;
  }
  throw StateError(
    'No program to draw an svg on this host: ${commands.keys.join(', ')}',
  );
}

/// The file names of a macos icon set and their size in pixels (the points
/// of `size` by its `scale`), from the text of its `Contents.json`.
Map<String, int> _macosIconSetSizes(String contentsJson) {
  var sizes = <String, int>{};
  if (jsonDecode(contentsJson) case {'images': List images}) {
    for (var image in images) {
      if (image case {
        'filename': String filename,
        'size': String size,
        'scale': String scale,
      }) {
        var points = double.tryParse(size.split('x').first);
        var factor = double.tryParse(scale.replaceAll('x', ''));
        if (points != null && factor != null) {
          sizes[filename] ??= (points * factor).round();
        }
      }
    }
  }
  return sizes;
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// A decoded image, drawn at any size ([draw]).
///
/// Its pixels are kept with their colours multiplied by their alpha: a
/// clear pixel then weighs nothing in an average, whatever its hidden
/// colour, and the edge of the picture keeps its colour at every size (no
/// dark fringe).
class _Picture {
  final int width;
  final int height;

  /// Red, green, blue (each multiplied by alpha) and alpha of each pixel,
  /// 0 to 255, row by row.
  final Float32List _pixels;

  _Picture._(this.width, this.height, this._pixels);

  /// Decodes [bytes], the content of the image at [path] (in the error
  /// only), whatever its format.
  factory _Picture.decode(String path, Uint8List bytes) {
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {}
    if (image == null || image.width == 0 || image.height == 0) {
      throw FormatException('Not an image: $path');
    }
    var pixels = Float32List(image.width * image.height * 4);
    var i = 0;
    for (var pixel in image) {
      var alpha = pixel.aNormalized.toDouble() * 255;
      pixels[i++] = pixel.rNormalized * alpha;
      pixels[i++] = pixel.gNormalized * alpha;
      pixels[i++] = pixel.bNormalized * alpha;
      pixels[i++] = alpha;
    }
    return _Picture._(image.width, image.height, pixels);
  }

  /// A [size] x [size] image of the picture, fitted in the middle of it
  /// and taking [ratio] of its width (1: up to its edges; less: a clear
  /// margin around).
  ///
  /// Each pixel is the average of what it covers of the picture, by area.
  img.Image draw(int size, {double ratio = 1}) {
    // Source pixels per pixel drawn.
    var scale = max(width, height) / (size * ratio);
    var columns = _spans(width, size, scale);
    var rows = _spans(height, size, scale);
    var bytes = Uint8List(size * size * 4);
    var o = 0;
    for (var y = 0; y < size; y++) {
      var row = rows[y];
      for (var x = 0; x < size; x++, o += 4) {
        var column = columns[x];
        var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
        for (var j = 0; j < row.weights.length; j++) {
          var rowWeight = row.weights[j];
          var i = ((row.first + j) * width + column.first) * 4;
          for (var k = 0; k < column.weights.length; k++, i += 4) {
            var weight = rowWeight * column.weights[k];
            r += _pixels[i] * weight;
            g += _pixels[i + 1] * weight;
            b += _pixels[i + 2] * weight;
            a += _pixels[i + 3] * weight;
          }
        }
        var alpha = _byte(a);
        if (alpha > 0) {
          bytes[o] = _byte(r * 255 / a);
          bytes[o + 1] = _byte(g * 255 / a);
          bytes[o + 2] = _byte(b * 255 / a);
          bytes[o + 3] = alpha;
        }
      }
    }
    return img.Image.fromBytes(
      width: size,
      height: size,
      bytes: bytes.buffer,
      numChannels: 4,
    );
  }
}

int _byte(double value) => value.round().clamp(0, 255);

/// The source cells one drawn cell covers along an axis: [weights] is the
/// part of the drawn cell each one takes, from the cell [first] on (their
/// sum is 1 inside the picture, less across its edge, empty outside).
typedef _Span = ({int first, Float64List weights});

/// The [_Span] of each of the [to] cells drawn along an axis of [from]
/// source cells, at [scale] source cells per cell drawn, the source centered.
List<_Span> _spans(int from, int to, double scale) {
  // Where the source starts, in cells drawn.
  var margin = (to - from / scale) / 2;
  return [
    for (var i = 0; i < to; i++)
      () {
        var start = max((i - margin) * scale, 0.0);
        var end = min((i + 1 - margin) * scale, from.toDouble());
        var first = start.floor();
        var last = min(end.ceil(), from);
        return (
          first: first,
          weights: Float64List.fromList([
            for (var cell = first; cell < last; cell++)
              max(min(end, cell + 1.0) - max(start, cell.toDouble()), 0.0) /
                  scale,
          ]),
        );
      }(),
  ];
}
