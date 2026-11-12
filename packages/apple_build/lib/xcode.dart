/// The selected Xcode: its developer folder, its simulator app (DeviceHub on
/// Xcode 27+, Simulator before) and its version.
///
/// io only, `null` results when not on macOS.
library;

export 'src/xcode.dart'
    show
        getXcodeDeveloperPath,
        xcodeSimulatorAppPaths,
        getXcodeSimulatorAppPath,
        XcodeVersion,
        xcodeVersionParse,
        getXcodeVersion;
