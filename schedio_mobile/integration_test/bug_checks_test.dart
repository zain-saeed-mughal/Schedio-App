import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('phone checks for the three reported bugs (read-only except an unchanged preference save)', (tester) async {
    final failures = <String>[];

    Future<void> pumpFor(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> settleLoad() async {
      await pumpFor(const Duration(milliseconds: 600));
      final end = DateTime.now().add(const Duration(seconds: 40));
      while (find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isNotEmpty &&
          DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await pumpFor(const Duration(milliseconds: 400));
    }

    void check(String name, {required bool ok, String detail = ''}) {
      debugPrint('BUGCHECK $name: ${ok ? 'PASS' : 'FAIL'}${detail.isEmpty ? '' : ' ($detail)'}');
      if (!ok) failures.add('$name $detail');
    }

    String? screenError() {
      final panels = find.byType(ErrorPanel).evaluate().map((e) => (e.widget as ErrorPanel).message).toList();
      final banners = find.byType(InlineBanner).evaluate().map((e) => e.widget as InlineBanner).where((b) => b.kind == BannerKind.error).map((b) => b.message).toList();
      final all = [...panels, ...banners].where((m) => m.isNotEmpty).toList();
      return all.isEmpty ? null : all.first;
    }

    Future<void> openQuickAction(String label) async {
      await tester.tap(find.byType(CenterFab));
      await settleLoad();
      final item = find.descendant(of: find.byType(AppSheet), matching: find.text(label));
      await tester.ensureVisible(item);
      await tester.tap(item);
      await settleLoad();
    }

    Future<void> back() async {
      final chip = find.byTooltip('Back');
      if (chip.evaluate().isNotEmpty) {
        await tester.tap(chip.first);
      } else {
        await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
      }
      await settleLoad();
    }

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    await settleLoad();

    await tester.tap(find.text('Pipeline').last);
    await settleLoad();
    var error = screenError();
    check('pipeline board', ok: error == null && tester.takeException() == null, detail: error ?? '${find.byType(RecordTile).evaluate().length} client cards');
    await tester.tap(find.text('Spreadsheet'));
    await settleLoad();
    error = screenError();
    check('pipeline spreadsheet', ok: error == null && tester.takeException() == null, detail: error ?? 'rendered');
    await tester.tap(find.text('Board'));
    await settleLoad();
    await tester.tap(find.text('Home').last);
    await settleLoad();

    await openQuickAction('Settings');
    final pushRow = find.text('Push notifications').evaluate().isNotEmpty;
    final wrongClaim = find.textContaining('not enabled').evaluate().isNotEmpty;
    check('settings push status', ok: !wrongClaim, detail: pushRow ? 'shows Push notifications on for this device' : 'push not registered yet; shows how to allow it');
    final save = find.text('Save preferences');
    await tester.ensureVisible(save);
    await tester.tap(save);
    var saved = false;
    String? saveError;
    for (var i = 0; i < 60 && !saved && saveError == null; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      saved = find.text('Notification preferences saved.').evaluate().isNotEmpty;
      saveError = screenError();
    }
    check('settings save (unchanged values)', ok: saved && saveError == null, detail: saveError ?? (saved ? 'saved' : 'no confirmation within 15 s'));
    await pumpFor(const Duration(seconds: 2));
    await back();

    await openQuickAction('My Booking Page');
    final open = find.text('Open booking profile');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await settleLoad();
    error = screenError();
    final pills = find.byType(SlotPill).evaluate().length;
    final empty = find.text('No available slots').evaluate().isNotEmpty;
    check('booking profile and today', ok: error == null, detail: error ?? (empty ? 'no slots left today (genuinely empty)' : '$pills pills (durations plus slots)'));
    final tomorrow = find.byType(DateCard).at(1);
    await tester.ensureVisible(tomorrow);
    await tester.tap(tomorrow);
    await settleLoad();
    error = screenError();
    final slotsTomorrow = find.byType(SlotPill).evaluate().length;
    check('booking slots tomorrow', ok: error == null && slotsTomorrow > 4, detail: error ?? '$slotsTomorrow pills including slots');
    check('booking never shows a parsing error', ok: find.textContaining('could not read').evaluate().isEmpty);
    await back();

    debugPrint('BUGCHECK SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
    expect(failures, isEmpty);
  });
}
