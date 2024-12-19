import 'dart:async';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:googleapis/androidpublisher/v3.dart';
// ignore: depend_on_referenced_packages
import 'package:googleapis_auth/auth_io.dart';
//import 'package:googleapis'

/// Scopes for Android Publisher
const androidPublisherScopes = [AndroidPublisherApi.androidpublisherScope];

/// Android Publisher Client
class AndroidPublisherClient {
  final AndroidPublisherApi _api;

  /// Constructor
  AndroidPublisherClient({required AndroidPublisherApi api}) : _api = api;

  /// Get publisher for a given package name
  AndroidPublisher getPublisher(String packageName) {
    return AndroidPublisher(packageName: packageName, api: _api);
  }
}

/// Prefer
Future<AndroidPublisherClient> initAndroidPublisherClient(
    {required Map serviceAccount}) async {
  var api = await initPublishApiClient(serviceAccount: serviceAccount);
  return AndroidPublisherClient(api: api);
}

/// Initialize the Android Publisher API, prefer [initAndroidPublisherClient]
Future<AndroidPublisherApi> initPublishApiClient(
    {required Map serviceAccount}) async {
  var credentials = ServiceAccountCredentials.fromJson(serviceAccount);
  var client =
      await clientViaServiceAccount(credentials, androidPublisherScopes);
  var publish = AndroidPublisherApi(client);
  return publish;
}

/// Android Publisher
class AndroidPublisher {
  /// Package name
  final String packageName;

  /// API
  final AndroidPublisherApi _api;

  @Deprecated('Do no use')

  /// Internal api
  AndroidPublisherApi get api => _api;

  /// Either api or client must be provided
  AndroidPublisher(
      {required this.packageName,
      AndroidPublisherApi? api,
      AndroidPublisherClient? client})
      : _api = api ?? client!._api;

  /// New edit, delete on error
  Future<AndroidPublisherAppEdit> newAppEdit() async {
    var appEdit = AppEdit();
    appEdit = await _api.edits.insert(appEdit, packageName);
    return AndroidPublisherAppEdit(appEdit: appEdit, publisher: this);
  }

  /// Read only app edit
  Future<T> readOnlyAppEdit<T>(
      Future<T> Function(AndroidPublisherAppEdit appEdit) action) async {
    var apAppEdit = await newAppEdit();
    try {
      return await action(apAppEdit);
    } catch (e) {
      await apAppEdit.delete();
      rethrow;
    }
  }

  /// Write app edit
  Future<T> writeAppEdit<T>(
      Future<T> Function(AndroidPublisherAppEdit appEdit) action,
      {bool? changesNotSentForReview}) async {
    var apAppEdit = await newAppEdit();
    try {
      var result = await action(apAppEdit);
      await apAppEdit.validateAndCommit(
          changesNotSentForReview: changesNotSentForReview);
      return result;
    } catch (e) {
      await apAppEdit.delete();
      rethrow;
    }
  }

  /// List tracks
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

  /// List bundles
  Future<List<int>> listBundles() async {
    return await readOnlyAppEdit((appEdit) async {
      return await appEdit.listBundles();
    });
  }

  /// Check if versionCode exists
  Future<bool> hasBundleVersionCode(int versionCode) async {
    return await readOnlyAppEdit((appEdit) async {
      return await appEdit.hasBundleVersionCode(versionCode);
    });
  }

  /// Publish version code
  Future<void> publishVersionCode(
      {required String trackName, required int versionCode}) async {
    await writeAppEdit((appEdit) async {
      await appEdit.publishTrack(
        trackName,
        versionCode: versionCode,
      );
    });
  }

  /// Publish version code
  Future<int?> getTrackVersionCode({required String trackName}) async {
    return await readOnlyAppEdit((appEdit) async {
      var versionCode = await appEdit.getTrackVersionCode(trackName);
      return versionCode;
    });
  }

  /// Check if versionCode exists, upload if not, publish.
  Future<void> uploadBundleAndPublish(
      {required String aabPath,
      required String trackName,
      required int versionCode,
      bool? changesNotSentForReview}) async {
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
      );
    }, changesNotSentForReview: changesNotSentForReview);
  }
}

/// Android Publisher App Edit
class AndroidPublisherAppEdit {
  /// Publisher
  final AndroidPublisher publisher;

  /// App edit
  final AppEdit appEdit;

  /// Id
  String get id => appEdit.id!;

  /// Package name
  String get packageName => publisher.packageName;

  AndroidPublisherApi get _api => publisher._api;

  /// Constructor
  AndroidPublisherAppEdit({required this.appEdit, required this.publisher});

  /// Safe
  Future<void> delete() async {
    try {
      await publisher._api.edits.delete(packageName, id);
    } catch (e) {
      stderr.writeln('Error deleting edit $id: $e');
    }
  }

  /// List bundles
  Future<List<int>> listBundles() async {
    var aabListResponse = await _api.edits.bundles.list(packageName, id);
    if (aabListResponse.bundles != null) {
      var bundleList = aabListResponse.bundles!.map((e) => e.versionCode!);
      return bundleList.toList();
    }
    return <int>[];
  }

  /// Check if versionCode exists
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

  /// Upload bundle
  Future<void> uploadBundle(String aabPath) async {
    var file = File(aabPath);
    var size = file.statSync().size;
    var media = Media(file.openRead(), size);

    stdout.writeln('uploading: $size bytes $aabPath');
    var aab =
        await _api.edits.bundles.upload(packageName, id, uploadMedia: media);
    stdout.writeln(aab.versionCode);
  }

  /// Publish track
  Future publishTrack(String trackName, {required int versionCode}) async {
    var track = Track();
    // track.track = trackName;
    track.releases = [
      TrackRelease()
        ..versionCodes = [versionCode.toString()]
        ..status = 'completed'
    ]; // v2:versionCodes = [versionCode];
    stdout.writeln('updating track: ${track.releases!.first.toJson()}');
    await _api.edits.tracks.update(track, packageName, appEdit.id!, trackName);
  }

  /// Publish track
  Future<int?> getTrackVersionCode(String trackName) async {
    //stdout.writeln('getting track: ${track.releases!.first.toJson()}');
    var track =
        await _api.edits.tracks.get(packageName, appEdit.id!, trackName);
    var releases = track.releases;
    if (releases != null) {
      for (var release in releases) {
        if (release.status == 'completed') {
          return int.parse(release.versionCodes!.first);
        }
      }
    }
    return null;
    //print(track.toJson());
  }

  /// Commit only as validate fails on changesNotSentForReview
  Future<void> validateAndCommit({bool? changesNotSentForReview}) async {
    if (changesNotSentForReview != true) {
      await _api.edits.validate(packageName, id);
    }
    await _api.edits.commit(packageName, id,
        changesNotSentForReview: changesNotSentForReview);
  }
}
