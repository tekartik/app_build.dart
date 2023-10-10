import 'package:path/path.dart';
// ignore: depend_on_referenced_packages
// ignore: depend_on_referenced_packages
import 'package:tekartik_firebase_build/app_build.dart';
import 'package:tekartik_firebase_build/firebase_deploy.dart';
import 'package:tekartik_test_menu_io/test_menu_io.dart';

void menuFirebaseWebAppBuilderContent(
    {required FlutterFirebaseWebAppBuilder builder}) {
  var path = builder.options.path;

  enter(() async {
    write('App path: ${absolute(path)}');
    write('Target: ${builder.options.deployOptions.target}');
    write('ProjectId: ${builder.options.deployOptions.projectId}');
    write('Hosting: ${builder.options.deployOptions.hostingId}');
  });
  var serveController = FirebaseWebAppActionController();

  void cancel() {
    serveController.cancel();
  }

  item('cancel build/serve/deploy', () async {
    cancel();
  });

  item('build', () async {
    cancel();
    await builder.build(controller: serveController);
  });

  item('serve', () async {
    cancel();
    await builder.serve(controller: serveController);
  });

  item('build and deploy', () async {
    cancel();
    await builder.buildAndDeploy(controller: serveController);
  });
  item('build and serve', () async {
    cancel();
    await builder.buildAndServe(controller: serveController);
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
}
