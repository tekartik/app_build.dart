# tekartik_appstore_publish

Validate and upload an iOS `.ipa` (the output of `flutter build ipa`) to App
Store Connect / TestFlight from a Dart build script. It runs Apple's command
line uploaders, `xcrun altool` (default) or `xcrun iTMSTransporter`, through
a [process_run](https://pub.dev/packages/process_run) shell.

## Getting started

Not on pub.dev, add it as a git dependency (`dev_dependencies` for a `tool/`
script):

```yaml
dev_dependencies:
  tekartik_appstore_publish:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/appstore_publish
```

```dart
import 'dart:io';

import 'package:tekartik_appstore_publish/appstore_publish.dart';

Future<void> main() async {
  var publisher = AppStorePublisher(
    // App Store Connect API key: AuthKey_<apiKey>.p8 in ~/private_keys (or
    // ./private_keys, ~/.private_keys, ~/.appstoreconnect/private_keys).
    credentials: AppStoreCredentialsApiKeyIssuerId(
      apiKey: Platform.environment['APPSTORE_API_KEY']!,
      issuerId: Platform.environment['APPSTORE_ISSUER_ID']!,
    ),
  );
  // Throws a ShellException when altool fails (its output is printed).
  await publisher.validateAndUploadIosApp(ipaPath: 'build/ios/ipa/my_app.ipa');
}
```

Platforms: macOS with Xcode (it needs `xcrun`), Dart VM.

## API

- Credentials: `AppStoreCredentialsApiKeyIssuerId(apiKey:, issuerId:)`
  (preferred, no two-factor prompt, works in CI) or
  `AppStoreCredentialsUserPassword(username:, password:)` (an Apple ID and an
  app-specific password; the password is handed to the tool in its
  environment, `-p @env:...`, never on the command line).
- `validateIosApp(ipaPath:)`, `uploadIosApp(ipaPath:, useTransporter:)`,
  `validateAndUploadIosApp(ipaPath:)`, `kill()` (stops the running command),
  `copyWith(credentials:, path:)`.
- `path`: the working directory of the commands (a relative `ipaPath` is
  read from there).

## Common pitfalls

- Never hardcode the credentials: read them from the environment or a
  git-ignored file.
- One publisher runs one command at a time; `kill()` only stops the current
  one.
- `useTransporter: true` with an API key passes altool's `--apiKey` and
  `--apiIssuer` options to iTMSTransporter (not checked there).
