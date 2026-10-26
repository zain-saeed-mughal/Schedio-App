import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/editor.dart';
import 'package:schedio_mobile/main.dart' as app;

/// Read-only checks of three items on the release code: the notifications
/// inbox finishes loading, the room form's Name field takes focus and opens
/// the keyboard, and meeting 11's detail shows the server error with Try again.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('r8 hands-on checks', (tester) async {
    final failures = <String>[];
    void log(String what, bool ok) {
      debugPrint('R8CHECK $what: ${ok ? 'PASS' : 'FAIL'}');
      if (!ok) failures.add(what);
    }

    Future<void> pumpFor(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    bool loading() => find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isNotEmpty;
    Future<bool> settle({int seconds = 30}) async {
      await pumpFor(const Duration(milliseconds: 600));
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (loading() && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await pumpFor(const Duration(milliseconds: 500));
      return !loading();
    }

    Future<void> back() async {
      final chip = find.byTooltip('Back');
      if (chip.evaluate().isNotEmpty) {
        await tester.tap(chip.first);
      } else {
        await tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
      }
      await settle();
    }

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    await settle();

    // 1. Inbox via the bell.
    await tester.tap(find.byTooltip('Notifications').first);
    final finished = await settle(seconds: 30);
    final title = find.text('Reminders and Alerts').evaluate().isNotEmpty;
    final empty = find.textContaining('will appear here').evaluate().isNotEmpty;
    final rows = find.byType(RecordTile).evaluate().length;
    final error = find.byType(ErrorPanel).evaluate().isNotEmpty;
    log('inbox opens and finishes loading (${empty ? 'empty state shown' : '$rows notifications'}${error ? ', error shown' : ''})', title && finished && !error && (empty || rows > 0));
    await back();

    // 2. Room form: tap the Name field.
    await tester.tap(find.byType(CenterFab));
    await settle();
    final suites = find.descendant(of: find.byType(AppSheet), matching: find.text('Meeting Suites'));
    await tester.ensureVisible(suites);
    await tester.tap(suites);
    await settle();
    await tester.tap(find.text('New Suite').first);
    await settle();
    final nameField = find.descendant(of: find.byType(Editor), matching: find.byType(EditableText)).first;
    await tester.ensureVisible(nameField);
    await pumpFor(const Duration(milliseconds: 500));
    final rect = tester.getRect(nameField);
    debugPrint('R8CHECK room Name field at ${rect.top.round()}..${rect.bottom.round()} of ${(tester.view.physicalSize.height / tester.view.devicePixelRatio).round()}');
    await tester.tap(nameField);
    await pumpFor(const Duration(seconds: 2));
    final focused = (tester.widget<EditableText>(nameField)).focusNode.hasFocus;
    final inset = tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    log('room form: tapping Name focuses it and opens the keyboard (${inset.round()} dp)', focused && inset > 0);
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpFor(const Duration(seconds: 1));
    final cancel = find.descendant(of: find.byType(Editor), matching: find.text('Cancel'));
    await tester.tap(cancel.last);
    await settle();
    if (find.text('Discard').evaluate().isNotEmpty) {
      await tester.tap(find.text('Discard').last);
      await settle();
    }
    log('room form closes without saving', find.byType(Editor).evaluate().isEmpty);
    await back();

    // 3. Meeting 11 detail.
    await tester.tap(find.text('Meetings').last);
    await settle();
    final meeting = find.textContaining('[TEST] v2.1 Meeting');
    if (meeting.evaluate().isEmpty) {
      log('meeting 11 listed', false);
    } else {
      await tester.tap(meeting.first);
      await settle();
      final serverError = find.textContaining('server had a problem').evaluate().isNotEmpty;
      final retry = find.text('Try again').evaluate().isNotEmpty;
      log('meeting 11 detail shows the server error with Try again (no crash, no blank screen)', serverError && retry && tester.takeException() == null);
      await back();
    }
    debugPrint('R8CHECK SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
    expect(failures, isEmpty);
  });
}
