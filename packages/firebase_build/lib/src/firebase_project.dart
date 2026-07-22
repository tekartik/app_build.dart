import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_common_build/common_app_builder.dart';

/// Lets callers cancel an in-progress [FirebaseProjectBuilder] action
/// (deploy, serve, etc).
class FirebaseProjectActionController {
  Shell? _shell;

  /// Kills the underlying `firebase` shell command, aborting the action it
  /// was passed to.
  void cancel() {
    _shell?.kill();
  }
}

/// Private extension to set the shell
extension FirebaseProjectActionControllerPrvExt
    on FirebaseProjectActionController {
  /// Set the shell
  set shell(Shell shell) {
    _shell = shell;
  }
}

/// Identifies a Firebase project and its default deploy functions, used by
/// [FirebaseProjectBuilder].
class FirebaseProjectOptions {
  /// Firebase project ID (used with `firebase --project`).
  final String projectId;

  /// Absolute, normalized working directory containing `firebase.json`.
  late final String path;

  /// Default function names to deploy when
  /// [FirebaseProjectBuilder.deployFunctions] is called without its own
  /// `functions` argument, e.g. `['commanddartv2dev',
  /// 'callcommanddartv2dev']`. If `null`/empty, all functions are
  /// deployed.
  final List<String>? functions;

  /// Creates options for [projectId], rooted at [path] (defaults to the
  /// current directory), with [functions] as the default deploy target
  /// list (defaults to `null`, meaning all functions).
  FirebaseProjectOptions({
    required this.projectId,
    String? path,
    this.functions,
  }) {
    this.path = normalize(absolute(path ?? '.'));
  }

  /// Returns a copy of these options, overriding [projectId], [path]
  /// and/or [functions] while keeping the rest unchanged.
  FirebaseProjectOptions copyWith({
    String? projectId,
    String? path,
    List<String>? functions,
  }) {
    return FirebaseProjectOptions(
      projectId: projectId ?? this.projectId,
      path: path ?? this.path,
      functions: functions ?? this.functions,
    );
  }
}

/// Runs `firebase` CLI deploy/serve commands for the project described by
/// [options].
class FirebaseProjectBuilder implements CommonAppBuilder {
  /// The project this builder targets.
  final FirebaseProjectOptions options;

  @override
  String get path => options.path;

  /// Creates a builder for the project described by [options].
  FirebaseProjectBuilder({required this.options});

  /// Deploys Firestore security rules via
  /// `firebase deploy --only firestore:rules`. If [controller] is given,
  /// it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deployFirestoreRules({
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run(
      'firebase deploy --only firestore:rules --project ${options.projectId}',
    );
  }

  /// Deploys Firestore indexes via
  /// `firebase deploy --only firestore:indexes`. If [controller] is given,
  /// it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deployFirestoreIndexes({
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run(
      'firebase deploy --only firestore:indexes --project ${options.projectId}',
    );
  }

  /// Deploys Storage security rules via `firebase deploy --only storage`.
  /// If [controller] is given, it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deployStorageRules({
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run(
      'firebase deploy --only storage --project ${options.projectId}',
    );
  }

  /// Deploys Cloud Functions via `firebase deploy --only functions[:name,...]`.
  ///
  /// [functions] overrides [FirebaseProjectOptions.functions] as the list
  /// of function names to deploy; if both are `null`/empty, all functions
  /// are deployed. If [controller] is given, it's wired to the underlying
  /// shell so [FirebaseProjectActionController.cancel] can abort the
  /// deploy.
  Future<void> deployFunctions({
    List<String>? functions,
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    var targetFunctions = functions ?? options.functions;
    var onlyArg = '';
    if (targetFunctions != null && targetFunctions.isNotEmpty) {
      var targets = targetFunctions
          .map((f) => f.startsWith('functions:') ? f : 'functions:$f')
          .join(',');
      onlyArg = ' --only $targets';
    } else {
      onlyArg = ' --only functions';
    }
    await shell.run('firebase deploy$onlyArg --project ${options.projectId}');
  }

  /// Deploys via `firebase deploy --only [only]`, where [only] is a raw
  /// comma-separated target list (e.g. `'hosting,firestore:rules'`). If
  /// [controller] is given, it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deployOnly(
    String only, {
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run(
      'firebase deploy --only $only --project ${options.projectId}',
    );
  }

  /// Deploys every configured target via a plain `firebase deploy`. If
  /// [controller] is given, it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deploy({FirebaseProjectActionController? controller}) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run('firebase deploy --project ${options.projectId}');
  }

  /// Starts the Firebase emulators via `firebase emulators:start`.
  ///
  /// [only], if given, is passed through as a raw `--only` target list
  /// (e.g. `'hosting,firestore'`); otherwise all configured emulators are
  /// started. If [controller] is given, it's wired to the underlying
  /// shell so [FirebaseProjectActionController.cancel] can stop it.
  Future<void> serve({
    String? only,
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    var onlyArg = only != null ? ' --only $only' : '';
    await shell.run(
      'firebase emulators:start --project ${options.projectId}$onlyArg',
    );
  }
}
