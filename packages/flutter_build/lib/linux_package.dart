/// Packages the Linux release of a Flutter desktop app for download: a
/// `.tar.gz` with its install script and a `.deb`.
library;

export 'src/linux_package.dart'
    show
        FlutterLinuxPackageFile,
        FlutterLinuxPackageInfo,
        flutterLinuxArch,
        flutterLinuxDebVersion,
        flutterLinuxPackage,
        flutterLinuxReleaseBundleDir;
