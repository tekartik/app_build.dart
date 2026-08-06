import 'package:tekartik_common_build/src/dversion_bump.dart';

Future<void> main(List<String> args) async {
  await pathAppVersionBumpAndGenerate();
}
