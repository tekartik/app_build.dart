import 'package:tekartik_common_build/formatter.dart';
import 'package:test/test.dart';

void main() {
  group('formatter', () {
    test('formatSize', () {
      expect(formatSize(0), '0 B');
      expect(formatSize(1023), '1023 B');
      expect(formatSize(1024), '1.000 KB');
      expect(formatSize(1024 * 1024 - 1), '1023.999 KB');
      expect(formatSize(1024 * 1024), '1.000 MB');
      expect(formatSize(1024 * 1024 * 1024), '1.000 GB');
      expect(formatSize(1234567), '1.177 MB');
      expect(formatSize(-1), '-1 B');
      expect(formatSize(-1024), '-1.000 KB');
      expect(formatSize(-1234567), '-1.177 MB');
    });
  });
}
