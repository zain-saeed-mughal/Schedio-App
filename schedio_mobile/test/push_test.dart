import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/app/push_routing.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/firebase_push.dart';
import 'package:schedio_mobile/core/push.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';

import 'env_and_errors_test.dart' show ScriptedAdapter, json;

class FakeTransport implements PushTransport {
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();
  bool granted = true, deleted = false;
  PushMessage? initial;

  @override
  String get platform => 'android';
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<String?> token() async => 'token-1';
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;
  @override
  Stream<PushMessage> get onMessageOpened => opened.stream;
  @override
  Future<PushMessage?> initialMessage() async => initial;
  @override
  Future<void> deleteToken() async => deleted = true;
  final shown = <PushMessage>[];
  @override
  Future<void> showForeground(PushMessage message) async => shown.add(message);
}

void main() {
  late List<RequestOptions> requests;
  late Api api;

  setUp(() {
    requests = [];
    api = Api(
      client: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
        ..httpClientAdapter = ScriptedAdapter((o) {
          requests.add(o);
          return json({'message': 'ok'}, 200);
        }),
    )..token = 'session';
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('registers the device token once and again after a refresh', () async {
    final transport = FakeTransport();
    final push = PushService(api, transport, enabled: true);
    await push.start();
    expect(requests.single.method, 'POST');
    expect(requests.single.path, 'devices');
    expect(requests.single.data, {'token': 'token-1', 'platform': 'android'});
    await push.register('token-1');
    expect(requests, hasLength(1));
    transport.refresh.add('token-2');
    await settle();
    expect(requests.last.data, {'token': 'token-2', 'platform': 'android'});
    expect(push.registeredToken, 'token-2');
  });

  test('a token refresh while offline does not raise an unhandled error', () async {
    var offline = false;
    final flaky = Api(
      client: Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))
        ..httpClientAdapter = ScriptedAdapter((o) {
          if (offline) throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
          return json({'message': 'ok'}, 200);
        }),
    )..token = 'session';
    final transport = FakeTransport();
    final push = PushService(flaky, transport, enabled: true);
    await push.start();
    offline = true;
    final errors = <Object>[];
    await runZonedGuarded(() async {
      transport.refresh.add('token-2');
      await settle();
    }, (e, _) => errors.add(e));
    expect(errors, isEmpty);
    expect(push.registeredToken, 'token-1');
    offline = false;
    transport.refresh.add('token-3');
    await settle();
    expect(push.registeredToken, 'token-3');
  });

  test('foreground duplicates are shown once and taps are routed', () async {
    final transport = FakeTransport();
    final push = PushService(api, transport, enabled: true);
    final shown = <PushMessage>[], openedMessages = <PushMessage>[];
    push
      ..onForeground = shown.add
      ..onOpen = openedMessages.add;
    await push.start();
    final message = PushMessage.fromData({'notification_id': 'n1', 'type': 'meeting_reminder', 'meeting_id': 11});
    transport.foreground
      ..add(message)
      ..add(message);
    transport.opened.add(message);
    await settle();
    expect(shown, hasLength(1));
    expect(openedMessages.single.targetId, '11');
    expect(transport.shown, hasLength(1), reason: 'one system notification per message');
  });

  test('a cold start from a notification tap opens it', () async {
    final transport = FakeTransport()
      ..initial = PushMessage.fromData({'type': 'task_assigned', 'task_id': '7'});
    final push = PushService(api, transport, enabled: true);
    final openedMessages = <PushMessage>[];
    push.onOpen = openedMessages.add;
    await push.start();
    expect(openedMessages.single.type, 'task_assigned');
  });

  test('unregister deletes the server token and the local token', () async {
    final transport = FakeTransport();
    final push = PushService(api, transport, enabled: true);
    await push.start();
    await push.unregister();
    expect(requests.last.method, 'DELETE');
    expect(requests.last.path, 'devices/token-1');
    expect(transport.deleted, isTrue);
    expect(push.registeredToken, isNull);
  });

  test('push stays silent unless enabled, permitted and signed in', () async {
    await PushService(api, FakeTransport(), enabled: false).start();
    await PushService(api, FakeTransport()..granted = false, enabled: true).start();
    await PushService(api..token = null, FakeTransport(), enabled: true).start();
    expect(requests, isEmpty);
  });

  test('push taps open the related meeting, task or the inbox', () {
    final meeting = screenForPush(PushMessage.fromData({'type': 'meeting_reminder', 'meeting_id': 11}));
    expect(meeting, isA<RecordScreen>());
    expect((meeting as RecordScreen).initial.module, Module.meetings);
    expect(meeting.initial.id, '11');
    final task = screenForPush(PushMessage.fromData({'type': 'task_assigned', 'task_id': 7}));
    expect((task as RecordScreen).initial.module, Module.tasks);
    expect(screenForPush(const PushMessage(type: 'other')), isA<RecordsScreen>());
  });
  test('a tapped foreground notification keeps its routing data', () {
    final original = PushMessage.fromData(
      {'notification_id': 'n9', 'type': 'meeting_reminder', 'meeting_id': 42},
      title: 'Meeting in 15 minutes',
      body: 'Open Schedio for details',
    );
    final back = FirebasePushTransport.fromPayload(FirebasePushTransport.toPayload(original))!;
    expect(back.notificationId, 'n9');
    expect(back.type, 'meeting_reminder');
    expect(back.targetId, '42');
    expect(back.title, 'Meeting in 15 minutes');
    expect(back.dedupeKey, original.dedupeKey);
    expect(FirebasePushTransport.fromPayload('not json'), isNull);
    expect(FirebasePushTransport.fromPayload(null), isNull);
  });
}
