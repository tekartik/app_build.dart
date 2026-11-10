# tekartik_playstore_publish

Upload Android App Bundles (`.aab`) to Google Play and release a version code
on a track (internal, alpha, beta, production, Wear OS) from a Dart script,
with a service account. It drives the Google Play Developer API
(`googleapis` `androidpublisher/v3`) and handles its "edits" (open, validate,
commit, or delete on error) for you.

## Getting started

Not on pub.dev, add it as a git dependency (a dev dependency when only a
`tool/` script uses it):

```yaml
dev_dependencies:
  tekartik_playstore_publish:
    git:
      url: https://github.com/tekartik/app_build.dart
      path: packages/playstore_publish
```

Credentials: a Google Cloud service account JSON key, invited in the Play
Console (Users and permissions) with release rights on the app. Keep it out
of git, for example in `.local/service_account.json`.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:tekartik_playstore_publish/playstore_publish.dart';

Future<void> main() async {
  var serviceAccount =
      jsonDecode(await File('.local/service_account.json').readAsString())
          as Map;
  var client = await initAndroidPublisherClient(serviceAccount: serviceAccount);
  var publisher = client.getPublisher('com.example.app');
  await publisher.uploadBundleAndPublish(
    aabPath: 'build/app/outputs/bundle/release/app-release.aab',
    trackName: publishTrackInternal,
    versionCode: 12, // the version code inside the bundle (`+12`)
  );
}
```

[example/main.dart](example/main.dart) reads the package name and the version
code from the bundle (`getAabInfo` of `tekartik_android_utils`, needs
`bundletool` on the PATH).

## What to use

| Need | API |
|---|---|
| Upload and release in one edit | `AndroidPublisher.uploadBundleAndPublish` (upload skipped when the version code is already there) |
| Release an uploaded version code (promote internal to production) | `publishVersionCode(trackName:, versionCode:, releaseStatus:)` |
| Read | `listTracks()`, `listBundles()`, `hasBundleVersionCode(n)`, `getTrackVersionCode(trackName:)` (each in its own edit, never committed) |
| Several changes in one edit, raw API calls | `writeAppEdit((appEdit) async { ... })` (validated and committed, deleted if the callback throws), `readOnlyAppEdit` |
| From a local `.aab` file and `.local/service_account.json` | `LocalAab`, `manageBundle`, `uploadBundle`, `publishBundle` (older helpers) |

Track names: `publishTrackInternal`, `publishTrackAlpha`, `publishTrackBeta`,
`publishTrackProduction`, `publishTrackWearInternal`, `publishTrackWearBeta`,
`publishTrackWearProduction`, or the name of a custom closed track.

## Platforms

Dart VM only (`dart:io`, network): build scripts and CI, not apps.

## Pitfalls

* A version code can be uploaded once: bump the `+N` of the `pubspec.yaml`
  `version:` before rebuilding.
* `versionCode` must be the one inside the bundle.
* The default release status is `AndroidPublisher.releaseStatusCompleted`
  (full rollout on that track); pass `releaseStatusDraft` to finish the
  rollout in the Play Console.
* `changesNotSentForReview: true` is required in some states (first release
  of a new app, a change already in review); it skips the validate step.
* A `DetailedApiRequestError` holds the Play Console message: `403` means the
  service account has no access to the app.
* Progress goes to stdout (`aab: N`, `uploading: ...`, `updating track: ...`).
* The authenticated client cannot be closed yet: a script may take a few
  seconds to exit after its last call (idle connections).

## Agent skills

The package ships the `tekartik-playstore-publish-upload` agent skill in
`skills/`. In a project that depends on this package, install it with:

```sh
dart run skills@ get
```
