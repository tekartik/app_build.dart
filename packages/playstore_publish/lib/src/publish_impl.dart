import 'dart:async';
import 'dart:io';

import 'package:googleapis/androidpublisher/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart';
import 'package:tekartik_android_utils/aab_utils.dart';

//import 'package:googleapis'

const _scopes = [AndroidPublisherApi.androidpublisherScope];

/// A local `.aab` file and its parsed manifest info, used as input to
/// [manageBundle]/[uploadBundle]/[publishBundle].
class LocalAab {
  /// Path to the `.aab` file on disk.
  String path;

  /// Parsed manifest info for [path], populated by [init] if not provided
  /// up front.
  AabInfo? aabInfo;

  /// Creates a reference to the `.aab` at [path], optionally with
  /// already-known [aabInfo] (otherwise call [init] before reading
  /// [versionCode]/[packageName]).
  LocalAab(this.path, [this.aabInfo]);

  /// The bundle's version code, parsed from [aabInfo].
  ///
  /// [init] must have been called (or [aabInfo] provided) first.
  int get versionCode => int.parse(aabInfo!.versionCode!);

  /// Populates [aabInfo] from [path]'s manifest, if not already set. Logs
  /// to stderr (but does not throw) if [path] doesn't exist.
  Future init() async {
    if (aabInfo == null) {
      if (!File(path).existsSync()) {
        stderr.writeln('missing file $path');
      }
      aabInfo = await getAabInfo(path);
    }
  }

  /// The bundle's package name, from [aabInfo].
  ///
  /// [init] must have been called (or [aabInfo] provided) first.
  String? get packageName => aabInfo!.name;

  /// Converts this to a `{...aabInfo, path}` map, mainly for
  /// debugging/logging via [toString].
  Map<String, dynamic> toMap() {
    var map = aabInfo!.toMap();
    map['path'] = path;
    return map;
  }

  @override
  String toString() => toMap().toString();
}

const _noTrack = '_no_track_';

/// Uploads [localAab] to the Play Console without publishing it to any
/// track. See [manageBundle] for the service account lookup and upload
/// behavior.
Future uploadBundle(LocalAab localAab) async {
  return await manageBundle(localAab, publishOptions: _noPublishOptions);
}

/// Publishes the already-uploaded [localAab] to [track] (defaults to
/// [publishTrackInternal]), without re-uploading it. See [manageBundle] for
/// the service account lookup and publish behavior.
Future publishBundle(LocalAab localAab, {String? track}) async {
  track ??= publishTrackInternal;
  return await manageBundle(
    localAab,
    publishOptions: PublishOptions(track: track),
  );
}

/// Whether [manageBundle] should upload the bundle.
class UploadOptions {
  /// If `true`, the bundle is uploaded; if `false`, upload is skipped
  /// (the bundle is expected to already exist on the Play Console).
  final bool upload;

  /// Creates upload options with the given [upload] flag.
  UploadOptions({required this.upload});
}

/// Controls whether and how [manageBundle] publishes the bundle to a
/// release track.
class PublishOptions {
  /// Release track to publish to (e.g. [publishTrackInternal]), or `null`
  /// to skip publishing.
  final String? track;

  /// If `true`, changes that have not been sent for review are ignored
  /// (skips the validate step). Sometimes necessary for initial
  /// publishing.
  final bool? changesNotSentForReview;

  /// Release status to set (e.g. `'completed'`, `'draft'`); defaults to
  /// `'completed'` when `null`.
  final String? releaseStatus;

  /// Creates publish options targeting [track] (`null` to skip
  /// publishing), with [changesNotSentForReview] and [releaseStatus]
  /// defaulting to `null` (see their field docs).
  PublishOptions({
    this.track,
    this.changesNotSentForReview,
    this.releaseStatus,
  });
}

final _noPublishOptions = PublishOptions(track: _noTrack);
final _noUploadOptions = UploadOptions(upload: false);

/// Compat alias for [publishTrackInternal].
// @Deprecated('Use publishTrackInternal')
const internalTrack = publishTrackInternal;

/// The `'internal'` testing track.
const publishTrackInternal = 'internal';

/// The `'production'` release track.
const publishTrackProduction = 'production';

/// The `'beta'` testing track.
const publishTrackBeta = 'beta';

/// The `'alpha'` testing track.
const publishTrackAlpha = 'alpha';

/// The `'wear:beta'` Wear OS testing track.
const publishTrackWearBeta = 'wear:beta';

/// The `'wear:internal'` Wear OS testing track.
const publishTrackWearInternal = 'wear:internal';

/// The `'wear:production'` Wear OS release track.
const publishTrackWearProduction = 'wear:production';

/// Uploads and/or publishes [localAab] using a Google service account.
///
/// Looks for the service account JSON key at [serviceAccountPath]
/// (defaults to `.local/service_account.json`), opens a Play Console edit,
/// and:
/// - if [uploadOptions] requests upload (defaults to not uploading — see
///   [uploadBundle]/[publishBundle] for the common cases), uploads the
///   bundle at [localAab]'s path, throwing if that version code was
///   already uploaded as an apk;
/// - if [uploadOptions] does *not* request upload, expects the version
///   code to already exist as an apk or bundle, throwing if it's missing;
/// - if [publishOptions] specifies a track, publishes the (possibly newly
///   uploaded) version code to that track;
/// - validates and commits the edit.
///
/// The edit is deleted (discarding changes) and the error rethrown if any
/// step fails.
Future manageBundle(
  LocalAab localAab, {
  String? serviceAccountPath,
  UploadOptions? uploadOptions,
  PublishOptions? publishOptions,
}) async {
  uploadOptions ??= _noUploadOptions;
  publishOptions ??= _noPublishOptions;
  await localAab.init();

  ServiceAccountCredentials? credentials;
  // Try to look for a local service account
  Object? exception;
  var serviceAccountFileFound = false;
  var serviceAccountFile = File(
    serviceAccountPath ?? join('.local', 'service_account.json'),
  );
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
    // ignore: only_throw_errors
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

    stdout.writeln(
      'package: $packageName, versionCode: ${localAab.versionCode}',
    );
    // Search in apks
    var apkListResponse = await publish.edits.apks.list(
      packageName,
      appEdit.id!,
    );
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
        // ignore: only_throw_errors
        throw 'Version already uploaded as apk';
      }
    }

    // Search and aabs
    var aabListResponse = await publish.edits.bundles.list(
      packageName,
      appEdit.id!,
    );
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
        // ignore: only_throw_errors
        throw 'Version already uploaded as aab';
      }
    } else {
      if (uploadOptions == _noUploadOptions) {
        // if (devWarning(false)) {
        // ignore: only_throw_errors
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
      var aab = await publish.edits.bundles.upload(
        packageName,
        editId!,
        uploadMedia: media,
      );
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
          ..status = 'completed',
      ]; // v2:versionCodes = [versionCode];
      stdout.writeln('updating track: ${track.releases!.first.toJson()}');
      await publish.edits.tracks.update(
        track,
        packageName,
        appEdit.id!,
        trackName,
      );
    }

    stdout.writeln('uploaded');

    // await publishTrack('internal'); // 'alpha'
    if (publishOptions != _noPublishOptions) {
      await publishTrack(publishOptions.track ?? publishTrackInternal);
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
