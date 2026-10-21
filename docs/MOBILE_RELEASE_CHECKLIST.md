# Schedio Mobile Release Checklist

Status values: PASS, FAIL, BLOCKED, NOT TESTED. A feature is PASS only with evidence: a named automated test, or a recorded device run.

Last updated: 2026-10-21. Flutter 3.47.7 / Dart 3.13.5. Branch `mobile/production-hardening` (based on `main` at `8bd453a`).

Device: Android phone model `2404ARN45A` (serial `p7a6a6mfqwx8ww9l`), USB debugging, connected to the isolated local backend (`scripts/start_local_sqlite.ps1`, SQLite, port 8090) through `adb reverse`. This is a development setup. It proves the app against the real Laravel API code, but not against a hosted HTTPS server.

## Automated checks

| Check | Result | Evidence |
|---|---|---|
| `flutter analyze` | PASS | No issues found |
| `flutter test` (unit and widget) | PASS | 44 tests in `mobile_test`, `approval_test`, `auth_provider_test`, `env_and_errors_test`, `features_test`, `model_parsing_test` |
| `integration_test/app_test.dart` on the phone | PASS | Cold launch shows sign-in; empty submit shows validation |
| `integration_test/staging_test.dart` on the phone | PASS | 3 accounts sign in; admin creates a task in the app; a second session changes it and the app shows the change after refresh; employees get 403 on admin data and 404 on another company's task; each account signs out |
| `integration_test/workflows_test.dart` on the phone | PASS (1m40s) | Client create and edit, spreadsheet view, meeting edit, meeting notes create and edit, all four calendar views, RSVP notification delivered, opening marks it read, preferences saved twice |
| `integration_test/remaining_features_test.dart` on the phone | PASS (1m08s) | Meeting created through the real date and time pickers with an inline guest saved as a client; registration approved with role, department and title (local fixture prepared and restored) |
| `integration_test/device_checks_test.dart` on the phone | BLOCKED | Dashboard step passed on the first run. Later runs could not install: the phone's "Install via USB" prompt was not confirmed (`INSTALL_FAILED_USER_RESTRICTED`). Covers booking, offline message and recovery. |

## Defects found on the device and fixed

| Defect | Severity | Fix | Regression test |
|---|---|---|---|
| Meetings tab failed to load ("List is not a subtype of Map") when a meeting's `metadata` was an empty JSON array | P1 | Tolerant `asMap` reads for every nested object in `lib/core/models.dart` | `model_parsing_test.dart` |
| Same risk at sign-in for accounts whose notification `categories` is an empty array | P1 | Same | `model_parsing_test.dart` |
| After a tab switch, the previous tab stayed laid out at zero opacity because the shell never rebuilt when the animation ended | P2 | Shell rebuilds on transition completion | `features_test.dart` tab navigation |
| The keyboard stayed open after signing in, hiding the bottom bar | P2 | Sign-in closes the keyboard on submit | `device_checks_test.dart` asserts the bar is visible |

## Features

| Feature | Implementation | API integration | Unit test | Widget test | Device test | Release blocker | Notes |
|---|---|---|---|---|---|---|---|
| Sign in, validation | Complete | VERIFIED | PASS | PASS | PASS (app_test, staging_test) | No | |
| Registration | Complete | VERIFIED | NOT TESTED | NOT TESTED | NOT TESTED | No | |
| Account status screens | Complete | VERIFIED | PASS | PASS | NOT TESTED | No | |
| Session expiry, offline resume | Complete | VERIFIED | PASS | n/a | BLOCKED (device_checks install) | No | |
| Logout | Complete | VERIFIED | PASS | n/a | PASS (staging_test, 3 accounts) | No | |
| Role and company isolation | Server enforced | VERIFIED | n/a | PASS (admin-only queue) | PASS (staging_test) | No | |
| Dashboard | Complete | VERIFIED | n/a | PASS | PASS (device_checks first run) | No | |
| Bottom navigation, Quick Actions | Complete | n/a | n/a | PASS | PASS (all integration suites) | No | |
| Calendar month, week, day, agenda | Complete | VERIFIED | n/a | PASS | PASS (workflows_test) | No | Rescheduling through the edit form |
| Meeting list, detail, edit | Complete | VERIFIED | PASS | PASS | PASS (workflows_test) | No | Found and fixed the metadata crash |
| Meeting create with pickers and guest | Complete | VERIFIED | PASS | PASS | PASS (remaining_features_test) | No | |
| RSVP and notification delivery | Complete | VERIFIED | NOT TESTED | NOT TESTED | PASS (workflows_test; RSVP sent by a second account) | No | |
| Meeting notes | Complete | VERIFIED | n/a | PASS | PASS (workflows_test) | No | |
| Clients pipeline and spreadsheet | Complete | VERIFIED | n/a | PASS | PASS (workflows_test spreadsheet; Shift Stage in widget test) | No | Drag between columns not device tested |
| Client create and edit | Complete | VERIFIED | n/a | PASS | PASS (workflows_test) | No | |
| Tasks create and status | Complete | VERIFIED | PASS | PASS | PASS (staging_test) | No | |
| Notifications open, read, preferences | Complete | VERIFIED | PASS | PASS | PASS (workflows_test) | No | |
| Push notifications | Not implemented | BLOCKED | n/a | n/a | n/a | No | Server has no device-token endpoint |
| Rooms, events | Complete | VERIFIED | n/a | PASS | NOT TESTED | No | |
| Availability | Complete | VERIFIED | n/a | NOT TESTED | NOT TESTED | No | |
| Public booking | Complete | VERIFIED | PASS | NOT TESTED | BLOCKED (device_checks install) | No | |
| Registration queue approve | Complete | VERIFIED | PASS | PASS | PASS (remaining_features_test) | No | |
| Registration queue reject | Complete | VERIFIED | n/a | PASS | NOT TESTED | No | |
| Offline message and recovery | Complete | VERIFIED | PASS | n/a | BLOCKED (device_checks install) | No | Test cuts the phone's tunnel to the server mid-run |
| App restart keeps session | Complete | n/a | PASS (token restore) | n/a | NOT TESTED | No | |
| Wi-Fi only (no USB) | Supported in debug builds | n/a | n/a | n/a | NOT TESTED | No | Needs the local server to listen on the LAN; the script binds to 127.0.0.1 |

