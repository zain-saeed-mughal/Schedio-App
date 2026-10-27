# Push, In-App Notifications and Meeting Reminders Report

Updated 2026-10-27, 20:50 PKT. Production (`https://schedio.live/api/v1/`), Schedio HQ (company 1). Phone: Xiaomi 2404ARN45A (Android 16 / HyperOS), signed in as Hammad Developer (user 3, account timezone UTC, phone clock Asia/Karachi).

Production access by the mobile team:
- Reads.
- One approved controlled test: [TEST] meeting 29.
- Read/unread changes to the account's single sandbox notification, restored afterwards.

No backend code was changed. No tokens or credentials were logged. App fixes are in the working tree only: not committed and not in a release build.

## Status at a glance

| Area | Status |
|---|---|
| In-app inbox with a real persistent notification (list, filter, refresh, detail, read/unread, mark all read, badge, restart, timezone) | **VERIFIED PASS on the phone** (section 3) |
| Automatic scheduled reminders | **FAIL (backend), fix not deployed.** Reminder 31 stayed pending (section 5) |
| Real reminder FCM delivery | **BLOCKED.** No reminder has been dispatched |
| Meeting time storage | **FAIL (backend).** API times are stored 5 hours early (section 6) |
| Release readiness | **Not ready to release.** The app side is ready for a candidate build. Release waits on the two backend fixes and an end-to-end reminder check |

## 1. Backend update received (verified by the backend team, 2026-10-27)

1. Firebase service-account path corrected to an existing, readable credentials file.
2. The notifications table had zero rows. This confirms the earlier finding that the empty inbox was not an app bug.
3. A database-only sandbox notification was created for user 3:
   - id `d75f2da1-a4d0-4ea8-b7d3-ad40e326b9bb`
   - title "[TEST] Schedio Notification Inbox"
   - category `meeting_reminders`
4. It appeared in the app's Reminders and Alerts screen, and individual read/unread was checked by hand on the phone.
5. Website Notification Center category filter and search queries fixed for the text `data` column (syntax and read-only SQL checks).
6. Failed reminder: reminder 31 (user 3, due 19:30 Asia/Karachi) stayed pending. **PostgreSQL uses Asia/Karachi while Laravel uses UTC.** A timezone-safe Reminder Engine patch is prepared and backed up on the server but **not deployed**.
7. The 5-hour meeting time storage bug is still unresolved.

## 2. Which build has the notification changes

