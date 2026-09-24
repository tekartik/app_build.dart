import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_common_build/formatter.dart' as f;

/// A dart output file of a web build, with its size.
class FlutterWebBuildFile {
  /// The path, relative to `build/web`.
  final String name;

  /// The size in bytes.
  final int size;

  /// The size once gzipped, as served by a hosting.
  final int gzipSize;

  /// Creates a file entry.
  FlutterWebBuildFile({
    required this.name,
    required this.size,
    required this.gzipSize,
  });

  /// Reads [file], [name] being its path relative to `build/web`.
  static Future<FlutterWebBuildFile> read(
    File file, {
    required String name,
  }) async {
    var bytes = await file.readAsBytes();
    return FlutterWebBuildFile(
      name: name,
      size: bytes.length,
      gzipSize: gzip.encode(bytes).length,
    );
  }

  @override
  String toString() => '$name (${f.formatSize(size)})';
}

/// The size of the dart output of the last `flutter build web` of an app.
///
/// Only what the app compiles to is counted, the engine (`canvaskit/`,
/// `skwasm`) being the same for every app:
/// - the javascript: `main.dart.js` and its deferred parts
///   (`main.dart.js_1.part.js`...);
/// - for a `--wasm` build, the WebAssembly: `main.dart.wasm`, its deferred
///   parts, and the `main.dart.mjs` loader. A `--wasm` build also has the
///   javascript, the fallback of the browsers without wasm GC.
class FlutterWebBuildSize {
  /// The app name, its folder name by default.
  final String name;

  /// The javascript files, `main.dart.js` first, empty when not built.
  final List<FlutterWebBuildFile> jsFiles;

  /// The WebAssembly files, `main.dart.wasm` first, empty without `--wasm`.
  final List<FlutterWebBuildFile> wasmFiles;

  /// How long the build took, when known.
  final Duration? buildDuration;

  /// Creates a build size.
  FlutterWebBuildSize({
    required this.name,
    required this.jsFiles,
    required this.wasmFiles,
    this.buildDuration,
  });

  /// Whether the app has a web build.
  bool get isBuilt => jsFiles.isNotEmpty || wasmFiles.isNotEmpty;

  /// Whether the build is a `--wasm` one.
  bool get hasWasm => wasmFiles.isNotEmpty;

  /// The number of javascript deferred parts.
  int get jsPartCount => jsFiles.isEmpty ? 0 : jsFiles.length - 1;

  /// All the javascript, in bytes.
  int get jsSize => _sum(jsFiles, (file) => file.size);

  /// All the javascript once gzipped, in bytes.
  int get jsGzipSize => _sum(jsFiles, (file) => file.gzipSize);

  /// All the WebAssembly (and its loader), in bytes.
  int get wasmSize => _sum(wasmFiles, (file) => file.size);

  /// All the WebAssembly (and its loader) once gzipped, in bytes.
  int get wasmGzipSize => _sum(wasmFiles, (file) => file.gzipSize);

  static int _sum(
    List<FlutterWebBuildFile> files,
    int Function(FlutterWebBuildFile file) size,
  ) => files.fold(0, (total, file) => total + size(file));

  /// Reads the last web build (`build/web`) of the flutter app at [path].
  ///
  /// [name] defaults to the app folder name.
  static Future<FlutterWebBuildSize> read(
    String path, {
    String? name,
    Duration? buildDuration,
  }) async {
    var webPath = join(path, 'build', 'web');
    var jsFiles = <FlutterWebBuildFile>[];
    var wasmFiles = <FlutterWebBuildFile>[];
    var webDir = Directory(webPath);
    if (webDir.existsSync()) {
      var files = webDir.listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      var mainJs = files
          .where((file) => basename(file.path) == 'main.dart.js')
          .firstOrNull;
      // Older flutter versions put it in a sub folder.
      mainJs ??= webDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => basename(file.path) == 'main.dart.js')
          .firstOrNull;
      if (mainJs != null) {
        jsFiles.add(await _readFile(webPath, mainJs));
        for (var file in files) {
          if (basename(file.path).startsWith('main.dart.js_')) {
            jsFiles.add(await _readFile(webPath, file));
          }
        }
      }
      bool isWasm(File file) {
        var fileName = basename(file.path);
        return fileName.startsWith('main.dart') &&
            (fileName.endsWith('.wasm') || fileName.endsWith('.mjs'));
      }

      int wasmOrder(File file) => switch (basename(file.path)) {
        'main.dart.wasm' => 0,
        'main.dart.mjs' => 2,
        _ => 1,
      };
      for (var file
          in files.where(isWasm).toList()
            ..sort((a, b) => wasmOrder(a).compareTo(wasmOrder(b)))) {
        wasmFiles.add(await _readFile(webPath, file));
      }
    }
    return FlutterWebBuildSize(
      name: name ?? basename(normalize(absolute(path))),
      jsFiles: jsFiles,
      wasmFiles: wasmFiles,
      buildDuration: buildDuration,
    );
  }

  static Future<FlutterWebBuildFile> _readFile(String webPath, File file) =>
      FlutterWebBuildFile.read(
        file,
        name: posix.joinAll(split(relative(file.path, from: webPath))),
      );

  /// One line per kind of output, such as
  /// `main.dart.js (2.907 MB, gzip 864.919 KB)`.
  List<String> toLines() {
    if (!isBuilt) {
      return ['$name: not built'];
    }
    var parts = switch (jsPartCount) {
      0 => '',
      1 => ', 1 part',
      _ => ', $jsPartCount parts',
    };
    var js = f.formatSize(jsSize);
    var jsGzip = f.formatSize(jsGzipSize);
    var wasm = f.formatSize(wasmSize);
    var wasmGzip = f.formatSize(wasmGzipSize);
    return [
      if (jsFiles.isNotEmpty) 'main.dart.js ($js, gzip $jsGzip$parts)',
      if (hasWasm) 'main.dart.wasm ($wasm, gzip $wasmGzip, with main.dart.mjs)',
    ];
  }

  @override
  String toString() => '$name: ${toLines().join(', ')}';
}

