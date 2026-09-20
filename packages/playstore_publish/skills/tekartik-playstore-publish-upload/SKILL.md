---
name: tekartik-playstore-publish-upload
description: >-
  Use when a Dart build script or tool/ menu must upload an Android app
  bundle (.aab) to the Google Play Console or promote a version code to a
  release track (internal, alpha, beta, production, wear:*) with a service
  account, using package:tekartik_playstore_publish: initAndroidPublisherClient,
  AndroidPublisherClient.getPublisher, AndroidPublisher (listTracks,
  listBundles, hasBundleVersionCode, getTrackVersionCode, publishVersionCode,
  uploadBundleAndPublish, readOnlyAppEdit, writeAppEdit),
  AndroidPublisherAppEdit, releaseStatusDraft / releaseStatusCompleted,
  publishTrackInternal / publishTrackProduction..., and the LocalAab,
  manageBundle, uploadBundle, publishBundle file based helpers.
---

# tekartik_playstore_publish: upload and release Android bundles

`package:tekartik_playstore_publish/playstore_publish.dart` drives the Google
Play Developer API (`googleapis` `androidpublisher/v3`) from a Dart script:
authenticate with a service account, upload an `.aab`, put a version code on
a track. Every Play Console change happens inside an "edit" that must be
validated and committed; the package opens, commits or discards it for you.
Dart VM only (`dart:io`, network).

## Guidelines

### Setup

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    tekartik_playstore_publish:
      git:
        url: https://github.com/tekartik/app_build.dart
        path: packages/playstore_publish
  ```
  `dev_dependencies` when it only serves a `tool/` script. It brings
  `googleapis`, `googleapis_auth` and `tekartik_android_utils`; the library
  re-exports `AndroidPublisherApi` so the raw API is reachable without
  importing `googleapis` yourself.
* Import `package:tekartik_playstore_publish/playstore_publish.dart` (one
  library).
* Credentials: a Google Cloud service account JSON key, granted access to
  the app in the Play Console (Users and permissions, release management).
  Keep the file out of git (`.local/service_account.json` is the convention
  and the default of `manageBundle`), decode it with `jsonDecode` and pass
  the `Map` to `initAndroidPublisherClient(serviceAccount:)`. The scope used
  is `androidPublisherScopes`
  (`[AndroidPublisherApi.androidpublisherScope]`). `initPublishApiClient`
  returns the bare `AndroidPublisherApi` instead; prefer the client.
* `client.getPublisher('com.example.app')` gives an `AndroidPublisher` per
  application id (`packageName`), sharing the authenticated client.
  `AndroidPublisher(packageName:, client:)` or `(packageName:, api:)` is the
  same thing by hand; exactly one of `api`/`client` is required.

### Publishing

* Track names: `publishTrackInternal` (`'internal'`), `publishTrackAlpha`,
  `publishTrackBeta`, `publishTrackProduction`, and the Wear OS ones
  `publishTrackWearInternal`, `publishTrackWearBeta`,
  `publishTrackWearProduction` (`'wear:...'`). `internalTrack` is a legacy
  alias of `publishTrackInternal`. Custom closed testing tracks use the
  name shown in the console; `listTracks()` returns what the app has.
* Release status: `AndroidPublisher.releaseStatusCompleted` (default: served
  to everyone on the track, full rollout) or
  `AndroidPublisher.releaseStatusDraft` (created but not rolled out; finish
  it in the console). Pass it as `releaseStatus:`.
* `uploadBundleAndPublish(aabPath:, trackName:, versionCode:, releaseStatus:,
  changesNotSentForReview:)` is the one-call release: in a single edit it
  uploads the bundle unless `versionCode` is already there (then it just
  prints `versionCode N already exists`), sets the track release to
  `versionCode`, validates and commits. `versionCode` must be the version
  code inside the bundle (`android:versionCode`, the `+N` of the flutter
  `version:`); read it with `getAabInfo` from
  `package:tekartik_android_utils/aab_utils.dart` (needs `bundletool` on the
  PATH) or derive it from `pubspec.yaml`.
* `publishVersionCode(trackName:, versionCode:, releaseStatus:)` promotes an
  already uploaded version code (internal to production, for instance).
* `changesNotSentForReview: true` commits with `changesNotSentForReview` and
  skips the validate step; the Play API requires it in some states (first
  release of a new app, a change already pending review). Leave it null
  otherwise.
* Reads: `listBundles()` (uploaded version codes), `hasBundleVersionCode(n)`,
  `getTrackVersionCode(trackName:)` (the version code of the `completed`
  release of the track, `null` when none), `listTracks()`. They open a
  read-only edit and never commit.
* Custom edits: `writeAppEdit((appEdit) async { ... },
  changesNotSentForReview:)` runs your callback on an
  `AndroidPublisherAppEdit`, then validates and commits it, or deletes it
  and rethrows when the callback throws; `readOnlyAppEdit(...)` deletes it
  on failure only and never commits. Inside, use
  `appEdit.uploadBundle(aabPath)`, `appEdit.publishTrack(trackName,
  versionCode:, releaseStatus:)`, `appEdit.listBundles()`,
  `appEdit.hasBundleVersionCode(n)`, `appEdit.getTrackVersionCode(trackName,
  releaseStatus:)`; `appEdit.id`, `appEdit.packageName` and
  `appEdit.appEdit` (the raw `AppEdit`) let you call the raw
  `AndroidPublisherApi` (`edits.details`, `edits.listings`...) in the same
  edit. `newAppEdit()` gives an edit you must `delete()` or
  `validateAndCommit()` yourself.
* Version codes are immutable on Google Play: a bundle already uploaded
  cannot be replaced; bump `version:` (`+N`) in `pubspec.yaml` and rebuild
  (`flutter build appbundle` writes
  `build/app/outputs/bundle/release/app-release.aab`, or
  `<flavor>Release/app-<flavor>-release.aab` with flavors).
* A `DetailedApiRequestError` (from `package:googleapis/androidpublisher/v3.dart`)
  carries the Play Console message: `403` means the service account lacks
  access to the app, `400` usually a bad version code or track; print
  `e.message` and `e.jsonResponse`.
* Progress is written to `stdout`/`stderr` by the package (`aab: N`,
  `uploading: ...`, `updating track: ...`); there is no quiet mode.

### File based helpers (older API)

* `LocalAab(path)` wraps an `.aab`; `await localAab.init()` reads its
  manifest with `bundletool` (`getAabInfo`), then `versionCode` and
  `packageName` are available. `manageBundle(localAab, serviceAccountPath:,
  uploadOptions:, publishOptions:)` reads the service account file itself
  (default `.local/service_account.json`), uploads when
  `UploadOptions(upload: true)` (throws `'Version already uploaded as aab'`
  when the version code exists), publishes to `PublishOptions(track:,
  changesNotSentForReview:, releaseStatus:)` when a track is given, then
  validates and commits. `uploadBundle(localAab)` uploads without
  publishing; `publishBundle(localAab, track:)` publishes an existing upload
  (`publishTrackInternal` by default) and throws `'Version N not found'`
  when the bundle was never uploaded. They need `bundletool` on the PATH;
  prefer the `AndroidPublisher` API in new code.
* `bin/apk_publish_upload.dart` is an old `apk` (not bundle) uploader with
  OAuth user credentials; not maintained, do not build on it.

## Examples

### Upload the release bundle to the internal track

```dart
// tool/publish_android.dart — dart run tool/publish_android.dart
import 'dart:convert';
import 'dart:io';

