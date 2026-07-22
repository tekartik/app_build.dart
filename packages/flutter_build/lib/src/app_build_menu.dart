import 'package:dev_build/menu/menu.dart';
import 'package:dev_build/shell.dart';
import 'package:path/path.dart';
import 'package:tekartik_flutter_build/app_build.dart';

import 'controller.dart';

/// Registers dev-menu items (build, run, serve, deploy, clean, generate
/// version, report JS size, and a `'cancel current build/server'` item)
/// for the given [builder]. `'build and deploy'` and `'deploy'` items are
/// only added when [builder] has a deployer.
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
    await builder.buildOnly();
    if (await builder.hasDeployYamlFile()) {
      await builder.buildToDeploy();
    }
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
  item('Js size', () async {
    await builder.reportJsSize();
  });
}

/// Registers dev-menu items for each project in [builders] (see
/// [menuFlutterWebAppBuilderContent]).
///
/// If [builders] has 2 or more entries, each gets its own submenu named
/// after its [FlutterWebAppBuilder.target], plus an `'all'` submenu with
/// combined build/build-and-deploy/deploy/clean items that run across all
/// of them; with exactly one entry, its items are added directly (no
/// submenu).
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
