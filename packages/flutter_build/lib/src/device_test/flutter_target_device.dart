import 'dart:async';
import 'dart:io';

import 'package:tekartik_android_utils/build_utils.dart';
import 'package:tekartik_android_utils/emulator_utils.dart';
import 'package:tekartik_apple_build/ios_simulator.dart';

/// Where a flutter app runs: a phone, an emulator or a simulator found or
/// launched for it (android, ios), or the host desktop.
enum FlutterDeviceTarget {
  /// An Android device or emulator (an AVD launched when needed).
  android,

  /// An iOS simulator (booted when needed, DeviceHub on Xcode 27+).
  ios,

  /// The Linux desktop.
  linux,

  /// The macOS desktop.
  macos,

  /// The Windows desktop.
  windows;

  /// `true` for linux, macos and windows, the device being the host.
  bool get isDesktop => !isMobile;

  /// `true` for android and ios.
  bool get isMobile =>
      this == FlutterDeviceTarget.android || this == FlutterDeviceTarget.ios;

  /// The flutter platform folder of the target (`android`, `ios`...).
  String get platform => name;

  /// `true` when it can run from this host: android anywhere, ios and macos
  /// on macOS, linux and windows on their own.
  bool get isSupportedOnHost => switch (this) {
    FlutterDeviceTarget.android => true,
    FlutterDeviceTarget.ios || FlutterDeviceTarget.macos => Platform.isMacOS,
    FlutterDeviceTarget.linux => Platform.isLinux,
    FlutterDeviceTarget.windows => Platform.isWindows,
  };

  /// The desktop target of the host.
  static FlutterDeviceTarget get host => Platform.isMacOS
      ? FlutterDeviceTarget.macos
      : Platform.isWindows
      ? FlutterDeviceTarget.windows
      : FlutterDeviceTarget.linux;

  /// The targets supported on this host, mobile first: android, ios (on
  /// macOS) and the [host] desktop.
  static List<FlutterDeviceTarget> get hostTargets =>
      values.where((target) => target.isSupportedOnHost).toList();
}

/// How [withFlutterTargetDevice] picks and launches a device.
class FlutterTargetDeviceOptions {
  /// Android: the online device to use (adb serial).
  final String? serial;

  /// Android: the AVD to use (its running emulator, or a launch of it).
  final String? avd;

  /// iOS: the simulator to use, a UDID or a name (booted when needed).
  final String? simulator;

  /// Android, iOS: keep the emulator (simulator) launched running.
  final bool keep;

  /// Android, iOS: launch the emulator without a window (the simulator
  /// without opening DeviceHub).
  final bool noWindow;

  /// Android, iOS: how long a launch may take to boot.
  final Duration bootTimeout;

  /// The device chosen by [serial], [avd] or [simulator] (the default one
  /// when none is given), [keep], [noWindow], [bootTimeout].
  const FlutterTargetDeviceOptions({
    this.serial,
    this.avd,
    this.simulator,
    this.keep = false,
    this.noWindow = false,
    this.bootTimeout = const Duration(minutes: 5),
  });

  /// These options choosing [serial], [avd] and [simulator] instead.
  FlutterTargetDeviceOptions withDevice({
    String? serial,
    String? avd,
    String? simulator,
  }) => FlutterTargetDeviceOptions(
    serial: serial,
    avd: avd,
    simulator: simulator,
    keep: keep,
    noWindow: noWindow,
    bootTimeout: bootTimeout,
  );
}

/// A device [withFlutterTargetDevice] can use, see
/// [listFlutterTargetDeviceCandidates].
class FlutterTargetDeviceCandidate {
  /// Its target.
  final FlutterDeviceTarget target;

  /// The adb serial (an online android device), the AVD (one to launch),
  /// the simulator UDID (ios) or the target name (desktop).
  final String id;

  /// A name for the user (`Pixel_9 (emulator-5554)`, `iPhone 17 iOS 27.0`).
  final String name;

  /// `true` when online (android), booted (ios) or the host (desktop),
  /// `false` when it would be launched.
  final bool running;

