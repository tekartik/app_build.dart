/// Formats [bytes] as a human-readable size string with 3 decimal places
/// and the largest fitting unit (e.g. `'1.500 KB'`, `'2.000 MB'`), using
/// 1024-based (binary) units. Negative values keep their sign (e.g.
/// `'-512 B'`).
String formatSize(int bytes) {
  var absBytes = bytes.abs();
  var sign = bytes < 0 ? '-' : '';
  if (absBytes < 1024) {
    return '$sign$absBytes B';
  } else if (absBytes < 1024 * 1024) {
    var kb = absBytes / 1024;
    return '$sign${kb.toStringAsFixed(3)} KB';
  } else if (absBytes < 1024 * 1024 * 1024) {
    var mb = absBytes / (1024 * 1024);
    return '$sign${mb.toStringAsFixed(3)} MB';
  } else {
    var gb = absBytes / (1024 * 1024 * 1024);
    return '$sign${gb.toStringAsFixed(3)} GB';
  }
}
