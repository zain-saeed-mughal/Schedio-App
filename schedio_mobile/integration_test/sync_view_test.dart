import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/models.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/records_screen.dart';
import 'package:schedio_mobile/main.dart' as app;

/// Read-only sync check for one client: refreshes Pipeline, opens the client's
/// detail screen and compares what the app shows and what the API returns with
/// the expected values. Writes nothing.
const clientId = int.fromEnvironment('SYNC_CLIENT_ID', defaultValue: 14);
const expectContact = String.fromEnvironment('SYNC_EXPECT_CONTACT');
const expectStatus = String.fromEnvironment('SYNC_EXPECT_STATUS');
const expectName = String.fromEnvironment('SYNC_EXPECT_NAME', defaultValue: '[TEST] Sync Client 01');
const expectRep = String.fromEnvironment('SYNC_EXPECT_REP', defaultValue: 'Hammad Developer');
const expectCampaign = String.fromEnvironment('SYNC_EXPECT_CAMPAIGN', defaultValue: 'QA Sync Test');
const tag = String.fromEnvironment('SYNC_TAG', defaultValue: 'sync');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('sync view check (read-only)', (tester) async {
    final semantics = tester.ensureSemantics();
    final failures = <String>[];
    void log(String what, bool ok) {
      debugPrint('SYNCV $what: ${ok ? 'PASS' : 'FAIL'}');
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

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    final api = container.read(apiProvider);
    Future<T> async<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;

    final me = (await async(() => api.request('auth/me')))['data'] as Json;
    final company = asMap(me['company']);
    debugPrint('SYNCV account: ${me['name']} (user ${me['id']}), company ${company?['id']} ${company?['name']}');
    log('account is in Schedio HQ (company 1)', asInt(company?['id']) == 1);

    // API.
    final c = resultOf(await async(() => api.request('clients/$clientId')));
    debugPrint('SYNCV API: id ${c['id']}, company_name "${c['company_name']}", contact_name "${c['contact_name']}", status ${c['status']}, '
        'assigned_to ${nameOf(c['assigned_to'])} (id ${asInt(c['assigned_to'])}), campaign "${c['campaign']}", deal_value ${c['deal_value']}, '
        'contact_role "${c['contact_role']}", progress "${c['progress']}"');
    log('API: record ID $clientId', asInt(c['id']) == clientId);
    if (expectContact.isNotEmpty) log('API: contact name is "$expectContact"', c['contact_name'] == expectContact);
    if (expectStatus.isNotEmpty) log('API: stage is $expectStatus', c['status'] == expectStatus);
    log('API: company name is "$expectName"', c['company_name'] == expectName);
    log('API: representative is $expectRep', nameOf(c['assigned_to']) == expectRep);
    log('API: campaign is "$expectCampaign"', c['campaign'] == expectCampaign);

    // App: Pipeline, refresh, board card, detail screen.
    await settle();
    await tester.tap(find.text('Pipeline').last);
    await settle();
    container.read(refreshProvider.notifier).refresh();
    await settle();
    if (find.text('Board').evaluate().isNotEmpty) {
      await tester.tap(find.text('Board'));
      await settle();
    }
    final title = find.text(expectName);
    final stageLabel = expectStatus.isEmpty ? '' : '${expectStatus[0].toUpperCase()}${expectStatus.substring(1)}';
    log('Board shows the client${stageLabel.isEmpty ? '' : ' in $stageLabel'} after refresh',
        title.evaluate().isNotEmpty &&
            (stageLabel.isEmpty || find.bySemanticsLabel(RegExp('^${RegExp.escape(expectName)}, $stageLabel')).evaluate().isNotEmpty));
    final card = find.ancestor(of: title.first, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_DealCard'));
    final cardContact = expectContact.isEmpty || find.descendant(of: card.first, matching: find.text(expectContact)).evaluate().isNotEmpty;
    log('Board card shows contact "${expectContact.isEmpty ? '-' : expectContact}"', cardContact);
    await tester.ensureVisible(title.first);
    await settle();
    await shot('$tag-board');
    await tester.tap(title.first);
    await settle();
    final onDetail = find.byType(RecordScreen).evaluate().isNotEmpty;
    log('client detail screen opens', onDetail);
    if (onDetail) {
      final detail = find.byType(RecordScreen);
      bool shows(String text) => find.descendant(of: detail, matching: find.textContaining(text)).evaluate().isNotEmpty;
      log('detail shows company name', shows(expectName));
      if (expectContact.isNotEmpty) log('detail shows contact "$expectContact"', shows(expectContact));
      if (stageLabel.isNotEmpty) log('detail shows stage $stageLabel', shows(stageLabel) || shows(stageLabel.toUpperCase()));
      log('detail shows representative $expectRep', shows(expectRep));
      await shot('$tag-detail');
    }
    debugPrint('SYNCV SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
    semantics.dispose();
    expect(failures, isEmpty);
  });
}
