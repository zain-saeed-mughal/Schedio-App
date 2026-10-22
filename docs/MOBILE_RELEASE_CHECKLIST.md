# Schedio Mobile Release Checklist

Status values: PASS, FAIL, BLOCKED, NOT TESTED. A feature is PASS only with evidence: a named automated test, or a recorded device run.

Last updated: 2026-10-22, evening (base `main` at `3d949b1` plus uncommitted fixes listed below). Flutter 3.47.7 / Dart 3.13.5.

Device: Android phone model `2404ARN45A` (serial `p7a6a6mfqwx8ww9l`). Backend: the isolated local Laravel API (`scripts/start_local_sqlite.ps1`, SQLite), reached over USB (`adb reverse`) and, for the Wi-Fi and restart checks, over Wi-Fi only at `http://192.168.9.211:8090/api/v1/`. This proves the app against the real Laravel API code, not against a hosted HTTPS server.

## Automated checks

| Check | Result | Evidence |
|---|---|---|
| `flutter analyze` | PASS | No issues found |
| `flutter test` (unit, widget and layout) | PASS | 128 tests: the 65 from earlier, 1 calendar short-event regression, 32 screen layout sweeps (`test/responsive_test.dart`, missed taps are fatal), 13 robustness tests (`test/robustness_test.dart`) , 15 official API compatibility tests , a push token-refresh regression and foreground display and tap payload checks (`test/official_api_test.dart`, including the v2 dashboard, lookups and task status shapes) |
| Layout sweep: every screen at 320, 360, 390, 430, 600 and 800 wide, 2 landscape sizes, text scale 1.0, 1.3 and 2.0, plus notch, side cutout, gesture bar and open keyboard | PASS | `test/responsive_test.dart`: 32 screen variants x 28 configurations, 0 overflow or render errors (the first run found 9 problem areas, all fixed) |
| Signed production release APK (current code) | PASS | 2026-10-22 evening: `flutter build apk --release --dart-define=APP_ENV=production` built 58.7 MB, signer SHA-256 `807f482b...e0e181` (upload key), binary has no `10.0.2.2`, `127.0.0.1`, `192.168.`, `:8090` or test accounts; only the production API URL | Rebuilt later the same evening after the official API and Firebase changes: release AAB 58.1 MB (production, push off) and push-enabled release APK 59.6 MB, both signed with the same upload key, no development addresses. Gradle warns that one plugin has not migrated to built-in Kotlin (warning only) |
| Local API workflow audit | PASS (49/50, 1 by design) | Scripted run on 2026-10-22 against the local Laravel API with three seeded accounts (admin and employee in company A, employee in company B) plus accounts created through registration. Covers rooms, meetings, conflicts, availability, cancel, delete, events, registration, approval, rejection, sign-in states and token handling. The one miss: the server accepts a rejection without a reason and stores a default, matching the website; the app always asks for a reason. All test data and temporary tokens were removed afterwards |
| Account status and token checks on the local API | PASS | Deactivated account: `auth/me` and sign-in return 403 `account_status: inactive` with the reason. Expired token: 401. Revoked token after logout: 401. Invalid or missing token: 401 |
| Emulator run against the local API | PASS | Pixel 7 emulator, debug build with `API_BASE_URL=http://10.0.2.2:8090/api/v1/`: saved session restored, dashboard loaded live data, loader shown during load |
| `integration_test/app_test.dart` on the phone | NOT TESTED on current code | Earlier PASS. On 2026-10-22 it failed because the test tapped before the splash finished (test timing after the loader change); the test now waits for the splash. Rerun pending: the phone install prompt timed out |
| `integration_test/staging_test.dart` on the phone | NOT TESTED on current code | Earlier PASS. On 2026-10-22 sign-in for 3 accounts passed, then the test typed before the task editor finished loading (test timing); now waits for the field. Rerun pending |
| `integration_test/workflows_test.dart` on the phone | PASS | 2026-10-22 run 3, with the calendar fix: clients, meetings, notes, 4 calendar views, inbox, preferences; 0 layout errors. The run before the fix failed on the short-meeting overflow |
| `integration_test/remaining_features_test.dart` on the phone | PASS | 2026-10-22 run 3: meeting with pickers, external guest saved as a new client; registers its own applicant and approves it in the app as a manager |
| `integration_test/device_checks_test.dart` on the phone | FAIL (booking step only) | 2026-10-22: dashboard PASS, offline message PASS, offline recovery PASS (run 2). Booking FAIL in run 3: the tap on tomorrow did not select it; the app now accepts date taps during loading and the test retries and logs. Rerun pending |
| `integration_test/session_persistence_test.dart` on the phone, Wi-Fi only | PASS (earlier build) | Launch 1 signs in over Wi-Fi; after a force-stop, launch 2 opens the workspace with the saved session (not re-run on 2026-10-22) |
| Signed release on the phone | PASS (smoke) | Installed and launched to sign-in; not debuggable. Sign-in BLOCKED: staging has no DNS. |
| `integration_test/staging_smoke_test.dart` (HTTPS staging, read-only) | BLOCKED | Written and analyzed; refuses HTTP, private hosts and non-staging builds. Needs the staging server and staging test credentials. |
| API contract check, development copy | PASS (56/58) | `tool/api_contract_check.dart`: 56 of 58 routes present, 13 of 13 authenticated reads return 200 JSON with expected fields; only the 2 push device routes are missing |
| API contract check, official production | PASS (58/58 routes present) | 2026-10-22 late evening, read-only, no token: all 58 routes present, none open or non-JSON. Presence only; authenticated responses NOT TESTED because the replacement credentials were published in the shared contract and must be rotated again |
| Production on the physical phone | PASS (read-only) | 2026-10-23: read-only tour on 2404ARN45A against `schedio.live` with the owner's saved session: 19 screens PASS, 0 FAIL, 4 detail screens NOT TESTED (no records). No API errors on any screen. Firebase initialized; notification permission granted; `POST /devices` succeeded. Writes, synchronization and push delivery NOT TESTED |
| API contract check, hosted staging server by IP | PASS (56/58) | `SCHEDIO_HOST=staging.schedio.live dart run tool/api_contract_check.dart http://203.215.161.245/api/v1/`: same 52 routes as the development copy, only the 2 push device routes missing. Plain HTTP and no DNS yet. This server runs the development copy, not the official backend |
| Official backend contract | BLOCKED | No access to the official repository, documentation or an official staging server |

