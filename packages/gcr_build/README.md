# tekartik_gcr_build

Build a docker compose project, push its image to Google Artifact Registry and
deploy it to Google Cloud Run, from a Dart `tool/` script. It chains the
`docker`, `docker compose` and `gcloud` command lines (process_run `Shell`),
so it runs on the Dart VM only (Linux, macOS, Windows), never in an app.

## Getting started

A git dependency (not on pub.dev), usually a dev dependency of the server
package whose `tool/` script deploys it:

```yaml
dev_dependencies:
  tekartik_gcr_build:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/gcr_build
```

The machine needs `docker` with the compose plugin, and the `gcloud` cli
logged in (`gcloud auth login`) on an account allowed to push to Artifact
Registry and to deploy Cloud Run in the project (both APIs enabled).

```dart
// tool/deploy.dart, run from the server package: dart run tool/deploy.dart
import 'package:tekartik_gcr_build/gcr.dart';

Future<void> main() async {
  var project = GcrProject(
    // The folder holding docker-compose.yaml (and its Dockerfile).
    path: '.',
    options: GcrProjectOptions(
      projectId: 'my-gcp-project',
      region: gcrRegionBelgium, // europe-west1
      name: 'my-server-repo', // the Artifact Registry repository
      image: 'my_server', // the `image:` of the docker-compose.yaml service
      serviceName: 'my-server', // the Cloud Run service
    ),
    verbose: true,
  );
  await project.buildAndDeploy();
}
```

`buildAndDeploy()` builds the image (`docker compose build`), tags it as
`<region>-docker.pkg.dev/<projectId>/<name>/<image>`, configures the docker
authentication, creates the repository when missing, pushes the image and
runs `gcloud run deploy`. See [example/main.dart](example/main.dart) for the
steps one by one.

## What to use

| Call | Runs |
| --- | --- |
| `buildAndDeploy()` | the whole pipeline below |
| `build()` | `docker compose build` |
| `buildAndRun()` | `kill()` then `docker compose up --build --pull never` (blocks while the service runs) |
| `kill()` | `docker compose kill` when `docker compose ps -q` lists something |
| `dockerTagImage()`, `dockerPush()` | `docker tag` / `docker push` of the Artifact Registry image |
| `configureDockerAuth()` | `gcloud auth configure-docker <region>-docker.pkg.dev`, once per region |
| `createArtifactRepository(force:)` | `gcloud artifacts repositories create`, skipped when it exists |
| `listArtifactRepositories()` | the repositories of the project, as `GcrArtifactRepository` |
| `deploy()` | `gcloud run deploy <serviceName> --image ... --allow-unauthenticated` |
| `dockerKillAll()` | `docker kill` of **every** running container of the machine |

Every project command runs in `path`. A failing command throws a
`ShellException` (process_run).

## Pitfalls

* `deploy()` passes `--allow-unauthenticated`: the service is public.
  Restrict it with IAM afterwards if it must not be.
* `image` must be the image name the compose file builds, or the tag and the
  push find nothing.
* The container must listen on the `PORT` Cloud Run injects (8080 by
  default).
* `buildAndDeploy()` refreshes the generated `lib/src/version.dart` of the
  dart package at `path` (the one built into the image) from its
  `pubspec.yaml`, through `generateVersion` of `tekartik_common_build`: a
  missing or hand-written file is left alone, and nothing is generated when
  `path` is not a dart package.
* `dockerKillAll()` is not the project's `kill()`: it stops every container
  of the machine.
