import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

/// Sync test 02 (mobile -> website). Moves only client 14 "[TEST] Sync Client
/// 01" from Discovery to Scheduled through the app's own Pipeline workflow
/// (Shift Stage -> Scheduled -> Move Deal), driven by this test because adb
/// taps are blocked on the phone. Verifies the result through the API and on
/// the board and spreadsheet. Touches no other record.
const clientId = 14;
const clientName = '[TEST] Sync Client 01';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('sync 02: move client 14 to Scheduled in the app', (tester) async {
    final semantics = tester.ensureSemantics();
    Future<T> async<T>(Future<T> Function() f) async {
      Object? error;
      StackTrace? trace;
      T? value;
      await tester.runAsync(() async {
        try {
          value = await f();
        } catch (e, s) {
          error = e;
          trace = s;
        }
      });
      if (error != null) Error.throwWithStackTrace(error!, trace!);
      return value as T;
    }

    final failures = <String>[];
    void log(String what, bool ok) {
      debugPrint('SYNC2 $what: ${ok ? 'PASS' : 'FAIL'}');
      if (!ok) failures.add(what);
    }

    Future<void> pumpFor(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> settle() async {
      await pumpFor(const Duration(milliseconds: 600));
      final end = DateTime.now().add(const Duration(seconds: 30));
      while (find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isNotEmpty &&
          DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await pumpFor(const Duration(milliseconds: 600));
    }

    Future<void> shot(String name) async {
      debugPrint('QAMARK SHOT $name');
      await pumpFor(const Duration(seconds: 4));
    }

    String summary(Json c) =>
        'id ${c['id']}, company_name "${c['company_name']}", contact_name "${c['contact_name']}", status ${c['status']}, '
        'assigned_to ${nameOf(c['assigned_to'])} (id ${asInt(c['assigned_to'])}), campaign "${c['campaign']}", deal_value ${c['deal_value']}';

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    final api = container.read(apiProvider);

    // Guards: sandbox company and the exact record.
    final me = (await async(() => api.request('auth/me')))['data'] as Json;
    final company = asMap(me['company']);
    debugPrint('SYNC2 account: ${me['name']} (user ${me['id']}), company ${company?['id']} ${company?['name']}');
    if (asInt(company?['id']) != 1) fail('Refusing: not company 1');
    final before = resultOf(await async(() => api.request('clients/$clientId')));
    debugPrint('SYNC2 API before: ${summary(before)}');
    if (before['company_name'] != clientName) fail('Refusing: client $clientId is not $clientName');
    if (before['status'] != 'discovery') fail('Refusing: client $clientId is ${before['status']}, expected discovery');

    // App workflow: Pipeline -> Board -> card -> Shift Stage -> Scheduled -> Move Deal.
    await settle();
    await tester.tap(find.text('Pipeline').last);
    await settle();
    if (find.text('Board').evaluate().isNotEmpty) {
      await tester.tap(find.text('Board'));
      await settle();
    }
    final title = find.text(clientName);
    log('client 14 card is on the Board in Discovery', title.evaluate().isNotEmpty && find.bySemanticsLabel(RegExp('^${RegExp.escape(clientName)}, Discovery')).evaluate().isNotEmpty);
    await tester.ensureVisible(title.first);
    await settle();
    await shot('04-before-board-discovery');
    final card = find.ancestor(of: title.first, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_DealCard'));
    final shift = find.descendant(of: card.first, matching: find.text('Shift Stage'));
    await tester.ensureVisible(shift);
    await tester.tap(shift);
    await settle();
    final sheet = find.byType(AppSheet);
    final scheduled = find.descendant(of: sheet, matching: find.widgetWithText(FilterPill, 'Scheduled'));
    log('Shift Stage sheet opens for this client', sheet.evaluate().isNotEmpty && find.descendant(of: sheet, matching: find.text(clientName)).evaluate().isNotEmpty);
    await tester.tap(scheduled.first);
    await settle();
    await shot('05-shift-stage-sheet-scheduled-selected');
    await tester.tap(find.descendant(of: sheet, matching: find.text('Move Deal')));
    var toast = false;
    for (var i = 0; i < 60 && !toast; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      toast = find.text('Deal moved successfully!').evaluate().isNotEmpty;
    }
    log('app confirms "Deal moved successfully!"', toast);
    await settle();

    // API confirmation.
    final after = resultOf(await async(() => api.request('clients/$clientId')));
    debugPrint('SYNC2 API after: ${summary(after)}');
    log('API: client 14 status is scheduled', after['status'] == 'scheduled');
    log('API: same record ID 14', asInt(after['id']) == clientId);
    final unchanged = ['company_name', 'contact_name', 'campaign', 'deal_value'].every((k) => '${after[k]}' == '${before[k]}') &&
        asInt(after['assigned_to']) == asInt(before['assigned_to']);
    log('API: name, contact, campaign, value and representative unchanged', unchanged);

    // Refresh the mobile Pipeline and check the views.
    container.read(refreshProvider.notifier).refresh();
    await settle();
    await tester.ensureVisible(find.text(clientName).first);
    await settle();
    log('after refresh the Board card shows Scheduled', find.bySemanticsLabel(RegExp('^${RegExp.escape(clientName)}, Scheduled')).evaluate().isNotEmpty);
    await shot('06-after-board-scheduled');
    await tester.tap(find.text('Spreadsheet'));
    await settle();
    log('Spreadsheet lists the client as SCHEDULED', find.bySemanticsLabel(RegExp('^${RegExp.escape(clientName)}.*SCHEDULED', dotAll: true)).evaluate().isNotEmpty);
    await shot('07-after-spreadsheet-scheduled');

    debugPrint('SYNC2 SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
    semantics.dispose();
    expect(failures, isEmpty);
  });
}
