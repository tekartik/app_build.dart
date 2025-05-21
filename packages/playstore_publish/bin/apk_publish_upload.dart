#!/usr/bin/env dart
// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' // ignore: depend_on_referenced_packages
    as commons;
import 'package:args/args.dart';
import 'package:googleapis/androidpublisher/v3.dart';
import 'package:googleapis/people/v1.dart';
import 'package:process_run/stdio.dart';
import 'package:tekartik_android_utils/apk_utils.dart';
import 'package:tekartik_android_utils/src/import.dart';
import 'package:tekartik_io_auth_utils/io_auth_utils.dart';

final List<String> scopes = [
  //emailScope,
  AndroidPublisherApi.androidpublisherScope,
]; //['email'];

const String alphaTrackName = 'alpha';

const String _flagHelp = 'help';
const String _optionAuth = 'auth';

Future main(List<String> args) async {
  var parser = ArgParser();

  parser.addFlag(_flagHelp, abbr: 'h', help: 'Usage help', negatable: false);
  parser.addOption(
    _optionAuth,
    help: 'Auth json definition file',
    defaultsTo: null,
  );

  var results = parser.parse(args);

  parser.parse(args);

  var help = parseBool(results[_flagHelp])!;
  var authJsonFile = results[_optionAuth]?.toString();

  if (authJsonFile == null) {
    stderr.writeln('Missing auth json file');
    help = true;
  }
  void usage() {
    stdout.writeln('apk_publish_upload <path_to_apk_file> --auth auth.json');
    stdout.writeln(parser.usage);
  }

  if (help) {
    usage();
    return;
  }

  if (results.rest.length == 1) {
    // New just give the apk
    var apkFile = results.rest[0];

    if (File(authJsonFile!).existsSync()) {
      var authClientInfo = (await AuthClientInfo.load(filePath: authJsonFile))!;
      stdout.writeln(authClientInfo);
      var authClient = await authClientInfo.getClient(scopes);

      try {
        var peopleApi = PeopleServiceApi(authClient);
        var person = await peopleApi.people.get('me');
        stdout.writeln(person.toJson());
      } catch (e) {
        stderr.writeln('PlusApi error $e');
      }

      var api = AndroidPublisherApi(authClient);
      /*
        String packageName = 'com.tekartik.buvettekpcm';
        AppEdit appEdit = await api.edits.insert(null, packageName);
        print(appEdit.toJson());
        await api.edits.delete(packageName, appEdit.id);
        */
      var apkInfo = (await getApkInfo(apkFile))!;
      var packageName = apkInfo.name!;
      var appEdit = AppEdit();
      appEdit = await api.edits.insert(appEdit, packageName);
      try {
        stdout.writeln(appEdit.toJson());

        stdout.writeln('name : ${apkInfo.name}');
        stdout.writeln('versionCode : ${apkInfo.versionCode}');
        stdout.writeln('versionName : ${apkInfo.versionName}');

        var data = await File(apkFile).readAsBytes();
        var media = commons.Media(Stream.fromIterable([data]), data.length);
        stdout.writeln('uploading ${data.length}...');
        var apk = await api.edits.apks.upload(
          packageName,
          appEdit.id!,
          uploadMedia: media,
        );
        stdout.writeln('uploaded');
        stdout.writeln('versionCode: ${apk.versionCode}');

        var track = Track();
        // track.track = trackName;
        track.releases = [
          TrackRelease()
            ..versionCodes = [apk.versionCode.toString()]
            ..status = 'completed',
        ]; // v2:versionCodes = [versionCode];
        track = await api.edits.tracks.update(
          track,
          packageName,
          appEdit.id!,
          alphaTrackName,
        );
        stdout.writeln('versionCodes: ${track.releases!.first.versionCodes}');

        await api.edits.commit(packageName, appEdit.id!);
        stdout.writeln('commited');
      } catch (e) {
        try {
          await api.edits.delete(packageName, appEdit.id!);
        } catch (e2) {
          stderr.writeln('edits.delete error $e2');
        }
        rethrow;
      }
    } else {
      stderr.writeln('auth json file not found: $authJsonFile');
    }
  } else {
    stderr.writeln('only one aab file must be specified: $authJsonFile');
  }
}