/// A markdown table of [sizes], one app per row.
///
/// The wasm columns are only there when one of the builds has wasm, the
/// build column when one of the durations is known.
String flutterWebBuildSizeMarkdownTable(List<FlutterWebBuildSize> sizes) {
  var hasWasm = sizes.any((size) => size.hasWasm);
  var hasDuration = sizes.any((size) => size.buildDuration != null);
  String sizeCell(int bytes) => f.formatSize(bytes);
  var rows = [
    [
      'app',
      'js',
      'js gzip',
      'js parts',
      if (hasWasm) ...['wasm', 'wasm gzip'],
      if (hasDuration) 'build',
    ],
    for (var size in sizes)
      [
        size.name,
        if (!size.isBuilt) ...[
          'not built',
          '',
          '',
        ] else if (size.jsFiles.isEmpty) ...[
          '',
          '',
          '',
        ] else ...[
          sizeCell(size.jsSize),
          sizeCell(size.jsGzipSize),
          '${size.jsPartCount}',
        ],
        if (hasWasm)
          if (size.hasWasm) ...[
            sizeCell(size.wasmSize),
            sizeCell(size.wasmGzipSize),
          ] else ...[
            '',
            '',
          ],
        if (hasDuration) _durationCell(size.buildDuration),
      ],
  ];
  var widths = [
    for (var column = 0; column < rows.first.length; column++)
      rows.map((row) => row[column].length).reduce((a, b) => a > b ? a : b),
  ];
  String line(List<String> cells) => [
    cells.first.padRight(widths.first),
    for (var column = 1; column < cells.length; column++)
      cells[column].padLeft(widths[column]),
  ].join(' | ');
  return [
    '| ${line(rows.first)} |',
    '|${[for (var width in widths) '-' * (width + 2)].join('|')}|',
    for (var row in rows.skip(1)) '| ${line(row)} |',
  ].join('\n');
}

String _durationCell(Duration? duration) =>
    duration == null ? '' : '${duration.inSeconds}s';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

const _reportTitleDefault = 'Web build size report';

/// A markdown report of [sizes]: a [title], the date ([now] by default) and
/// the [flutterWebBuildSizeMarkdownTable].
String flutterWebBuildSizeMarkdownReport(
  List<FlutterWebBuildSize> sizes, {
  String title = _reportTitleDefault,
  DateTime? now,
}) {
  now ??= DateTime.now();
  return '# $title\n\n'
      '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} '
      '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}\n\n'
      '${flutterWebBuildSizeMarkdownTable(sizes)}\n';
}

/// Writes the [flutterWebBuildSizeMarkdownReport] of [sizes] to
/// `<dir>/<name>_YYYY_MM_DD.md`, replacing the report of the same day, and
/// returns the file.
Future<File> flutterWebBuildSizeWriteReport(
  List<FlutterWebBuildSize> sizes, {
  required String dir,
  String name = 'build_web_size_report',
  String title = _reportTitleDefault,
  DateTime? now,
}) async {
  now ??= DateTime.now();
  var date = '${now.year}_${_twoDigits(now.month)}_${_twoDigits(now.day)}';
  var file = File(join(dir, '${name}_$date.md'));
  await file.parent.create(recursive: true);
  await file.writeAsString(
    flutterWebBuildSizeMarkdownReport(sizes, title: title, now: now),
  );
  return file;
}
