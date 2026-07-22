import 'dart:async';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:googleapis/androidpublisher/v3.dart';
// ignore: depend_on_referenced_packages
import 'package:googleapis_auth/auth_io.dart';

//import 'package:googleapis'

/// OAuth scopes required to call the Google Play Android Publisher API,
/// passed to [initPublishApiClient].
const androidPublisherScopes = [AndroidPublisherApi.androidpublisherScope];

/// A ready-to-use Android Publisher API client, from which per-package
/// [AndroidPublisher]s are obtained via [getPublisher]. Prefer creating
/// one via [initAndroidPublisherClient].
class AndroidPublisherClient {
  final AndroidPublisherApi _api;

  /// Wraps an already-authenticated [AndroidPublisherApi] client.
  AndroidPublisherClient({required this._api});

  /// Returns an [AndroidPublisher] for the app identified by
  /// [packageName] (e.g. `'com.example.app'`), sharing this client's API
  /// connection.
  AndroidPublisher getPublisher(String packageName) {
    return AndroidPublisher(packageName: packageName, api: _api);
  }
}

/// Authenticates with [serviceAccount] (a decoded Google service account
/// JSON key) and returns a ready-to-use [AndroidPublisherClient]. Preferred
/// over calling [initPublishApiClient] directly.
Future<AndroidPublisherClient> initAndroidPublisherClient({
  required Map serviceAccount,
}) async {
  var api = await initPublishApiClient(serviceAccount: serviceAccount);

  return AndroidPublisherClient(api: api);
}

/// Authenticates with [serviceAccount] (a decoded Google service account
/// JSON key) using [androidPublisherScopes] and returns the raw
/// [AndroidPublisherApi] client. Prefer [initAndroidPublisherClient].
Future<AndroidPublisherApi> initPublishApiClient({
  required Map serviceAccount,
}) async {
  var credentials = ServiceAccountCredentials.fromJson(serviceAccount);
  var client = await clientViaServiceAccount(
    credentials,
    androidPublisherScopes,
  );
  var publish = AndroidPublisherApi(client);
  return publish;
}

/// Google Play operations (list/upload bundles, list/publish tracks) for a
/// single app, identified by [packageName]. Each operation opens and
/// closes its own "app edit" transaction against the Play Console API.
class AndroidPublisher {
  /// Release status: the release's APKs/bundles are not served to users.
  static const releaseStatusDraft = 'draft';

  /// Release status: the release has no further changes and its
  /// APKs/bundles are being served to all eligible users.
  static const releaseStatusCompleted = 'completed';

  /// The Android application ID this publisher operates on (e.g.
  /// `'com.example.app'`).
  final String packageName;

  /// API
  final AndroidPublisherApi _api;

  @Deprecated('Do no use')
  /// The underlying [AndroidPublisherApi] client.
  AndroidPublisherApi get api => _api;

  /// Creates a publisher for [packageName]. Exactly one of [api] or
  /// [client] must be provided to supply the underlying API connection.
  AndroidPublisher({
    required this.packageName,
    AndroidPublisherApi? api,
    AndroidPublisherClient? client,
  }) : _api = api ?? client!._api;

  /// Opens a new Play Console "edit" transaction for [packageName].
  ///
  /// The caller is responsible for eventually calling
  /// [AndroidPublisherAppEdit.delete] (to discard) or
  /// [AndroidPublisherAppEdit.validateAndCommit] (to apply); prefer
  /// [readOnlyAppEdit] or [writeAppEdit], which handle this automatically.
  Future<AndroidPublisherAppEdit> newAppEdit() async {
    var appEdit = AppEdit();
    appEdit = await _api.edits.insert(appEdit, packageName);

    return AndroidPublisherAppEdit(appEdit: appEdit, publisher: this);
  }

  /// Opens a new app edit (see [newAppEdit]), runs [action] on it, then
  /// deletes the edit (discarding any changes) regardless of the outcome,
  /// rethrowing on failure.
  ///
  /// Returns whatever [action] returns.
  Future<T> readOnlyAppEdit<T>(
    Future<T> Function(AndroidPublisherAppEdit appEdit) action,
  ) async {
    var apAppEdit = await newAppEdit();
    try {
      return await action(apAppEdit);
    } catch (e) {
      await apAppEdit.delete();
      rethrow;
    }
  }

