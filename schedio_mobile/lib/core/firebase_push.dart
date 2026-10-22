// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'device_alerts.dart';
import 'push.dart';

class FirebasePushTransport implements PushTransport {
  final FirebaseMessaging messaging;
  final FlutterLocalNotificationsPlugin local;
  final _opened = StreamController<PushMessage>.broadcast();

  FirebasePushTransport(this.messaging, this.local) {
    FirebaseMessaging.onMessageOpenedApp.map(toMessage).listen(_opened.add);
    localNotificationTaps.stream.map(fromPayload).where((m) => m != null).cast<PushMessage>().listen(_opened.add);
  }

  static Future<PushTransport?> create() async {
    if (!PushService.enabledByBuild) return null;
    try {
      await Firebase.initializeApp();
      final local = FlutterLocalNotificationsPlugin();
      await initializeLocalNotifications(local);
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      return FirebasePushTransport(FirebaseMessaging.instance, local);
    } catch (e) {
      if (kDebugMode) debugPrint('Push disabled: Firebase could not start ($e)');
      return null;
    }
  }

  static PushMessage toMessage(RemoteMessage m) => PushMessage.fromData(
    m.data,
    title: m.notification?.title,
    body: m.notification?.body,
  );

  static String toPayload(PushMessage m) => jsonEncode({
    'notification_id': m.notificationId,
    'type': m.type,
    'target_id': m.targetId,
    'title': m.title,
    'body': m.body,
  });

  static PushMessage? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = jsonDecode(payload);
      return data is Map<String, dynamic> ? PushMessage.fromData(data) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  String get platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  @override
  Future<bool> requestPermission() async {
    final settings = await messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() => messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage => FirebaseMessaging.onMessage.map(toMessage);

  @override
  Stream<PushMessage> get onMessageOpened => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async {
    final m = await messaging.getInitialMessage();
    if (m != null) return toMessage(m);
    final launch = await local.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? fromPayload(launch?.notificationResponse?.payload)
        : null;
  }

  @override
  Future<void> deleteToken() => messaging.deleteToken();

  @override
  Future<void> showForeground(PushMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (message.title == null && message.body == null) return;
    await local.show(
      id: message.dedupeKey.hashCode & 0x7fffffff,
      title: message.title,
      body: message.body,
      payload: toPayload(message),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          pushChannelId,
          'Schedio alerts',
          channelDescription: 'Meeting reminders, invitations, updates and task activity',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
        ),
      ),
    );
  }
}
