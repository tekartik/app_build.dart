// ignore_for_file: avoid_print

import 'dart:io';

import 'package:tekartik_gcr_build/gcr.dart';

/// The deploy steps of a docker compose project one by one, from its
/// `tool/` script: `dart run tool/gcr.dart run|kill|push|deploy|list`.
Future<void> main(List<String> args) async {
  var project = GcrProject(
    path: 'server', // where docker-compose.yaml is
    options: GcrProjectOptions(
      projectId: 'my-gcp-project',
      region: gcrRegionBelgium,
      name: 'my-server-repo',
      image: 'my_server',
      serviceName: 'my-server',
      memory: '1G',
    ),
  );
  switch (args.firstOrNull) {
    case 'run':
      // Kills the running containers of the project, then builds and runs
      // it locally; blocks until the containers stop.
      await project.buildAndRun();
    case 'kill':
      await project.kill();
    case 'push':
      await project.build();
      await project.dockerTagImage();
      await project.configureDockerAuth();
      await project.createArtifactRepository();
      await project.dockerPush();
    case 'deploy':
      // The last pushed image.
      await project.deploy();
    case 'list':
      for (var repository in await project.listArtifactRepositories()) {
        print('${repository.repository} (${repository.region})');
      }
    default:
      print('usage: run|kill|push|deploy|list');
      exitCode = 64;
  }
}
