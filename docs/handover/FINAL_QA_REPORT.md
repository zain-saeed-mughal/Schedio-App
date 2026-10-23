# Schedio Mobile: Final QA Report

Release r7 (`RELEASE_MANIFEST.md`), production API v2.1 at `https://schedio.live/api/v1/`, test phone Xiaomi 2404ARN45A (Android 16). Testing from 2026-10-22 to 2026-10-24.

**Overall status: READY FOR ANDROID CLIENT ACCEPTANCE, with two open conditions.**
- Every critical workflow passed on the phone against production.
- The backend v2.1 fixes are deployed and independently verified.
- Open condition 1: **website ↔ mobile sync has not been verified** (no website tester).
- Open condition 2: **notification read/unread and mark-all-read are untested**, because the account has no inbox notifications to act on.
- Neither condition is a known defect, but both should be checked before a full production rollout. iOS is not built.

Labels:
- **VERIFIED PASS**: proven on the phone against production, or by a named automated test.
- **(manual)**: observed by the tester.
- **FAIL**: tested and broken.
- **BLOCKED**: cannot be tested until an external step happens.
- **NOT TESTED**: not attempted (reason given).

## 1. Feature matrix

| Area | Feature | Result | Evidence |
|---|---|---|---|
| Start | Splash, saved session, environment check | VERIFIED PASS | r7 launch on the phone; `test/env_and_errors_test.dart` |
| Auth | Sign in | VERIFIED PASS (manual) | Tester signed in on r6 on 2026-10-24; server answers 401 for wrong credentials in under a second |
| | Session survives app updates | VERIFIED PASS | r6 → QA build → r7 installed in place, still signed in |
| | Expired session / blocked account handling | VERIFIED PASS (mocked) | 401 → sign-in, 403 `account_status` → notice; unit tests |
| | Logout and token revocation | NOT TESTED on production | Would end the live session; unit tests pass |
| | Registration, Request Staff Access | NOT TESTED on production | A real applicant would notify company admins; widget tests pass |
| Roles | Employees blocked from admin features | VERIFIED PASS | Company 2 employee: admin queue 403; task controls hidden for non-owners (`test/permissions_test.dart`) |
| Isolation | Company data separation | VERIFIED PASS | Company 2 account: company 1 meetings, tasks, notes 404; no company 1 rows in lists |
| Home | Dashboard, metrics, quick actions | VERIFIED PASS | Screen tour (21/21) and r7 screenshot |
| | Badge matches inbox | VERIFIED PASS | r6/r7 screenshots; `test/inbox_badge_test.dart` |
| Calendar | Month, week, day, agenda; feed shows meetings and events | VERIFIED PASS | Screen tour; live CRUD |
| Availability | Check, conflicts, suggestions | VERIFIED PASS | Live CRUD |
| Meetings | List, detail, editor and lookups | VERIFIED PASS | Screen tour |
| | Create, validation, overlap refusal | VERIFIED PASS | Live CRUD (422 on invalid and overlapping) |
| | Reschedule | VERIFIED PASS | Live, v2.1: new time persisted, no 500 |
| | Cancel | VERIFIED PASS | Live, v2.1: status cancelled, slot freed |
| | Delete | VERIFIED PASS | Live, v2.1: 204, then 404 |
| | Reminder follows changes | VERIFIED PASS | Reminder created, kept on reschedule, removed on cancel |
| | RSVP | NOT TESTED | Needs a meeting from another organiser |
| Notes | Create, read, edit, delete | VERIFIED PASS | Live CRUD |
| | Empty note rejected | VERIFIED PASS | 422 |
| Tasks | Create with assignee and due date, status, filter | VERIFIED PASS | Live CRUD |
| | Edit (title, priority, assignee, due date) and delete | VERIFIED PASS | Live, v2.1 (API); r7 task detail shows status, Edit and Delete on the phone (`UI task detail` step) |
| Clients | Create, edit, delete, validation | VERIFIED PASS | Live CRUD |
| Pipeline | Board, Spreadsheet, stage transitions | VERIFIED PASS | Live CRUD (3 transitions); bug checks |
| Rooms | Create, edit, amenities, capacity, delete, double booking, pagination | VERIFIED PASS | Live CRUD and v2.1 |
| Events | Create, edit, delete, calendar | VERIFIED PASS | Live CRUD |
| Public booking | Profile, slots, empty day vs error, date change, submit | VERIFIED PASS | Bug checks; live booking at the chosen slot |
| Notifications | Inbox list | VERIFIED PASS | Screen tour |
| | Read, unread, mark one, mark all | NOT TESTED | No database notification exists for the account; automated check ready |
| | Preferences save | VERIFIED PASS | Live (changed, read back, restored) |
| Push | Details in `FIREBASE_VERIFICATION_REPORT.md` | VERIFIED PASS (18 of 21; 3 not tested) | |
| Admin | Registration queue, detail, options | VERIFIED PASS (read-only) | Screen tour; live list filters |
| | Approve, reject | NOT TESTED | Needs an authorized test applicant and recipients |
| Profile/Settings | Screens, booking link, push status | VERIFIED PASS | Screen tour; bug checks |
| Persistence | After refresh and after reopening the app | VERIFIED PASS | Run 2 in a fresh process: all records shown, then deleted and gone |
| Sync | Website ↔ mobile | BLOCKED | No website tester or website access; plan in `HANDOVER_CHECKLIST.md` |
| UI | Every screen at phone/tablet sizes, large text, notch, keyboard | VERIFIED PASS (automated) | `test/responsive_test.dart` |
| Reliability | Offline message and recovery | VERIFIED PASS (2026-10-22) | Not repeated on r7 |
| Security | HTTPS only, cleartext off, backup off, no secrets in the package, no tokens in logs | VERIFIED PASS | r7 inspection |
| Forms | Creating records by tapping form screens | NOT TESTED on the phone | adb taps blocked on this phone; covered by widget tests and live API tests using the same payloads |

