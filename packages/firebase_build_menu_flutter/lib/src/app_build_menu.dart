import 'package:dev_build/menu/menu.dart';
import 'package:path/path.dart';
// ignore: depend_on_referenced_packages
// ignore: depend_on_referenced_packages
import 'package:tekartik_firebase_build/app_build.dart';
import 'package:tekartik_firebase_build/firebase_deploy.dart';

void menuFirebaseWebAppBuilderContent(
    {required FlutterFirebaseWebAppBuilder builder}) {
  var path = builder.options.path;

  enter(() async {
    write('App path: ${absolute(path)}');
    write('Target: ${builder.options.deployOptions.target}');
    write('ProjectId: ${builder.options.deployOptions.projectId}');
    write('Hosting: ${builder.options.deployOptions.hostingId}');
  });
  var actionController = FirebaseWebAppActionController();

  void cancel() {
    actionController.cancel();
  }

  item('cancel build/serve/deploy', () async {
    cancel();
  });

  item('build and deploy', () async {
    cancel();
    await builder.buildAndDeploy(controller: actionController);
  });

  item('build', () async {
    cancel();
    await builder.build(controller: actionController);
  });

  item('serve', () async {
    cancel();
    await builder.serve(controller: actionController);
  });
  item('deploy', () async {
    cancel();
    await builder.deploy(controller: actionController);
  });

  item('build and serve', () async {
    cancel();
    await builder.buildAndServe(controller: actionController);
  });
  item('clean', () async {
    cancel();
    await builder.clean();
  });
}

void menuFirebaseAppContent(
    {required List<FlutterFirebaseWebAppBuilder> builders}) {
  for (var builder in builders) {
    menu('target ${builder.target}', () {
      menuFirebaseWebAppBuilderContent(builder: builder);
    });
  }
  menu('all', () {
    var actionController = FirebaseWebAppActionController();

    void cancel() {
      actionController.cancel();
    }

    item('build', () async {
      cancel();
      for (var builder in builders) {
        await builder.build(controller: actionController);
      }
    });

    item('build and deploy', () async {
      cancel();
      for (var builder in builders) {
        await builder.buildAndDeploy(controller: actionController);
      }
    });
    item('deploy', () async {
      cancel();
      for (var builder in builders) {
        await builder.deploy(controller: actionController);
      }
    });

    item('clean', () async {
      cancel();
      for (var builder in builders) {
        await builder.clean();
      }
    });
  });
}
