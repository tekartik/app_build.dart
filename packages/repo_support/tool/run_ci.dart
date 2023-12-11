import 'package:dev_build/package.dart';
import 'package:path/path.dart';

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
