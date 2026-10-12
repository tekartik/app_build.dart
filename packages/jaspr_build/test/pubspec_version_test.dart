import 'package:tekartik_jaspr_build/jaspr_build.dart';
import 'package:test/test.dart';

import 'src/site_fixture.dart';

void main() {
  group('pubspecVersion', () {
    late SiteFixture package;
    setUp(() async {
      package = await SiteFixture.create();
    });
    tearDown(() async {
      await package.delete();
    });

    test('without the build number', () {
      package.file('pubspec.yaml', 'name: my_app\nversion: 1.0.24+63\n');
      expect(pubspecVersion(package.path), '1.0.24');
    });
    test('quoted, no build number', () {
      package.file('pubspec.yaml', "name: my_app\nversion: '0.3.0'\n");
      expect(pubspecVersion(package.path), '0.3.0');
    });
    test('missing', () {
      package.file('pubspec.yaml', 'name: my_app\n');
      expect(() => pubspecVersion(package.path), throwsStateError);
    });
  });
}
