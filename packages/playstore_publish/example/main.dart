// Uploads a bundle and releases it on the internal testing track:
//
//   dart run example/main.dart build/app/outputs/bundle/release/app-release.aab
//
// Needs .local/service_account.json (a Google Cloud service account key
// invited in the Play Console with release rights on the app) and
// bundletool on the PATH (to read the package name and version code).
import 'dart:convert';
import 'dart:io';

import 'package:tekartik_android_utils/aab_utils.dart';
import 'package:tekartik_playstore_publish/playstore_publish.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run example/main.dart <app-release.aab>');
    exitCode = 64;
    return;
  }
  var aabPath = args.first;
  var aabInfo = await getAabInfo(aabPath);
  var serviceAccount =
      jsonDecode(await File('.local/service_account.json').readAsString())
          as Map;

  var client = await initAndroidPublisherClient(serviceAccount: serviceAccount);
  var publisher = client.getPublisher(aabInfo.name!);
  // One edit: upload (skipped when the version code is already there),
  // release on the track (full rollout), validate and commit.
  await publisher.uploadBundleAndPublish(
    aabPath: aabPath,
    trackName: publishTrackInternal,
    versionCode: int.parse(aabInfo.versionCode!),
  );
}
