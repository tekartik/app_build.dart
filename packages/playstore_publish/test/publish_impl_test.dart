@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:path/path.dart';
import 'package:tekartik_android_utils/aab_utils.dart';
import 'package:tekartik_playstore_publish/playstore_publish.dart';
import 'package:tekartik_playstore_publish/src/publish_impl.dart'
    show manageBundleWithPublisher;
import 'package:test/test.dart';

const _packageName = 'com.example.app';
const _editId = 'edit1';

/// A fake Play Console, answering the edit calls of one package in memory and
/// recording them as `METHOD what`.
class _FakePlayConsole {
  /// The version codes of the uploaded bundles.
  final List<int> bundles;

  /// The calls made, e.g. `POST insert`, `GET bundles`, `PUT track internal`.
  final calls = <String>[];

  /// The body of the last track update.
  Map<String, Object?>? trackUpdate;

  /// The query of the last commit.
  Map<String, String>? commitQuery;

  _FakePlayConsole({List<int>? bundles}) : bundles = bundles ?? <int>[];

  late final publisher = AndroidPublisher(
    packageName: _packageName,
    api: AndroidPublisherApi(MockClient(_handle)),
  );

  Future<http.Response> _handle(http.Request request) async {
    http.Response json(Object? body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
    var path = request.url.path;
    var method = request.method;
    var editsPath = '/androidpublisher/v3/applications/$_packageName/edits';
    var editPath = '$editsPath/$_editId';
    void call(String what) => calls.add('$method $what');
    if (method == 'POST' && path == editsPath) {
      call('insert');
      return json({'id': _editId});
    } else if (method == 'GET' && path == '$editPath/bundles') {
      call('bundles');
      return json({
        'bundles': [
          for (var versionCode in bundles) {'versionCode': versionCode},
        ],
      });
    } else if (method == 'POST' &&
        path ==
            '/upload/androidpublisher/v3/applications/$_packageName/edits/$_editId/bundles') {
      call('upload');
      bundles.add(12);
      return json({'versionCode': 12});
    } else if (method == 'PUT' && path.startsWith('$editPath/tracks/')) {
      var track = path.substring('$editPath/tracks/'.length);
      call('track $track');
      trackUpdate = jsonDecode(request.body) as Map<String, Object?>;
      return json(trackUpdate);
    } else if (method == 'GET' && path.startsWith('$editPath/tracks/')) {
      var track = path.substring('$editPath/tracks/'.length);
      call('track $track');
      return json({
        'track': track,
        'releases': [
          {
            'status': 'completed',
            'versionCodes': ['10'],
          },
        ],
      });
    } else if (method == 'POST' && path == '$editPath:validate') {
      call('validate');
      return json({'id': _editId});
    } else if (method == 'POST' && path == '$editPath:commit') {
      call('commit');
      commitQuery = request.url.queryParameters;
      return json({'id': _editId});
    } else if (method == 'DELETE' && path == editPath) {
      call('delete');
      return http.Response('', 204);
    }
    throw StateError('unexpected $method ${request.url}');
  }

  /// The status of the last track update release.
  Object? get trackStatus =>
      ((trackUpdate!['releases'] as List).single as Map)['status'];
}

void main() {
  late Directory dir;
  late LocalAab localAab;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('playstore_publish_test');
    var path = join(dir.path, 'app-release.aab');
    await File(path).writeAsString('fake aab');
    localAab = LocalAab(
      path,
      AabInfo()
        ..name = _packageName
        ..versionCode = '12',
    );
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  group('AndroidPublisher', () {
    test('listBundles deletes its edit', () async {
      var console = _FakePlayConsole(bundles: [10, 11]);
      expect(await console.publisher.listBundles(), [10, 11]);
      expect(console.calls, ['POST insert', 'GET bundles', 'DELETE delete']);
    });

    test('getTrackVersionCode deletes its edit', () async {
      var console = _FakePlayConsole();
      expect(
        await console.publisher.getTrackVersionCode(trackName: 'beta'),
        10,
      );
      expect(console.calls, ['POST insert', 'GET track beta', 'DELETE delete']);
    });
  });

  group('manageBundleWithPublisher', () {
    test('upload only', () async {
      var console = _FakePlayConsole(bundles: [11]);
      await manageBundleWithPublisher(
        console.publisher,
        localAab,
        uploadOptions: UploadOptions(upload: true),
      );
      expect(console.calls, [
        'POST insert',
        'GET bundles',
        'POST upload',
        'POST validate',
        'POST commit',
      ]);
    });

    test('upload only, already uploaded', () async {
      var console = _FakePlayConsole(bundles: [12]);
      await manageBundleWithPublisher(
        console.publisher,
        localAab,
        uploadOptions: UploadOptions(upload: true),
        publishOptions: PublishOptions(),
      );
      expect(console.calls, [
        'POST insert',
        'GET bundles',
        'POST validate',
        'POST commit',
      ]);
    });

    test('publish only', () async {
      var console = _FakePlayConsole(bundles: [12]);
      await manageBundleWithPublisher(
        console.publisher,
        localAab,
        uploadOptions: UploadOptions(upload: false),
        publishOptions: PublishOptions(track: publishTrackBeta),
      );
      expect(console.calls, [
        'POST insert',
        'GET bundles',
        'PUT track beta',
        'POST validate',
        'POST commit',
      ]);
      expect(console.trackStatus, 'completed');
    });

    test('publish only, not uploaded', () async {
      var console = _FakePlayConsole(bundles: [11]);
      await expectLater(
        manageBundleWithPublisher(
          console.publisher,
          localAab,
          publishOptions: PublishOptions(track: publishTrackInternal),
        ),
        throwsStateError,
      );
      expect(console.calls, ['POST insert', 'GET bundles', 'DELETE delete']);
    });

    test('upload and publish as a draft not sent for review', () async {
      var console = _FakePlayConsole();
      await manageBundleWithPublisher(
        console.publisher,
        localAab,
        uploadOptions: UploadOptions(upload: true),
        publishOptions: PublishOptions(
          track: publishTrackInternal,
          releaseStatus: AndroidPublisher.releaseStatusDraft,
          changesNotSentForReview: true,
        ),
      );
      expect(console.calls, [
        'POST insert',
        'GET bundles',
        'POST upload',
        'PUT track internal',
        'POST commit',
      ]);
      expect(console.trackStatus, 'draft');
      expect(console.commitQuery!['changesNotSentForReview'], 'true');
    });

    test('nothing to do', () async {
      var console = _FakePlayConsole(bundles: [12]);
      await manageBundleWithPublisher(
        console.publisher,
        localAab,
        publishOptions: PublishOptions(),
      );
      await manageBundleWithPublisher(console.publisher, localAab);
      expect(console.calls, isEmpty);
    });
  });
}
