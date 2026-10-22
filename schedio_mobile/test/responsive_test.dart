import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/app/shell.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/features/authentication/auth_screen.dart';
import 'package:schedio_mobile/features/availability/availability_screen.dart';
import 'package:schedio_mobile/features/booking/booking_screen.dart';
import 'package:schedio_mobile/features/calendar/calendar_screen.dart';
import 'package:schedio_mobile/features/settings/profile_screen.dart';
import 'package:schedio_mobile/features/settings/settings_screen.dart';
import 'package:schedio_mobile/features/workspace/approval_screen.dart';
import 'package:schedio_mobile/features/workspace/editor.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';
import 'package:schedio_mobile/features/workspace/registration_queue.dart';

import 'support/fake_backend.dart';

const sizes = [
  Size(320, 640),
  Size(360, 740),
  Size(390, 844),
  Size(430, 932),
  Size(600, 960),
  Size(800, 1280),
  Size(740, 360),
  Size(932, 430),
];
const scales = [1.0, 1.3, 2.0];

const long = 'Quarterly roadmap review with the entire leadership team and partners';
final now = DateTime.now().toUtc();
String at(Duration d) => now.add(d).toIso8601String();

void richRoutes(FakeBackend b) {
  final page = {'current_page': 1, 'last_page': 1, 'total': 3};
  (int, Object?) list(List<Map<String, dynamic>> items) => (200, {'data': items, 'meta': page});
  b.routes['GET tasks'] = (_) => list([
    {'id': 41, 'title': long, 'status': 'in_progress', 'priority': 'high', 'due_date': at(const Duration(days: 1)), 'can_manage': true, 'assignee': {'id': 1, 'name': 'Ayesha Khan'}},
    {'id': 42, 'title': 'Send proposal', 'status': 'todo', 'priority': 'low'},
  ]);
  final room = {'id': 5, 'name': 'Board Room on the executive floor with a very long name', 'code': 'BRD', 'location': 'Floor 3, North wing', 'capacity': 12, 'amenities': ['Screen', 'Whiteboard', 'Conference phone', 'Video bar'], 'is_active': true, 'can_manage': true};
  final event = {'id': 6, 'title': 'Annual company offsite and strategy planning retreat', 'category': 'social', 'is_company_wide': true, 'start_time': at(const Duration(days: 2)), 'end_time': at(const Duration(days: 2, hours: 5)), 'location': 'Islamabad Serena Hotel', 'can_manage': true};
  b.routes['GET rooms'] = (_) => list([room]);
  b.routes['GET rooms/5'] = (_) => (200, {'data': room});
  b.routes['GET events'] = (_) => list([event]);
  b.routes['GET events/6'] = (_) => (200, {'data': event});
  b.routes['GET clients/31'] = (_) => (200, {
    'data': {'id': 31, 'company_name': 'Northwind Traders International Holdings', 'contact_name': 'Omar Farooq', 'contact_email': 'omar.farooq.longaddress@northwind-traders.example.test', 'contact_phone': '+92 300 1234567', 'status': 'paperwork_onboarding', 'deal_value': 1250000, 'campaign': 'Spring outreach', 'progress': 'Contract under review by legal', 'notes': long, 'can_manage': true},
  });
  b.routes['GET meetings/11/notes'] = (_) => list([
    {'id': 71, 'agenda': long, 'discussion': 'Budget and hiring', 'decisions': 'Approve Q3 plan', 'action_items': 'Share deck', 'can_manage': true},
  ]);
  b.routes['GET notifications'] = (_) => list([
    {'id': 'n1', 'read_at': null, 'created_at': at(const Duration(minutes: -5)), 'data': {'title': long, 'message': 'Bilal accepted your invitation to the quarterly roadmap review', 'meeting_id': 11}},
    {'id': 'n2', 'read_at': at(const Duration(hours: -1)), 'data': {'title': 'Task assigned', 'message': 'Send proposal', 'task_id': 41}},
  ]);
  b.routes['GET public/booking/ayesha'] = (_) => (200, {
    'data': {'name': 'Ayesha Khan', 'headline': 'Let us find a time that works for both of us', 'bio': long, 'timezone': 'UTC', 'durations': [15, 30, 45, 60]},
  });
  b.routes['GET public/booking/ayesha/slots'] = (_) => (200, {
    'data': [
      for (var h = 9; h < 17; h++)
        {'start_time': DateTime.utc(now.year, now.month, now.day + 1, h).toIso8601String(), 'end_time': DateTime.utc(now.year, now.month, now.day + 1, h, 30).toIso8601String()},
    ],
  });
  b.routes['GET lookups'] = (_) => (200, {
    'data': {
      'users': [for (var i = 1; i < 6; i++) {'id': i, 'name': 'Team member number $i with long name'}],
      'departments': [{'id': 4, 'name': 'Business development and partnerships'}],
      'rooms': [{'id': 5, 'name': 'Board Room'}],
      'clients': [{'id': 31, 'name': 'Northwind Traders'}],
    },
  });
  b.routes['GET admin/registration-requests/21/options'] = (_) => (200, {
    'roles': ['manager', 'employee', 'client'],
    'departments': [{'id': 4, 'name': 'Business development and partnerships'}],
  });
  b.routes['GET auth/registration-options'] = (_) => (200, {
    'data': {
      'companies': [
        {'id': 1, 'name': 'Schedio Technologies Headquarters and Regional Offices'},
        {'id': 2, 'name': 'Northwind Traders'},
      ],
      'departments': [
        {'id': 4, 'company_id': 1, 'name': 'Business development and partnerships'},
      ],
    },
  });
  b.routes['GET calendar/feed'] = (_) => (200, {
    'data': [
      for (final (id, h, m) in [(11, 9, 15), (12, 10, 30), (13, 11, 90)])
        {'id': id, 'title': long, 'entity_type': 'meeting', 'start_time': DateTime.utc(now.year, now.month, now.day, h).toIso8601String(), 'end_time': DateTime.utc(now.year, now.month, now.day, h, m).toIso8601String()},
      {'id': 6, 'title': 'Company offsite', 'entity_type': 'event', 'start_time': at(const Duration(hours: 1)), 'end_time': at(const Duration(hours: 3))},
    ],
  });
}

