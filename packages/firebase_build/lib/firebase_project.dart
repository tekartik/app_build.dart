/// Driving the `firebase` cli for one firebase project folder.
///
/// The implementation lives in `tekartik_firebase_tools_common`, which
/// aggregates it with the emulator suite and the auth/firestore/storage
/// explorer; only [FirebaseProjectBuilder] is redeclared here, to also be a
/// `CommonAppBuilder`.
library;

export 'package:tekartik_firebase_tools_common/firebase_project.dart'
    show
        FirebaseProjectOptions,
        FirebaseProjectActionController,
        firebaseFunctionsDeployOnly,
        firebaseFolderProjectId,
        firebaseRcContentProjectId;

export 'src/firebase_project.dart' show FirebaseProjectBuilder;
