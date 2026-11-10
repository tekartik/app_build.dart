// Bumps the version of the package in the current folder (patch and build
// number, the app default) and refreshes its generated lib/src/version.dart.
//
// Copy it to the tool/ folder of your package: run here, it bumps this
// package.
import 'package:tekartik_common_build/version_io.dart';

Future<void> main(List<String> args) async {
  await pathAppVersionBumpAndGenerate();
}
