import 'dart:async';
import 'dart:io';

import 'package:googleapis/androidpublisher/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path/path.dart';
import 'package:tekartik_android_utils/aab_utils.dart';

import 'android_publisher.dart';

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

/// Uploads [localAab] to the Play Console without publishing it to any
/// track, skipping the upload when its version code is already there. See
/// [manageBundle] for the service account lookup.
Future uploadBundle(LocalAab localAab) async {
  return await manageBundle(
    localAab,
    uploadOptions: UploadOptions(upload: true),
  );
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
/// (defaults to `.local/service_account.json`), then, in a single Play
/// Console edit validated (unless
/// [PublishOptions.changesNotSentForReview]) and committed, the way
/// [AndroidPublisher.uploadBundleAndPublish] does:
/// - when [uploadOptions] requests it (not by default, see [uploadBundle]),
///   uploads the bundle at [localAab]'s path, unless its version code is
///   already there;
/// - without upload, expects the version code to be there already, throwing
///   a [StateError] otherwise;
/// - when [publishOptions] has a track (none by default, see
///   [publishBundle]), publishes the version code to it with its
///   [PublishOptions.releaseStatus].
///
/// The edit is deleted (discarding changes) and the error rethrown if any
/// step fails. Nothing is done when there is neither an upload nor a track.
Future manageBundle(
  LocalAab localAab, {
  String? serviceAccountPath,
  UploadOptions? uploadOptions,
  PublishOptions? publishOptions,
}) async {
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
  try {
    var publisher = AndroidPublisher(
      packageName: localAab.packageName!,
      api: AndroidPublisherApi(client),
    );
    await manageBundleWithPublisher(
      publisher,
      localAab,
      uploadOptions: uploadOptions,
      publishOptions: publishOptions,
    );
  } finally {
    client.close();
  }
}

/// What [manageBundle] does with an opened [publisher], see there.
Future<void> manageBundleWithPublisher(
  AndroidPublisher publisher,
  LocalAab localAab, {
  UploadOptions? uploadOptions,
  PublishOptions? publishOptions,
}) async {
  var upload = uploadOptions?.upload ?? false;
  var track = publishOptions?.track;
  var versionCode = localAab.versionCode;
  stdout.writeln(
    'package: ${publisher.packageName}, versionCode: $versionCode',
  );
  if (!upload && track == null) {
    stdout.writeln('nothing to upload or publish');
    return;
  }
  var releaseStatus = publishOptions?.releaseStatus;
  var changesNotSentForReview = publishOptions?.changesNotSentForReview;
  if (upload && track != null) {
    await publisher.uploadBundleAndPublish(
      aabPath: localAab.path,
      trackName: track,
      versionCode: versionCode,
      releaseStatus: releaseStatus,
      changesNotSentForReview: changesNotSentForReview,
    );
    return;
  }
  await publisher.writeAppEdit((appEdit) async {
    var found = await appEdit.hasBundleVersionCode(versionCode);
    if (upload) {
      if (found) {
        stdout.writeln('versionCode $versionCode already exists');
      } else {
        await appEdit.uploadBundle(localAab.path);
      }
    } else {
      if (!found) {
        throw StateError('Version $versionCode not found');
      }
      await appEdit.publishTrack(
        track!,
        versionCode: versionCode,
        releaseStatus: releaseStatus,
      );
    }
  }, changesNotSentForReview: changesNotSentForReview);
}
