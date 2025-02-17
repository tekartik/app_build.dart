import 'package:dev_build/menu/menu_run_ci.dart';
import 'package:dev_build/shell.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

Future<void> main(List<String> args) async {
  var topPackagesPath = '..';
  var path = join(topPackagesPath, 'flutter_build');
  test('build_web_test', () async {
    var shell = Shell(workingDirectory: path);
    var prj = PubIoPackage(path);
    await prj.ready;
    await prj.pubGet();
    await shell.run('dart test test/build_web_test.dart');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
