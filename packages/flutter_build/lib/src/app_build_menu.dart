import 'package:dev_build/menu/menu.dart';
import 'package:dev_build/shell.dart';
import 'package:path/path.dart';
import 'package:tekartik_flutter_build/app_build.dart';

import 'controller.dart';

/// Single builder menu
void menuFlutterWebAppBuilderContent({required FlutterWebAppBuilder builder}) {
  //shellDebug = devWarning(true);
  var path = builder.options.path;
  var shell = Shell(workingDirectory: path);
  var buildController = BuildShellController(shell: shell);
  builder = builder.copyWith(controller: buildController);

  enter(() async {
    write('App path: ${absolute(path)}');
  });

  void cancel() {
    buildController.cancel();
  }

  item('cancel current build/server', () async {
    cancel();
  });

  if (builder.deployer != null) {
    item('build and deploy', () async {
      cancel();
      await builder.buildAndDeploy();
    });
  }

  item('build', () async {
    cancel();
    await builder.build();
  });

  item('run', () async {
    cancel();
    await builder.run();
  });

  item('serve', () async {
    cancel();
    await builder.serve();
  });
  if (builder.deployer != null) {
    item('deploy', () async {
      cancel();
      await builder.deploy();
    });
  }

  item('build and serve', () async {
    cancel();
    await builder.buildAndServe();
  });
  item('clean', () async {
    cancel();
    await builder.clean();
  });
  item('generateVersion', () async {
    await builder.generateVersion();
  });
}

/// Menu
void menuFlutterWebAppContent({required List<FlutterWebAppBuilder> builders}) {
  if (builders.length >= 2) {
    for (var builder in builders) {
      menu('target ${builder.target}', () {
        menuFlutterWebAppBuilderContent(builder: builder);
      });
    }

    menu('all', () {
      var actionController = BuildShellController();

      void cancel() {
        actionController.cancel();
      }

      item('build', () async {
        cancel();
        for (var builder in builders) {
          await builder.build();
        }
      });

      item('build and deploy', () async {
        cancel();
        for (var builder in builders) {
          await builder.buildAndDeploy();
        }
      });
      item('deploy', () async {
        cancel();
        for (var builder in builders) {
          await builder.deploy();
        }
      });

      item('clean', () async {
        cancel();
        for (var builder in builders) {
          await builder.clean();
        }
      });
    });
  } else {
    menuFlutterWebAppBuilderContent(builder: builders.first);
  }
}
