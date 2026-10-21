# Schedio Mobile Release Checklist

Status values: PASS, FAIL, BLOCKED, NOT TESTED. A feature is PASS only with evidence: a named automated test, or a recorded device run.

Last updated: 2026-10-22. Flutter 3.47.7 / Dart 3.13.5. Branch `mobile/production-hardening`.

Device: Android phone model `2404ARN45A` (serial `p7a6a6mfqwx8ww9l`). Backend: the isolated local Laravel API (`scripts/start_local_sqlite.ps1`, SQLite), reached over USB (`adb reverse`) and, for the Wi-Fi and restart checks, over Wi-Fi only at `http://192.168.9.211:8090/api/v1/`. This proves the app against the real Laravel API code, not against a hosted HTTPS server.

## Automated checks

| Check | Result | Evidence |
|---|---|---|
| `flutter analyze` | PASS | No issues found |
| `flutter test` (unit and widget) | PASS | 51 tests |
| `integration_test/app_test.dart` on the phone | PASS | Cold launch, validation |
| `integration_test/staging_test.dart` on the phone | PASS | 3 accounts, task sync from a second session, role and company isolation, logout |
| `integration_test/workflows_test.dart` on the phone | PASS | Clients, meetings, notes, 4 calendar views, RSVP notification, preferences |
| `integration_test/remaining_features_test.dart` on the phone | PASS | Meeting creation with pickers and inline client; registration approval |
| `integration_test/device_checks_test.dart` on the phone | PASS | Dashboard and bottom bar, public booking confirmed, offline message with the server cut off, recovery after reconnecting |
| `integration_test/session_persistence_test.dart` on the phone, Wi-Fi only | PASS | Launch 1 signs in over Wi-Fi; after a force-stop, launch 2 opens the workspace with the saved session |
| Signed release on the phone | PASS (smoke) | Installed and launched to sign-in; not debuggable. Sign-in BLOCKED: staging has no DNS. |

## Defects found on the device and fixed (this branch)

| Defect | Severity | Regression test |
|---|---|---|
| Meetings tab failed when `metadata` was `[]` | P1 | `model_parsing_test.dart` |
| Same risk at sign-in for empty preference `categories` | P1 | `model_parsing_test.dart` |
| Pull-to-refresh while offline leaked an unhandled `ApiFailure` (every list screen) | P1 | `features_test.dart` "pull to refresh while offline", fails without the fix |
| Keyboard stayed open after sign-in and hid the bottom bar | P2 | `device_checks_test.dart` |
| Previous tab stayed laid out after a tab switch | P2 | `features_test.dart` navigation |

## Features

| Feature | Implementation | API | Automated | Device | Release ready | Remaining blocker |
|---|---|---|---|---|---|---|
| Sign in and validation | Complete | VERIFIED (local) | PASS | PASS (USB and Wi-Fi) | BLOCKED | Hosted HTTPS API |
| Registration | Complete | VERIFIED (local) | NOT TESTED | NOT TESTED | BLOCKED | Hosted API; device run |
| Pending, rejected, inactive accounts | Complete | VERIFIED (local) | PASS | NOT TESTED | BLOCKED | Hosted API |
| Session persistence across restart | Complete | n/a | PASS | PASS (Wi-Fi) | PASS | |
| Token expiry, revocation, deactivation | Complete | VERIFIED (local, curl) | PASS | NOT TESTED | BLOCKED | Hosted API |
| Logout and token revocation | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Role and company isolation | Server enforced | VERIFIED (local) | PASS | PASS | BLOCKED | Repeat on staging |
| Dashboard | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Calendar month, week, day, agenda | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Meetings list, detail, create, edit | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Meeting cancel, delete | Complete | VERIFIED | NOT TESTED | NOT TESTED | BLOCKED | Device run |
| RSVP and notification delivery (in app) | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Meeting notes | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Clients pipeline, spreadsheet, edit | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Tasks create and status | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Notifications open, read, preferences | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Public booking | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Registration approval | Complete | VERIFIED | PASS | PASS | BLOCKED | Hosted API |
| Registration rejection | Complete | VERIFIED | PASS | NOT TESTED | BLOCKED | Device run |
| Rooms, events, availability | Complete | VERIFIED | PASS (editors) | NOT TESTED | BLOCKED | Device run |
| Offline message and recovery | Complete | n/a | PASS | PASS | PASS | |
| Wi-Fi only (no USB) | Complete | n/a | n/a | PASS (local server over LAN) | BLOCKED | Repeat against hosted HTTPS |
| Push notifications | Scaffolding (disabled) | BLOCKED | PASS (6 tests) | BLOCKED | BLOCKED | Device-token API, Firebase project |
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
| Staging backend | BLOCKED | `staging.schedio.live` does not resolve |
| Production backend | BLOCKED | `schedio.live/api/v1/*` returns 404 |
| iOS build and signing | BLOCKED | Requires macOS, Xcode and an Apple Developer account |

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

## Production readiness

Not ready. Remaining blockers:

1. Backend: deploy the mobile API on staging, then production (`BACKEND_INTEGRATION_HANDOFF.md`).
2. Run the full device sheet against staging with a signed staging release, including the website-to-mobile sync checks.
3. Decide the final application IDs.
4. Back up the upload keystore.
5. If push is in scope: backend device-token endpoints, the Firebase project, then the mobile transport and a delivery test on the device.
6. iOS build on a Mac.
