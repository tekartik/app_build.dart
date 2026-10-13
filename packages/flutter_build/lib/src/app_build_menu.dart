import 'package:dev_build/menu/menu.dart';
import 'package:dev_build/shell.dart';
import 'package:path/path.dart';
import 'package:tekartik_flutter_build/app_build.dart';

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
    await builder.build();
  });
  item('build only (no copy to deploy)', () async {
    cancel();
    await builder.buildOnly();
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

  item('bumpVersion', () async {
    await builder.bumpVersion();
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
/// of them (the deploy ones only when every builder has a deployer), each
/// item first cancelling what any of them runs; with exactly one entry, its
/// items are added directly (no submenu).
void menuFlutterWebAppContent({required List<FlutterWebAppBuilder> builders}) {
  if (builders.length >= 2) {
    for (var builder in builders) {
      menu('target ${builder.target}', () {
        menuFlutterWebAppBuilderContent(builder: builder);
      });
    }

    menu('all', () {
      var all = FlutterWebAppAllBuilders(builders);

      item('build', () async {
        all.cancel();
        for (var builder in all.builders) {
          await builder.build();
        }
      });

      if (all.canDeploy) {
        item('build and deploy', () async {
          all.cancel();
          for (var builder in all.builders) {
            await builder.buildAndDeploy();
          }
        });

        item('deploy', () async {
          all.cancel();
          for (var builder in all.builders) {
            await builder.deploy();
          }
        });
      }

      item('clean', () async {
        all.cancel();
        for (var builder in all.builders) {
          await builder.clean();
        }
      });
    });
  } else {
    menuFlutterWebAppBuilderContent(builder: builders.first);
  }
}

/// The builders of the `all` submenu, each one with its own controller so
/// that [cancel] stops whichever command is running.
class FlutterWebAppAllBuilders {
  /// Copies of the builders, each with the controller [newController]
  /// returns for it (a new shell in its folder by default).
  final List<FlutterWebAppBuilder> builders;

  /// Copies [builders], see [FlutterWebAppAllBuilders.builders].
  FlutterWebAppAllBuilders(
    List<FlutterWebAppBuilder> builders, {
    BuildShellController Function(FlutterWebAppBuilder builder)? newController,
  }) : builders = [
         for (var builder in builders)
           builder.copyWith(
             controller: (newController ?? _newBuildShellController)(builder),
           ),
       ];

  /// Whether every builder has a deployer, i.e. whether deploying them all
  /// can work.
  bool get canDeploy => builders.every((builder) => builder.deployer != null);

  /// Cancels the running command of every builder.
  void cancel() {
    for (var builder in builders) {
      builder.controller?.cancel();
    }
  }
}

BuildShellController _newBuildShellController(FlutterWebAppBuilder builder) =>
    BuildShellController(shell: Shell(workingDirectory: builder.path));
