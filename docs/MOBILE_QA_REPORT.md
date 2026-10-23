# Schedio Mobile QA Report

Date: 2026-10-23. Base commit `ea1d5c7` plus the uncommitted fixes listed here. Backend: `https://schedio.live/api/v1/` (production). Device: Xiaomi 2404ARN45A, Android 16 / HyperOS, signed in as the sandbox test account (role `developer`, company "Schedio HQ").

Result labels: VERIFIED PASS (observed on the phone or proven by a named automated test against production-shaped data; "(manual)" means observed by the tester, not captured by automated evidence), FAIL, BLOCKED, NOT TESTED.

## A. Bugs fixed

### 1. Clients and Pipeline: `'_Map<String, dynamic>' is not a subtype of type 'int?'`

| Item | Detail |
|---|---|
| Root cause | `Record.fromJson` cast `assigned_to` straight to `int?`; production sends an object |
| File and method | `lib/core/models.dart`, `Record.fromJson` |
| Endpoint | `GET clients?status=<stage>&per_page=100` |
| Actual response (sanitized, from the phone) | `{data: [{id: int, company_name: String, ..., status: String, status_label: String, deal_value: int, assigned_to: {id, name}, created_by: {id, name}}], meta: {current_page, last_page, per_page, total}, links: {...}}` |
| Expected by the old app | `assigned_to: int` |
| Change | New `asInt` and `nameOf` helpers. All ID fields (`assigned_to`, `room_id` or `room`, `department_id` or `department`, `client_id` or `client`, `meeting_id`, `capacity`) accept a number, numeric string or `{id}` object. Assignee name read from `assigned_to`. Amenities, attachments and pagination numbers also tolerate objects and strings |
| Regression tests | `test/production_bugs_test.dart` group "bug 1" (5 tests, including the board rendering a production client) |
| Device result | VERIFIED PASS: Board and Spreadsheet render on production with no error |

### 2. Settings: "Background push is not enabled" and failed save

| Item | Detail |
|---|---|
| Root cause, part 1 | The Device alerts subtitle was a hard-coded sentence ending "Background push is not enabled", shown on every build |
| Root cause, part 2 | Not reproducible on the current build. The API save was proven to work (`POST notifications/preferences` with unchanged values returned `{message, data: {channels, categories}}`). Most likely cause in the reporting build: the local Device alerts toggle shows a notification using `ic_stat_schedio`, which release resource shrinking can remove, raising a platform error shown as "Something went wrong" |
| Files and methods | `lib/features/settings/settings_screen.dart` (panel build), `lib/core/providers.dart` (`dashboardProvider`), `lib/core/api.dart` (`messageFor`), `android/app/src/main/res/raw/keep.xml` |
| Change | Settings shows "Push notifications: On for this device" when push is enabled and registered, explains how to allow notifications when it is not, and offers local device alerts only on builds without push (prevents duplicate alerts). Local inbox polling stops while push is active. The icon is explicitly kept in release builds. Unknown HTTP statuses now show their code, e.g. "Something went wrong (HTTP 400)" |
| Regression tests | `test/production_bugs_test.dart` group "bug 2" (3 tests) |
| Device result | VERIFIED PASS: push status shows on; Save preferences confirmed "Notification preferences saved." |

### 3. Public booking: "The server sent a response this app could not read"

| Item | Detail |
|---|---|
| Root cause | The slots reply has no `data` wrapper; the app read `['data'] as List`. Profile fields `booking_headline` and `booking_bio` were also ignored |
| File and method | `lib/features/booking/booking_screen.dart` (`load`, `book`), `lib/core/models.dart` (`BookingProfile.fromJson`) |
| Endpoints | `GET public/booking/{username}`, `GET public/booking/{username}/slots?date=&duration=` |
| Actual responses (sanitized) | Profile: `{data: {id, name, title, avatar_url, timezone: "Asia/Karachi", booking_headline, booking_bio, durations: [15, 30, 45, 60], default_duration: 15}}`. Slots: `{date, duration, slots: [{start_time: "2026-10-24T09:00:00+05:00", end_time, formatted_time, time_24}], total_available}` |
| Change | Slots read from `slots` (or `data`, or `data.slots`); anything else is reported as an error, never as an empty day. Profile reads the production names and uses `default_duration`. "No available slots" now appears only when the server really returns none; errors show an error banner. Booking confirmation reads `calendar_export_url` with or without `data` |
| Regression tests | `test/production_bugs_test.dart` group "bug 3" (4 tests) |
| Device result | VERIFIED PASS: profile loads; today shows a genuine empty day (after hours); tomorrow shows 16 slots in Asia/Karachi; no parsing error |

