import 'dart:async';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:googleapis/androidpublisher/v3.dart';
// ignore: depend_on_referenced_packages
import 'package:googleapis_auth/auth_io.dart';
//import 'package:googleapis'

const androidPublisherScopes = [AndroidPublisherApi.androidpublisherScope];

Future<AndroidPublisherApi> initPublishApiClient(
    {required Map serviceAccount}) async {
  var credentials = ServiceAccountCredentials.fromJson(serviceAccount);
  var client =
      await clientViaServiceAccount(credentials, androidPublisherScopes);
  var publish = AndroidPublisherApi(client);
  return publish;
}

class AndroidPublisher {
  final String packageName;
  final AndroidPublisherApi api;

  AndroidPublisher({required this.packageName, required this.api});

  /// New edit, delete on error
  Future<AndroidPublisherAppEdit> newAppEdit() async {
    var appEdit = AppEdit();
    appEdit = await api.edits.insert(appEdit, packageName);
    return AndroidPublisherAppEdit(appEdit: appEdit, publisher: this);
  }

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

  Future<T> writeAppEdit<T>(
      Future<T> Function(AndroidPublisherAppEdit appEdit) action) async {
    var apAppEdit = await newAppEdit();
    try {
      var result = await action(apAppEdit);
      await apAppEdit.validateAndCommit();
      return result;
    } catch (e) {
      await apAppEdit.delete();
      rethrow;
    }
  }

  Future<void> listTracks() async {
    var apAppEdit = await newAppEdit();
    try {
      var response = await api.edits.tracks.list(packageName, apAppEdit.id);
      for (var track in response.tracks!) {
        print(track.track);
      }
    } finally {
      await apAppEdit.delete();
    }
  }

  Future<void> listBundles() async {
    await readOnlyAppEdit((appEdit) async {
      await appEdit.listBundles();
    });
  }

  Future<bool> hasBundleVersionCode(int versionCode) async {
    return await readOnlyAppEdit((appEdit) async {
      return await appEdit.hasBundleVersionCode(versionCode);
    });
  }
}

class AndroidPublisherAppEdit {
  final AndroidPublisher publisher;
  final AppEdit appEdit;

  String get id => appEdit.id!;

  String get packageName => publisher.packageName;

  AndroidPublisherApi get api => publisher.api;

  AndroidPublisherAppEdit({required this.appEdit, required this.publisher});

  /// Safe
  Future<void> delete() async {
    try {
      await publisher.api.edits.delete(packageName, id);
    } catch (e) {
      print('Error deleting edit $id: $e');
    }
  }

  Future<void> listBundles() async {
    var aabListResponse = await api.edits.bundles.list(packageName, id);
    if (aabListResponse.bundles != null) {
      for (var bundle in aabListResponse.bundles!) {
        print('aab: ${bundle.versionCode}');
        //print(bundle.versionCode);
      }
    }
  }

  Future<bool> hasBundleVersionCode(int versionCode) async {
    var aabListResponse = await api.edits.bundles.list(packageName, id);
    if (aabListResponse.bundles != null) {
      for (var bundle in aabListResponse.bundles!) {
        print('aab: ${bundle.versionCode}');
        //print(bundle.versionCode);
        if (bundle.versionCode == versionCode) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> uploadBundle(String aabPath) async {
    var file = File(aabPath);
    var size = file.statSync().size;
    var media = Media(file.openRead(), size);

    print('uploading: $size bytes $aabPath');
    var aab =
        await api.edits.bundles.upload(packageName, id, uploadMedia: media);
    print(aab.versionCode);
  }

  Future publishTrack(String trackName, {required int versionCode}) async {
    var track = Track();
    // track.track = trackName;
    track.releases = [
      TrackRelease()
        ..versionCodes = [versionCode.toString()]
        ..status = 'completed'
    ]; // v2:versionCodes = [versionCode];
    print('updating track: ${track.releases!.first.toJson()}');
    await api.edits.tracks.update(track, packageName, appEdit.id!, trackName);
  }

  Future<void> validateAndCommit() async {
    await api.edits.validate(packageName, id);
    await api.edits.commit(packageName, id);
  }
}
