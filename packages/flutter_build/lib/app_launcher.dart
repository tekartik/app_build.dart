/// Builds and runs the desktop (host platform) release of a flutter app from
/// a dart command line (`bin/<app>.dart`), so that the app can be installed
/// with `dart install` or `dart pub global activate`.
///
/// io only, the app itself never imports it.
library;

export 'src/app_launcher.dart'
    show
        FlutterAppHostLauncher,
        flutterAppLauncherMain,
        findFlutterAppLauncherSourcePath,
        dartInstallSourcePath,
        pubspecLockSourcePath;
