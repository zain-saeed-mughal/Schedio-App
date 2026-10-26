# Schedio Mobile: Physical-Device QA Report (r8)

Date: 2026-10-26. Device: Xiaomi 2404ARN45A, Android 16 (HyperOS). Production API v2.1 `https://schedio.live/api/v1/` (60/60 routes). Account: Schedio HQ sandbox test account (company 1), unless stated. Final build: **r8** (`RELEASE_MANIFEST.md`), installed on the phone and opening signed in.

Evidence types:
- **Automated (device):** an integration test running the app's real code on the phone against production.
- **Device log:** adb logcat or dumpsys.
- **Manual:** observed by the tester on the phone.

How the device tests ran: the QA build was installed as an update with `adb install -r`, never letting a tool uninstall the app. It was signed with the same upload key so the session was kept. It was launched directly, and results were read from the device log. Taps by adb are blocked on this Xiaomi, so screens were driven by the tests inside the app.

## 1. Bugs found and fixed (in r8)

| Bug | Root cause | Fix | Evidence |
|---|---|---|---|
| After going offline and back online, Try again kept showing "We could not load this" until the app was restarted | After an error, the retry kept the old error on screen while reloading (no feedback). Pooled connections were never reset after a network change. Riverpod's default retried every failure 10 times in bursts, including errors that will never succeed (54 failed requests in one minute offline) | Try again now shows the loading state. On a network failure, reads reset the connection pool and retry once. Automatic retries only for network failures, 3 times, 2/4/6 s apart | `test/network_recovery_test.dart` (7 tests). **Device:** with Wi-Fi truly off, the message appears; after reconnecting, Try again shows loading and loads Meetings without restarting (PASS) |

Earlier fixes in r2–r7 still hold (see `FINAL_QA_REPORT.md`): parsing, push registration and tap, timezone, permissions, task edit/delete and badge.

## 2. Feature results on the phone

| Area | Check | Result | Evidence |
|---|---|---|---|
| Account | Signed in to Schedio HQ (company 1) | VERIFIED PASS | Automated probe |
| Login / logout | Sign out of one account and sign in to another | VERIFIED PASS (manual) | Tester signed out of the company-2 account and signed in to Schedio HQ on r7 |
| Session | Kept across app updates and restarts | VERIFIED PASS | r7 → QA builds → r8 installed in place; still signed in |
| Company isolation | Company-2 employee cannot see company-1 data or admin tools | VERIFIED PASS | Read-only run on the company-2 account (admin quick action hidden, CRUD write guard refused) |
| Screens | Dashboard, calendar (month/week/day/agenda), meetings, pipeline, editor lookups, inbox, tasks, rooms, events, availability, booking, registration queue, settings, profile | VERIFIED PASS (22 of 23) | Automated screen tour |
| Meeting detail | [TEST] meeting 11 | FAIL (backend) | `GET meetings/11` returns HTTP 500; the app shows "The Schedio server had a problem" with Try again (r8 check) |
| Forms | Meeting, task, client, room, event: fields, dropdowns, empty-save validation, date picker, keyboard, discard guard | VERIFIED PASS | Forms tour 38/39 plus the r8 check (room Name field focuses and opens the keyboard). The write guard confirmed no record was created |
| Keyboard | Real keyboard (303 dp) keeps the focused field visible | VERIFIED PASS | Forms tour on the phone |
| Clients and pipeline | Create, read, edit, 3 stage changes, invalid stage 422, delete | VERIFIED PASS | CRUD run 78/78 |
| Tasks | Create with assignee and due date, edit (PUT), empty-title 422, status, filter, delete | VERIFIED PASS | CRUD run |
| Meetings | Create, validation, reschedule, cancel, delete (204), overlap 422, calendar feed, availability, suggestions | VERIFIED PASS | CRUD run |
| Reminders | Reminder created with a meeting, kept after reschedule, removed on cancel | VERIFIED PASS (server data) | CRUD run (dashboard reminder counts) |
| Notes | Create, read, edit, list, delete; empty note 422 | VERIFIED PASS | CRUD run |
| Rooms | Create with amenities, edit capacity and amenities, double booking 422, pagination meta, delete | VERIFIED PASS | CRUD run |
| Events | Create, edit, calendar, delete | VERIFIED PASS | CRUD run |
| Public booking | Submit a booking at a free slot; slot then taken; cleanup | VERIFIED PASS | CRUD run |
| Persistence | [TEST] records shown after a fresh app start, then deleted and gone | VERIFIED PASS | Restart run 17/17 |
| Notification preferences | Change, read back, restore; Save on the phone | VERIFIED PASS | CRUD run; bug checks |
| Inbox | Opens and finishes loading (empty for this account) | VERIFIED PASS | r8 check |
| Inbox read/unread, mark all read | — | NOT TESTED | The account has no database notifications; test pushes do not create inbox entries and the server sent no reminder |
| Offline | Clear message, Try again, recovery after reconnecting | VERIFIED PASS | Offline test with airplane mode and Wi-Fi off |
| Website ↔ mobile sync | — | BLOCKED | Needs a person signed in on schedio.live; plan in `HANDOVER_CHECKLIST.md` |

