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

    final type = text('type') ?? text('category');
    final isTask = type?.toLowerCase().contains('task') ?? false;
    return PushMessage(
      notificationId: text('notification_id'),
      type: type,
      targetId: isTask
          ? text('task_id') ?? text('target_id')
          : text('meeting_id') ?? text('task_id') ?? text('target_id'),
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
  Future<void> showForeground(PushMessage message);
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
  @override
  Future<void> showForeground(PushMessage message) async {}
}

enum PushStatus { off, blocked, connecting, active }

class PushService {
  static const enabledByBuild = bool.fromEnvironment('PUSH_ENABLED');

  final Api api;
  final PushTransport transport;
  final bool enabled;
  final List<Duration> retryDelays;
  final status = ValueNotifier<PushStatus>(PushStatus.off);
  final _seen = <String>{};
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Timer? _retry;
  var _attempt = 0;
  String? registeredToken;
  void Function(PushMessage message)? onOpen;
  void Function(PushMessage message)? onForeground;

  PushService(
    this.api,
    this.transport, {
    bool? enabled,
    this.retryDelays = const [
      Duration(seconds: 20),
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 15),
    ],
  }) : enabled = enabled ?? enabledByBuild;

  bool firstTime(PushMessage m) => _seen.add(m.dedupeKey);

  Future<void> start() async {
    if (!enabled || api.token == null) return;
    await stopListening();
    if (!await transport.requestPermission()) {
      status.value = PushStatus.blocked;
      return;
    }
    if (registeredToken == null) status.value = PushStatus.connecting;
    _subscriptions
      ..add(
        transport.onTokenRefresh.listen(
          (token) => register(token).catchError((Object e) => _failed(e)),
        ),
      )
      ..add(
        transport.onForegroundMessage.listen((m) {
          if (!firstTime(m)) return;
          transport.showForeground(m).catchError((Object _) {});
          onForeground?.call(m);
        }),
      )
      ..add(
        transport.onMessageOpened.listen((m) {
          _seen.add(m.dedupeKey);
          onOpen?.call(m);
        }),
      );
    _attempt = 0;
    await _registerCurrent();
    final initial = await transport.initialMessage();
    if (initial != null && firstTime(initial)) onOpen?.call(initial);
  }

  /// Tries again straight away, e.g. when the app returns to the foreground.
  Future<void> retryNow() async {
    if (!enabled || api.token == null || status.value != PushStatus.connecting) return;
    _retry?.cancel();
    await _registerCurrent();
  }

  Future<void> _registerCurrent() async {
    try {
      final token = await transport.token();
      if (token == null) throw StateError('No push token yet');
      await register(token);
    } catch (e) {
      _failed(e);
    }
  }

  void _failed(Object error) {
    debugPrint('Schedio push registration failed, will retry (${error.runtimeType}: ${error is ApiFailure ? 'HTTP ${error.status} ${error.message}' : error})');
    if (registeredToken != null) return;
    status.value = PushStatus.connecting;
    _retry?.cancel();
    if (_subscriptions.isEmpty || retryDelays.isEmpty) return;
    final delay = retryDelays[_attempt.clamp(0, retryDelays.length - 1)];
    _attempt++;
    _retry = Timer(delay, _registerCurrent);
  }

  Future<void> register(String token) async {
    if (!enabled || api.token == null || token == registeredToken) return;
    await api.request(
      'devices',
      method: 'POST',
      data: {'token': token, 'platform': transport.platform},
    );
    registeredToken = token;
    _retry?.cancel();
    _attempt = 0;
    status.value = PushStatus.active;
  }

  Future<void> unregister() async {
    await stopListening();
    final token = registeredToken;
    registeredToken = null;
    status.value = PushStatus.off;
    if (!enabled || token == null || api.token == null) return;
    try {
      await api.request('devices/${Uri.encodeComponent(token)}', method: 'DELETE');
    } finally {
      await transport.deleteToken();
    }
  }

  Future<void> stopListening() async {
    _retry?.cancel();
    _retry = null;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }
}