  /// The [target] device [id] named [name], [running] or not.
  const FlutterTargetDeviceCandidate({
    required this.target,
    required this.id,
    required this.name,
    required this.running,
  });

  /// [options] choosing this device.
  FlutterTargetDeviceOptions select(FlutterTargetDeviceOptions options) =>
      switch (target) {
        FlutterDeviceTarget.android =>
          running
              ? options.withDevice(serial: id)
              : options.withDevice(avd: id),
        FlutterDeviceTarget.ios => options.withDevice(simulator: id),
        _ => options.withDevice(),
      };

  @override
  String toString() => '$name${running ? '' : ' (to launch)'}';
}

/// The android candidates of [state]: the online devices then the AVDs not
/// running.
List<FlutterTargetDeviceCandidate> androidTargetDeviceCandidates(
  AndroidDevicesState state,
) {
  var candidates = <FlutterTargetDeviceCandidate>[];
  var runningAvds = <String>{};
  for (var device in state.devices) {
    var serial = device.serial;
    if (serial == null || device.type != adbDeviceStateOnline) {
      continue;
    }
    var avd = state.runningAvdNames[serial];
    if (avd != null) {
      runningAvds.add(avd);
    }
    candidates.add(
      FlutterTargetDeviceCandidate(
        target: FlutterDeviceTarget.android,
        id: serial,
        name: '${avd ?? device.model ?? serial} ($serial)',
        running: true,
      ),
    );
  }
  for (var avd in state.avds) {
    if (!runningAvds.contains(avd)) {
      candidates.add(
        FlutterTargetDeviceCandidate(
          target: FlutterDeviceTarget.android,
          id: avd,
          name: avd,
          running: false,
        ),
      );
    }
  }
  return candidates;
}

/// The ios candidates of [simulators] ([listIosSimulators]), in their order.
List<FlutterTargetDeviceCandidate> iosTargetDeviceCandidates(
  List<IosSimulator> simulators,
) => [
  for (var simulator in simulators)
    FlutterTargetDeviceCandidate(
      target: FlutterDeviceTarget.ios,
      id: simulator.udid,
      name: '${simulator.name} iOS ${simulator.iosVersion.join('.')}',
      running: simulator.isBooted,
    ),
];

FlutterTargetDeviceCandidate _hostCandidate(FlutterDeviceTarget target) =>
    FlutterTargetDeviceCandidate(
      target: target,
      id: target.name,
      name: target.name,
      running: true,
    );

/// The devices of [target] to choose from (a UI), see
/// [FlutterTargetDeviceCandidate.select]. Empty when the target is not
/// supported on this host.
///
/// Android reads adb and the AVDs (`initAndroidBuildEnvironment`), ios the
/// available simulators.
Future<List<FlutterTargetDeviceCandidate>> listFlutterTargetDeviceCandidates(
  FlutterDeviceTarget target,
) async {
  if (!target.isSupportedOnHost) {
    return const [];
  }
  switch (target) {
    case FlutterDeviceTarget.android:
      await initAndroidBuildEnvironment();
      return androidTargetDeviceCandidates(await getAndroidDevicesState());
    case FlutterDeviceTarget.ios:
      return iosTargetDeviceCandidates(await listIosSimulators());
    default:
      return [_hostCandidate(target)];
  }
}

/// No device of [target] can be chosen: the [candidates] to pick from
/// (empty when there are none, [message] tells why).
class FlutterTargetDeviceException implements Exception {
  /// The target.
  final FlutterDeviceTarget target;

  /// Why, for the user.
  final String message;

  /// The devices to choose from ([FlutterTargetDeviceCandidate.select]).
  final List<FlutterTargetDeviceCandidate> candidates;

  /// No device of [target] chosen ([message]) among [candidates].
  FlutterTargetDeviceException(
    this.target,
    this.message, {
    this.candidates = const [],
  });

  @override
  String toString() => '${target.name}: $message';
}

/// The device given to the action of [withFlutterTargetDevice].
class FlutterTargetDevice {
  /// Its target.
  final FlutterDeviceTarget target;

