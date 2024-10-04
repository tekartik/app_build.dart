import 'package:dev_build/package.dart';

var topDir = '..';

Future<void> main() async {
  await packageRunCi('..', options: PackageRunCiOptions(recursive: true));
}
