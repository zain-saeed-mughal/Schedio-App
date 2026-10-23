# Schedio Firebase Push Verification

Device: Xiaomi 2404ARN45A, Android 16 (HyperOS), sandbox account. Evidence labels: **Automated** (integration test against live Firebase and the production API), **Device log** (adb logcat or dumpsys), **Manual** (observed by the tester).

FCM test pushes (`notifications/test-push`, `php artisan firebase:test-push`) are delivered by Firebase only and do not create a Laravel database notification, so they never appear in the in-app inbox. That is expected, not an inbox bug.

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Firebase initialization | VERIFIED PASS | Device log: `FirebaseApp initialization successful`, once |
| 2 | Package and Firebase project | VERIFIED PASS | `schedio-app-bc57b`, `live.schedio.schedio_mobile`; r7 manifest |
| 3 | Push-enabled release flags | VERIFIED PASS | r7 built with `PUSH_ENABLED=true`; Settings shows push status |
| 4 | Device token registration | VERIFIED PASS | Automated 2026-10-24: "Device registered successfully."; registered token equals the current token (never logged) |
| 5 | Token refresh and retry | VERIFIED PASS | Unit tests; device: recovered from `SERVICE_NOT_AVAILABLE` on r3 |
| 6 | Notification permission | VERIFIED PASS | `POST_NOTIFICATIONS: granted=true` |
| 7 | High-importance channel | VERIFIED PASS | `schedio_high_importance_channel`, importance 4 |
| 8 | Foreground delivery | VERIFIED PASS | Automated 2026-10-24: received in the app; one tray notification; server sent to exactly 1 token |
| 9 | Background delivery | VERIFIED PASS | Device log and Manual (r3) |
| 10 | Closed-app delivery | VERIFIED PASS (manual) | Tester, r3 |
| 11 | Locked-screen delivery | VERIFIED PASS (manual) | Tester, r3 |
| 12 | Tap routing | VERIFIED PASS | Device and Manual: opens Schedio at the inbox |
| 13 | In-app inbox | VERIFIED PASS | Screen tour; list loads (currently empty) |
| 14 | Read and unread | NOT TESTED | No database notification exists for the account |
| 15 | Mark as read | NOT TESTED | Same |
| 16 | Mark all as read | NOT TESTED | Same; automated check is ready and restores state |
| 17 | Badge counts | VERIFIED PASS | Badge uses the inbox `unread_count`; r6/r7 screenshots; `test/inbox_badge_test.dart` |
| 18 | Preferences persistence | VERIFIED PASS | Automated: changed, read back, restored |
| 19 | Timestamps and timezone | PARTIAL | API timestamps carry offsets; push body text uses UTC (backend B-8) |
| 20 | Recipients and company isolation | VERIFIED PASS | Test push to the signed-in user only (1 token); company 2 account sees no company 1 data |
| 21 | No duplicates | VERIFIED PASS | One tray notification per push; local inbox polling stops while push is active |
| + | Reminders after meeting changes | VERIFIED PASS (server side) | Reminder created, kept after reschedule, removed after cancel; delivery of the reminder push itself not awaited (scheduled 45+ days ahead) |

The push code in r7 is unchanged since r3 apart from logging, so the r3 manual results still apply. To re-confirm on r7: close Schedio normally, run `php artisan firebase:test-push <sandbox test account email>`, check the notification arrives with the screen locked, and tap it.

To test read/unread: create a real notification for the test account (for example, have another sandbox user assign it a task or invite it to a meeting, with that user's agreement), then open the inbox and use Mark read / Mark unread / Mark all as read, or run the QA build with `CRUD_PHASE=notifications`.

Xiaomi, Oppo and Vivo: allow Autostart and set battery saver to "No restrictions" for Schedio.
