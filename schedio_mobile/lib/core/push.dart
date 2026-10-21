import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';

class PushMessage {
  final String? notificationId;
  final String? type;
  final String? targetId;
  final String? title;
  final String? body;

  const PushMessage({
    this.notificationId,
    this.type,
    this.targetId,
    this.title,
    this.body,
  });

  factory PushMessage.fromData(Map<String, dynamic> data, {String? title, String? body}) {
    String? text(String key) {
      final v = data[key];
      return v == null || '$v'.isEmpty ? null : '$v';
    }

    return PushMessage(
      notificationId: text('notification_id'),
      type: text('type'),
      targetId: text('meeting_id') ?? text('task_id') ?? text('target_id'),
      title: title ?? text('title'),
      body: body ?? text('body'),
    );
  }

  String get dedupeKey => notificationId ?? '$type:$targetId:$title';
}

abstract class PushTransport {
  String get platform;
  Future<bool> requestPermission();
  Future<String?> token();
  Stream<String> get onTokenRefresh;
  Stream<PushMessage> get onForegroundMessage;
  Stream<PushMessage> get onMessageOpened;
  Future<PushMessage?> initialMessage();
  Future<void> deleteToken();
}

class DisabledPushTransport implements PushTransport {
  const DisabledPushTransport();
  @override
  String get platform => defaultTargetPlatform.name;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Stream<PushMessage> get onForegroundMessage => const Stream.empty();
  @override
  Stream<PushMessage> get onMessageOpened => const Stream.empty();
  @override
  Future<PushMessage?> initialMessage() async => null;
  @override
  Future<void> deleteToken() async {}
}

class PushService {
  static const enabledByBuild = bool.fromEnvironment('PUSH_ENABLED');

  final Api api;
  final PushTransport transport;
  final bool enabled;
  final _seen = <String>{};
  final _subscriptions = <StreamSubscription<dynamic>>[];
  String? registeredToken;
  void Function(PushMessage message)? onOpen;
  void Function(PushMessage message)? onForeground;

  PushService(this.api, this.transport, {bool? enabled})
    : enabled = enabled ?? enabledByBuild;

  bool firstTime(PushMessage m) => _seen.add(m.dedupeKey);

  Future<void> start() async {
    if (!enabled || api.token == null) return;
    await stopListening();
    if (!await transport.requestPermission()) return;
    final token = await transport.token();
    if (token != null) await register(token);
    _subscriptions
      ..add(transport.onTokenRefresh.listen(register))
      ..add(
        transport.onForegroundMessage.listen((m) {
          if (firstTime(m)) onForeground?.call(m);
        }),
      )
      ..add(
        transport.onMessageOpened.listen((m) {
          _seen.add(m.dedupeKey);
          onOpen?.call(m);
        }),
      );
    final initial = await transport.initialMessage();
    if (initial != null && firstTime(initial)) onOpen?.call(initial);
  }

  Future<void> register(String token) async {
    if (!enabled || api.token == null || token == registeredToken) return;
    await api.request(
      'devices',
      method: 'POST',
      data: {'token': token, 'platform': transport.platform},
    );
    registeredToken = token;
  }

  Future<void> unregister() async {
    await stopListening();
    final token = registeredToken;
    registeredToken = null;
    if (!enabled || token == null || api.token == null) return;
    try {
      await api.request('devices/${Uri.encodeComponent(token)}', method: 'DELETE');
    } finally {
      await transport.deleteToken();
    }
  }

  Future<void> stopListening() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }
}
