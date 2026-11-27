import 'dart:io';

import 'package:tekartik_flutter_build/app_icon.dart';

/// `dart run tekartik_flutter_build:app_icon [app folder]`: draws the
/// drawing of the icon of a flutter app (`img/app_icon.svg`) into the image
/// its icons are made of (`img/app_icon.webp`), see [flutterAppIconFromSvg].
/// The app is the current folder by default.
///
/// Prints the path of the image; exit code 1 with the reason when it cannot
/// be made (no drawing, no program to draw an svg on this host).
Future<void> main(List<String> arguments) async {
  try {
    stdout.writeln(
      await flutterAppIconFromSvg(appPath: arguments.firstOrNull ?? '.'),
    );
  } on StateError catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  }
}
