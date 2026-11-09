@TestOn('vm && !windows')
library;

import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:tekartik_appstore_publish/appstore_publish.dart';
import 'package:tekartik_appstore_publish/src/appstore_publisher.dart'
    show appStorePasswordEnvVar;
import 'package:test/test.dart';

void main() {
  test('the Apple ID password is not on the command line', () async {
    var dir = await Directory.systemTemp.createTemp('appstore_publish');
    addTearDown(() => dir.delete(recursive: true));
    var bin = Directory('${dir.path}/bin')..createSync();
    var out = '${dir.path}/xcrun_out';
    // A fake xcrun writing its arguments and the password variable, then
    // failing like a rejected upload.
    var xcrun = File('${bin.path}/xcrun')
      ..writeAsStringSync(
        '#!/bin/sh\n'
        'echo "\$*" > "\$FAKE_XCRUN_OUT"\n'
        'printf %s "\$$appStorePasswordEnvVar" > "\$FAKE_XCRUN_OUT.env"\n'
        'exit 1\n',
      );
    await run('chmod +x ${shellArgument(xcrun.path)}', verbose: false);
    shellEnvironment = ShellEnvironment()
      ..paths.prepend(bin.path)
      ..vars['FAKE_XCRUN_OUT'] = out;
    addTearDown(() => shellEnvironment = null);

    const password = 'SECRET-PASSWORD-1234';
    var publisher = AppStorePublisher(
      credentials: AppStoreCredentialsUserPassword(
        username: 'me@example.com',
        password: password,
      ),
    );
    try {
      await publisher.validateIosApp(ipaPath: 'app.ipa');
      fail('should fail');
    } on ShellException catch (e) {
      expect(e.message, isNot(contains(password)));
      expect(e.message, contains('-p @env:$appStorePasswordEnvVar'));
    }
    var args = File(out).readAsStringSync();
    expect(args, isNot(contains(password)));
    expect(args, contains('-u me@example.com -p @env:'));
    // The tool reads it from its environment.
    expect(File('$out.env').readAsStringSync(), password);
  });
}
