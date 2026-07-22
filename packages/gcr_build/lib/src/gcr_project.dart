import 'package:dev_build/shell.dart';
import 'package:process_run/stdio.dart';
import 'package:tekartik_common_build/version_io.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_gcr_build/gcr.dart';
import 'package:tekartik_gcr_build/src/docker.dart';

var _debug = false; // devWarning(true);
void _log(Object? message) {
  if (_debug) {
    // ignore: avoid_print
    print(message);
  }
}

/// A Docker Compose project deployed to Google Cloud Run, described by
/// [options]. Operations live on [GcrProjectExt].
class GcrProject {
  /// Whether shell commands log their output.
  final bool verbose;

  /// Working directory containing the project's `docker-compose` file.
  final String path;

  /// Google Cloud project/service/image configuration.
  final GcrProjectOptions options;

  /// Creates a project rooted at [path] (defaults to the current
  /// directory), described by [options]. [verbose] defaults to `false`.
  GcrProject({this.path = '.', required this.options, bool? verbose})
    : verbose = verbose ?? false;
}

/// Build, run, and Google Cloud Run deploy operations available on a
/// [GcrProject].
extension GcrProjectExt on GcrProject {
  Shell get _shell =>
      Shell(workingDirectory: path, verbose: verbose, commandVerbose: true);

  /// Configures `docker` to authenticate against Artifact Registry for
  /// [GcrProjectOptions.region], via `gcloud auth configure-docker`. Needed
  /// once per region after `gcloud auth login`.
  Future<void> configureDockerAuth() async {
    await _shell.run('''
    gcloud auth configure-docker ${options.region}-docker.pkg.dev
    ''');
  }

  /// Tags the local [GcrProjectOptions.image] with its full Artifact
  /// Registry path, in preparation for [dockerPush].
  Future<void> dockerTagImage() async {
    await _shell.run('''
  docker tag ${options.image} \\
${options.region}-docker.pkg.dev/${options.projectId}/${options.name}/${options.image}
  ''');
  }

  /// Kills any running containers ([kill]), then rebuilds and runs the
  /// project via `docker compose up --build --pull never`.
  Future<void> buildAndRun() async {
    try {
      await kill();
    } catch (_) {}
    if (_debug) {
      _log('Before running');
    }
    try {
      await _shell.cloneWithOptions(_shell.options.clone(verbose: true)).run('''
    docker compose up --build --pull never
    ''');
      if (_debug) {
        _log('After running');
      }
    } finally {
      if (_debug) {
        _log('Finally running');
      }
    }
  }

  /// Builds the project's Docker image via `docker compose build`, without
  /// running it.
  Future<void> build() async {
    await _shell.run('''
    docker compose build
    ''');
  }

  /// Runs the full pipeline: generates the version file, builds and tags
  /// the image, configures Docker auth, creates the Artifact Registry
  /// repository if needed (in parallel with the build/tag steps), then
  /// pushes ([dockerPush]) and deploys ([deploy]) the image.
  Future<void> buildAndDeploy() async {
    var futures = [
      shellStdioLinesGrouper.runZoned(() async {
        await generateVersion();
        await build();
        await dockerTagImage();
      }),
      shellStdioLinesGrouper.runZoned(() async {
        await configureDockerAuth();
        await createArtifactRepository();
      }),
    ];
    await Future.wait(futures);
    await dockerPush();
    await deploy();
  }

  /// Lists all Artifact Registry repositories in
  /// [GcrProjectOptions.projectId], via `gcloud artifacts repositories list`.
  Future<List<GcrArtifactRepository>> listArtifactRepositories() async {
    var result = await _shell.run('''
    gcloud artifacts repositories list --project=${options.projectId} --format json
    ''');
    var text = result.outText;
    var list = jsonDecode(text.trim()) as List;
    return list
        .map((item) => GcrArtifactRepository.fromJson(item as Map))
        .toList();
  }

  /// Creates the Artifact Registry repository named
  /// [GcrProjectOptions.name] (with [GcrProjectOptions.description] if
  /// set).
  ///
  /// If [force] is `false` (the default), first checks (via
  /// [listArtifactRepositories]) whether a repository with that name
  /// already exists and, if so, does nothing instead of creating it. If
  /// [force] is `true`, that check is skipped and creation is always
  /// attempted.
  Future<void> createArtifactRepository({bool? force}) async {
    force ??= false;
    if (!force) {
      var list = await listArtifactRepositories();
      if (list.map((e) => e.repository).contains(options.name)) {
        stdout.writeln('Artifact repository "${options.name}" already exists');
        return;
      }
    }
    await _shell.run('''
    gcloud artifacts repositories create ${options.name} --repository-format=docker \\
      --location=${options.region} \\
      ${options.description == null ? '' : '--description ${shellArgument(options.description!)}'} \\
      --project=${options.projectId}
    ''');
  }

  /// Kills the project's running containers via `docker compose kill`, if
  /// any are running.
  Future<void> kill() async {
    var processIds = await dockerComposeGetRunningProcessIds();
    if (processIds.isNotEmpty) {
      await _shell.run('''
    docker compose kill
    ''');
    }
  }

  String get _dockerImage =>
      '${options.region}-docker.pkg.dev/${options.projectId}/${options.name}/${options.image}';

  /// Pushes the tagged image (see [dockerTagImage]) to Artifact Registry
  /// via `docker push`.
  Future<void> dockerPush() async {
    await _shell.run('''
  docker push ${shellArgument(_dockerImage)}
  ''');
  }

  /// Deploys the image to Cloud Run as [GcrProjectOptions.serviceName],
  /// allowing unauthenticated access, via `gcloud run deploy`.
  ///
  /// The image must already have been pushed (see [dockerPush]).
  Future<void> deploy() async {
    await _shell.cloneWithOptions(_shell.options.clone(verbose: true)).run('''
        gcloud run deploy ${options.serviceName} \\
        --region ${options.region} \\
        --project ${options.projectId} \\
        --image ${shellArgument(_dockerImage)} \\
        ${options.memory == null ? '' : '--memory ${options.memory}'} \\
        --allow-unauthenticated
        ''');
  }
}
