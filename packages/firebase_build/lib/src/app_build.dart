import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_flutter_build/app_build.dart';

import 'firebase_deploy.dart';

/// Runs `flutter build web` in [directory].
Future<void> flutterWebAppBuild(String directory) async {
  var shell = Shell().cd(directory);
  await shell.run('flutter build web');
}

/// Builds the Flutter web app in [directory] and deploys it to Firebase
/// Hosting, using [firebaseDeployOptions] for the deploy target/project.
///
/// [deployDir] overrides where the built output is copied before deploying
/// (assumes a static web site in a `'public'` subfolder by default; see
/// `firebaseDefaultDeployDir`).
Future<void> flutterWebAppBuildAndDeploy(
  String directory, {
  required FirebaseDeployOptions firebaseDeployOptions,
  String? deployDir,
}) async {
  await flutterWebAppBuild(directory);
  await firebaseWebAppBuildToDeploy(directory, deployDir: deployDir);
  await firebaseWebAppDeploy(
    directory,
    firebaseDeployOptions,
    deployDir: deployDir,
  );
}

/// Builds the Flutter web app in [directory] and serves it locally via the
/// Firebase emulator, using [firebaseDeployOptions] for the target/project.
///
/// [deployDir] overrides where the built output is copied before serving
/// (assumes a static web site in a `'public'` subfolder by default; see
/// `firebaseDefaultDeployDir`).
Future<void> flutterWebAppBuildAndServe(
  String directory, {
  required FirebaseDeployOptions firebaseDeployOptions,
  String? deployDir,
}) async {
  await flutterWebAppBuild(directory);
  await firebaseWebAppBuildToDeploy(directory, deployDir: deployDir);
  await firebaseWebAppServe(
    directory,
    firebaseDeployOptions,
    deployDir: deployDir,
  );
}

/// Options for building and deploying a Flutter web app to Firebase
/// Hosting, used by [FlutterFirebaseWebAppBuilder].
class FlutterFirebaseWebAppOptions {
  /// Absolute, normalized path to the Flutter project.
  late final String path;

  /// Directory the built web app is copied to before deploy/serve.
  /// Defaults to `deploy/firebase/hosting/public`
  /// (`firebaseDefaultWebDeployDir`) when `null`.
  final String? deployDir;

  /// Options controlling `flutter build web`, or `null` for defaults.
  final FlutterWebAppBuildOptions? buildOptions;

  /// Firebase deploy target/project options.
  final FirebaseDeployOptions deployOptions;

  /// Creates options for the Flutter project at [path] (defaults to the
  /// current directory), deployed with [deployOptions]. [deployDir] and
  /// [buildOptions] default to `null` (see their field docs).
  FlutterFirebaseWebAppOptions({
    String? path,
    this.deployDir,
    required this.deployOptions,
    this.buildOptions,
  }) {
    this.path = normalize(absolute(path ?? '.'));
  }

  /// Returns a copy of these options, overriding [path], [deployDir],
  /// [buildOptions] and/or [deployOptions] while keeping the rest
  /// unchanged.
  FlutterFirebaseWebAppOptions copyWith({
    String? path,
    String? deployDir,
    FlutterWebAppBuildOptions? buildOptions,
    FirebaseDeployOptions? deployOptions,
  }) {
    return FlutterFirebaseWebAppOptions(
      path: path ?? this.path,
      deployDir: deployDir ?? this.deployDir,
      buildOptions: buildOptions ?? this.buildOptions,
      deployOptions: deployOptions ?? this.deployOptions,
    );
  }
}

/// Builds, serves and deploys a Flutter web app to Firebase Hosting,
/// combining `FlutterWebAppBuilder` with the Firebase deploy/serve helpers.
class FlutterFirebaseWebAppBuilder implements CommonAppBuilder {
  /// The underlying plain Flutter web app builder used for the
  /// build/clean/copy-to-deploy steps.
  FlutterWebAppBuilder get webAppBuilder => _flutterWebAppBuilderOnly;
  late final FlutterWebAppBuilder _flutterWebAppBuilderOnly;

  /// Options controlling how this builder builds and deploys.
  final FlutterFirebaseWebAppOptions options;

  /// Absolute path to the Flutter project, i.e. [options]' `path`.
  @override
  String get path => options.path;

  /// Creates a builder for the project/deploy target described by
  /// [options].
  FlutterFirebaseWebAppBuilder({required this.options}) {
    _flutterWebAppBuilderOnly = FlutterWebAppBuilder(
      options: FlutterWebAppOptions(
        buildOptions: options.buildOptions,
        path: options.path,
        deployDir: options.deployDir ?? firebaseDefaultWebDeployDir,
      ),
    );
  }

  /// The Firebase deploy target, i.e. `options.deployOptions.target`.
  String get target => options.deployOptions.target;

  /// Builds the Flutter web app and copies the output into the deploy
  /// directory, without deploying or serving it.
  Future<void> build({FirebaseWebAppActionController? controller}) async {
    await _flutterWebAppBuilderOnly.buildOnly();
    await _flutterWebAppBuilderOnly.buildToDeploy();
  }

  /// Removes the built Flutter web app output for this project.
  Future<void> clean() async {
    await flutterWebAppClean(options.path);
  }

  /// Copies the built output to the deploy directory and serves it locally
  /// via the Firebase emulator. [controller], if given, can be used to
  /// control/observe the running serve action.
  Future<void> serve({FirebaseWebAppActionController? controller}) async {
    await _flutterWebAppBuilderOnly.buildToDeploy();

    await firebaseWebAppServe(
      options.path,
      options.deployOptions,
      deployDir: options.deployDir,
      controller: controller,
    );
  }

  /// Copies the built output to the deploy directory and deploys it to
  /// Firebase Hosting. [controller], if given, can be used to
  /// control/observe the running deploy action.
  Future<void> deploy({FirebaseWebAppActionController? controller}) async {
    await _flutterWebAppBuilderOnly.buildToDeploy();

    await firebaseWebAppDeploy(
      options.path,
      options.deployOptions,
      deployDir: options.deployDir,
      controller: controller,
    );
  }

  /// Runs [build] followed by [serve].
  Future<void> buildAndServe({
    FirebaseWebAppActionController? controller,
  }) async {
    await build(controller: controller);
    await serve(controller: controller);
  }

  /// Copies the already-built Flutter web app output into the deploy
  /// directory, without rebuilding.
  Future<void> copyBuildToDeploy() async {
    await _flutterWebAppBuilderOnly.buildToDeploy();
  }

  /// Runs [build] followed by [deploy].
  Future<void> buildAndDeploy({
    FirebaseWebAppActionController? controller,
  }) async {
    await build(controller: controller);
    await deploy(controller: controller);
  }
}