  /// Opens a new app edit (see [newAppEdit]), runs [action] on it, then
  /// validates and commits the edit (see
  /// [AndroidPublisherAppEdit.validateAndCommit], passing
  /// [changesNotSentForReview] through). If [action] throws, the edit is
  /// deleted instead and the error rethrown.
  ///
  /// Returns whatever [action] returns.
  Future<T> writeAppEdit<T>(
    Future<T> Function(AndroidPublisherAppEdit appEdit) action, {
    bool? changesNotSentForReview,
  }) async {
    var apAppEdit = await newAppEdit();
    try {
      var result = await action(apAppEdit);
      await apAppEdit.validateAndCommit(
        changesNotSentForReview: changesNotSentForReview,
      );
      return result;
    } catch (e) {
      await apAppEdit.delete();
      rethrow;
    }
  }

  /// Lists the names of all release tracks configured for this app (e.g.
  /// `'production'`, `'beta'`, `'internal'`).
  Future<List<String>> listTracks() async {
    var apAppEdit = await newAppEdit();
    try {
      var response = await _api.edits.tracks.list(packageName, apAppEdit.id);
      var tracks = response.tracks!.map((e) => e.track!).toList();
      return tracks;
    } finally {
      await apAppEdit.delete();
    }
  }

  /// Lists the version codes of all uploaded app bundles for this app.
  Future<List<int>> listBundles() async {
    return await readOnlyAppEdit((appEdit) async {
      return await appEdit.listBundles();
    });
  }

  /// Checks whether an app bundle with the given [versionCode] has already
  /// been uploaded.
  Future<bool> hasBundleVersionCode(int versionCode) async {
    return await readOnlyAppEdit((appEdit) async {
      return await appEdit.hasBundleVersionCode(versionCode);
    });
  }

  /// Publishes the app bundle with [versionCode] to the release track
  /// [trackName].
  ///
  /// [releaseStatus] defaults to [releaseStatusCompleted] (see
  /// [AndroidPublisherAppEdit.publishTrack]).
  Future<void> publishVersionCode({
    required String trackName,
    required int versionCode,
    String? releaseStatus,
  }) async {
    await writeAppEdit((appEdit) async {
      await appEdit.publishTrack(
        trackName,
        versionCode: versionCode,
        releaseStatus: releaseStatus,
      );
    });
  }

  /// Returns the version code currently published on release track
  /// [trackName] with status [releaseStatusCompleted], or `null` if none
  /// matches.
  Future<int?> getTrackVersionCode({required String trackName}) async {
    return await readOnlyAppEdit((appEdit) async {
      var versionCode = await appEdit.getTrackVersionCode(trackName);
      return versionCode;
    });
  }

  /// Uploads the app bundle at [aabPath] (unless [versionCode] was already
  /// uploaded) and publishes it to release track [trackName].
  ///
  /// [releaseStatus] defaults to [releaseStatusCompleted]. If
  /// [changesNotSentForReview] is `true`, the commit skips the validate
  /// step (see [AndroidPublisherAppEdit.validateAndCommit]).
  Future<void> uploadBundleAndPublish({
    required String aabPath,
    required String trackName,
    required int versionCode,
    String? releaseStatus,
    bool? changesNotSentForReview,
  }) async {
    await writeAppEdit((appEdit) async {
      var found = await appEdit.hasBundleVersionCode(versionCode);
      if (!found) {
        await appEdit.uploadBundle(aabPath);
      } else {
        stdout.writeln('versionCode $versionCode already exists');
      }

      await appEdit.publishTrack(
        trackName,
        versionCode: versionCode,
        releaseStatus: releaseStatus,
      );
    }, changesNotSentForReview: changesNotSentForReview);
  }
}

/// A single in-progress Play Console "edit" transaction, opened via
/// [AndroidPublisher.newAppEdit], through which bundles are
/// listed/uploaded and tracks are read/published.
class AndroidPublisherAppEdit {
  /// The publisher this edit was opened from.
  final AndroidPublisher publisher;

  /// The underlying Play Developer API edit resource.
  final AppEdit appEdit;

  /// This edit's ID, as assigned by the Play Developer API.
  String get id => appEdit.id!;