## Defects found on the device and fixed (this branch)

| Defect | Severity | Regression test |
|---|---|---|
| Meetings tab failed when `metadata` was `[]` | P1 | `model_parsing_test.dart` |
| Same risk at sign-in for empty preference `categories` | P1 | `model_parsing_test.dart` |
| Pull-to-refresh while offline leaked an unhandled `ApiFailure` (every list screen) | P1 | `features_test.dart` "pull to refresh while offline", fails without the fix |
| Keyboard stayed open after sign-in and hid the bottom bar | P2 | `device_checks_test.dart` |
| Previous tab stayed laid out after a tab switch | P2 | `features_test.dart` navigation |
| Calendar day and week: meetings under about 40 minutes overflowed their block (yellow stripes in debug, clipped time in release) | P2 | `workflow_test.dart` "short meetings fit", fails without the fix; phone workflows run 3 |
| Dashboard, pipeline KPI strip, registration banner, booking and home date strips, detail header, calendar header and sign-in footer overflowed at 320 wide or larger system fonts | P2 | `responsive_test.dart` |
| Settings crashed if opened before the account finished loading | P2 | `robustness_test.dart` |
| Unexpected server data showed raw Dart errors to users (22 places) | P2 | `robustness_test.dart` "unexpected server shape" |
| Booking ignored a date tap while slots were loading, so the day did not change | P3 | `robustness_test.dart`, fails without the fix |
| Editors discarded typed changes on Cancel or back without asking | P3 | `robustness_test.dart` "unsaved changes" (4 tests) |

## Official API integration changes (2026-10-22, evening)

Made after the official backend documentation arrived. All are backward compatible with the development API, and covered by `test/official_api_test.dart` (10 tests).