  /// The `flutter -d` device id: adb serial, simulator UDID or the desktop
  /// target name.
  final String id;

  /// A name for the user.
  final String name;

  /// `true` when [withFlutterTargetDevice] launched (booted) it.
  final bool launched;

  /// The [target] device [id] named [name], [launched] or not.
  FlutterTargetDevice({
    required this.target,
    required this.id,
    required this.name,
    this.launched = false,
  });

  @override
  String toString() =>
      '${target.name} $name${name == id ? '' : ' ($id)'}'
      '${launched ? ' launched' : ''}';
}

/// Runs [action] on a device of [target]:
///
/// - android: the device or emulator of [FlutterTargetDeviceOptions.serial]
///   or [FlutterTargetDeviceOptions.avd], else the first online emulator or
///   device, else the only AVD, launched (`withAndroidDevice` of
///   tekartik_android_utils);
/// - ios: the simulator of [FlutterTargetDeviceOptions.simulator], else the
///   booted one, else the first iPhone of the latest runtime, booted
///   (`withIosSimulator` of tekartik_apple_build);
/// - linux, macos, windows: the host.
///
/// A device launched is stopped after [action] unless
/// [FlutterTargetDeviceOptions.keep]. [onLaunching] is called with its id
/// (serial, UDID) before a launch. Returns the result of [action].
///
/// Throws a [FlutterTargetDeviceException] with the candidates when no
/// device can be chosen (several AVDs and nothing online, an unknown
/// simulator...) or the target is not supported on this host, a
/// [TimeoutException] when the launched device does not boot.
Future<T> withFlutterTargetDevice<T>(
  FlutterDeviceTarget target,
  Future<T> Function(FlutterTargetDevice device) action, {
  FlutterTargetDeviceOptions options = const FlutterTargetDeviceOptions(),
  void Function(String id)? onLaunching,
}) async {
  if (!target.isSupportedOnHost) {
    throw FlutterTargetDeviceException(
      target,
      'not supported on ${Platform.operatingSystem}',
    );
  }
  switch (target) {
    case FlutterDeviceTarget.android:
      await initAndroidBuildEnvironment();
      var state = await getAndroidDevicesState();
      AndroidEmulatorRunTarget chosen;
      try {
        chosen = androidEmulatorRunChooseTarget(
          devices: state.devices,
          runningAvdNames: state.runningAvdNames,
          avds: state.avds,
          serial: options.serial,
          avd: options.avd,
        );
      } on StateError catch (e) {
        throw FlutterTargetDeviceException(
          target,
          e.message,
          candidates: androidTargetDeviceCandidates(state),
        );
      }
      return await withAndroidDevice(
        (device) => action(
          FlutterTargetDevice(
            target: target,
            id: device.serial,
            name: device.avd ?? device.serial,
            launched: device.launched,
          ),
        ),
        serial: chosen.serial,
        avd: chosen.avdToLaunch,
        keep: options.keep,
        noWindow: options.noWindow,
        bootTimeout: options.bootTimeout,
        onLaunching: onLaunching,
      );
    case FlutterDeviceTarget.ios:
      var simulators = await listIosSimulators();
      IosSimulator chosen;
      try {
        chosen = iosSimulatorChooseTarget(
          simulators,
          simulator: options.simulator,
        );
      } on StateError catch (e) {
        throw FlutterTargetDeviceException(
          target,
          e.message,
          candidates: iosTargetDeviceCandidates(simulators),
        );
      }
      return await withIosSimulator(
        (simulator) => action(
          FlutterTargetDevice(
            target: target,
            id: simulator.udid,
            name:
                '${simulator.simulator.name} iOS '
                '${simulator.simulator.iosVersion.join('.')}',
            launched: simulator.launched,
          ),
        ),
        simulator: chosen.udid,
        keep: options.keep,
        noWindow: options.noWindow,
        bootTimeout: options.bootTimeout,
        onLaunching: (simulator) => onLaunching?.call(simulator.udid),
      );
    default:
      return await action(
        FlutterTargetDevice(target: target, id: target.name, name: target.name),
      );
  }
}