import 'package:tekartik_android_utils/aab_utils.dart';
import 'package:tekartik_playstore_publish/playstore_publish.dart';

Future<void> main() async {
  var aabPath = 'build/app/outputs/bundle/release/app-release.aab';
  var serviceAccount =
      jsonDecode(File('.local/service_account.json').readAsStringSync())
          as Map;

  // bundletool must be on the PATH.
  var aabInfo = await getAabInfo(aabPath);
  var packageName = aabInfo.name!;
  var versionCode = int.parse(aabInfo.versionCode!);

  var client = await initAndroidPublisherClient(serviceAccount: serviceAccount);
  var publisher = client.getPublisher(packageName);
  await publisher.uploadBundleAndPublish(
    aabPath: aabPath,
    trackName: publishTrackInternal,
    versionCode: versionCode,
  );
}
```

### Inspect what is on the Play Console

```dart
import 'dart:convert';
import 'dart:io';

import 'package:tekartik_playstore_publish/playstore_publish.dart';

Future<void> main() async {
  var client = await initAndroidPublisherClient(
    serviceAccount:
        jsonDecode(File('.local/service_account.json').readAsStringSync())
            as Map,
  );
  var publisher = client.getPublisher('com.example.app');
  print('tracks: ${await publisher.listTracks()}');
  print('bundles: ${await publisher.listBundles()}');
  for (var track in [publishTrackInternal, publishTrackProduction]) {
    var versionCode = await publisher.getTrackVersionCode(trackName: track);
    print('$track: ${versionCode ?? 'nothing completed'}');
  }
}
```

### Promote the internal build to production as a draft release

```dart
import 'package:tekartik_playstore_publish/playstore_publish.dart';

Future<void> promoteToProduction(AndroidPublisher publisher) async {
  var versionCode = await publisher.getTrackVersionCode(
    trackName: publishTrackInternal,
  );
  if (versionCode == null) {
    throw StateError('nothing on the internal track');
  }
  // Draft: finish the rollout in the Play Console.
  await publisher.publishVersionCode(
    trackName: publishTrackProduction,
    versionCode: versionCode,
    releaseStatus: AndroidPublisher.releaseStatusDraft,
  );
}
```

### One edit: phone and wear bundles, plus a raw API call

```dart
import 'package:tekartik_playstore_publish/playstore_publish.dart';

Future<void> releaseBoth(
  Map serviceAccount, {
  required String phoneAab,
  required int phoneVersionCode,
  required String wearAab,
  required int wearVersionCode,
}) async {
  var api = await initPublishApiClient(serviceAccount: serviceAccount);
  var publisher = AndroidPublisher(packageName: 'com.example.app', api: api);
  await publisher.writeAppEdit((appEdit) async {
    if (!await appEdit.hasBundleVersionCode(phoneVersionCode)) {
      await appEdit.uploadBundle(phoneAab);
    }
    if (!await appEdit.hasBundleVersionCode(wearVersionCode)) {
      await appEdit.uploadBundle(wearAab);
    }
    await appEdit.publishTrack(publishTrackBeta, versionCode: phoneVersionCode);
    await appEdit.publishTrack(
      publishTrackWearBeta,
      versionCode: wearVersionCode,
    );
    // Raw googleapis call in the same edit.
    var details = await api.edits.details.get(
      appEdit.packageName,
      appEdit.id,
    );
    print('contact: ${details.contactEmail}');
  });
}
```

### Older file based helpers

```dart
import 'package:tekartik_playstore_publish/playstore_publish.dart';

Future<void> main() async {
  var localAab = LocalAab('build/app/outputs/bundle/release/app-release.aab');
  // Reads .local/service_account.json, uploads, publishes to no track.
  await uploadBundle(localAab);
  // Later: put the uploaded version code on beta.
  await publishBundle(localAab, track: publishTrackBeta);
}
```
