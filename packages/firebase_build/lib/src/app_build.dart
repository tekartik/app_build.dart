import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_flutter_build/app_build.dart';

import 'firebase_deploy.dart';

/// Build a web app
Future<void> flutterWebAppBuild(String directory) async {
  var shell = Shell().cd(directory);
  await shell.run('flutter build web');
}

/// Build a web app and deploy
///
/// Assume static web site in a 'public' subfolder
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

/// Build a web app and serve
///
/// Assume static web site in a 'public' subfolder
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

/// Web app options
class FlutterFirebaseWebAppOptions {
  /// Project path
  late final String path;

  /// Deploy directory
  final String? deployDir;

  /// Build options
  final FlutterWebAppBuildOptions? buildOptions;

  /// Deploy options
  final FirebaseDeployOptions deployOptions;

  /// Constructor
  FlutterFirebaseWebAppOptions({
    /// default to current directory
    String? path,
    this.deployDir,
    required this.deployOptions,
    this.buildOptions,
  }) {
    this.path = normalize(absolute(path ?? '.'));
  }

  /// Copy with
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

/// Convenient builder.
class FlutterFirebaseWebAppBuilder implements CommonAppBuilder {
  late final FlutterWebAppBuilder _flutterWebAppBuilderOnly;

  /// Options
  final FlutterFirebaseWebAppOptions options;

  /// Project path.
  @override
  String get path => options.path;

  /// Constructor
  FlutterFirebaseWebAppBuilder({required this.options}) {
    _flutterWebAppBuilderOnly = FlutterWebAppBuilder(
      options: FlutterWebAppOptions(
        buildOptions: options.buildOptions,
        path: options.path,
        deployDir: options.deployDir,
      ),
    );
  }

  /// Target
  String get target => options.deployOptions.target;

  /// Build only
  Future<void> build({FirebaseWebAppActionController? controller}) async {
    await _flutterWebAppBuilderOnly.buildOnly();
    await firebaseWebAppBuildToDeploy(
      options.path,
      deployDir: options.deployDir,
    );
  }

  /// Clean
  Future<void> clean() async {
    await flutterWebAppClean(options.path);
  }

  /// Serve
  Future<void> serve({FirebaseWebAppActionController? controller}) async {
    await firebaseWebAppServe(
      options.path,
      options.deployOptions,
      controller: controller,
    );
  }

  /// Deploy
  Future<void> deploy({FirebaseWebAppActionController? controller}) async {
    await firebaseWebAppDeploy(
      options.path,
      options.deployOptions,
      deployDir: options.deployDir,
      controller: controller,
    );
  }

  /// Build and serve
  Future<void> buildAndServe({
    FirebaseWebAppActionController? controller,
  }) async {
    await build(controller: controller);
    await serve(controller: controller);
  }

  /// Build and deploy
  Future<void> buildAndDeploy({
    FirebaseWebAppActionController? controller,
  }) async {
    await build(controller: controller);
    await deploy(controller: controller);
  }
}
