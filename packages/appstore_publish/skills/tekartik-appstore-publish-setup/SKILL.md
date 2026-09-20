---
name: tekartik-appstore-publish-setup
description: >-
  Use when a Dart build script or tool/ menu must validate or upload an iOS
  .ipa to App Store Connect / TestFlight from the command line with
  package:tekartik_appstore_publish: AppStorePublisher (validateIosApp,
  uploadIosApp, validateAndUploadIosApp, kill, copyWith),
  AppStoreCredentialsApiKeyIssuerId, AppStoreCredentialsUserPassword,
  AppStoreCredentials, the xcrun altool / iTMSTransporter commands it wraps
  and where the ipa of `flutter build ipa` lands.
---

# tekartik_appstore_publish: upload an ipa to App Store Connect

`package:tekartik_appstore_publish/appstore_publish.dart` wraps the two Apple
command line uploaders, `xcrun altool` and `xcrun iTMSTransporter`, in one
class, `AppStorePublisher`, so a Dart build script can validate and push the
`.ipa` produced by `flutter build ipa` to TestFlight. It only runs a shell
(`process_run`), so it needs a Mac with Xcode installed; nothing here talks
to the App Store Connect REST API.

## Guidelines

* Dependency (git, not on pub.dev; the app_build.dart repo is a workspace,
  the package sits in `packages/appstore_publish`):
  ```yaml
  dependencies:
    tekartik_appstore_publish:
      git:
        url: https://github.com/tekartik/app_build.dart
        path: packages/appstore_publish
  ```
  Put it in `dev_dependencies` when it only serves a `tool/` script.
* Import `package:tekartik_appstore_publish/appstore_publish.dart`. It
  exports `AppStorePublisher`, `AppStoreCredentials`,
  `AppStoreCredentialsApiKeyIssuerId` and `AppStoreCredentialsUserPassword`
  and nothing else.
* Credentials, two flavours, both implement `AppStoreCredentials`:
  * `AppStoreCredentialsApiKeyIssuerId(apiKey:, issuerId:)`: an App Store
    Connect API key (`--apiKey`/`--apiIssuer`). `apiKey` is the short key id
    of the `.p8` file, which `altool` looks up as
    `AuthKey_<apiKey>.p8` in `./private_keys`, `~/private_keys`,
    `~/.private_keys` or `~/.appstoreconnect/private_keys`. Preferred: no
    two-factor prompt, works in CI.
  * `AppStoreCredentialsUserPassword(username:, password:)`: an Apple ID
    and an app-specific password (`-u`/`-p`).
  Read them from the environment or a git-ignored file
  (`.local/appstore.json`), never hardcode them; they end up on the command
  line, so prefer the API key on shared machines.
* `AppStorePublisher({credentials, path})`: `path` is the working directory
  of the shell (default: current directory), relevant when `ipaPath` is
  relative. The `issuerId:`/`apiKey:` constructor parameters are
  deprecated equivalents of `AppStoreCredentialsApiKeyIssuerId`; when
  `credentials` is omitted both must be given, else the constructor throws.
  `copyWith(credentials:, path:)` returns a new publisher.
* Operations (each runs one `xcrun` command and throws a `ShellException`
  on a non-zero exit, the tool output having been printed already):
  * `validateIosApp(ipaPath:)`: `xcrun altool --validate-app -f <ipa> -t ios`.
  * `uploadIosApp(ipaPath:, useTransporter:)`: `xcrun altool --upload-app`
    by default; `useTransporter: true` uses
    `xcrun iTMSTransporter -m upload -assetFile <ipa>` instead (same
    credentials), useful when altool is flaky on large uploads.
  * `validateAndUploadIosApp(ipaPath:)`: the two in sequence with altool.
  * `kill()`: kills the command in progress (returns `true` when one was
    running); wire it to a `cancel` menu item or a signal handler.
* The ipa comes from `flutter build ipa` (signing set up in Xcode or
  `--export-options-plist`); it lands in `build/ios/ipa/<app name>.ipa`. Run
  the build with `process_run` (`run('flutter build ipa')`) before
  publishing; the package does not build.
* The commands are sequential and slow (minutes); do not run two publishers
  concurrently on the same ipa. A build number already uploaded is rejected
  by App Store Connect: bump the `+N` of `version:` in `pubspec.yaml` before
  each upload.
* Testing: there is no unit test in the package (everything shells out to
  Xcode). Keep the publisher behind a function taking an `AppStorePublisher`
  so the rest of the script stays testable, and guard the script with
  `Platform.isMacOS`.

## Examples

### Build the ipa and push it to TestFlight with an API key

```dart
// tool/publish_ios.dart — dart run tool/publish_ios.dart
import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:tekartik_appstore_publish/appstore_publish.dart';

Future<void> main() async {
  if (!Platform.isMacOS) {
    stderr.writeln('App Store upload needs macOS and Xcode');
    exit(1);
  }
  var env = Platform.environment;
  var publisher = AppStorePublisher(
    credentials: AppStoreCredentialsApiKeyIssuerId(
      apiKey: env['APPSTORE_API_KEY']!,
      issuerId: env['APPSTORE_ISSUER_ID']!,
    ),
  );

  await run('flutter build ipa');

  await publisher.validateAndUploadIosApp(
    ipaPath: 'build/ios/ipa/my_app.ipa',
  );
}
```

### Apple ID with an app-specific password, upload through Transporter

```dart
import 'dart:convert';
import 'dart:io';

import 'package:tekartik_appstore_publish/appstore_publish.dart';

Future<void> main() async {
  // .local/appstore.json: {"username": "me@example.com", "password": "xxxx-xxxx-xxxx-xxxx"}
  var json =
      jsonDecode(File('.local/appstore.json').readAsStringSync())
          as Map<String, Object?>;
  var publisher = AppStorePublisher(
    credentials: AppStoreCredentialsUserPassword(
      username: json['username'] as String,
      password: json['password'] as String,
    ),
    path: '/path/to/my_flutter_app',
  );
  await publisher.validateIosApp(ipaPath: 'build/ios/ipa/my_app.ipa');
  await publisher.uploadIosApp(
    ipaPath: 'build/ios/ipa/my_app.ipa',
    useTransporter: true,
  );
}
```

### Same credentials, several apps, cancellable from a dev menu

`dev_build` (dev dependency) provides the console menu.

```dart
import 'dart:io';

import 'package:dev_build/menu/menu_io.dart';
import 'package:tekartik_appstore_publish/appstore_publish.dart';

Future<void> main(List<String> arguments) async {
  var base = AppStorePublisher(
    credentials: AppStoreCredentialsApiKeyIssuerId(
      apiKey: Platform.environment['APPSTORE_API_KEY']!,
      issuerId: Platform.environment['APPSTORE_ISSUER_ID']!,
    ),
  );
  var apps = {
    'my_app': base.copyWith(path: '../my_app'),
    'my_other_app': base.copyWith(path: '../my_other_app'),
  };
  mainMenuConsole(arguments, () {
    for (var entry in apps.entries) {
      var name = entry.key;
      var publisher = entry.value;
      menu(name, () {
        item('validate', () async {
          await publisher.validateIosApp(ipaPath: 'build/ios/ipa/$name.ipa');
        });
        item('upload', () async {
          await publisher.uploadIosApp(ipaPath: 'build/ios/ipa/$name.ipa');
        });
        item('cancel', () {
          publisher.kill();
        });
      });
    }
  });
}
```
