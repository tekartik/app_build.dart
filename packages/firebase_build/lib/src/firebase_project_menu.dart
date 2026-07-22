import 'package:dev_build/menu/menu.dart';
import 'package:path/path.dart';
import 'firebase_project.dart';

/// Registers dev-menu items to serve emulators, deploy functions,
/// Firestore rules/indexes, or everything, for the given [builder], plus a
/// `'cancel action'` item to abort whichever action is running.
void menuFirebaseProjectBuilderContent({
  required FirebaseProjectBuilder builder,
}) {
  var path = builder.options.path;
  var projectId = builder.options.projectId;
  var actionController = FirebaseProjectActionController();

  enter(() async {
    write('Firebase project path: ${absolute(path)}');

    write('ProjectId: $projectId');
    var functions = builder.options.functions;
    if (functions != null) {
      write('Functions: ${functions.join(', ')}');
    }
  });

  void cancel() {
    actionController.cancel();
  }

  item('cancel action', () async {
    cancel();
  });

  item('serve emulators', () async {
    cancel();
    await builder.serve(controller: actionController);
  });

  item('deploy functions', () async {
    cancel();
    await builder.deployFunctions(controller: actionController);
  });

  item('deploy firestore rules', () async {
    cancel();
    await builder.deployFirestoreRules(controller: actionController);
  });

  item('deploy firestore indexes', () async {
    cancel();
    await builder.deployFirestoreIndexes(controller: actionController);
  });

  item('deploy all', () async {
    cancel();
    await builder.deploy(controller: actionController);
  });
}

/// Registers dev-menu items for each project in [builders] (see
/// [menuFirebaseProjectBuilderContent]).
///
/// If [builders] has 2 or more entries, each gets its own submenu named
/// after its project ID; with exactly one entry, its items are added
/// directly (no submenu); with none, nothing is added.
void menuFirebaseProjectContent({
  required List<FirebaseProjectBuilder> builders,
}) {
  if (builders.length >= 2) {
    for (var builder in builders) {
      menu('project ${builder.options.projectId}', () {
        menuFirebaseProjectBuilderContent(builder: builder);
      });
    }
  } else if (builders.isNotEmpty) {
    menuFirebaseProjectBuilderContent(builder: builders.first);
  }
}