### 4. Push notification tap did nothing

| Item | Detail |
|---|---|
| Root cause | Backend notifications carry `click_action: FLUTTER_NOTIFICATION_CLICK`; no activity declared that action. Phone log: `Error: Activity not started, unable to resolve Intent { act=FLUTTER_NOTIFICATION_CLICK }` |
| File | `android/app/src/main/AndroidManifest.xml` |
| Change | Intent filter for `FLUTTER_NOTIFICATION_CLICK` on `MainActivity` |
| Device result | VERIFIED PASS: tapping a background notification opened Schedio and routed to the notifications inbox |

### 4b. Release build: push never registered, Device alerts shown instead

| Item | Detail |
|---|---|
| Root cause | Google Play services refused the first token request (`SERVICE_NOT_AVAILABLE`); the app stopped trying for the whole session, so Settings fell back to the Device alerts switch |
| Files | `lib/core/push.dart`, `lib/app/shell.dart`, `lib/features/settings/settings_screen.dart` |
| Change | Retries with backoff and on app resume, keeps listening for token refresh, Settings shows the real push state |
| Tests | `test/push_test.dart` (3 new), `test/production_bugs_test.dart` (2 new) |
| Device result | VERIFIED PASS on the r3 release build: token retrieved and Settings shows "Push notifications: On for this device" (shown only after the server accepts the device). Test push delivery pending |

### 5. Other hardening from the API audit

Data-only pushes are now displayed in the background and when closed (`schedioBackgroundMessage` in `lib/core/firebase_push.dart`); token refresh errors no longer surface as unhandled errors; approval options accept role objects and a `data` wrapper; record detail, registration departments and inbox alerts no longer require exact shapes.

## B. Firebase evidence (2026-10-23, production)

| Check | Result | Evidence |
|---|---|---|
| Firebase project and package | VERIFIED PASS | `google-services.json`: project `schedio-app-bc57b`, package `live.schedio.schedio_mobile` |
| Initialization | VERIFIED PASS | `FirebaseInitProvider: FirebaseApp initialization successful`; started once |
| Notification permission | VERIFIED PASS | `POST_NOTIFICATIONS: granted=true` |
| Channel | VERIFIED PASS | `schedio_high_importance_channel`, `mImportance=4`; manifest default channel matches |
| Token registration | VERIFIED PASS | `POST devices`: "Device registered successfully." (token not logged); the token the app holds equals the current FCM token |
| Backend dispatch | VERIFIED PASS | `notifications/test-push`: `success: true`, 2 tokens: current device delivered with a message ID; an old token from the earlier release install returned `NotRegistered` |
| Foreground | VERIFIED PASS | Message received by the app on the high-importance channel; exactly one notification in the tray |
| Background | VERIFIED PASS | With the launcher in front: `FirebaseMessaging: Showing notification`, tray record importance 4 on the correct channel; the user saw it on the phone |
| Notification tap | VERIFIED PASS | Opened the app through `FLUTTER_NOTIFICATION_CLICK` and routed to the inbox |
| Foreground, background, normally closed and locked screen on the r3 release build | VERIFIED PASS (manual) | Observed on the phone by the tester on 2026-10-23 after the backend test push; not captured by automated logs |
| Notification tap on the r3 release build | VERIFIED PASS (manual) | Tester confirmed tapping opens Schedio |
| Real feature notifications (meeting, task, booking) | NOT TESTED | Need sandbox records |

