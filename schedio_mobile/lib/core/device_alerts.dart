import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// Opt-in presentation of newly received server inbox items. This never schedules
/// reminders, polls in the background, or replaces Laravel's reminder engine.
class DeviceAlerts {
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  bool initialized = false, syncing = false;
  Future<void> initialize() async {
    if (initialized) return;
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_schedio'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
    initialized = true;
  }

  Future<bool> enabled(int userId) async =>
      (await SharedPreferences.getInstance()).getBool(
        'device_alerts_$userId',
      ) ??
      false;
  Future<bool> setEnabled(int userId, bool enabled) async {
    await initialize();
    var granted = false;
    if (enabled) {
      granted =
          await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else {
      await plugin.cancelAll();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('device_alerts_$userId', enabled && granted);
    if (enabled) await prefs.remove('device_alert_watermark_$userId');
    return enabled && granted;
  }

  Future<void> sync(Api api, Account account) async {
    if (syncing || !account.preferences.inApp || !await enabled(account.id)) {
      return;
    }
    syncing = true;
    try {
      await initialize();
      final prefs = await SharedPreferences.getInstance();
      final key = 'device_alert_watermark_${account.id}';
      final previous = DateTime.tryParse(prefs.getString(key) ?? '');
      final response = await api.request('notifications');
      final records = response['data'] as List;
      DateTime? newest;
      var hasNewUnread = false;
      for (final raw in records) {
        final record = raw as Json;
        final created = DateTime.tryParse(
          record['created_at'] as String? ?? '',
        );
        if (created == null) continue;
        if (newest == null || created.isAfter(newest)) newest = created;
        if (previous != null &&
            created.isAfter(previous) &&
            record['read_at'] == null) {
          hasNewUnread = true;
        }
      }
      newest ??= DateTime.tryParse(response['server_time'] as String? ?? '');
      if (newest != null) {
        await prefs.setString(key, newest.toUtc().toIso8601String());
      }
      // First synchronization establishes a baseline rather than alerting old history.
      if (hasNewUnread) {
        await plugin.show(
          id: 1,
          title: 'New Schedio activity',
          body: 'Open your inbox to view new activity.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'schedio_inbox',
              'Workspace activity',
              channelDescription:
                  'New activity received from your Schedio inbox',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              visibility: NotificationVisibility.private,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    } finally {
      syncing = false;
    }
  }
}
