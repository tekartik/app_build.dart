import 'package:path/path.dart';
import 'package:dev_test/package.dart';

var topDir = '..';

Future<void> main() async {
  for (var dir in [
    'repo_support',
    'firebase_build',
  ]) {
    var path = join(topDir, dir);
    await packageRunCi(path);
  }
}
