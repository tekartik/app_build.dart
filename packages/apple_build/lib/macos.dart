/// The macOS host: its version, opening an app.
///
/// io only. The macOS project of a flutter app (entitlements, sandbox) is
/// `MacosProject` of tekartik_build_flutter.
library;

export 'src/macos.dart'
    show
        macosVersionParse,
        getMacosVersion,
        openMacosAppArguments,
        openMacosApp;