| File | Change |
|---|---|
| `lib/core/api.dart` | `ApiFailure.unsupported` marks a missing route; empty or `204` replies count as success; `dashboard` and `lookups` are rebuilt from other endpoints when their route is missing; notification filters also send `filter` |
| `lib/core/models.dart` | `resultOf` and `slotsOf` read the documented and current shapes; notes accept `title`, `content` and a list of action items; `Dashboard` constructor |
| `lib/features/availability/availability_screen.dart`, `lib/features/workspace/editor.dart` | Availability and suggestions accept both shapes; participant names fall back to the user list |
| `lib/features/workspace/records_screen.dart` | Detail screens fall back to the list record when the detail route is missing; tasks with `pending` show the official status set |
| `lib/features/settings/settings_screen.dart` | Preferences also send `channels` |
| `lib/core/firebase_push.dart`, `lib/main.dart` | Firebase Cloud Messaging transport, only started when built with `PUSH_ENABLED=true`; keeps the classic FCM registration token the backend expects |
| `pubspec.yaml` | Added `firebase_core` and `firebase_messaging` |
| `android/build.gradle.kts`, `android/app/build.gradle.kts` | Google Services plugin (added by the project owner), now applied only when `google-services.json` exists so clean checkouts still build. Native `firebase-analytics` was also added by the owner: it collects usage data and must be declared in the Play data safety form, or removed |

## Screen audit and responsiveness (2026-10-22)

Every screen was rendered by `test/responsive_test.dart` with long titles and full data at widths 320, 360, 390, 430, 600 and 800, landscape 740x360 and 932x430, text scale 1.0, 1.3 and 2.0, plus a notch with gesture bar, a side cutout in landscape, and the keyboard open. Result after fixes: 0 overflow or render errors.

| Screen | Layout sweep | Issues found and fixed |
|---|---|---|
| Splash | PASS (covered by launch tests) | none |
| Sign in | PASS | Footer could not wrap at 2.0 text: now wraps and centers |
| Registration | PASS | Same footer fix |
| Dashboard | PASS | Workspace pill, registration banner (fixed 112 height), week date strip (fixed 64 height) overflowed: now flexible or grow with text |
| Quick actions sheet | PASS | Fixed through the dashboard fixes behind it |
| Calendar month, week, day, agenda | PASS | Header pill could not wrap; short meetings overflowed their blocks |
| Meetings, tasks, rooms, events, notifications, notes lists | PASS | none |
| Pipeline | PASS | KPI strip fixed at 92 height: now grows with text |
| Meeting, task, client, room, event detail | PASS | Header time column and pipeline label overflowed at large text |
| Meeting, task, client, room, event, note editors | PASS | Added unsaved-changes prompt and drag to dismiss the keyboard |
| Availability | PASS | none |
| Public booking | PASS | Date strip grows with text; date taps during loading now work |
| Profile | PASS | none |
| Settings | PASS | Crash if opened before the account loaded |
| Registration queue, approval | PASS | none |

Not covered automatically: real tablet hardware, iOS devices, and screen readers. Large-screen layouts reuse the phone layout at full width; content is readable at 600 and 800 wide with no errors, but there is no dedicated two-pane tablet design.

## Features

| Feature | Implementation | API | Automated | Device | Release ready | Remaining blocker |
|---|---|---|---|---|---|---|
| Sign in and validation | Complete | VERIFIED (local) | PASS | PASS (USB and Wi-Fi) | BLOCKED | Hosted HTTPS API |
| Registration | Complete | VERIFIED (local audit: 201 pending, duplicate email 422) | PASS (workflow_test) | NOT TESTED | BLOCKED | Hosted API; device run |
| Pending, rejected, inactive accounts | Complete | VERIFIED (local audit: 403 with `pending`, `rejected`, `inactive`) | PASS | NOT TESTED | BLOCKED | Hosted API |
| Session persistence across restart | Complete | n/a | PASS | PASS (Wi-Fi) | PASS | |
| Token expiry, revocation, deactivation | Complete | VERIFIED (local audit: expired 401, revoked 401, deactivated 403) | PASS | NOT TESTED | BLOCKED | Hosted API |
| Logout and token revocation | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Role and company isolation | Server enforced | VERIFIED (local) | PASS | PASS | BLOCKED | Repeat on staging |
| Dashboard | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Calendar month, week, day, agenda | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Meetings list, detail, create, edit | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Meeting cancel, delete | Complete | VERIFIED (local audit: organizer only, cancel frees the slot and leaves the calendar feed, delete then 404) | PASS (workflow_test) | NOT TESTED | BLOCKED | Device run; hosted API |
| RSVP and notification delivery (in app) | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Meeting notes | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Clients pipeline, spreadsheet, edit | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Tasks create and status | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Notifications open, read, preferences | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Public booking | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Registration approval | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Registration rejection | Complete | VERIFIED (local audit) | PASS | NOT TESTED | BLOCKED | Device run |
| Rooms, events, availability | Complete | VERIFIED (local audit: room and event create, detail, update, delete, permissions and company isolation; availability conflict, free slot, suggestions, invalid range) | PASS (editors, room and event detail) | NOT TESTED | BLOCKED | Device run |
| Offline message and recovery | Complete | n/a | PASS | PASS | PASS | |
| Wi-Fi only (no USB) | Complete | n/a | n/a | PASS (local server over LAN) | BLOCKED | Repeat against hosted HTTPS |
| Push notifications | Firebase transport implemented (`lib/core/firebase_push.dart`), off unless built with `PUSH_ENABLED=true`; initialized once with `DefaultFirebaseOptions.currentPlatform` (FlutterFire config for project `schedio-app-bc57b`, Android only; iOS reports unsupported and push stays off) | Routes present on production (unverified) | PASS (6 tests) | NOT TESTED | BLOCKED | Delivery needs: backend FCM sending, a signed-in push-enabled build on a phone, then a real reminder. iOS needs `GoogleService-Info.plist` and an APNs key. Android Firebase file is in place (git-ignored) |
| Web to mobile sync | Shared database | VERIFIED via a second API session | PASS | PASS (staging_test, workflows_test) | BLOCKED | Website UI check on staging |

