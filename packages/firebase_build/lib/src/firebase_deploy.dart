import 'dart:io';

import 'package:cv/cv.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_deploy/fs_deploy.dart';
import 'package:tekartik_web_publish/web_publish.dart';

/// Default directory the built web app is copied into before Firebase
/// deploy/serve: `<hosting dir>/public`.
var firebaseDefaultWebDeployDir = join(firebaseDefaultHostingDir, 'public');

/// Default deploy directory, i.e. [firebaseDefaultWebDeployDir].
var firebaseDefaultDeployDir = firebaseDefaultWebDeployDir;

/// Default Firebase hosting config directory relative to the project root:
/// `deploy/firebase/hosting`.
var firebaseDefaultHostingDir = join('deploy', 'firebase', 'hosting');

/// Identifies the Firebase project/hosting target to deploy or serve to.
class FirebaseDeployOptions implements WebAppDeployOptions {
  /// Firebase project ID (used with `firebase --project`).
  String projectId;

  /// Firebase Hosting site ID to bind [target] to (used with
  /// `firebase target:apply hosting`).
  String hostingId;

  /// Hosting target name (used with `deploy --only hosting:<target>`).
  String target;

  /// Creates deploy options for [projectId], binding hosting [target] to
  /// [hostingId].
  FirebaseDeployOptions({
    required this.projectId,
    required this.hostingId,
    required this.target,
  });

  /// Returns a copy of these options, overriding [projectId], [hostingId]
  /// and/or [target] while keeping the rest unchanged.
  FirebaseDeployOptions copyWith({
    String? projectId,
    String? hostingId,
    String? target,
  }) {
    return FirebaseDeployOptions(
      projectId: projectId ?? this.projectId,
      hostingId: hostingId ?? this.hostingId,
      target: target ?? this.target,
    );
  }
}

String _fixFolder(String path, String folder) {
  if (isAbsolute(folder)) {
    return folder;
  }
  return join(path, folder);
}

/// Deploys the already-built web app under [deployDir] (defaults to
/// [firebaseDefaultHostingDir] resolved against [path]; relative paths are
/// resolved against [path]) to Firebase Hosting, using [options] for the
/// project/target/hosting-id.
///
/// Configures the hosting target/hosting-id binding first if needed. If
/// [controller] is given, it's wired to the underlying shell so
/// [FirebaseWebAppActionController.cancel] can abort the deploy.
Future firebaseWebAppDeploy(
  String path,
  FirebaseDeployOptions options, {
  String? deployDir,
  FirebaseWebAppActionController? controller,
}) async {
  deployDir = _fixFolder(path, deployDir ?? firebaseDefaultHostingDir);

  var projectId = options.projectId;
  var target = options.target;

  var shell = Shell().pushd(deployDir);
  controller?.shell = shell;

  await _firebaseWebAppPrepareHosting(path, options, deployDir: deployDir);

  await shell.run(
    'firebase --project $projectId deploy --only hosting:$target',
  );
}

/// Configure hosting for target if needed
Future _firebaseWebAppPrepareHosting(
  String path,
  FirebaseDeployOptions options, {
  String? deployDir,
}) async {
  deployDir = _fixFolder(path, deployDir ?? firebaseDefaultHostingDir);

  var projectId = options.projectId;
  var target = options.target;
  var hostingId = options.hostingId;

  try {
    var firebaseRcMap = parseJsonObject(
      File(join(deployDir, '.firebaserc')).readAsStringSync(),
    )!;
    var existingHostingId = firebaseRcMap.getKeyPathValue([
      'targets',
      projectId,
      'hosting',
      target,
      0,
    ]);
    if (existingHostingId == hostingId) {
      // Hosting id matches
      return;
    }
  } catch (_) {}

  // Configure hosting for target
  var shell = Shell().pushd(deployDir);
  await shell.run('firebase --project $projectId target:clear hosting $target');
  await shell.run(
    'firebase --project $projectId target:apply hosting $target $hostingId',
  );
}

/// Copies the built web app from `[path]/build/[folder]` into
/// `<deployDir>/public` (where [deployDir] defaults to
/// [firebaseDefaultHostingDir] resolved against [path]), following the
/// copy rules declared in that build folder's `deploy.yaml`.
///
/// [folder] is the build output subfolder under `build/`, defaulting to
/// `'web'`.
///
/// Throws a [StateError] if the build folder has no `deploy.yaml`.
Future<void> firebaseWebAppBuildToDeploy(
  String path, {
  String? deployDir,
  String folder = 'web',
}) async {
  var buildFolder = join(path, 'build', folder);
  deployDir = join(
    _fixFolder(path, deployDir ?? firebaseDefaultHostingDir),
    'public',
  );

  var deployFile = File(join(buildFolder, 'deploy.yaml'));
  // ignore: avoid_slow_async_io
  if (!await deployFile.exists()) {
    throw StateError('Missing deploy.yaml file ($deployFile)');
  }
  await fsDeploy(
    options: FsDeployOptions()..noSymLink = true,
    yaml: deployFile,
    src: Directory(buildFolder),
    dst: Directory(deployDir),
  );
}

/// Typo error - Use firebaseWebAppBuildToDeploy
@Deprecated('Typo error - Use firebaseWebAppBuildToDeploy')
var firebaseWepAppBuildToDeploy = firebaseWebAppBuildToDeploy;

/// Serves the already-built web app under [deployDir] (defaults to
/// [firebaseDefaultHostingDir] resolved against [path]) locally via
/// `firebase emulators:start`, using [options] for the project/target.
///
/// Configures the hosting target/hosting-id binding first if needed. If
/// [controller] is given, it's wired to the underlying shell so
/// [FirebaseWebAppActionController.cancel] can stop the emulator.
Future<void> firebaseWebAppServe(
  String path,
  FirebaseDeployOptions options, {
  String? deployDir,
  FirebaseWebAppActionController? controller,
}) async {
  deployDir = _fixFolder(path, deployDir ?? firebaseDefaultHostingDir);

  var projectId = options.projectId;

  var target = options.target;

  var shell = Shell().pushd(deployDir);
  controller?._shell = shell;
  await _firebaseWebAppPrepareHosting(path, options, deployDir: deployDir);
  await shell.run(
    'firebase emulators:start --project $projectId  --only hosting:$target',
  );
}

/// Lets callers cancel an in-progress [firebaseWebAppDeploy] or
/// [firebaseWebAppServe] action.
class FirebaseWebAppActionController {
  Shell? _shell;

  /// Kills the underlying `firebase` shell command, aborting the deploy or
  /// serve action it was passed to.
  void cancel() {
    _shell?.kill();
  }
}

/// Firebase web app action controller private extension
extension FirebaseWebAppActionControllerPrvExt
    on FirebaseWebAppActionController {
  set shell(Shell shell) {
    _shell = shell;
  }
}
