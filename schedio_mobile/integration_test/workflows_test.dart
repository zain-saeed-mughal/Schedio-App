import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/editor.dart';
import 'package:schedio_mobile/main.dart' as app;

import 'staging_test.dart' show field, signIn, waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  AppMotion.ambient = false;
  testWidgets('Staging: client, meeting, calendar, inbox and preferences', (
    tester,
  ) async {
    expect([
      '10.0.2.2',
      '127.0.0.1',
      'localhost',
    ], contains(Uri.parse(Api.baseUrl).host));
    await Api().clearToken();
    app.main();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      const String.fromEnvironment('ADMIN_A_EMAIL'),
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      const String.fromEnvironment('ADMIN_A_PASSWORD'),
    );
    await tester.tap(signIn);
    await waitFor(tester, find.byType(WorkspaceShell));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SchedioApp)),
    );
    final api = container.read(apiProvider);
    final employee = Api();
    final login = await employee.request(
      'auth/login',
      method: 'POST',
      data: {
        'email': const String.fromEnvironment('EMPLOYEE_A_EMAIL'),
        'password': const String.fromEnvironment('EMPLOYEE_A_PASSWORD'),
        'device_name': 'Local workflow verification',
      },
    );
    employee.token = login['token'] as String;
    final marker = 'ANDROID-FLOW-${DateTime.now().millisecondsSinceEpoch}';
    String? clientId, meetingId;
    final previousEmail = container.read(authProvider).value!.preferences.email;
    Future<void> tap(Finder finder) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          350,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 40,
        );
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> back() async {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    Future<void> save([String label = 'Save']) async {
      await tap(find.text(label));
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (find.byType(Editor).evaluate().isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(
        find.byType(Editor),
        findsNothing,
        reason: 'The server must accept the save and close the editor.',
      );
      await tester.pumpAndSettle();
    }

    try {
      await tap(find.text('Pipeline'));
      await tap(find.text('Add New Deal'));
      await waitFor(tester, field('Company name'));
      await tester.enterText(
        field('Company name'),
        marker,
      );
      await tester.enterText(
        field('Contact name'),
        'Android contact',
      );
      await save();
      await tap(find.text('Spreadsheet'));
      await waitFor(tester, find.widgetWithText(RecordTile, marker));
      final clients = await api.request('clients', query: {'search': marker});
      clientId = (clients['data'] as List).single['id'].toString();
      await tap(find.widgetWithText(RecordTile, marker));
      await waitFor(tester, find.text('Android contact'));
      await tap(find.text('Edit'));
      await waitFor(tester, field('Contact name'));
      await tester.enterText(
        field('Contact name'),
        'Updated Android contact',
      );
      await save();
      await waitFor(tester, find.text('Updated Android contact'));
      expect(
        (await api.request('clients/$clientId'))['data']['contact_name'],
        'Updated Android contact',
      );
      await back();

      final now = tz.TZDateTime.now(
        locationFor(container.read(authProvider).value!.timezone),
      );
      final start = tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        now.day,
        10,
        15,
      ).toUtc();
      await api.request(
        'meetings',
        method: 'POST',
        data: {
          'title': marker,
          'start_time': start.toIso8601String(),
          'end_time': start.add(const Duration(hours: 1)).toIso8601String(),
          'timezone': 'Asia/Karachi',
          'type': 'virtual',
          'client_id': int.parse(clientId),
          'participant_ids': [login['user']['id']],
        },
      );
      final created = await api.request('meetings', query: {'search': marker});
      meetingId = (created['data'] as List).single['id'].toString();
      container.read(refreshProvider.notifier).refresh();
      await tap(find.text('Meetings'));
      await waitFor(tester, find.widgetWithText(RecordTile, marker));
      await tap(find.widgetWithText(RecordTile, marker));
      await waitFor(tester, find.text(marker));
      await tap(find.text('Edit'));
      await waitFor(tester, field('Title'));
      await tester.enterText(
        field('Title'),
        '$marker edited',
      );
      await save('Save & Set Reminder');
      await waitFor(tester, find.text('$marker edited'));
      expect(
        (await api.request('meetings/$meetingId'))['data']['title'],
        '$marker edited',
      );
      await tap(find.widgetWithText(DetailRow, 'Meeting notes'));
      await tap(find.text('New Note'));
      await waitFor(tester, field('Agenda'));
      await tester.enterText(
        field('Agenda'),
        marker,
      );
      await save();
      await waitFor(tester, find.widgetWithText(RecordTile, 'Meeting note'));
      await tap(find.widgetWithText(RecordTile, 'Meeting note'));
      await waitFor(tester, find.text(marker));
      await tap(find.text('Edit'));
      await waitFor(tester, field('Agenda'));
      await tester.enterText(
        field('Agenda'),
        '$marker revised agenda',
      );
      await save();
      await waitFor(tester, find.text('$marker revised agenda'));
      await back();
      await back();
      await back();
      await tap(find.text('Calendar'));
      for (final mode in ['Month', 'Week', 'Day', 'Agenda']) {
        await tap(find.text(mode));
        await waitFor(tester, find.text('$marker edited'));
      }
      await employee.request(
        'meetings/$meetingId/rsvp',
        method: 'POST',
        data: {'status': 'accepted'},
      );
      String? notificationId;
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (notificationId == null && DateTime.now().isBefore(deadline)) {
        final notifications = await api.request('notifications');
        for (final item in notifications['data'] as List) {
          if (item['data']['meeting_id'].toString() == meetingId) {
            notificationId = item['id'].toString();
            break;
          }
        }
        if (notificationId == null) {
          await tester.pump(const Duration(seconds: 1));
        }
      }
      expect(notificationId, isNotNull, reason: 'Queued RSVP inbox delivery');
      await tap(find.byTooltip('Notifications'));
      final notification = find.byWidgetPredicate(
        (w) => w is RecordTile && w.record.id == notificationId,
      );
      await waitFor(tester, notification);
      await tap(notification);
      await waitFor(tester, find.text('Mark unread'));
      final readDeadline = DateTime.now().add(const Duration(seconds: 30));
      Map<String, dynamic>? inboxItem;
      while (DateTime.now().isBefore(readDeadline)) {
        final inbox = await api.request('notifications');
        inboxItem = (inbox['data'] as List).cast<Map<String, dynamic>>().singleWhere(
          (n) => n['id'] == notificationId,
        );
        if (inboxItem['read_at'] != null) break;
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(inboxItem?['read_at'], isNotNull);
      await back();
      await back();
      await tap(find.byType(CenterFab));
      await tap(find.text('Settings'));
      final emailSwitch = find.widgetWithText(
        SwitchRow,
        'Email notifications',
      );
      await tap(emailSwitch);
      await tap(find.text('Save preferences'));
      await waitFor(tester, find.text('Notification preferences saved.'));
      await back();
      await tap(find.byType(CenterFab));
      await tap(find.text('Settings'));
      expect(tester.widget<SwitchRow>(emailSwitch).value, !previousEmail);
      await tap(emailSwitch);
      await tap(find.text('Save preferences'));
      await waitFor(tester, find.text('Notification preferences saved.'));
    } finally {
      if (meetingId != null) {
        await api.request('meetings/$meetingId', method: 'DELETE');
      }
      if (clientId != null) {
        await api.request('clients/$clientId', method: 'DELETE');
      }
      await employee.request('auth/logout', method: 'POST');
      await api.request('auth/logout', method: 'POST');
      await api.clearToken();
    }
  });
}