## 3. Firebase push on the phone

| Check | Result | Evidence |
|---|---|---|
| Token registered with the server | VERIFIED PASS | Push status active; test push targets 1 token |
| Foreground | VERIFIED PASS | Received in the app on `schedio_high_importance_channel`; tray record importance 4 |
| Background | VERIFIED PASS | Play services: received and delivered; Firebase: "Showing notification"; heads-up banner |
| Locked screen | VERIFIED PASS (manual) | Tester saw the Schedio notification on the lock screen |
| Closed app | PARTIAL | One delivery took 1,162 ms (Play services had to start the app, which suggests it was closed) and the notification was shown. A forced close before sending could not be done: a closed app cannot trigger its own push |
| Tap opens Schedio at the inbox | VERIFIED PASS | Tester tapped the notification; the app opened on "Reminders and Alerts" (detected automatically) |
| Reminder push from the server | FAIL (backend) | Meeting with a 15-minute reminder: no push arrived (Play services log shows nothing at the due time) |
| Timestamps | PARTIAL (backend) | API timestamps carry offsets; push text uses UTC |

## 4. Automated tests (current tree)

| Suite | Result | Backend |
|---|---|---|
| `flutter analyze` | No issues | n/a |
| `flutter test` (170 unit and widget tests) | All pass | Mocked, production-shaped |
| `tool/api_contract_check.dart` | 60/60 | Production, no token |
| `phone_qa_test.dart` (probe, tour, forms, bug checks, CRUD, offline) | See section 2 | Production, on the phone |
| `push_phone_test.dart` (foreground, background, closed, tap) | See section 3 | Firebase and production, on the phone |
| `r8_checks_test.dart` | 4/4 PASS | Production, on the phone |

## 5. Backend items (Laravel)

| # | Issue | Evidence | Severity |
|---|---|---|---|
| 1 | Meeting reminder pushes are not sent | [TEST] meeting 27 (reminder due 20:38 PKT, 2026-10-26): no push reached the device | High |
| 2 | `GET meetings/11` returns 500 (list and notes work) | Meeting 11 still has a blank note from before the v2.1 validation fix | Medium |
| 3 | Push text shows times in UTC | Earlier pushes | Medium |
| 4 | Dashboard unread metric can disagree with the inbox | App uses the inbox count | Low |
| 5 | Test-push reply includes part of the device token | Reply body | Low |
| 6 | Tasks, clients and events do not send `can_manage` | App infers it; server still enforces | Low |

## 6. Test data

Every [TEST] record created on 2026-10-26 was deleted, including reminder meeting 27. The earlier leftovers you asked to keep remain: [TEST] meeting 11 and two completed tasks.

## 7. Release status

r8 is installed on the phone and is the recommended build. Remaining before full rollout:
- **Website sync check:** needs a website tester.
- **Inbox read/unread:** needs a real notification.
- **Reminder pushes:** a backend fix is needed.
- **Closed-app push:** confirm with a server-side trigger (`php artisan firebase:test-push`).
