import 'dart:async';
import 'dart:io';

import 'package:googleapis/androidpublisher/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart';
import 'package:tekartik_android_utils/aab_utils.dart';
//import 'package:googleapis'

const _scopes = [AndroidPublisherApi.androidpublisherScope];

class LocalAab {
  String path;
  AabInfo? aabInfo;

  LocalAab(this.path, [this.aabInfo]);

  int get versionCode => int.parse(aabInfo!.versionCode!);

  Future init() async {
    if (aabInfo == null) {
      if (!File(path).existsSync()) {
        print('missing file $path');
      }
      aabInfo = await getAabInfo(path);
    }
  }

  String? get packageName => aabInfo!.name;

  Map<String, dynamic> toMap() {
    var map = aabInfo!.toMap();
    map['path'] = path;
    return map;
  }

  @override
  String toString() => toMap().toString();
}

const _noTrack = '_no_track_';

/// Upload aabs
Future uploadBundle(LocalAab localAab) async {
  return await manageBundle(localAab, publishOptions: _noPublishOptions);
}

/// Publish to internal by default
Future publishBundle(LocalAab localAab, {String? track}) async {
  track ??= internalTrack;
  return await manageBundle(localAab,
      publishOptions: PublishOptions(track: track));
}

class UploadOptions {
  final bool upload;

  UploadOptions({required this.upload});
}

class PublishOptions {
  final String track;

  PublishOptions({required this.track});
}

final _noPublishOptions = PublishOptions(track: _noTrack);
final _noUploadOptions = UploadOptions(upload: false);
const internalTrack = 'internal';

Future manageBundle(LocalAab localAab,
    {String? serviceAccountPath,
    UploadOptions? uploadOptions,
    PublishOptions? publishOptions}) async {
  uploadOptions ??= _noUploadOptions;
  publishOptions ??= _noPublishOptions;
  await localAab.init();

  ServiceAccountCredentials? credentials;
  // Try to look for a local service account
  Object? exception;
  var serviceAccountFileFound = false;
  var serviceAccountFile =
      File(serviceAccountPath ?? join('.local', 'service_account.json'));
  try {
    var serviceAccountJson = await serviceAccountFile.readAsString();
    // print(serviceAccountJson);
    credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    serviceAccountFileFound = true;
  } catch (e) {
    print(e);
    exception = e;
  }
  if (exception != null) {
    if (!serviceAccountFileFound) {
      stderr.writeln('No service account file found in $serviceAccountFile');
    }
    print(exception);
    throw exception;
  }
  var client = await clientViaServiceAccount(credentials!, _scopes);
  var publish = AndroidPublisherApi(client);

  var appEdit = AppEdit();
  var packageName = localAab.packageName!;
  appEdit = await publish.edits.insert(appEdit, localAab.packageName!);
  var editId = appEdit.id;
  try {
    var response = await publish.edits.tracks.list(packageName, appEdit.id!);
    for (var track in response.tracks!) {
      print(track.track);
    }

    print('package: $packageName, versionCode: ${localAab.versionCode}');
    // Search in apks
    var apkListResponse =
        await publish.edits.apks.list(packageName, appEdit.id!);
    var found = false;
    if (apkListResponse.apks != null) {
      for (var apk in apkListResponse.apks!) {
        print('apk: ${apk.versionCode}');
        if (apk.versionCode == localAab.versionCode) {
          found = true;
          break;
        }
      }
    }

    if (found) {
      if (uploadOptions != _noUploadOptions) {
        throw 'Version already uploaded as apk';
      }
    }

    // Search and aabs
    var aabListResponse =
        await publish.edits.bundles.list(packageName, appEdit.id!);
    if (aabListResponse.bundles != null) {
      for (var bundle in aabListResponse.bundles!) {
        print('aab: ${bundle.versionCode}');
        //print(bundle.versionCode);
        if (bundle.versionCode == localAab.versionCode) {
          // throw 'Version already uploaded';
          found = true;
          break;
        }
      }
    }

    if (found) {
      if (uploadOptions != _noUploadOptions) {
        throw 'Version already uploaded as aab';
      }
    } else {
      if (uploadOptions == _noUploadOptions) {
        // if (devWarning(false)) {
        throw 'Version ${localAab.versionCode} not found';
        // }
      }
    }

    var file = File(localAab.path);
    var size = file.statSync().size;
    var media = Media(file.openRead(), size);

    int? versionCode;
    if (uploadOptions != _noUploadOptions) {
      print('uploading: $size bytes $localAab');
      var aab = await publish.edits.bundles
          .upload(packageName, editId!, uploadMedia: media);
      print(aab.versionCode);
      versionCode = aab.versionCode;
    } else {
      print('publishing $localAab');
      versionCode = localAab.versionCode;
    }

    Future publishTrack(String trackName) async {
      var track = Track();
      // track.track = trackName;
      track.releases = [
        TrackRelease()
          ..versionCodes = [versionCode.toString()]
          ..status = 'completed'
      ]; // v2:versionCodes = [versionCode];
      print('updating track: ${track.releases!.first.toJson()}');
      await publish.edits.tracks
          .update(track, packageName, appEdit.id!, trackName);
    }

    print('uploaded');

    // await publishTrack('internal'); // 'alpha'
    if (publishOptions != _noPublishOptions) {
      await publishTrack(publishOptions.track);
    }

    await publish.edits.validate(packageName, editId!);
    await publish.edits.commit(packageName, editId);
  } catch (e) {
    print(e);
    await publish.edits.delete(packageName, editId!);
    rethrow;
  } finally {
    // await publish.edits.delete(packageName, appEdit.id);
  }
}