Record rec(Map<String, dynamic> j, Module m) => Record.fromJson(j, m);

typedef Step = Future<void> Function(WidgetTester tester);

const navigationSteps = {'quick actions', 'pipeline'};

Future<void> tapInView(WidgetTester t, Finder target) async {
  expect(target, findsOneWidget);
  await t.ensureVisible(target);
  await Scrollable.ensureVisible(t.element(target), alignment: 0.5);
  await t.pump();
  await t.tap(target);
  await settle(t);
}

final screens = <String, (Widget, Step?)>{
  'sign in': (const AuthScreen(), null),
  'registration': (const AuthScreen(), (t) async {
    await tapInView(t, find.text('Request Staff Access'));
    expect(find.text('Submit Registration'), findsOneWidget);
  }),
  'home': (const WorkspaceShell(), null),
  'quick actions': (const WorkspaceShell(), (t) async {
    await tapInView(t, find.byType(CenterFab));
    expect(find.text('Quick Actions'), findsOneWidget);
  }),
  'calendar month': (const CalendarScreen(), null),
  'calendar week': (const CalendarScreen(), (t) async {
    await tapInView(t, find.text('Week'));
  }),
  'calendar day': (const CalendarScreen(), (t) async {
    await tapInView(t, find.text('Day'));
  }),
  'calendar agenda': (const CalendarScreen(), (t) async {
    await tapInView(t, find.text('Agenda'));
  }),
  'meetings list': (const RecordsScreen(module: Module.meetings), null),
  'tasks list': (const RecordsScreen(module: Module.tasks), null),
  'rooms list': (const RecordsScreen(module: Module.rooms), null),
  'events list': (const RecordsScreen(module: Module.events), null),
  'notifications': (const RecordsScreen(module: Module.notifications), null),
  'meeting notes': (const RecordsScreen(module: Module.notes, meetingId: '11'), null),
  'pipeline': (const WorkspaceShell(), (t) async {
    await tapInView(t, find.text('Pipeline'));
    expect(find.text('Clients and Pipeline'), findsWidgets);
  }),
  'meeting detail': (RecordScreen(initial: rec({'id': 11, 'title': long}, Module.meetings)), null),
  'task detail': (RecordScreen(initial: rec({'id': 41, 'title': long}, Module.tasks)), null),
  'client detail': (RecordScreen(initial: rec({'id': 31, 'company_name': 'Northwind'}, Module.clients)), null),
  'room detail': (RecordScreen(initial: rec({'id': 5, 'name': 'Board Room'}, Module.rooms)), null),
  'event detail': (RecordScreen(initial: rec({'id': 6, 'title': 'Offsite'}, Module.events)), null),
  'meeting editor': (const Editor(module: Module.meetings), null),
  'task editor': (const Editor(module: Module.tasks), null),
  'client editor': (const Editor(module: Module.clients), null),
  'room editor': (const Editor(module: Module.rooms), null),
  'event editor': (const Editor(module: Module.events), null),
  'note editor': (const Editor(module: Module.notes, meetingId: '11'), null),
  'availability': (const AvailabilityScreen(), null),
  'booking': (const BookingScreen(), (t) async {
    await t.enterText(find.byType(TextFormField).first, 'ayesha');
    await tapInView(t, find.text('Open booking profile'));
    expect(find.text('Verified Host'), findsOneWidget);
  }),
  'profile': (const ProfileScreen(), null),
  'settings': (const SettingsScreen(), null),
  'registration queue': (const RegistrationQueueScreen(), null),
  'approval': (ApprovalScreen(applicant: rec(requestFixtures.first, Module.administration)), null),
};

