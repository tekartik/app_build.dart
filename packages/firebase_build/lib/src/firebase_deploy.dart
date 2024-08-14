import 'dart:io';

import 'package:cv/cv.dart';
import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_deploy/fs_deploy.dart';
import 'package:tekartik_web_publish/web_publish.dart';

var firebaseDefaultWebDeployDir = join(firebaseDefaultHostingDir, 'public');
var firebaseDefaultDeployDir = firebaseDefaultWebDeployDir;
var firebaseDefaultHostingDir = join('deploy', 'firebase', 'hosting');

class FirebaseDeployOptions implements WebAppDeployOptions {
  String projectId;

  /// Billable firebase project
  String hostingId;

  /// Domain
  String target;

  FirebaseDeployOptions({
    required this.projectId,
    required this.hostingId,
    required this.target,
  });

  /// Copy with new values.
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

/// Deploy from deploy/firebase/hosting
Future firebaseWebAppDeploy(String path, FirebaseDeployOptions options,
    {String? deployDir, FirebaseWebAppActionController? controller}) async {
  deployDir = _fixFolder(path, deployDir ?? firebaseDefaultHostingDir);

  var projectId = options.projectId;
  var target = options.target;

  var shell = Shell().pushd(deployDir);
  controller?.shell = shell;

  await _firebaseWebAppPrepareHosting(path, options, deployDir: deployDir);

  await shell
      .run('firebase --project $projectId deploy --only hosting:$target');
}

/// Configure hosting for target if needed
Future _firebaseWebAppPrepareHosting(String path, FirebaseDeployOptions options,
    {String? deployDir}) async {
  deployDir = _fixFolder(path, deployDir ?? firebaseDefaultHostingDir);

  var projectId = options.projectId;
  var target = options.target;
  var hostingId = options.hostingId;

  try {
    var firebaseRcMap = parseJsonObject(
        File(join(deployDir, '.firebaserc')).readAsStringSync())!;
    var existingHostingId = firebaseRcMap
        .getKeyPathValue(['targets', projectId, 'hosting', target, 0]);
    if (existingHostingId == hostingId) {
      // Hosting id matches
      return;
    }
  } catch (_) {}

  // Configure hosting for target
  var shell = Shell().pushd(deployDir);
  await shell.run('firebase --project $projectId target:clear hosting $target');
  await shell.run(
      'firebase --project $projectId target:apply hosting $target $hostingId');
}

/// Copy to deploy using deploy.yaml
Future<void> firebaseWebAppBuildToDeploy(String path,
    {String? deployDir, String folder = 'web'}) async {
  var buildFolder = join(path, 'build', folder);
  deployDir =
      join(_fixFolder(path, deployDir ?? firebaseDefaultHostingDir), 'public');

  var deployFile = File(join(buildFolder, 'deploy.yaml'));
  // ignore: avoid_slow_async_io
  if (!await deployFile.exists()) {
    throw StateError('Missing deploy.yaml file ($deployFile)');
  }
  await fsDeploy(
      options: FsDeployOptions()..noSymLink = true,
      yaml: deployFile,
      src: Directory(buildFolder),
      dst: Directory(deployDir));
}

@Deprecated('Typo error - Use firebaseWebAppBuildToDeploy')
var firebaseWepAppBuildToDeploy = firebaseWebAppBuildToDeploy;

/// Deploy from deploy/firebase/hosting
Future<void> firebaseWebAppServe(String path, FirebaseDeployOptions options,
    {String? deployDir, FirebaseWebAppActionController? controller}) async {
  deployDir = _fixFolder(path, deployDir ?? firebaseDefaultHostingDir);

  var projectId = options.projectId;

  var target = options.target;

  var shell = Shell().pushd(deployDir);
  controller?._shell = shell;
  await _firebaseWebAppPrepareHosting(path, options, deployDir: deployDir);
  await shell.run(
      'firebase emulators:start --project $projectId  --only hosting:$target');
}

class FirebaseWebAppActionController {
  Shell? _shell;

  void cancel() {
    _shell?.kill();
  }
}

extension FirebaseWebAppActionControllerPrvExt
    on FirebaseWebAppActionController {
  set shell(Shell shell) {
    _shell = shell;
  }
}
