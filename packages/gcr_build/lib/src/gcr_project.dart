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

/// Google cloud project
class GcrProject {
  /// If verbose logging is done
  final bool verbose;

  /// Path to the project
  final String path;

  /// Options
  final GcrProjectOptions options;

  /// Constructor
  GcrProject({this.path = '.', required this.options, bool? verbose})
      : verbose = verbose ?? false;
}

/// Helpers
extension GcrProjectExt on GcrProject {
  Shell get _shell =>
      Shell(workingDirectory: path, verbose: verbose, commandVerbose: true);

  /// Configure docker auth, need after login once per region
  Future<void> configureDockerAuth() async {
    await _shell.run('''
    gcloud auth configure-docker ${options.region}-docker.pkg.dev
    ''');
  }

  /// Tag the image before pushing
  Future<void> dockerTagImage() async {
    await _shell.run('''
  docker tag ${options.image} \\
${options.region}-docker.pkg.dev/${options.projectId}/${options.name}/${options.image}
  ''');
  }

  /// Rebuild and run
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

  /// Rebuild and run
  Future<void> build() async {
    await _shell.run('''
    docker compose build
    ''');
  }

  /// Full build and deploy
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
      })
    ];
    await Future.wait(futures);
    await dockerPush();
    await deploy();
  }

  /// List existing artifact repositories
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

  /// Create artifact repository
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

  /// Terminate/kill
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

  /// Push the docker image
  Future<void> dockerPush() async {
    await _shell.run('''
  docker push ${shellArgument(_dockerImage)}
  ''');
  }

  /// Deploy the docker image (must be pushed first)
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
