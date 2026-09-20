---
name: tekartik-gcr-build-deploy
description: >-
  Use when a Dart tool/ script must build a docker compose project, push its
  image to Google Artifact Registry and deploy it to Google Cloud Run with
  package:tekartik_gcr_build: GcrProjectOptions (projectId, region,
  gcrRegionBelgium, name, image, serviceName, memory), GcrProject and
  GcrProjectExt (buildAndDeploy, build, buildAndRun, kill, dockerTagImage,
  dockerPush, deploy, configureDockerAuth, createArtifactRepository,
  listArtifactRepositories), GcrArtifactRepository and dockerKillAll.
---

# tekartik_gcr_build: docker compose to Cloud Run

`package:tekartik_gcr_build/gcr.dart` chains the `docker`, `docker compose`
and `gcloud` commands that take a service from a local `docker-compose.yaml`
to a running Cloud Run service: build the image, tag it for Artifact
Registry, create the repository, push, `gcloud run deploy`. It is an
experiment kept small: one options class, one project class with an
extension of shell wrappers. Dart VM only.

## Guidelines

* Dependency (git, not on pub.dev), usually a dev dependency of the server
  package whose `tool/` script deploys it:
  ```yaml
  dev_dependencies:
    tekartik_gcr_build:
      git:
        url: https://github.com/tekartik/app_build.dart
        path: packages/gcr_build
  ```
* Import `package:tekartik_gcr_build/gcr.dart`: `GcrProject`,
  `GcrProjectExt`, `GcrProjectOptions`, `gcrRegionBelgium`,
  `GcrArtifactRepository`, `dockerKillAll`.
* Prerequisites on the machine: `docker` with the compose plugin, the
  `gcloud` cli logged in (`gcloud auth login`) on an account allowed to push
  to Artifact Registry and deploy Cloud Run in the project, and the Artifact
  Registry and Cloud Run APIs enabled on the project. Commands are printed
  before running (`commandVerbose: true`); pass `verbose: true` to
  `GcrProject` to also see their output.
* `GcrProjectOptions(projectId:, region:, name:, image:, serviceName:,
  description:, memory:)`:
  * `projectId`: the Google Cloud project id.
  * `region`: a Cloud Run region; `gcrRegionBelgium` is `'europe-west1'`.
  * `name`: the Artifact Registry repository (lowercase letters, digits and
    hyphens, starting and ending with a letter).
  * `image`: the image name of the `docker-compose.yaml` service
    (`image: my_image`), what `docker compose build` produces and what gets
    tagged as `<region>-docker.pkg.dev/<projectId>/<name>/<image>`.
  * `serviceName`: the Cloud Run service (lowercase alphanumerics and
    dashes, 63 chars max), part of the service url.
  * `memory`: `'512MB'` (default when null), `'1G'`, `'2G'`, `'4G'`, `'8G'`,
    `'16G'`; `description` is the repository description.
* `GcrProject(path:, options:, verbose:)`: `path` (default `'.'`) is the
  folder holding `docker-compose.yaml` and the `Dockerfile`; every shell
  command runs there.
* Pipeline: `buildAndDeploy()` runs, in parallel, `generateVersion` (the
  `lib/src/version.dart` of the package in the current directory, from
  `tekartik_common_build`, only when the file already exists) then `build()`
  and `dockerTagImage()`, and `configureDockerAuth()` then
  `createArtifactRepository()`; then `dockerPush()` and `deploy()`. Run the
  script from the package root so the version file is the right one.
* Steps, callable alone: `build()` (`docker compose build`),
  `buildAndRun()` (`kill()` then `docker compose up --build --pull never`,
  blocks while the service runs), `kill()` (`docker compose kill` when
  `docker compose ps -q` lists something), `dockerTagImage()`,
  `configureDockerAuth()` (`gcloud auth configure-docker
  <region>-docker.pkg.dev`, once per region), `createArtifactRepository(force:)`
  (skips when `listArtifactRepositories()` already contains `name`, unless
  `force: true`), `dockerPush()`, `deploy()` (`gcloud run deploy
  <serviceName> --image ... --allow-unauthenticated`, so the service is
  public; restrict it with IAM afterwards if needed).