## Release configuration

| Item | Status | Evidence |
|---|---|---|
| Environment profiles | PASS | `lib/core/env.dart`, unit tested |
| Release builds reject HTTP and private hosts | PASS | Unit tested |
| Cleartext only in debug | PASS | Main manifest `usesCleartextTraffic="false"`; permissive config only in `src/debug` |
| Release signing configured | PASS | Upload keystore and `key.properties` in `%USERPROFILE%\.schedio\` (outside OneDrive and the repo). Gradle reads `android/key.properties`, then `SCHEDIO_KEY_PROPERTIES`, then `~/.schedio/key.properties`. |
| Signed release APK | PASS | `flutter build apk --release --dart-define=APP_ENV=staging`, 58.7 MB. `apksigner verify`: signer `CN=Schedio, O=Schedio, C=PK`, SHA-256 `807f482bd929658c8d9984513a9b1dfb76871f071c643f33edbae51f44a0e181` |
| Signed app bundle | PASS with warning | `flutter build appbundle --release --dart-define=APP_ENV=staging`, 59.2 MB, `jarsigner`: jar verified, same signer. Flutter could not run its symbol-strip check because `apkanalyzer` (Android SDK command-line tools) is missing; native libraries are release-sized. |
| Android SDK command-line tools | FAIL | Not installed. Install "Android SDK Command-line Tools (latest)" from Android Studio, SDK Manager, SDK Tools, then run `flutter doctor --android-licenses`. |
| Signed release installed on phone | BLOCKED | Needs the phone's "Install via USB" confirmation, and the debug build uninstalled first (different signature) |
| Staging backend | BLOCKED | `staging.schedio.live` has no DNS record |
| Production backend | BLOCKED | `schedio.live/api/v1/*` returns an HTML 404; see `docs/BACKEND_DEPLOYMENT_REQUIREMENTS.md` |
| Application ID | Decision needed | Android `live.schedio.schedio_mobile`, iOS `live.schedio.schedioMobile`. Both work but differ; pick the final ID before the first store upload, because it cannot change afterwards. |
| iOS build and signing | BLOCKED | Requires macOS and an Apple Developer account (steps below) |

## Keystore custody

- Files: `%USERPROFILE%\.schedio\schedio-upload.jks` and `%USERPROFILE%\.schedio\key.properties` (contains the generated passwords).
- Back up both to a password manager or other secure storage. Every future Play Store update must be signed with this key. If it is lost, an upload-key reset through Play App Signing is required.
- Never commit them. `*.jks`, `*.keystore` and `android/key.properties` are git-ignored, and these copies live outside the repository.

## iOS preparation

1. A Mac with the current Xcode, CocoaPods and Flutter 3.47.x.
2. Apple Developer Program membership; register the final bundle ID and create the distribution certificate and provisioning profile.
3. `cd schedio_mobile && flutter build ipa --release --dart-define=APP_ENV=production`, then upload with Xcode Organizer or Transporter to TestFlight.
4. Test the local-notification permission prompt on a device.

## Remaining steps before a production recommendation

1. Confirm the phone's install prompt (or enable "Install via USB" in Developer options), then rerun `device_checks_test.dart` and install the signed release APK.
2. Backend team: complete `docs/BACKEND_DEPLOYMENT_REQUIREMENTS.md` on staging (DNS, HTTPS, acceptance checks).
3. Run the signed staging release on the phone against staging, including Wi-Fi only and restart checks.
4. Install the Android SDK command-line tools and rebuild the bundle.
5. Decide the final application IDs.
