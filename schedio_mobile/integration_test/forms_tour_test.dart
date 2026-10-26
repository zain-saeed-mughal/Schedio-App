import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/app/nav_bar.dart';
import 'package:schedio_mobile/core/api.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/features/workspace/editor.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// Opens every create form with the real signed-in session, checks fields,
/// required-field validation, date/time pickers and the discard guard, and
/// never saves. A write guard blocks any POST/PUT/PATCH/DELETE before it
/// leaves the device and reports it as a failure.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('forms tour (no records are created)', (tester) async {
    final results = <String>[];
    final failures = <String>[];
    final blockedWrites = <String>[];
    void log(String line, {bool ok = true}) {
      results.add(line);
      if (!ok) failures.add(line);
      debugPrint('FORMS $line');
    }

    tzdata.initializeTimeZones();
    final api = Api();
    api.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (o.method != 'GET') {
            blockedWrites.add('${o.method} ${o.path}');
            return h.reject(DioException(requestOptions: o, message: 'blocked by QA write guard'));
          }
          h.next(o);
        },
      ),
    );
    await tester.pumpWidget(ProviderScope(overrides: [apiProvider.overrideWithValue(api)], child: const SchedioApp()));

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
      await pumpFor(const Duration(milliseconds: 500));
    }

    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    await settle();

    Future<void> quick(String label) async {
      await tester.tap(find.byType(CenterFab));
      await settle();
      final item = find.descendant(of: find.byType(AppSheet), matching: find.text(label));
      await tester.ensureVisible(item);
      await tester.tap(item);
      await settle();
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

    Future<void> checkEditor(String name, {required List<String> requiredMessages, String? dateTile, required String saveLabel}) async {
      if (find.byType(Editor).evaluate().isEmpty) {
        log('$name: form opens: FAIL (editor not shown)', ok: false);
        return;
      }
      final exception = tester.takeException();
      log('$name: form opens${exception == null ? '' : ' with error $exception'}: ${exception == null ? 'PASS' : 'FAIL'}', ok: exception == null);
      final fields = find.descendant(of: find.byType(Editor), matching: find.byType(EditableText)).evaluate().length;
      final dropdowns = find.descendant(of: find.byType(Editor), matching: find.byWidgetPredicate((w) => w is DropdownButton || w is DropdownMenu || w.runtimeType.toString().contains('Select'))).evaluate().length;
      log('$name: $fields text fields, $dropdowns dropdowns: ${fields > 0 ? 'PASS' : 'FAIL'}', ok: fields > 0);

      // Required-field validation on an empty form.
      final save = find.text(saveLabel);
      await tester.ensureVisible(save.last);
      await tester.tap(save.last);
      await settle();
      final shown = requiredMessages.where((m) => find.textContaining(m).evaluate().isNotEmpty).toList();
      log('$name: empty save shows ${shown.isEmpty ? 'no message' : shown.join(', ')}: ${shown.isNotEmpty ? 'PASS' : 'FAIL'}', ok: shown.isNotEmpty);
      log('$name: still open after invalid save (nothing sent): ${find.byType(Editor).evaluate().isNotEmpty && blockedWrites.isEmpty ? 'PASS' : 'FAIL'}',
          ok: find.byType(Editor).evaluate().isNotEmpty && blockedWrites.isEmpty);

      // Keyboard: tapping the first field opens the real keyboard and the
      // field stays visible above it.
      final first = find.descendant(of: find.byType(Editor), matching: find.byType(EditableText)).first;
      await tester.ensureVisible(first);
      await tester.tap(first);
      await pumpFor(const Duration(seconds: 2));
      final view = tester.view;
      final inset = view.viewInsets.bottom / view.devicePixelRatio;
      final screenHeight = view.physicalSize.height / view.devicePixelRatio;
      final keyboardUp = inset > 0;
      final focused = find.descendant(
        of: find.byType(Editor),
        matching: find.byWidgetPredicate((w) => w is EditableText && w.focusNode.hasFocus),
      );
      final remaining = find.descendant(of: find.byType(Editor), matching: find.byType(EditableText)).evaluate().length;
      if (focused.evaluate().isEmpty) {
        log('$name: keyboard ${keyboardUp ? 'opens (${inset.round()} dp)' : 'did not open'} but no field has focus ($remaining fields on screen): FAIL', ok: false);
        FocusManager.instance.primaryFocus?.unfocus();
        await pumpFor(const Duration(seconds: 1));
      } else {
        final fieldBottom = tester.getRect(focused.first).bottom;
        final visible = fieldBottom <= screenHeight - inset + 1;
        log('$name: keyboard opens (${inset.round()} dp) and the focused field stays visible: ${keyboardUp && visible ? 'PASS' : 'FAIL'}', ok: keyboardUp && visible);
      }
      // Type through a field's controller (the real keyboard is not scriptable).
      final target = focused.evaluate().isNotEmpty
          ? focused.first
          : find.descendant(of: find.byType(Editor), matching: find.byType(EditableText)).first;
      await tester.ensureVisible(target);
      (tester.widget<EditableText>(target)).controller.text = 'QA form check';
      await pumpFor(const Duration(milliseconds: 500));
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFor(const Duration(seconds: 1));

      // Date and time picker opens and cancels.
      if (dateTile != null) {
        final tile = find.descendant(of: find.byType(Editor), matching: find.byType(PickerTile));
        if (tile.evaluate().isEmpty) {
          log('$name: "$dateTile" picker: FAIL (tile not found)', ok: false);
        } else {
          await tester.ensureVisible(tile.first);
          await tester.tap(tile.first);
          await settle();
          final opened = find.byType(DatePickerDialog).evaluate().isNotEmpty;
          if (opened) {
            await tester.tap(find.text('Cancel').last);
            await settle();
          }
          log('$name: date picker opens and cancels: ${opened && find.byType(DatePickerDialog).evaluate().isEmpty ? 'PASS' : 'FAIL'}',
              ok: opened && find.byType(DatePickerDialog).evaluate().isEmpty);
        }
      }

      // Cancel with unsaved text asks to discard.
      final cancel = find.descendant(of: find.byType(Editor), matching: find.text('Cancel'));
      await tester.tap(cancel.last);
      await settle();
      final asked = find.text('Discard changes?').evaluate().isNotEmpty;
      if (asked) {
        await tester.tap(find.text('Keep').last);
        await settle();
      }
      final kept = find.byType(Editor).evaluate().isNotEmpty;
      log('$name: Cancel with edits asks "Discard changes?", Keep stays: ${asked && kept ? 'PASS' : 'FAIL'}', ok: asked && kept);
      if (!kept) return;
      await tester.tap(cancel.last);
      await settle();
      if (find.text('Discard').evaluate().isNotEmpty) {
        await tester.tap(find.text('Discard').last);
        await settle();
      }
      final closed = find.byType(Editor).evaluate().isEmpty;
      log('$name: Discard closes the form: ${closed ? 'PASS' : 'FAIL'}', ok: closed);
    }

    // Meeting.
    await quick('Schedule Meeting');
    await checkEditor('meeting', requiredMessages: ['is required'], dateTile: 'Starts', saveLabel: 'Save & Set Reminder');

    // Task.
    await quick('My Tasks');
    await tester.tap(find.text('New Task').first);
    await settle();
    await checkEditor('task', requiredMessages: ['is required'], dateTile: 'Due date (optional)', saveLabel: 'Save');
    await back();

    // Client / deal.
    await tester.tap(find.text('Pipeline').last);
    await settle();
    await tester.tap(find.text('Add New Deal').first);
    await settle();
    await checkEditor('client', requiredMessages: ['is required'], saveLabel: 'Save');
    await tester.tap(find.text('Home').last);
    await settle();

    // Room.
    await quick('Meeting Suites');
    await tester.tap(find.text('New Suite').first);
    await settle();
    await checkEditor('room', requiredMessages: ['is required'], saveLabel: 'Save');
    await back();

    // Event.
    await quick('Events and Holidays');
    await tester.tap(find.text('New Event').first);
    await settle();
    await checkEditor('event', requiredMessages: ['is required'], dateTile: 'Starts', saveLabel: 'Save');
    await back();

    log('write guard: ${blockedWrites.isEmpty ? 'no write was attempted' : 'blocked ${blockedWrites.join(', ')}'}: ${blockedWrites.isEmpty ? 'PASS' : 'FAIL'}',
        ok: blockedWrites.isEmpty);
    debugPrint('FORMS SUMMARY: ${results.where((r) => r.endsWith('PASS')).length} pass, ${failures.length} fail');
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