## C. Feature matrix

| Area | Feature | Result | Evidence |
|---|---|---|---|
| Authentication | Sign in, saved session after app updates | VERIFIED PASS | Owner signed in on the phone; session survived in-place updates |
| | Logout and token revocation | NOT TESTED on production | Avoided revoking the owner's session; unit tests pass |
| | Registration, Request Staff Access | NOT TESTED on production | Would create a real applicant; widget tests pass |
| | Pending, rejected, inactive account handling | NOT TESTED on production | Local API audit PASS on 2026-10-22 |
| | Company isolation | BLOCKED | Needs the staff test account (rotated credentials) |
| Dashboard | Metrics, cards, quick actions, navigation | VERIFIED PASS | Read-only tour and screenshots |
| Calendar | Month, week, day, agenda | VERIFIED PASS | Read-only tour |
| | Create, edit, cancel, conflicts | FAIL (backend) | Create, conflicts and calendar feed PASS; reschedule and cancel are saved but the server answers HTTP 500. See section G |
| Meetings | List | VERIFIED PASS | Tour |
| | Detail, CRUD, notes | FAIL (backend) | Create, read and notes CRUD PASS; meeting delete HTTP 500. RSVP NOT TESTED. See section G |
| Clients and pipeline | Board, Spreadsheet | VERIFIED PASS | Bug checks on the phone |
| | Create, edit, stage change, delete | VERIFIED PASS | Live API on the phone, see section G |
| Tasks | List | VERIFIED PASS | Tour |
| | Create, assignment, due date, status, detail | VERIFIED PASS | Live API on the phone; the API has no task edit or delete. See section G |
| Rooms and events | Lists | VERIFIED PASS | Tour |
| | Rooms and events CRUD, amenities, room conflicts | VERIFIED PASS | Live API on the phone, see section G |
| Availability | Screen, suggestions shape | VERIFIED PASS | Tour; shape probe `{slots, count}` |
| Public booking | Profile, slots, empty day vs error, date change | VERIFIED PASS | Bug checks |
| | Submit a booking | VERIFIED PASS | [TEST] booking on the test account at the correct local time; its meeting cannot be deleted (backend) |
| Notifications | Inbox list | VERIFIED PASS | Tour |
| | Read, unread, mark all | NOT TESTED | The account had no notifications during the run; the rerun was interrupted by a USB disconnect |
| | Preferences save | VERIFIED PASS | Bug checks and probe |
| Settings, profile | Screens | VERIFIED PASS | Tour |
| Admin | Registration queue list | VERIFIED PASS | Tour |
| | Approve, reject | NOT TESTED | Queue lists and filters PASS; submitting a [TEST] applicant would notify the other admins in the company |
| Website sync | All modules | BLOCKED | Needs a person working on the website |
| UI | Layout at all sizes, text scales, notch, keyboard | VERIFIED PASS | `test/responsive_test.dart` (32 screens) |
| Reliability | Offline message and recovery | NOT TESTED on current code | PASS on 2026-10-22 |

Automated: `flutter analyze` clean; `flutter test` 149 passing. API contract: 58 of 58 routes present on production; authenticated read shapes captured for 17 endpoints (`integration_test/api_shape_probe_test.dart`).

## D. Backend actions for the Laravel developer

| # | Issue | Severity |
|---|---|---|
| 1 | Delete device tokens that FCM reports as `NotRegistered` (the test push still targets an old token) | Medium |
| 2 | The test-push reply exposes the first 16 characters of each device token; remove them | Low |
| 3 | Notification text formats times in UTC ("02:09 PM" for a 19:09 Pakistan send); format in the recipient's timezone | Medium |
| 4 | Confirm that company "Schedio HQ" is the isolated sandbox, and share rotated test credentials privately | High |
| 5 | For the terminated-app test: after the app is closed, run `php artisan firebase:test-push <sandbox test account email>` | Medium |

## E. Remaining issues