  /// The Android application ID this edit applies to, i.e.
  /// `publisher.packageName`.
  String get packageName => publisher.packageName;

  AndroidPublisherApi get _api => publisher._api;

  /// Wraps an already-opened [appEdit] belonging to [publisher]. Prefer
  /// [AndroidPublisher.newAppEdit].
  AndroidPublisherAppEdit({required this.appEdit, required this.publisher});

  /// Deletes this edit, discarding any changes made through it. Errors are
  /// caught and logged to stderr rather than thrown.
  Future<void> delete() async {
    try {
      await publisher._api.edits.delete(packageName, id);
    } catch (e) {
      stderr.writeln('Error deleting edit $id: $e');
    }
  }

  /// Lists the version codes of all app bundles uploaded so far within
  /// this edit.
  Future<List<int>> listBundles() async {
    var aabListResponse = await _api.edits.bundles.list(packageName, id);
    if (aabListResponse.bundles != null) {
      var bundleList = aabListResponse.bundles!.map((e) => e.versionCode!);
      return bundleList.toList();
    }
    return <int>[];
  }

  /// Checks whether an app bundle with the given [versionCode] has already
  /// been uploaded within this edit.
  Future<bool> hasBundleVersionCode(int versionCode) async {
    var aabListResponse = await _api.edits.bundles.list(packageName, id);
    if (aabListResponse.bundles != null) {
      for (var bundle in aabListResponse.bundles!) {
        stdout.writeln('aab: ${bundle.versionCode}');
        //print(bundle.versionCode);
        if (bundle.versionCode == versionCode) {
          return true;
        }
      }
    }
    return false;
  }

  /// Uploads the `.aab` file at [aabPath] as a new app bundle within this
  /// edit, logging its size and resulting version code.
  Future<void> uploadBundle(String aabPath) async {
    var file = File(aabPath);
    var size = file.statSync().size;
    var media = Media(file.openRead(), size);

    stdout.writeln('uploading: $size bytes $aabPath');
    var aab = await _api.edits.bundles.upload(
      packageName,
      id,
      uploadMedia: media,
    );
    stdout.writeln(aab.versionCode);
  }

  /// Sets release track [trackName] to serve [versionCode], within this
  /// edit.
  ///
  /// [releaseStatus] defaults to [AndroidPublisher.releaseStatusCompleted].
  Future publishTrack(
    String trackName, {
    String? releaseStatus,
    required int versionCode,
  }) async {
    releaseStatus ??= AndroidPublisher.releaseStatusCompleted;
    var track = Track();
    // track.track = trackName;
    track.releases = [
      TrackRelease()
        ..versionCodes = [versionCode.toString()]
        ..status = releaseStatus,
    ]; // v2:versionCodes = [versionCode];
    stdout.writeln('updating track: ${track.releases!.first.toJson()}');
    await _api.edits.tracks.update(track, packageName, appEdit.id!, trackName);
  }

  /// Returns the version code of release track [trackName]'s release
  /// whose status matches [releaseStatus] (defaults to
  /// [AndroidPublisher.releaseStatusCompleted]), or `null` if none
  /// matches.
  Future<int?> getTrackVersionCode(
    String trackName, {
    String? releaseStatus,
  }) async {
    //stdout.writeln('getting track: ${track.releases!.first.toJson()}');
    releaseStatus ??= AndroidPublisher.releaseStatusCompleted;
    var track = await _api.edits.tracks.get(
      packageName,
      appEdit.id!,
      trackName,
    );
    var releases = track.releases;
    if (releases != null) {
      for (var release in releases) {
        if (release.status == releaseStatus) {
          return int.parse(release.versionCodes!.first);
        }
      }
    }
    return null;
    //print(track.toJson());
  }

  /// Validates and commits this edit, applying all changes made through
  /// it.
  ///
  /// If [changesNotSentForReview] is `true`, the validate step is skipped
  /// (the Play Developer API rejects validation of edits marked this way)
  /// and only commit is called.
  Future<void> validateAndCommit({bool? changesNotSentForReview}) async {
    if (changesNotSentForReview != true) {
      await _api.edits.validate(packageName, id);
    }
    await _api.edits.commit(
      packageName,
      id,
      changesNotSentForReview: changesNotSentForReview,
    );
  }
}
