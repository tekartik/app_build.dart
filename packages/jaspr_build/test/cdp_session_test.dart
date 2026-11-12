@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:tekartik_jaspr_build/jaspr_screenshot.dart';
import 'package:test/test.dart';

void main() {
  test('CdpSession call after the page went away', () async {
    var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var closed = Completer<void>();
    server.listen((request) async {
      var socket = await WebSocketTransformer.upgrade(request);
      // The page goes away (Chrome crashed, the tab was closed).
      await socket.close();
      closed.complete();
    });
    try {
      var session = await CdpSession.connect('ws://127.0.0.1:${server.port}');
      await closed.future;
      // The session sees the end of the connection.
      await session.events.toList();
      await expectLater(
        session
            .call('Runtime.evaluate', {'expression': '1'})
            .timeout(const Duration(seconds: 5)),
        throwsA(isA<CdpException>()),
      );
      await expectLater(session.evaluate('1'), throwsA(isA<CdpException>()));
    } finally {
      await server.close(force: true);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
