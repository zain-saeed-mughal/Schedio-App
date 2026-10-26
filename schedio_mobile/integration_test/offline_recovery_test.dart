import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schedio_mobile/app.dart';
import 'package:schedio_mobile/core/providers.dart';
import 'package:schedio_mobile/core/widgets.dart';
import 'package:schedio_mobile/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Offline and recovery on a real device, read-only. The host script watches
/// for the QAMARK lines and switches airplane mode: OFFLINE_PLEASE -> on,
/// ONLINE_PLEASE -> off. Runs once per install (flag in SharedPreferences).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  AppMotion.ambient = false;

  testWidgets('offline message and recovery with Try again', (tester) async {
    final prefs = await tester.runAsync(SharedPreferences.getInstance) as SharedPreferences;
    if (prefs.getBool('qa_offline_done_v3') == true) {
      debugPrint('OFFLINE skipped: already run for this install');
      return;
    }
    final failures = <String>[];
    void log(String what, bool ok) {
      debugPrint('OFFLINE $what: ${ok ? 'PASS' : 'FAIL'}');
      if (!ok) failures.add(what);
    }

    Future<void> pumpFor(Duration d) async {
      final end = DateTime.now().add(d);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    bool showsError() => find.textContaining('Could not reach the Schedio server').evaluate().isNotEmpty ||
        find.textContaining('took too long').evaluate().isNotEmpty;

    app.main();
    for (var i = 0; i < 240 && find.byType(WorkspaceShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (find.byType(WorkspaceShell).evaluate().isEmpty) fail('No saved session');
    await pumpFor(const Duration(seconds: 3));
    final container = ProviderScope.containerOf(tester.element(find.byType(SchedioApp)));
    await tester.tap(find.text('Meetings').last);
    await pumpFor(const Duration(seconds: 6));
    log('Meetings loads online', !showsError());

    debugPrint('QAMARK OFFLINE_PLEASE');
    var offlineShown = false;
    await pumpFor(const Duration(seconds: 4));
    container.read(refreshProvider.notifier).refresh();
    for (var i = 0; i < 24 && !offlineShown; i++) {
      await pumpFor(const Duration(seconds: 5));
      offlineShown = showsError() && find.text('Try again').evaluate().isNotEmpty;
    }
    log('offline: clear "could not reach" message with Try again (no crash, no empty list)', offlineShown);

    debugPrint('QAMARK ONLINE_PLEASE');
    await pumpFor(const Duration(seconds: 30));
    if (find.text('Try again').evaluate().isNotEmpty) {
      await tester.tap(find.text('Try again').first);
      await pumpFor(const Duration(milliseconds: 600));
      final feedback = find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isNotEmpty ||
          find.text('Try again').evaluate().isEmpty;
      log('Try again shows loading instead of the old error', feedback);
      var recovered = false;
      for (var i = 0; i < 20 && !recovered; i++) {
        await pumpFor(const Duration(seconds: 2));
        recovered = !showsError() && find.text('Try again').evaluate().isEmpty &&
            find.byWidgetPredicate((w) => w is SchedioLoadingIndicator && w.isLoading).evaluate().isEmpty;
      }
      log('after reconnecting, Try again loads Meetings without restarting the app', recovered);
    } else {
      log('screen recovered on its own after reconnecting (automatic retry)', !showsError());
    }
    await tester.runAsync(() => prefs.setBool('qa_offline_done_v3', true));
    debugPrint('OFFLINE SUMMARY: ${failures.isEmpty ? 'all PASS' : failures.join(' | ')}');
    expect(failures, isEmpty);
  });
}
