import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/authentication/auth_screen.dart';
import 'package:schedio_mobile/features/booking/booking_screen.dart';
import 'package:schedio_mobile/features/settings/settings_screen.dart';
import 'package:schedio_mobile/features/workspace/editor.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';

import 'support/fake_backend.dart';

Widget opener(Widget screen) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen)),
        child: const Text('Open'),
      ),
    ),
  ),
);

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppField && w.label == label),
  matching: find.byType(TextFormField),
);

class SlowAuth extends AuthController {
  final completer = Completer<Account?>();
  @override
  Future<Account?> build() => completer.future;
}

void main() {
  setUpAll(prepareWidgetTests);

  group('friendly errors', () {
    test('server failures keep their message', () {
      expect(friendlyError(const ApiFailure('Room is already booked.')), 'Room is already booked.');
    });
    test('unexpected response shapes never show Dart type errors', () {
      Object? error;
      try {
        (<String, dynamic>{'data': 'oops'})['data'] as List;
      } catch (e) {
        error = e;
      }
      final message = friendlyError(error!);
      expect(message, contains('could not read'));
      expect(message, isNot(contains('subtype')));
    });
    test('anything else gets a generic retry message', () {
      expect(friendlyError(StateError('x')), 'Something went wrong. Please try again.');
    });
  });

  testWidgets('a list with an unexpected server shape shows a readable error and retry', (tester) async {
    phoneSize(tester);
    final backend = FakeBackend();
    backend.routes['GET tasks'] = (_) => (200, {'data': 'not a list'});
    await tester.pumpWidget(harness(backend, const RecordsScreen(module: Module.tasks)));
    await settle(tester);
    expect(find.textContaining('could not read'), findsOneWidget);
    expect(find.textContaining('subtype'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('unsaved changes', () {
    testWidgets('leaving an untouched editor closes it straight away', (tester) async {
      phoneSize(tester, height: 1400);
      await tester.pumpWidget(harness(FakeBackend(), opener(const Editor(module: Module.tasks))));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await settle(tester);
      expect(find.byType(Editor), findsNothing);
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('leaving with typed changes asks first and can keep editing', (tester) async {
      phoneSize(tester, height: 1400);
      await tester.pumpWidget(harness(FakeBackend(), opener(const Editor(module: Module.tasks))));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.enterText(field('Title'), 'Draft task');
      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await settle(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(find.byType(Editor), findsOneWidget);
      expect(find.text('Draft task'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Discard'));
      await settle(tester);
      expect(find.byType(Editor), findsNothing);
    });

    testWidgets('the system back gesture is also protected', (tester) async {
      phoneSize(tester, height: 1400);
      await tester.pumpWidget(harness(FakeBackend(), opener(const Editor(module: Module.tasks))));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.enterText(field('Title'), 'Draft task');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
      await navigator.maybePop();
      await settle(tester);
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.byType(Editor), findsOneWidget);
    });

    testWidgets('saving closes the editor without asking', (tester) async {
      phoneSize(tester, height: 1400);
      final backend = FakeBackend();
      await tester.pumpWidget(harness(backend, opener(const Editor(module: Module.tasks))));
      await tester.tap(find.text('Open'));
      await settle(tester);
      await tester.enterText(field('Title'), 'Ship it');
      await tester.tap(find.widgetWithText(AppButton, 'Save'));
      await settle(tester);
      expect(backend.lastWrite()!.path, 'tasks');
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(Editor), findsNothing);
    });
  });

  testWidgets('booking: a date tapped while slots are loading is not ignored', (tester) async {
    phoneSize(tester, height: 1800);
    final backend = FakeBackend();
    // Dates are the host's (UTC here), not the phone's.
    final utcNow = DateTime.now().toUtc();
    final now = DateTime(utcNow.year, utcNow.month, utcNow.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    String day(DateTime d) => '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';
    final todayHeld = Completer<void>();
    Map<String, dynamic> slot(DateTime d, int hour) => {
      'start_time': DateTime.utc(d.year, d.month, d.day, hour).toIso8601String(),
      'end_time': DateTime.utc(d.year, d.month, d.day, hour, 30).toIso8601String(),
    };
    backend.routes['GET public/booking/ayesha'] = (_) => (
      200,
      {
        'data': {'name': 'Ayesha Khan', 'timezone': 'UTC', 'durations': [30]},
      },
    );
    backend.routes['GET public/booking/ayesha/slots'] = (o) async {
      if (o.queryParameters['date'] == day(tomorrow)) {
        return (200, {'data': [slot(tomorrow, 9)]});
      }
      await todayHeld.future;
      return (200, {'data': [slot(now, 20), slot(now, 21), slot(now, 22)]});
    };
    await tester.pumpWidget(harness(backend, const BookingScreen()));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).first, 'ayesha');
    await tester.tap(find.text('Open booking profile'));
    for (var i = 0; i < 10 && find.byType(DateCard).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(DateCard), findsWidgets, reason: 'profile loaded, today still loading');
    await tester.tap(find.byType(DateCard).at(1));
    await tester.pump(const Duration(milliseconds: 300));
    todayHeld.complete();
    await settle(tester);
    expect(tester.widget<DateCard>(find.byType(DateCard).at(1)).selected, isTrue);
    expect(find.byType(SlotPill), findsNWidgets(2), reason: 'one duration and only the single slot for tomorrow; the late reply for today was discarded');
  });

  testWidgets('settings opened before the account loads shows a loader instead of crashing', (tester) async {
    phoneSize(tester);
    final auth = SlowAuth();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/'))..httpClientAdapter = FakeBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(Api(client: dio)..token = 't'),
          authProvider.overrideWith(() => auth),
          deviceAlertsProvider.overrideWithValue(SilentAlerts()),
        ],
        child: MaterialApp(theme: schedioTheme(), home: const SettingsScreen()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SchedioLoadingIndicator), findsOneWidget);
    auth.completer.complete(Account.fromJson(userFixture()));
    await settle(tester);
    expect(find.byType(NotificationPreferencesPanel), findsOneWidget);
  });
  group('registration options', () {
    Future<void> openRegistration(WidgetTester tester, Object? data) async {
      phoneSize(tester, height: 1600);
      final backend = FakeBackend();
      backend.routes['GET auth/registration-options'] = (_) => (200, {'data': data});
      await tester.pumpWidget(harness(backend, const AuthScreen()));
      await settle(tester);
      await tester.ensureVisible(find.text('Request Staff Access'));
      await tester.tap(find.text('Request Staff Access'));
      await settle(tester);
    }

    testWidgets('an empty Laravel array is treated as no options, not an error', (tester) async {
      await openRegistration(tester, <dynamic>[]);
      expect(find.text('Submit Registration'), findsOneWidget);
      expect(find.byType(InlineBanner).evaluate().where((e) => (e.widget as InlineBanner).kind == BannerKind.error), isEmpty);
    });

    testWidgets('a malformed response shows a readable message', (tester) async {
      await openRegistration(tester, 'oops');
      expect(find.textContaining('could not read'), findsOneWidget);
      expect(find.textContaining('subtype'), findsNothing);
    });
  });
  testWidgets('registration options without a data wrapper list the companies', (tester) async {
    phoneSize(tester, height: 1600);
    final backend = FakeBackend();
    backend.routes['GET auth/registration-options'] = (_) => (
      200,
      {
        'companies': [{'id': 1, 'name': 'Schedio HQ', 'slug': 'schedio-hq'}],
        'departments': [{'id': 2, 'name': 'Sales', 'code': 'BD', 'company_id': 1}],
      },
    );
    await tester.pumpWidget(harness(backend, const AuthScreen()));
    await settle(tester);
    await tester.ensureVisible(find.text('Request Staff Access'));
    await tester.tap(find.text('Request Staff Access'));
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await settle(tester);
    expect(find.text('Schedio HQ'), findsWidgets);
  });
}
