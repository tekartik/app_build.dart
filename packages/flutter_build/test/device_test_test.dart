import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_android_utils/adb_utils.dart';
import 'package:tekartik_android_utils/emulator_utils.dart';
import 'package:tekartik_apple_build/ios_simulator.dart';
import 'package:tekartik_flutter_build/device_test.dart';
import 'package:test/test.dart';

AdbDeviceInfo _adb(String serial, String type, {String? model}) =>
    AdbDeviceInfo()
      ..serial = serial
      ..type = type
      ..model = model;

void main() {
  group('FlutterDeviceTarget', () {
    test('host', () {
      var host = FlutterDeviceTarget.host;
      expect(host.isDesktop, isTrue);
      expect(host.isSupportedOnHost, isTrue);
      expect(
        FlutterDeviceTarget.hostTargets.first,
        FlutterDeviceTarget.android,
      );
      expect(FlutterDeviceTarget.hostTargets.last, host);
      expect(FlutterDeviceTarget.ios.isSupportedOnHost, Platform.isMacOS);
      expect(FlutterDeviceTarget.ios.isMobile, isTrue);
      expect(FlutterDeviceTarget.ios.platform, 'ios');
    });
  });

  group('candidates', () {
    test('android', () {
      var candidates = androidTargetDeviceCandidates(
        AndroidDevicesState(
          devices: [
            _adb('emulator-5554', adbDeviceStateOnline),
            _adb('R58M', adbDeviceStateOnline, model: 'SM_G973F'),
            _adb('emulator-5556', 'offline'),
          ],
          runningAvdNames: {'emulator-5554': 'Pixel_9'},
          avds: ['Pixel_9', 'Wear_OS'],
        ),
      );
      expect(candidates.map((c) => c.toString()), [
        'Pixel_9 (emulator-5554)',
        'SM_G973F (R58M)',
        'Wear_OS (to launch)',
      ]);
      var options = const FlutterTargetDeviceOptions(keep: true);
      var online = candidates.first.select(options);
      expect(online.serial, 'emulator-5554');
      expect(online.avd, isNull);
      expect(online.keep, isTrue);
      var toLaunch = candidates.last.select(options);
      expect(toLaunch.avd, 'Wear_OS');
      expect(toLaunch.serial, isNull);
    });
    test('ios', () {
      var candidates = iosTargetDeviceCandidates([
        IosSimulator(
          udid: 'U1',
          name: 'iPhone 17',
          runtime: '${iosSimulatorRuntimePrefix}27-0',
          state: iosSimulatorStateBooted,
        ),
        IosSimulator(
          udid: 'U2',
          name: 'iPad (A16)',
          runtime: '${iosSimulatorRuntimePrefix}26-5',
          state: 'Shutdown',
        ),
      ]);
      expect(candidates.map((c) => c.toString()), [
        'iPhone 17 iOS 27.0',
        'iPad (A16) iOS 26.5 (to launch)',
      ]);
      var options = candidates.last.select(
        const FlutterTargetDeviceOptions(serial: 'ignored', noWindow: true),
      );
      expect(options.simulator, 'U2');
      expect(options.serial, isNull);
      expect(options.noWindow, isTrue);
    });
    test('host', () async {
      var candidates = await listFlutterTargetDeviceCandidates(
        FlutterDeviceTarget.host,
      );
      expect(candidates.single.id, FlutterDeviceTarget.host.name);
      expect(
        await listFlutterTargetDeviceCandidates(
          Platform.isWindows
              ? FlutterDeviceTarget.linux
              : FlutterDeviceTarget.windows,
        ),
        isEmpty,
      );
    });
  });

  group('withFlutterTargetDevice', () {
    test('host', () async {
      var host = FlutterDeviceTarget.host;
      var device = await withFlutterTargetDevice(
        host,
        (device) async => device,
      );
      expect(device.id, host.name);
      expect(device.launched, isFalse);
    });
    test('not supported', () async {
      var target = Platform.isWindows
          ? FlutterDeviceTarget.linux
          : FlutterDeviceTarget.windows;
      await expectLater(
        withFlutterTargetDevice(target, (device) async {}),
        throwsA(isA<FlutterTargetDeviceException>()),
      );
    });
  });

  test('flutterDeviceTestArguments', () {
    expect(flutterDeviceTestArguments(deviceId: 'macos'), [
      'test',
      'integration_test',
      '-d',
      'macos',
      '-r',
      'json',
    ]);
    expect(
      flutterDeviceTestArguments(
        deviceId: 'U1',
        test: 'integration_test/all_test.dart',
        plainName: 'open',
        arguments: ['--flavor', 'dev'],
      ),
      [
        'test',
        'integration_test/all_test.dart',
        '-d',
        'U1',
        '-r',
        'json',
        '--plain-name',
        'open',
        '--flavor',
        'dev',
      ],
    );
  });

  test('flutterMissingPlatforms', () async {
    var dir = await Directory.systemTemp.createTemp('flutter_platforms');
    try {
      await Directory(join(dir.path, 'ios')).create();
      expect(flutterMissingPlatforms(dir.path, ['ios', 'macos', 'macos']), [
        'macos',
      ]);
      expect(await flutterCreatePlatformsIfMissing(dir.path, ['ios']), isEmpty);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('testJsonSummaryCheckExitCode', () {
    var summary = testJsonReporterParseLines([]);
    expect(testJsonSummaryCheckExitCode(summary, 0).done, isNull);
    expect(testJsonSummaryCheckExitCode(summary, 1).done, isFalse);
  });
}