## Synchronization report

- **Model:** one Laravel database and API; the app keeps no business data of its own.
- **Verified on the phone:**
  - a task created in the app, then changed by a second session, showed the new status after refresh;
  - a meeting created through the API showed up in the app's Meetings list and all calendar views;
  - an RSVP sent by another account produced a notification in the app.
- **Not verified:** the website UI itself. The local web pages can't render because their frontend assets aren't built, and the web frontend is out of scope. This must be checked on staging (create on web, see on mobile, and the reverse).
- **Refresh strategy:** a full refresh when the app returns to the foreground, pull to refresh on every list, targeted refresh after each action, and a 30-second dashboard and badge refresh while the app is open (paused in the background). This isn't real-time; real-time would need server broadcasting (see BACKEND_INTEGRATION_HANDOFF.md section 10).

## Reminder and notification report

- Reminders are scheduled and sent only by Laravel (`schedio:process-reminders`, queue jobs). The app does not schedule reminders.
- In-app notifications: list, open, mark read (automatic on open), mark unread, delete and preferences all work against the API. RSVP delivery was verified on the device.
- Local device alerts: optional, raised when the app refreshes. Not true background push.
- Background push: mobile scaffolding is in place (`lib/core/push.dart`, `lib/app/push_routing.dart`) and covered by 6 tests: token registration, refresh, de-duplication, tap routing, unregister on logout, and silence when disabled. Delivery is BLOCKED: there are no `devices` endpoints and no Firebase project configuration. It is disabled unless built with `--dart-define=PUSH_ENABLED=true`.

## Release configuration

| Item | Status | Evidence |
|---|---|---|
| Environment profiles | PASS | `lib/core/env.dart`, unit tested |
| Release builds reject HTTP and private hosts | PASS | Unit tested; release binary contains no `10.0.2.2`, `127.0.0.1`, `192.168.`, `:8090`, test accounts or credential references |
| Cleartext only in debug | PASS | Release manifest disables cleartext |
| Upload keystore | PASS | `C:\Users\aliah\.schedio\schedio-upload.jks`, alias `upload`, RSA 4096, valid until 2054-03-08, SHA-256 `80:7F:48:2B:…:E1:81` |
| Keystore backup | NOT TESTED | Owner must copy `schedio-upload.jks` and `key.properties` to secure storage; not verifiable from here |
| Signed release APK | PASS | 58.7 MB, apksigner verified, same SHA-256 |
| Signed app bundle | PASS | 56.4 MB, `jarsigner` verified; built without the symbol-strip warning after installing the command-line tools |
| Android SDK command-line tools | PASS | Installed `cmdline-tools/latest` 23.0 (SHA-1 verified); `flutter doctor` Android toolchain green |
| Staging backend | BLOCKED | `staging.schedio.live` still does not resolve (no DNS `A` record). The server at `203.215.161.245` answers for that host name over HTTP, and its website renders, but HTTPS is not set up |
| Production backend | BLOCKED | `schedio.live/api/v1/*` returns 404 |
| iOS build and signing | BLOCKED | Requires macOS, Xcode and an Apple Developer account |

