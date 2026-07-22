import 'dart:io';

import 'package:path/path.dart';
import 'package:tekartik_deploy/fs_deploy.dart';

String _fixFolder(String path, String folder) {
  if (isAbsolute(folder)) {
    return normalize(folder);
  }
  return normalize(absolute(join(path, folder)));
}

/// Copies the built web app from [buildDir] into [deployDir] (both
/// resolved against [path] if relative), following the copy rules
/// declared in `[buildDir]/deploy.yaml`.
///
/// Throws a [StateError] if that build folder has no `deploy.yaml`.
Future<void> webAppBuildToDeploy(
  String path, {
  required String deployDir,
  required String buildDir,
}) async {
  buildDir = _fixFolder(path, buildDir);
  deployDir = _fixFolder(path, deployDir);

  var deployFile = File(join(buildDir, 'deploy.yaml'));
  // ignore: avoid_slow_async_io
  if (!await deployFile.exists()) {
    throw StateError('Missing deploy.yaml file ($deployFile)');
  }
  await fsDeploy(
    options: FsDeployOptions()..noSymLink = true,
    yaml: deployFile,
    src: Directory(buildDir),
    dst: Directory(deployDir),
  );
}
