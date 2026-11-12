import 'package:path/path.dart';
import 'package:tekartik_apple_build/apple_build.dart';
import 'package:test/test.dart';

void main() {
  group('xcode', () {
    test('xcodeVersionParse', () {
      var version = xcodeVersionParse('Xcode 27.2\nBuild version 27B52\n')!;
      expect(version.version, [27, 2]);
      expect(version.major, 27);
      expect(version.build, '27B52');
      expect(version.toString(), 'Xcode 27.2 (27B52)');
      expect(xcodeVersionParse('Xcode 16.4.1')!.version, [16, 4, 1]);
      expect(xcodeVersionParse('Xcode 16.4.1')!.build, isNull);
      expect(xcodeVersionParse('xcode-select: error'), isNull);
    });
    test('xcodeSimulatorAppPaths', () {
      var developer = join(
        'Applications',
        'Xcode.app',
        'Contents',
        'Developer',
      );
      expect(xcodeSimulatorAppPaths(developer), [
        join(
          'Applications',
          'Xcode.app',
          'Contents',
          'Applications',
          'DeviceHub.app',
        ),
        join(developer, 'Applications', 'Simulator.app'),
      ]);
    });
  });
  group('macos', () {
    test('macosVersionParse', () {
      expect(macosVersionParse('26.6\n'), [26, 6]);
      expect(macosVersionParse('15.7.1'), [15, 7, 1]);
      expect(macosVersionParse(''), isEmpty);
      expect(macosVersionParse('x.1'), isEmpty);
    });
    test('openMacosAppArguments', () {
      expect(openMacosAppArguments('DeviceHub'), ['-a', 'DeviceHub']);
      expect(
        openMacosAppArguments(
          '/Applications/My.app',
          newInstance: true,
          arguments: ['--flag'],
        ),
        ['-n', '-a', '/Applications/My.app', '--args', '--flag'],
      );
    });
  });
  test('host', () async {
    // Null off macOS, values on a macOS host with Xcode.
    var developerPath = await getXcodeDeveloperPath();
    var version = await getXcodeVersion();
    var macos = await getMacosVersion();
    expect(developerPath == null, version == null);
    if (macos == null) {
      expect(developerPath, isNull);
    }
  });
}