## Staging release smoke procedure

Run once the backend team confirms the staging URL and sends staging test credentials privately. No USB tunnel, localhost or LAN address is involved.

1. `cd schedio_mobile && dart run tool/api_contract_check.dart https://staging.schedio.live/api/v1/`. Expect 56 of 58 present (or 54 if push is deployed).
2. Automated tour on the phone over Wi-Fi or mobile data: `flutter test integration_test/staging_smoke_test.dart -d <device> --dart-define=APP_ENV=staging --dart-define=STAGING_EMAIL=... --dart-define=STAGING_PASSWORD=...` (pass the password from a local file, never commit it).
3. Signed release: `flutter build apk --release --dart-define=APP_ENV=staging`, confirm the signer SHA-256 `807f482b...e0e181` with `apksigner verify --print-certs`, install, then by hand: sign in, dashboard, each tab, create and cancel a test meeting, open a notification, public booking, sign out, force-stop and relaunch.
4. Web sync: create a meeting on the staging website and confirm it appears in the app after pull to refresh; create one in the app and confirm it on the website.
5. Record each step as PASS or FAIL in this file.

## Application ID and versioning

- Current: Android `live.schedio.schedio_mobile`, iOS `live.schedio.schedioMobile`. Neither is publicly listed on Google Play (404) or the App Store (0 results). Unlisted drafts in a Play Console account can't be seen from here.
- Proposal: use **`live.schedio.app`** on both platforms. It's short, stable, and the same everywhere. Not changed yet; needs the owner's confirmation before the first upload, because it can never change afterwards.
- Versioning: `pubspec.yaml` `version: <name>+<build>` (now `1.0.0+1`). Use semantic versions for the name and a build number that only ever increases (for example the CI run number). Pass both at build time: `flutter build appbundle --release --dart-define=APP_ENV=production --build-name=1.0.0 --build-number=<n>`.

## iOS preparation

Display name `Schedio` (Info.plist), icons and launch screen exist. Needs a Mac:

1. Current Xcode, CocoaPods, Flutter 3.47.x.
2. Apple Developer account; register the final bundle ID; distribution certificate and provisioning profile.
3. For push: enable Push Notifications and Background Modes (remote notifications), add an APNs key in Firebase, and add `GoogleService-Info.plist`.
4. `flutter build ipa --release --dart-define=APP_ENV=production`, then upload to TestFlight.

Not compiled; no iOS build is claimed.

## Safety checks (2026-10-22, late evening)

| Check | Result | Evidence |
|---|---|---|
| Local backup of all uncommitted work | PASS | `.local-backups/20261022-2335/` in `Schedio-Latest` (binary patch of 36 changed files, verified with `git apply --check -R`, plus copies of the 9 new files). Excluded through `.git/info/exclude`, never committed |
| Credential scan of every changed, new and tracked file | PASS | No published passwords, bearer tokens, private keys, service-account files or real test-account emails. Signing passwords are only read from the external `key.properties`. `lib/firebase_options.dart` contains the Firebase Android client key, which Firebase treats as public configuration; restrict it to the package and signing SHA-1 in Google Cloud |
| `google-services.json` | Present, git-ignored | Matches `firebase_options.dart` (project `schedio-app-bc57b`, package `live.schedio.schedio_mobile`) |

## Physical device test suites