void main() {
  setUpAll(prepareWidgetTests);
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  for (final MapEntry(key: name, value: (screen, step)) in screens.entries) {
    testWidgets('$name renders at every size and text scale', (tester) async {
      final problems = <String>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        final where = RegExp(r'lib/[a-z_/]+\.dart:\d+').firstMatch(details.toString())?.group(0) ?? 'unknown';
        final text = '${details.exceptionAsString().split('\n').first} @ $where';
        problems.add('${tester.view.physicalSize} x${tester.platformDispatcher.textScaleFactor}: $text');
      };
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      Future<void> render(Size size, double scale, {FakeViewPadding insets = FakeViewPadding.zero, FakeViewPadding keyboard = FakeViewPadding.zero}) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = insets;
        tester.view.viewPadding = insets;
        tester.view.viewInsets = keyboard;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final backend = FakeBackend();
        richRoutes(backend);
        await tester.pumpWidget(Container());
        await tester.pumpWidget(harness(backend, screen));
        await settle(tester);
        final keyboardCoversNavigation = keyboard.bottom > 0 && navigationSteps.contains(name);
        if (step != null && !keyboardCoversNavigation) await step(tester);
        final pending = tester.takeException();
        if (pending != null) problems.add('$size x$scale: ${'$pending'.split('\n').first}');
      }

      try {
        for (final size in sizes) {
          for (final scale in scales) {
            await render(size, scale);
          }
        }
        const notch = FakeViewPadding(top: 48, bottom: 34);
        const sideNotch = FakeViewPadding(left: 48, right: 48, bottom: 21);
        await render(const Size(390, 844), 1.3, insets: notch);
        await render(const Size(932, 430), 1.0, insets: sideNotch);
        await render(const Size(360, 740), 1.0, insets: notch, keyboard: const FakeViewPadding(bottom: 300));
        await render(const Size(390, 844), 1.3, insets: notch, keyboard: const FakeViewPadding(bottom: 320));
      } finally {
        FlutterError.onError = original;
      }
      for (final p in problems) {
        debugPrint('SWEEP $name | $p');
      }
      expect(problems, isEmpty);
    });
  }
}
