import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_common_build/common_app_builder.dart';

/// Action controller for firebase project commands.
class FirebaseProjectActionController {
  Shell? _shell;

  /// Cancel the action
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

/// Firebase project options
class FirebaseProjectOptions {
  /// Firebase project ID
  final String projectId;

  /// Project path (working directory containing firebase.json)
  late final String path;

  /// Functions to deploy, e.g. ['commanddartv2dev', 'callcommanddartv2dev']
  final List<String>? functions;

  /// Constructor
  FirebaseProjectOptions({
    required this.projectId,
    String? path,
    this.functions,
  }) {
    this.path = normalize(absolute(path ?? '.'));
  }

  /// Copy with
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

/// Firebase project builder helper.
class FirebaseProjectBuilder implements CommonAppBuilder {
  /// Project options
  final FirebaseProjectOptions options;

  @override
  String get path => options.path;

  /// Constructor
  FirebaseProjectBuilder({required this.options});

  /// Deploy firestore rules
  Future<void> deployFirestoreRules({
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run(
      'firebase deploy --only firestore:rules --project ${options.projectId}',
    );
  }

  /// Deploy firestore indexes
  Future<void> deployFirestoreIndexes({
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run(
      'firebase deploy --only firestore:indexes --project ${options.projectId}',
    );
  }

  /// Deploy storage rules
  Future<void> deployStorageRules({
    FirebaseProjectActionController? controller,
  }) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run(
      'firebase deploy --only storage --project ${options.projectId}',
    );
  }

  /// Deploy functions
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

  /// Deploy only specified targets.
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

  /// Deploy everything
  Future<void> deploy({FirebaseProjectActionController? controller}) async {
    var shell = Shell(workingDirectory: path);
    controller?.shell = shell;
    await shell.run('firebase deploy --project ${options.projectId}');
  }

  /// Start emulators
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
