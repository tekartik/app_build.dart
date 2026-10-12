import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';

/// Converts [src] (png, jpeg...) to the webp [dst] with `cwebp` (package
/// webp), resized to [width] and/or [height] when given (the other side
/// keeps the ratio). Creates the folder of [dst].
Future<void> webpConvert(
  String src,
  String dst, {
  int? width,
  int? height,
  int quality = 80,
}) async {
  await Directory(dirname(dst)).create(recursive: true);
  var resize = (width != null || height != null)
      ? ['-resize', '${width ?? 0}', '${height ?? 0}']
      : <String>[];
  await Shell(verbose: false).run(
    'cwebp ${shellArguments(['-quiet', '-q', '$quality', ...resize, src, '-o', dst])}',
  );
}