| Suite | Purpose | Writes | Status |
|---|---|---|---|
| `integration_test/readonly_tour_test.dart` | Opens every screen against the configured API with the session already saved on the phone: dashboard, calendar (4 views), meetings and one detail, pipeline, meeting editor (lookups), notifications list, tasks and one detail, rooms and one detail, events and one detail, availability, booking profile and slots, registration queue, settings, profile. Reports PASS or FAIL per screen with item counts only, and whether a push device token is registered (yes or no, never the token). Never opens a notification, because that marks it read | None | **PASS** (2026-10-23, production, owner's saved session, developer role): 19 PASS, 0 FAIL, 4 NOT TESTED. PASS: dashboard, calendar tab and Week, Day, Agenda, Month views, meetings tab, pipeline (clients), meeting editor with lookups, notifications list, tasks list, rooms list, events list, availability, booking page, booking profile and slots, registration queue, settings, profile. NOT TESTED: meeting, task, room and event detail, because the account has no such records. Push device token registered with the server: yes (token not logged). Two test-only fixes were needed: a quick-action tap that matched the dashboard banner too, and a wait that counted a hidden loader |
| `integration_test/sandbox_writes_test.dart` | Meetings (create, read, update, calendar feed, cancel frees slot), meeting notes, clients and stage change, tasks and status changes, rooms, events, notification read and unread restore, registration submit and reject, staff isolation | Yes, all titled `[TEST] ... <timestamp>` and deleted afterwards | NOT RUN: refuses to start without `SANDBOX_CONFIRMED=yes`, the sandbox company ID and rotated credentials; stops before any write if the admin is not in that company |
| `integration_test/app_test.dart`, `staging_test.dart`, `workflows_test.dart`, `remaining_features_test.dart`, `device_checks_test.dart`, `session_persistence_test.dart` | Full UI workflows | Yes | Local development API only (host guard). Last phone results are listed in "Automated checks" |

Run the read-only tour (keeps the installed app and its session):

```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/readonly_tour_test.dart -d p7a6a6mfqwx8ww9l --dart-define=APP_ENV=production --dart-define=PUSH_ENABLED=true --keep-app-running
```

Run the sandbox writes only after the backend confirms the sandbox, with values typed at run time and never saved in a file in the repository:

```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/sandbox_writes_test.dart -d p7a6a6mfqwx8ww9l --dart-define=APP_ENV=production --dart-define=SANDBOX_CONFIRMED=yes --dart-define=SANDBOX_COMPANY_ID=<id> --dart-define=SANDBOX_ADMIN_EMAIL=<email> --dart-define=SANDBOX_ADMIN_PASSWORD=<password> --dart-define=SANDBOX_STAFF_EMAIL=<email> --dart-define=SANDBOX_STAFF_PASSWORD=<password>
```

Web and mobile synchronization stays a manual check with two people or two screens: create, edit and cancel a `[TEST]` meeting on the website and confirm it in the app after pull to refresh, then the reverse; repeat for a client stage and a task status.

## Blocked items and owners

| # | Item | Severity | Owner | Status |
|---|---|---|---|---|
| 1 | Rotate the test passwords again (both v1 and v2 contracts published them) and share them privately | Critical | Backend developer | BLOCKED |
| 2 | Confirm in writing that the test accounts are isolated in a sandbox company on production, and give its company ID | Critical | Backend developer | BLOCKED |
| 3 | Read-only tour: PASS on 2026-10-23 (19 of 19 reachable screens). Still open: detail screens need at least one meeting, task, room and event in the sandbox; the authenticated contract checker needs a rotated token | Backend creates sample records, or the sandbox write suite does | Partly done |
| 4 | Sandbox write tests and web and mobile synchronization | Critical | Mobile team with the backend developer | BLOCKED (needs 1 and 2) |
| 5 | Confirm canonical CRM stages (v2 lists `lead`, `discovery`, `proposal`, `won`, `lost`; v1 and the website use six different stages) | High | Backend developer | BLOCKED |
| 6 | Confirm room create fields (`amenities_text` or an `amenities` array) and the real `lookups` shape | Medium | Backend developer | BLOCKED |
| 7 | Push delivery FAILED on 2026-10-23 00:19 to 00:20 (PKT): `POST notifications/test-push` was accepted twice ("Test notification requested.") from the signed-in phone, but no message arrived in the foreground (30 s) or in the tray while backgrounded, and the phone log shows no FCM delivery for the app. Token registration, permission and Firebase start all PASS on the device. Backend to check: the queue worker is running, the FCM HTTP v1 response for that device token, and that the token stored for this user is the one the phone registered most recently. Optional isolation step: send a Firebase console test campaign to the Android app; if that arrives, the problem is server side. Terminated-app test and tap routing still to do | High | Backend developer, then mobile team | BLOCKED |
| 8 | iOS: FlutterFire config for iOS, `GoogleService-Info.plist`, APNs key, Mac build and TestFlight | Medium | Mobile team with a Mac | BLOCKED |
| 9 | Final application ID | High | Project owner | BLOCKED |
| 10 | Upload keystore backup | High | Project owner | NOT TESTED |
| 11 | Native `firebase-analytics`: keep and declare in the Play data safety form, or remove | Medium | Project owner | BLOCKED |
| 12 | Google Play internal testing upload | Medium | Project owner approval | NOT TESTED |

## Production readiness

Recommendation: **not ready for production approval yet.** Done and verified: all 58 routes exist on production, the app reads the official shapes, a read-only tour of 19 screens passed on the physical phone against production with no API errors, the push device token is registered with the server, Firebase initializes, 126 automated tests pass, and signed release APK and AAB build. Not yet verified: authenticated responses across all screens, any write workflow, web and mobile synchronization, and real FCM delivery. Approve once items 1 to 4 and 7 pass with recorded evidence, item 5 is settled, and items 9 to 11 are decided.

### Push delivery test evidence (2026-10-23)

| Check | Result | Evidence |
|---|---|---|
| Signed-in account on the phone | Observed | Role `developer`, company "Schedio HQ" |
| Firebase initialization, single start | PASS | `FirebaseApp initialization successful`, started once with `DefaultFirebaseOptions` |
| Notification permission | PASS | `POST_NOTIFICATIONS: granted=true` (user set) |
| Device token registered (`POST /devices`) | PASS | App holds a server-accepted token; value never logged |
| `POST notifications/test-push` | Accepted | Route present (401 without token); two authenticated requests accepted |
| Foreground delivery | FAIL | No `onMessage` within 30 s |
| Background delivery | FAIL | App backgrounded by system intent; no Schedio notification posted in the tray |
| Terminated delivery | NOT TESTED | Needs the server CLI trigger after the app is closed |
| Tap routing | NOT TESTED | Needs a delivered notification |
| Fix from this run | DONE | Token refresh while offline raised an unhandled error; now handled (`test/push_test.dart`) |

### Android notification channel fix (2026-10-23)

Diagnosis on the phone: Schedio had no notification channels at all (not even Firebase's fallback channel), so no push had ever been posted for the app. The Firebase error seen in the log came from `com.xiaomi.mipicks`, not Schedio.

| Change | File |
|---|---|
| Creates `schedio_high_importance_channel` with `IMPORTANCE_HIGH` before the Flutter UI starts | `android/app/src/main/kotlin/live/schedio/schedio_mobile/MainActivity.kt` |
| Firebase default channel `schedio_high_importance_channel` and default icon `ic_stat_schedio` | `android/app/src/main/AndroidManifest.xml` |
| Foreground messages shown as a system notification on the same channel (Firebase does not draw them in the foreground, so no duplicates); taps on these route like background taps, including cold starts | `lib/core/firebase_push.dart`, `lib/core/device_alerts.dart`, `lib/core/push.dart` |
| In-app toast removed for pushes (the system notification replaces it) | `lib/app/shell.dart` |
| Tests: one system notification per message, tap payload round trip | `test/push_test.dart` |

| Check | Result | Evidence |
|---|---|---|
| Channel exists on the phone | PASS | `mId='schedio_high_importance_channel' mImportance=4` after launching the new build |
| Manifest metadata in the built APK | PASS | `aapt2 dump`: default channel and icon present (debug and release) |
| Firebase starts once | PASS | `FirebaseApp initialization successful` |
| Background delivery, tap routing, foreground delivery, terminated delivery | NOT TESTED | The phone disconnected from USB during the first run; no push was sent. Rerun with `integration_test/push_delivery_test.dart` (`PUSH_MODE=background`, then `PUSH_MODE=foreground`), and for terminated: close the app, then the backend runs `php artisan firebase:test-push <sandbox test account email>` |

### Release artifacts (2026-10-23)

| File | Build | Signer SHA-256 |
|---|---|---|
| `release-builds/Schedio-1.0.0-production-push-20261023.apk` (59.6 MB) | Release, `APP_ENV=production`, `PUSH_ENABLED=true` | `807f482b...e0e181` (upload key) |
| `release-builds/Schedio-1.0.0-production-20261023.aab` (58.1 MB) | Release, `APP_ENV=production`, push off | same key |

Both: no development addresses, cleartext traffic off, `POST_NOTIFICATIONS` declared. `release-builds/` is excluded from git through `.git/info/exclude`. APK SHA-256: `54e1a6fff53fa864ce5a3cbeefae283a18d904b5710b5fff4b58769a5eadcb08`.