## 2. Fixes made during QA

| Problem | Root cause | Fix | Build |
|---|---|---|---|
| Pipeline crashed (`Map` is not `int?`) | `assigned_to` arrives as `{id, name}` | Tolerant ID parsing | r2 |
| Settings said push was not enabled; save failed | Hard-coded subtitle; icon removed by shrinking | Real push status; icon kept | r2 |
| Booking "could not read" | Slots reply has no `data` wrapper | Reads production shape; errors shown | r2 |
| Notification tap did nothing | No activity for `FLUTTER_NOTIFICATION_CLICK` | Intent filter | r2 |
| Release build never registered for push | First token request refused; no retry | Retries; "Setting up" status | r3 |
| Times saved hours off | Server ignores offsets; app sent UTC | Wall-clock time in the account timezone | r4 |
| Possible crashes on unusual data | Hard casts | Tolerant parsing | r5 |
| Badge 11 over an empty inbox | Dashboard metric disagrees with the inbox | Badge uses the inbox count | r6 |
| Task status, edit and delete missing; client and event edit/delete missing | Server omits `can_manage` for these; app required it; task edit/delete deliberately hidden before v2.1 | Role/ownership fallback; task Edit and Delete enabled | r7 |
| Editing a task would drop its meeting link | Editor sent only the screen's meeting id | Keeps the task's meeting | r7 |

## 3. Automated and device tests (current working tree, 2026-10-24)

| Suite | Result | Backend |
|---|---|---|
| `flutter analyze` | No issues | n/a |
| `flutter test` (163 unit and widget tests) | All pass | Mocked with sanitized production-shaped responses |
| `tool/api_contract_check.dart` | 60/60 present | Real production, no token |
| `crud_live_test.dart` run 1 (v2.1, notifications, full CRUD, UI) | 77 pass, 0 fail | Real production sandbox, on the phone |
| `crud_live_test.dart` run 2 (fresh process, persistence, deletion) | 17 pass, 0 fail | Real production sandbox, on the phone |
| `crud_live_test.dart` inventory | Cleanup verified; nothing unrelated removed | Real production (read-mostly) |
| `isolation_probe_test.dart` | PASS | Real production, company 2 account (read-only) |
| `push_diagnose_test.dart` | PASS: registration, dispatch, foreground receipt | Real Firebase and production (r6 code; push code unchanged in r7) |
| `bug_checks_test.dart` | 7/7 PASS | Real production, on the phone (r6 code) |
| `readonly_tour_test.dart` | 21 pass, 0 fail, 2 not tested (no records) | Real production, on the phone (r6 code) |

How device tests are run safely: the QA build is a profile build signed with the same upload key as the release, installed with `adb install -r` (never uninstall), launched directly, and its results read from `adb logcat`. The temporary signing change was reverted after every build (`android/app/build.gradle.kts` is unchanged in git).

Incident: one earlier attempt let `flutter drive` install the test build; the phone's install prompt was not confirmed in time, so the tool uninstalled and reinstalled the app and the saved sign-in was lost. No server data was affected. The process above prevents a repeat.

## 4. Test data on production

Sandbox company 1, test account only: [TEST] meeting 11 (scheduled 2026-12-15 20:00 +05:00), completed [TEST] task 8 and one more completed [TEST] task from the final run. Kept because no further cleanup was approved; delete them in the app (or ask the mobile team to) once approved.