* `listArtifactRepositories()` parses `gcloud artifacts repositories list
  --format json` into `GcrArtifactRepository` objects: `name` is the full
  resource name, `project`, `region` and `repository` are parsed from it;
  `GcrArtifactRepository.fromJson(map)` is the only constructor (pure Dart,
  unit testable).
* `dockerKillAll()` kills every running container on the machine (`docker
  ps -q`), not only the project's; use `project.kill()` for the project.
* Errors surface as `ShellException` from `process_run` (non-zero exit of a
  command); `buildAndRun` swallows the error of its initial `kill()` only.
* The `docker-compose.yaml` should build a single service listening on the
  `PORT` Cloud Run injects (8080 by default) and its image name must match
  `options.image`; a Dart server `Dockerfile` usually runs `dart compile exe
  bin/server.dart` on a `dart:stable` stage copied into a small runtime
  image.

## Examples

### Deploy script

```dart
// tool/deploy.dart — from the server package root: dart run tool/deploy.dart
import 'package:tekartik_gcr_build/gcr.dart';

final options = GcrProjectOptions(
  projectId: 'my-gcp-project',
  region: gcrRegionBelgium,
  name: 'my-server-repo',
  image: 'my_server',
  serviceName: 'my-server',
  description: 'My server docker images',
  memory: '1G',
);

Future<void> main() async {
  var project = GcrProject(options: options, verbose: true);
  await project.buildAndDeploy();
}
```

### Run locally, then the steps by hand

```dart
import 'package:tekartik_gcr_build/gcr.dart';

Future<void> main(List<String> args) async {
  var project = GcrProject(
    path: 'server', // where docker-compose.yaml is
    options: GcrProjectOptions(
      projectId: 'my-gcp-project',
      region: gcrRegionBelgium,
      name: 'my-server-repo',
      image: 'my_server',
      serviceName: 'my-server',
    ),
  );
  switch (args.firstOrNull) {
    case 'run':
      await project.buildAndRun(); // blocks until the container stops
    case 'kill':
      await project.kill();
    case 'push':
      await project.build();
      await project.dockerTagImage();
      await project.configureDockerAuth();
      await project.createArtifactRepository();
      await project.dockerPush();
    case 'deploy':
      await project.deploy(); // uses the last pushed image
    default:
      print('usage: run|kill|push|deploy');
  }
}
```

### Dev menu

```dart
import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_gcr_build/gcr.dart';

Future<void> main(List<String> arguments) async {
  var project = GcrProject(
    options: GcrProjectOptions(
      projectId: 'my-gcp-project',
      region: gcrRegionBelgium,
      name: 'my-server-repo',
      image: 'my_server',
      serviceName: 'my-server',
    ),
  );
  mainMenuConsole(arguments, () {
    item('build and run locally', () => project.buildAndRun());
    item('kill', () => project.kill());
    item('build and deploy', () => project.buildAndDeploy());
    item('list artifact repositories', () async {
      for (var repo in await project.listArtifactRepositories()) {
        print('${repo.repository} (${repo.region})');
      }
    });
    item('kill all docker containers', () => dockerKillAll());
  });
}
```

### Unit test of the repository parsing

```dart
import 'package:tekartik_gcr_build/gcr.dart';
import 'package:test/test.dart';

void main() {
  test('GcrArtifactRepository.fromJson', () {
    var repo = GcrArtifactRepository.fromJson({
      'name': 'projects/my_project/locations/my_region/repositories/my_repo',
      'format': 'DOCKER',
    });
    expect(repo.project, 'my_project');
    expect(repo.region, 'my_region');
    expect(repo.repository, 'my_repo');
  });
}
```
