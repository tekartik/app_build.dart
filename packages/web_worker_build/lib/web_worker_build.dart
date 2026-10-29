/// Builds a Dart program into the JavaScript file that a web app loads
/// besides its page (a web worker, a shared worker, an AudioWorklet module)
/// with dart2js, again only when the Dart SDK or a dependency changed.
///
/// dart:io only: for the setup tools of the packages providing a script, and
/// the `tool/dev_build_setup.dart` of the apps.
library;

export 'src/project_packages.dart'
    show ProjectPackages, findPackageConfigFile, folderHash;
export 'src/web_worker_script.dart'
    show WebWorkerScript, WebWorkerScriptSetupResult;
