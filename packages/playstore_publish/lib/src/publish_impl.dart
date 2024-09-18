import 'dart:async';
import 'dart:io';

import 'package:googleapis/androidpublisher/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart';
import 'package:tekartik_android_utils/aab_utils.dart';
//import 'package:googleapis'

const _scopes = [AndroidPublisherApi.androidpublisherScope];

/// Local aab
class LocalAab {
  /// Path to the aab
  String path;

  /// Aab info
  AabInfo? aabInfo;

  /// Constructor
  LocalAab(this.path, [this.aabInfo]);

  /// Version code
  int get versionCode => int.parse(aabInfo!.versionCode!);

  /// Init
  Future init() async {
    if (aabInfo == null) {
      if (!File(path).existsSync()) {
        stderr.writeln('missing file $path');
      }
      aabInfo = await getAabInfo(path);
    }
  }

  /// Package name
  String? get packageName => aabInfo!.name;

  /// To map
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
  track ??= publishTrackInternal;
  return await manageBundle(localAab,
      publishOptions: PublishOptions(track: track));
}

/// Upload options
class UploadOptions {
  /// Upload
  final bool upload;

  /// Constructor
  UploadOptions({required this.upload});
}

/// Publish options
class PublishOptions {
  /// Track
  final String track;

  /// Constructor
  PublishOptions({required this.track});
}

final _noPublishOptions = PublishOptions(track: _noTrack);
final _noUploadOptions = UploadOptions(upload: false);

/// Compat
// @Deprecated('Use publishTrackInternal')
const internalTrack = publishTrackInternal;

/// Common track
const publishTrackInternal = 'internal';

/// Production track
const publishTrackProduction = 'production';

/// Beta track
const publishTrackBeta = 'beta';

/// Alpha track
const publishTrackAlpha = 'alpha';

/// Wear beta track
const publishTrackWearBeta = 'wear:beta';

/// Wear internal track
const publishTrackWearInternal = 'wear:internal';

/// Wear production track
const publishTrackWearProduction = 'wear:production';

/// manageBundle
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
    stderr.writeln(e);
    exception = e;
  }
  if (exception != null) {
    if (!serviceAccountFileFound) {
      stderr.writeln('No service account file found in $serviceAccountFile');
    }
    stderr.writeln(exception);
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
      stdout.writeln(track.track);
    }

    stdout
        .writeln('package: $packageName, versionCode: ${localAab.versionCode}');
    // Search in apks
    var apkListResponse =
        await publish.edits.apks.list(packageName, appEdit.id!);
    var found = false;
    if (apkListResponse.apks != null) {
      for (var apk in apkListResponse.apks!) {
        stdout.writeln('apk: ${apk.versionCode}');
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
        stdout.writeln('aab: ${bundle.versionCode}');
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
      stdout.writeln('uploading: $size bytes $localAab');
      var aab = await publish.edits.bundles
          .upload(packageName, editId!, uploadMedia: media);
      stdout.writeln(aab.versionCode);
      versionCode = aab.versionCode;
    } else {
      stdout.writeln('publishing $localAab');
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
      stdout.writeln('updating track: ${track.releases!.first.toJson()}');
      await publish.edits.tracks
          .update(track, packageName, appEdit.id!, trackName);
    }

    stdout.writeln('uploaded');

    // await publishTrack('internal'); // 'alpha'
    if (publishOptions != _noPublishOptions) {
      await publishTrack(publishOptions.track);
    }

    await publish.edits.validate(packageName, editId!);
    await publish.edits.commit(packageName, editId);
  } catch (e) {
    stderr.writeln(e);
    await publish.edits.delete(packageName, editId!);
    rethrow;
  } finally {
    // await publish.edits.delete(packageName, appEdit.id);
  }
}
