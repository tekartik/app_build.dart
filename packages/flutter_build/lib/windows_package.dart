/// Packages the Windows release of a Flutter desktop app for download: a
/// folder that runs on a machine without the Visual C++ redistributable
/// (what an installer packs), and its `.zip`.
library;

export 'src/windows_package.dart'
    show
        FlutterWindowsPackage,
        FlutterWindowsPackageFile,
        FlutterWindowsPackageInfo,
        flutterWindowsArch,
        flutterWindowsFileVersion,
        flutterWindowsPackage,
        flutterWindowsReleaseBundleDir,
        flutterWindowsRuntimeDir,
        flutterWindowsRuntimeDllNames;