| Issue | Severity | Status |
|---|---|---|
| Real feature notifications (meeting, task, booking) | Medium | NOT TESTED |
| Meeting reschedule, cancel and delete return HTTP 500 | High | Backend; see section G |
| Website and mobile synchronization | High | BLOCKED on a website tester |
| Company isolation with the staff account | High | BLOCKED on rotated credentials |
| Push delivery on the r3 release build | Done | VERIFIED PASS (manual): all app states and tap |
| iOS | Medium | BLOCKED: needs Firebase iOS config, APNs key and a Mac |

## F. Release deliverables

See "Release artifacts" at the end of `MOBILE_RELEASE_CHECKLIST.md` for paths, sizes, signing and checksums.

Recommendation: not production-ready yet. The three reported bugs, push delivery in foreground and background, and notification taps are fixed and verified on the phone. Writes, synchronization, isolation and terminated-app push remain to be verified.

## G. Live CRUD on production (2026-10-23, night)

Sandbox check (read-only, `integration_test/sandbox_probe_test.dart`): account "Mobile App Tester" (user 8), company 1 "Schedio HQ", role `developer`, `can_administer` and `can_manage_rooms` true. Writes used only "[TEST] ..." records assigned to the test account, with no other participants and nothing company-wide.

Method: `integration_test/crud_live_test.dart` on the phone with the app's own API client, payloads and models. Phase `create` runs create, read, update, re-read and delete per workflow and checks the app's screens; phase `reopen` checks the records in a fresh app process, deletes them and checks they disappear. Final run: 56 pass, 6 fail (all backend errors).

| Workflow | Result | Evidence |
|---|---|---|
| Clients CRUD, validation, pagination, model | VERIFIED PASS | Update read back; deleted client returns 404; empty name returns 422 |
| Pipeline stage changes | VERIFIED PASS | 3 stage changes persisted; invalid stage returns 422 |
| Tasks: create, assignee, due date, status, filter | VERIFIED PASS | Edit and delete not offered by the API |
| Meetings: create, read, validation, conflicts, suggestions, calendar feed | VERIFIED PASS | Overlap returns 422; cancelled meeting frees the slot |
| Meetings: reschedule, cancel | FAIL (backend) | Change is saved, but the server replies HTTP 500 |
| Meetings: delete | FAIL (backend) | Always HTTP 500 |
| Notes CRUD | VERIFIED PASS | Empty note is accepted (backend validation gap) |
| Rooms CRUD, amenities, double booking | VERIFIED PASS | `GET rooms` has no pagination `meta` |
| Events CRUD | VERIFIED PASS | Not company-wide |
| Public booking | VERIFIED PASS | Booked at the chosen slot (09:00 Asia/Karachi); slot no longer offered |
| Notification preferences | VERIFIED PASS | Changed, read back, restored |
| Notification read and unread | NOT TESTED | No notifications existed during the run; rerun stopped by a USB disconnect |
| Registration queue | VERIFIED PASS (read-only) | Approve and reject not exercised |
| Persistence after refresh and after reopening the app | VERIFIED PASS | Shown in Meetings, Pipeline, My Tasks, Meeting Suites, Events |
| Creating records through the form screens | NOT TESTED | Taps are blocked on this phone |

App fixes (in r4):
- Times were shifted by the timezone offset. The server keeps a time's wall-clock part and ignores its offset, and the app sent UTC. Times are now sent in the account timezone with offset; covered by `test/api_time_test.dart`.
- Tasks: the assignee is now read from `assignee`.
- Test harness: a bug that hid failures in the live test is fixed.

Backend actions:
1. Meeting update and cancel save, then return 500 (meetings 4, 6, 7). High.
2. Meeting delete always returns 500 (meetings 1–10). High.
3. Empty notes are accepted. Low.
4. `GET rooms` has no pagination `meta`. Low.
5. There's no task edit or delete endpoint. Low.
6. The server ignores time offsets. Medium.

Left on production: 10 cancelled [TEST] meetings (one has a blank note), 6 completed [TEST] tasks, and 10 notifications to the test account. No [TEST] clients, rooms or events remain.


> Superseded for handover by `docs/handover/` (final release r6, 2026-10-24).
