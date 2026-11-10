@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_web_publish/surge_web_publish.dart';
import 'package:test/test.dart';

void main() {
  group('SurgeWebAppDeployer', () {
    late Directory top;
    late File log;
    setUp(() async {
      top = await Directory.systemTemp.createTemp('web_publish_surge');
      var bin = join(top.path, 'bin');
      log = File(join(top.path, 'surge.log'));
      // Fake surge, writes its working directory and arguments
      var surge = File(join(bin, 'surge'))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '#!/bin/sh\npwd -P >> ${shellArgument(log.path)}\n'
          'echo "\$@" >> ${shellArgument(log.path)}\n',
        );
      await Shell(verbose: false).run('chmod +x ${shellArgument(surge.path)}');
      // First in the PATH of every Shell, before the user paths
      shellEnvironment = {
        ...shellEnvironment,
        'PATH': '$bin:${shellEnvironment['PATH']}',
      };
      expect(whichSync('surge'), surge.path);
    });
    tearDown(() async {
      shellEnvironment = null;
      await top.delete(recursive: true);
    });

    test('deploy path argument over the default path', () async {
      var defaultDir = Directory(join(top.path, 'default'))..createSync();
      var otherDir = Directory(join(top.path, 'other'))..createSync();
      var deployer = SurgeWebAppDeployer(
        path: defaultDir.path,
        options: SurgeWebAppDeployOptions(domain: 'test.surge.invalid'),
      );
      await deployer.deploy(path: otherDir.path);
      await deployer.deploy();
      expect(log.readAsLinesSync(), [
        otherDir.resolveSymbolicLinksSync(),
        '. --domain test.surge.invalid',
        defaultDir.resolveSymbolicLinksSync(),
        '. --domain test.surge.invalid',
      ]);
    });
  }, skip: Platform.isWindows ? 'posix shell script' : false);
}
