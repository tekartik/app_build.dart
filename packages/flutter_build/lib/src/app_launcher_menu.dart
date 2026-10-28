import 'package:dev_build/menu/menu.dart';
import 'package:tekartik_build_flutter/build_flutter.dart';

import 'app_launcher.dart';

/// Registers dev-menu items for the desktop release of [launcher] (built in
/// `deploy/<platform>`, the one `bin/<app>.dart` runs): build and run,
/// build, run (built first when missing), one run item per [runArguments]
/// entry (its label to the app arguments), run in debug, and install the
/// global command (`dart install`).
void menuFlutterAppHostLauncherContent({
  required FlutterAppHostLauncher launcher,
  Map<String, List<String>> runArguments = const {},
}) {
  var platform = buildPlatformCurrent;
  item('build and run $platform', () async {
    await launcher.build();
    await launcher.run();
  });
  item('build $platform', () async {
    await launcher.build();
  });
  item('run $platform', () async {
    await launcher.buildIfNeededAndRun();
  });
  runArguments.forEach((label, arguments) {
    item('run $platform $label', () async {
      await launcher.buildIfNeededAndRun(arguments: arguments);
    });
  });
  item('run $platform (debug)', () async {
    await launcher.runDebug();
  });
  item('install the global command (dart install)', () async {
    await launcher.install();
  });
}