| Build | SHA-256 (first 16) | Notification UI changes |
|---|---|---|
| r9 (`…20261026-r9.apk`) | `20d9f9ba75f67068` | No |
| r10 (`…20261027-r10.apk`) | `2fb1e1ca57961538` | No (built before these changes) |
| QA build of the working tree (installed on the phone since 19:34, used by the backend team's manual check and by these tests) | `7411fadb7997ede3` | **Yes.** Built 18:55; no `lib/` file has changed since (checked) |

The changes exist **only in the working tree and the QA build**. A new candidate build is needed to ship them (not built; needs approval).

## 3. Phone results with the real notification

Run with `integration_test/notifications_real_test.dart`, driven through the app's own screens against production. The notification was read from `schedio.live` by its id; no fixture or local record was used. Two runs: run 1 at 20:41 PKT, then run 2 as a fresh app start at 20:44. Screenshots are `nr-*.png` in `notification-evidence/`.

| Check | Result | Detail |
|---|---|---|
| Fetched from the production API | VERIFIED PASS | Host `schedio.live`; inbox `total 1`, id `d75f2da1…` |
| Parsing | VERIFIED PASS | Title, message, kind Reminder, created time |
| Inbox shows it | VERIFIED PASS | `nr-01-inbox.png` |
| Time in the account timezone | VERIFIED PASS | Row "REMINDER · Today, 2:41 PM" (UTC). The phone clock would show 7:41 PM. Matches the server's `time_formatted` "02:41 PM", `timezone` UTC |
| Unread filter | VERIFIED PASS | Shows the unread notification (`nr-02-unread-filter.png`) |
| Pull to refresh | VERIFIED PASS | List stays, no error |
| Detail opens | VERIFIED PASS | Title and message, no error (`nr-03-detail-read.png`) |
| Opening marks read on the server | VERIFIED PASS | `read_at` set |
| Mark unread / Mark read persist on the server | VERIFIED PASS | `nr-04-detail-unread.png` |
| Badge follows every change | VERIFIED PASS | 0 → 1 (unread) → 0 (opened) → 1 → 0; always equal to `meta.unread_count` |
| Mark all read | VERIFIED PASS | Run only because this is the account's only notification. Server `unread_count 0`, badge 0, row shown as read (`nr-06-all-read.png`) |
| Detail navigation | VERIFIED PASS (no target) | The notification has no `meeting_id`/`task_id`, so the detail is its destination and no link button is shown. Meeting and task links are covered by widget tests |
| Persistence after restart | VERIFIED PASS | Fresh process: still read on the server and in the app, badge matches (`nr-07-after-restart.png`) |
| Original state restored | VERIFIED PASS | It was read before the tests and is read again (only `read_at` changed) |

**Production item shape** (as returned by `GET notifications`):
- **Top level:** `id`, `title`, `message`, `type` (`meeting_reminder`), `meeting_id`, `task_id`, `read_at`, `is_read`, `created_at`, `created_at_formatted`, `time_formatted`, `timezone`.
- **Nested `data`:** `category`, `type`, `title`, `message`, `meeting_id`, `action_url`, `icon`, `color`.
- **List `meta`:** `current_page`, `last_page`, `per_page`, `total`, `unread_count`.

The app reads both the top-level and the nested fields. This exact shape is now a regression test.

## 4. App changes (working tree)

| Area | Change |
|---|---|
| Parsing (`core/models.dart`) | `NotificationKind` from category, type or class name. JSON-string `data`. `task_id`, `payload.meeting_id`, `is_read`. "Notification" as the fallback title |
| Inbox row (`core/widgets.dart`) | Kind icon and label plus the time in the account timezone (previously no time) |
| Detail (`records_screen.dart`) | "View task" for task notifications |
| Push while open (`app/shell.dart`) | Refreshes the inbox, badge and lists (previously only the dashboard) |
| Push tap | Marks read, then refreshes again so the badge drops |
| Routing (`app/push_routing.dart`, `core/push.dart`) | `category` fallback. Task pushes open the task. Responses, invitations and reminders open the meeting. Anything else opens the inbox |

No local inbox records are ever created.

## 5. Scheduled reminders

| Check | Result |
|---|---|
| Reminder created with a meeting; follows a time change | VERIFIED PASS (server data, meeting 29: `active_reminders` 0 → 1, kept after reschedule) |
| Dispatch at the due time | **FAIL (backend).** Reminder 31 due 19:30 PKT stayed pending; no push, no inbox record. Cause confirmed by the backend team: PostgreSQL session Asia/Karachi vs Laravel UTC |
| Real reminder push on the phone (foreground, background, closed, lock screen, tap) | **BLOCKED** until the Reminder Engine patch is deployed |
| Reminder shows once in the inbox, no duplicate from the push | **BLOCKED.** Duplicate filtering by `notification_id` passes in automated tests |

Not claimed: automatic reminders and real reminder FCM delivery are **not fixed**. The backend patch is not deployed.

## 6. Meeting time storage (backend, open)

| Sent | Save returns | Read returns |
|---|---|---|
| `19:30:00+05:00` (create) | `14:30+05:00` | `14:30+05:00` |
| `19:45:00Z` (update) | `19:45:00+00:00` | `19:45:00+05:00` |

Incoming times are converted to UTC and then written into a Karachi database session, so **every saved meeting time is 5 hours early**. The app must not compensate. The backend needs the database session timezone set to UTC (BACKEND_TIMEZONE_FIX.md fix A) together with UTC normalisation. No further meetings will be created or rescheduled until this is fixed.

## 7. Tests

| Suite | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | **318 passed, 0 failed.** That includes the 89 Calendar Hub and My Meetings tests and 27 notification tests |
| API contract check (production) | 60 endpoints, 0 missing, 0 problems |
| Phone: real notification, runs 1 and 2 | **28 checks, all PASS** (19 in run 1, 9 in run 2) |

## 8. Remaining blockers

| # | Blocker | Owner | Unblocks |
|---|---|---|---|
| 1 | Deploy the timezone-safe Reminder Engine patch (reminders due at the right instant) | Backend | Automatic reminders; real reminder push; reminder in the inbox |
| 2 | Fix meeting time storage: database session timezone UTC plus UTC normalisation | Backend | Correct meeting times from app and website; safe meeting tests; Sync test 06 |
| 3 | After 1 and 2: one end-to-end reminder test on the phone (app closed and locked, tap opens the meeting, one inbox entry) | Mobile, with backend | Reminder release sign-off |
| 4 | Real-event FCM payloads include `notification_id`, `type`, `meeting_id`/`task_id` | Backend | Mark-read-on-tap and no duplicates for real pushes |
| 5 | Invitations and task notifications need a second sandbox user (never sent to the person acting) | Backend/QA | Those categories on the device |
| 6 | Approval to build the next candidate (the notification UI changes are not in r9 or r10), then commit and push | Product owner | Shipping the app fixes |

## 9. Test data and phone state

- **Sandbox notification `d75f2da1…`:** read (its original state).
- **[TEST] meeting 29:** still exists (stored 19:45 PKT today, now past). Its reminder 31 is still pending on the server. Delete it with the user's approval once the backend team no longer needs it for the Reminder Engine fix.
- **Phone:** QA build of the working tree (`7411fadb…`), still signed in. r9 can be reinstalled at any time with `adb install -r`.

## 10. Files

- **App:** `lib/core/models.dart`, `lib/core/widgets.dart`, `lib/core/push.dart`, `lib/app/shell.dart`, `lib/app/push_routing.dart`, `lib/features/workspace/records_screen.dart`.
- **Tests:** `test/notifications_test.dart`.
- **Device tests:**
  - `integration_test/notifications_real_test.dart`
  - `notifications_probe_test.dart` (read-only)
  - `notifications_flow_test.dart`
  - `reminder_setup_test.dart`
  - `reminder_reschedule_test.dart`
- **Evidence:** `notification-evidence/`.
- **Backup:** `.local-backups/20261027-1833-pre-notifications/`.
