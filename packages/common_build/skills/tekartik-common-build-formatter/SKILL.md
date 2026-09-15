---
name: tekartik-common-build-formatter
description: >-
  Use when a Dart build, deploy or reporting script needs to print a byte
  count as a human readable size (B, KB, MB, GB, 1024-based, 3 decimals) with
  formatSize from package:tekartik_common_build/formatter.dart, for example to
  log the size of a built bundle, an archive or a deployed asset.
---

# tekartik_common_build: formatSize

`package:tekartik_common_build/formatter.dart` exports one function,
`formatSize(int bytes)`, which turns a byte count into a short string with the
largest fitting binary unit. It is used by the build helpers of
`app_build.dart` to report the size of a compiled bundle after a build. Pure
Dart, no `dart:io`, usable from any platform.

```dart
import 'package:tekartik_common_build/formatter.dart';

void main() {
  print(formatSize(1234567)); // 1.177 MB
}
```

## Guidelines

* `formatSize(int bytes)` returns `'<n> B'` below 1024 bytes, then
  `'<n.nnn> KB'`, `'<n.nnn> MB'` or `'<n.nnn> GB'` with exactly three decimals.
  Units are binary (1 KB is 1024 bytes) even though the labels are `KB`, `MB`
  and `GB`. There is no `TB`: anything from 1 GiB up is printed in `GB`.
* The argument is an `int`. Pass `file.lengthSync()`, `bytes.length`,
  `stat.size` or a sum of those; pass `0` for a missing artifact rather than
  skipping the log line, so the output stays parseable.
* Negative values keep their sign (`'-1.000 KB'`); the absolute value picks
  the unit.
* The output is meant for logs and console reports. Do not parse it back;
  keep the raw byte count when a number is needed later.
* Import `package:tekartik_common_build/formatter.dart` directly, or with a
  prefix (`as f`) when the script has its own `formatSize`.

## Examples

### Report the size of a built bundle

```dart
import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_common_build/formatter.dart';

Future<void> reportJsSize(String buildDir) async {
  var file = File(join(buildDir, 'main.dart.js'));
  var size = file.existsSync() ? file.lengthSync() : 0;
  stdout.writeln('main.dart.js (${formatSize(size)})');
}
```

### Total size of a deploy folder

```dart
import 'dart:io';

import 'package:tekartik_common_build/formatter.dart';

Future<String> directorySize(String path) async {
  var total = 0;
  await for (var entity in Directory(path).list(recursive: true)) {
    if (entity is File) {
      total += await entity.length();
    }
  }
  return formatSize(total);
}
```

### Before/after comparison

```dart
import 'package:tekartik_common_build/formatter.dart';

void reportDelta(String name, int before, int after) {
  // formatSize keeps the sign, so a shrink prints as '-12.500 KB'.
  print('$name: ${formatSize(before)} -> ${formatSize(after)} '
      '(${formatSize(after - before)})');
}
```

### Expected values in a test

```dart
import 'package:tekartik_common_build/formatter.dart';
import 'package:test/test.dart';

void main() {
  test('formatSize', () {
    expect(formatSize(0), '0 B');
    expect(formatSize(1023), '1023 B');
    expect(formatSize(1024), '1.000 KB');
    expect(formatSize(1024 * 1024 - 1), '1023.999 KB');
    expect(formatSize(1024 * 1024 * 1024), '1.000 GB');
    expect(formatSize(-1234567), '-1.177 MB');
  });
}
```

## Common mistakes

* Expecting decimal units: `formatSize(1000)` is `'1000 B'`, not `'1.000 KB'`.
* Passing a `double` or a `num`: the parameter is `int`.
* Formatting a `Future<int>` from `file.length()` without awaiting it.
