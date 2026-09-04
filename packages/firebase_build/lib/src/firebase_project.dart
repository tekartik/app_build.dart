import 'package:path/path.dart';
import 'package:tekartik_common_build/common_app_builder.dart';
import 'package:tekartik_firebase_tools_common/firebase_project.dart' as tools;

/// Runs `firebase` CLI deploy/serve commands for the project described by
/// [tools.FirebaseProjectBuilder.options].
///
/// The implementation lives in `tekartik_firebase_tools_common`; this subclass
/// only adds [CommonAppBuilder], so the version-generation helpers of
/// `CommonAppBuilderExt` (`generateVersion`, `generateVersionIfNeeded`) apply
/// to a firebase project like they do to every other builder of `app_build`.
class FirebaseProjectBuilder extends tools.FirebaseProjectBuilder
    implements CommonAppBuilder {
  /// Creates a builder for the project described by [options].
  FirebaseProjectBuilder({required super.options});
}

/// The firestore folder of an app (`deploy/firebase/firestore` by default),
/// holding the rules and indexes `firebase deploy --only firestore` sends.
extension FirebaseProjectBuilderExt on FirebaseProjectBuilder {
  /// Default firestore folder of an app, relative to its root:
  /// `deploy/firebase/firestore`, next to the hosting one
  /// (`firebaseDefaultHostingDir`).
  ///
  /// It holds a `firebase.json` naming the rules and indexes files
  /// (`firestore.rules`, `firestore.indexes.json`), and nothing else: an app
  /// with no backend deploys its whole security model from there.
  static final defaultFirestoreDir = join('deploy', 'firebase', 'firestore');

  /// The builder of the firestore folder of the app at [path] (the current
  /// directory by default), deploying to [projectId].
  ///
  /// [firestoreDir] is the folder holding the firestore `firebase.json`,
  /// relative to [path] unless absolute, [defaultFirestoreDir] by default.
  /// The builder deploys (`deployFirestore`, `deployFirestoreRules`,
  /// `deployFirestoreIndexes`) and serves (`serve`) from there:
  ///
  /// ```dart
  /// await FirebaseProjectBuilderExt.firestoreFolder(
  ///   projectId: 'my-project-dev',
  /// ).deployFirestore();
  /// ```
  static FirebaseProjectBuilder firestoreFolder({
    required String projectId,
    String? path,
    String? firestoreDir,
  }) {
    var appPath = normalize(absolute(path ?? '.'));
    firestoreDir ??= defaultFirestoreDir;
    return FirebaseProjectBuilder(
      options: tools.FirebaseProjectOptions(
        projectId: projectId,
        path: isAbsolute(firestoreDir)
            ? firestoreDir
            : join(appPath, firestoreDir),
      ),
    );
  }
}
