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

  /// The functions source folder relative to [path], i.e. the `source` of
  /// the `functions` entry of `firebase.json`.
  ///
  /// Only used to compile dart cloud functions, see
  /// [FirebaseProjectBuilder.compileFunctions].
  final String functionsSource;

  /// The dart entry point compiled to an executable, relative to
  /// [functionsSource].
  final String functionsEntryPoint;

  /// `--target-os` of `dart compile exe`, the os the firebase dart runtime
  /// runs the compiled functions on.
  final String functionsTargetOs;

  /// `--target-arch` of `dart compile exe`.
  final String functionsTargetArch;

  /// Creates options for [projectId], rooted at [path] (defaults to the
  /// current directory), with [functions] as the default deploy target
  /// list (defaults to `null`, meaning all functions).
  ///
  /// The `functions*` defaults match the `*_dartff` layout used across the
  /// projects: a `functions` folder with a `bin/server.dart` entry point,
  /// compiled for linux x64.
  FirebaseProjectOptions({
    required this.projectId,
    String? path,
    this.functions,
    this.functionsSource = 'functions',
    this.functionsEntryPoint = 'bin/server.dart',
    this.functionsTargetOs = 'linux',
    this.functionsTargetArch = 'x64',
  }) {
    this.path = normalize(absolute(path ?? '.'));
  }

  /// Absolute path of the functions source folder.
  String get functionsSourcePath => normalize(join(path, functionsSource));

  /// Returns a copy of these options, overriding the given fields while
  /// keeping the rest unchanged.
  FirebaseProjectOptions copyWith({
    String? projectId,
    String? path,
    List<String>? functions,
    String? functionsSource,
    String? functionsEntryPoint,
    String? functionsTargetOs,
    String? functionsTargetArch,
  }) {
    return FirebaseProjectOptions(
      projectId: projectId ?? this.projectId,
      path: path ?? this.path,
      functions: functions ?? this.functions,
      functionsSource: functionsSource ?? this.functionsSource,
      functionsEntryPoint: functionsEntryPoint ?? this.functionsEntryPoint,
      functionsTargetOs: functionsTargetOs ?? this.functionsTargetOs,
      functionsTargetArch: functionsTargetArch ?? this.functionsTargetArch,
    );
  }
}

/// The `--only` filter deploying [functions] needs.
///
/// `functions` when [functions] is null or empty (every function of the
/// project), `functions:a,functions:b` otherwise. A name already prefixed with
/// `functions:` is left alone.
String firebaseFunctionsDeployOnly(List<String>? functions) {
  if (functions == null || functions.isEmpty) {
    return 'functions';
  }
  return functions
      .map((name) => name.startsWith('functions:') ? name : 'functions:$name')
      .join(',');
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

  /// Runs `firebase deploy` in [path], restricted to [only] when given.
  Future<void> _deploy(
    String? only,
    FirebaseProjectActionController? controller,
  ) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    var onlyArg = only == null ? '' : ' --only $only';
    await shell.run('firebase deploy$onlyArg --project ${options.projectId}');
  }

  /// Deploys Firestore security rules via
  /// `firebase deploy --only firestore:rules`. If [controller] is given,
  /// it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deployFirestoreRules({
    FirebaseProjectActionController? controller,
  }) => _deploy('firestore:rules', controller);

  /// Deploys Firestore indexes via
  /// `firebase deploy --only firestore:indexes`. If [controller] is given,
  /// it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deployFirestoreIndexes({
    FirebaseProjectActionController? controller,
  }) => _deploy('firestore:indexes', controller);

  /// Deploys the Firestore rules and indexes at once via
  /// `firebase deploy --only firestore`.
  Future<void> deployFirestore({FirebaseProjectActionController? controller}) =>
      _deploy('firestore', controller);

  /// Deploys Storage security rules via `firebase deploy --only storage`.
  /// If [controller] is given, it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deployStorageRules({
    FirebaseProjectActionController? controller,
  }) => _deploy('storage', controller);

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
  }) => _deploy(
    firebaseFunctionsDeployOnly(functions ?? options.functions),
    controller,
  );

  /// Compiles the dart cloud functions server to an executable, i.e.
  /// `dart compile exe <functionsEntryPoint>` in the functions source folder,
  /// for the os/arch the firebase dart runtime expects.
  ///
  /// See [FirebaseProjectOptions.functionsSource] and friends for what is
  /// compiled and how.
  Future<void> compileFunctions() async {
    var shell = Shell(workingDirectory: options.functionsSourcePath);
    await shell.run(
      'dart compile exe ${options.functionsEntryPoint}'
      ' --target-os=${options.functionsTargetOs}'
      ' --target-arch=${options.functionsTargetArch}',
    );
  }

  /// Runs [compileFunctions] followed by [deployFunctions].
  Future<void> compileAndDeployFunctions({
    List<String>? functions,
    FirebaseProjectActionController? controller,
  }) async {
    await compileFunctions();
    await deployFunctions(functions: functions, controller: controller);
  }

  /// Deploys via `firebase deploy --only [only]`, where [only] is a raw
  /// comma-separated target list (e.g. `'hosting,firestore:rules'`). If
  /// [controller] is given, it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deployOnly(
    String only, {
    FirebaseProjectActionController? controller,
  }) => _deploy(only, controller);

  /// Deploys every configured target via a plain `firebase deploy`. If
  /// [controller] is given, it's wired to the underlying shell so
  /// [FirebaseProjectActionController.cancel] can abort the deploy.
  Future<void> deploy({FirebaseProjectActionController? controller}) =>
      _deploy(null, controller);

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
