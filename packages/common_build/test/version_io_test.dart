@TestOn('vm')
library;

import 'package:tekartik_common_build/src/version_io.dart';
import 'package:test/test.dart';

void main() {
  test('Generate Version', () async {
    await generateVersion();
  });
}
