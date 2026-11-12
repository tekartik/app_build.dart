/// Runs the tests of a flutter app on a device of a target: a phone, an
/// emulator or a simulator found or launched for it (android, ios), or the
/// host desktop; its missing platform folders created first; the
/// `flutter test -r json` output parsed into a summary.
///
/// io only, the app itself never imports it.
library;

export 'src/device_test/flutter_platform_create.dart'
    show flutterMissingPlatforms, flutterCreatePlatformsIfMissing;
export 'src/device_test/flutter_target_device.dart'
    show
        FlutterDeviceTarget,
        FlutterTargetDeviceOptions,
        FlutterTargetDeviceCandidate,
        androidTargetDeviceCandidates,
        iosTargetDeviceCandidates,
        listFlutterTargetDeviceCandidates,
        FlutterTargetDeviceException,
        FlutterTargetDevice,
        withFlutterTargetDevice;
export 'src/device_test/test_json_reporter.dart'
    show
        TestJsonFailure,
        TestJsonTestDone,
        TestJsonSummary,
        TestJsonReporterParser,
        testJsonReporterParseLines;
export 'src/device_test/test_json_run.dart'
    show
        TestJsonRunResult,
        testJsonSummaryCheckExitCode,
        runTestJsonCommand,
        flutterDeviceTestArguments,
        runFlutterDeviceTest;
