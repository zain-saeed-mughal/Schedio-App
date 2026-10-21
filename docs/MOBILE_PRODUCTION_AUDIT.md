# Schedio Mobile Production Audit

Scope: the Flutter app in `schedio_mobile/` only. The Laravel web application was read to confirm the API contract but was not modified.

Audit date: 2026-10-21. Toolchain: Flutter 3.47.7, Dart 3.13.5 (matches the `sdk: ^3.13.3` constraint and the committed `pubspec.lock`).

## Repository state at audit time

- Branch `main`, HEAD `8bd453a`. Working tree clean apart from the untracked folder `Schedio-Latest/`.
- `Schedio-Latest/` is a second clone of the same GitHub repository at the older commit `46bb5f5`. Its `schedio_mobile/lib` is byte-identical to the main checkout (ignoring line endings). It was left untouched. Recommendation: delete it or move it outside the repository so it cannot be committed by accident.
- Baseline before changes: `flutter analyze` reported no issues and `flutter test` passed 20 of 20.

## Architecture summary

| Area | Implementation |
|---|---|
| State | Riverpod 3 (`AsyncNotifier`, `FutureProvider.family`) |
| Navigation | One GoRouter route hosting a custom 4-tab shell with a notched bottom bar; detail screens pushed with `MaterialPageRoute` |
| Networking | Dio with a bearer-token interceptor, `Api.request` wrapper, `Repository` for typed reads |
| Storage | `flutter_secure_storage` for the Sanctum token, `shared_preferences` for device alert preference only |
| Models | Hand-written typed models in `lib/core/models.dart` decoded at the repository boundary |
| UI | Design system in `lib/core/ui/` and `lib/theme/` (charcoal glass, amber accent), animated splash in `lib/app/splash.dart` |

## Findings

Status: FIXED means changed in this pass and covered by an automated test where noted. OPEN means still outstanding.

### P0, release blocking

| # | Finding | Status |
|---|---|---|
| P0-1 | With no `API_BASE_URL`, the app silently used `https://schedio.live/api/v1/`, which has no mobile API. Logins failed with the raw Laravel message "The route api/v1/auth/login could not be found." | FIXED in the app: explicit `APP_ENV` profiles (`development`, `staging`, `production`) in `lib/core/env.dart`, and a clear message for missing API routes. OPEN on the server: the mobile API must be deployed to the production host before a production build can work (see MOBILE_API_REQUIREMENTS.md). |
| P0-2 | Release builds could be pointed at HTTP, localhost, emulator or LAN addresses. The old guard only checked a fixed host list and `kDebugMode`. | FIXED. `Env.validate` rejects HTTP and private or local hosts for every release build and for staging and production profiles. Tested in `test/env_and_errors_test.dart`. |
| P0-3 | No release signing configuration exists (`android/key.properties` is absent). `flutter build apk --release` produces an unsigned APK that Android will not install. | FIXED. Upload keystore created outside the repo and OneDrive (`%USERPROFILE%.schedio`); Gradle reads it from there. Signed APK and AAB verified. See the keystore custody notes in MOBILE_RELEASE_CHECKLIST.md. |
| P0-4 | No reachable HTTPS backend with the mobile API. `staging.schedio.live` has no DNS record and `schedio.live` returns an HTML 404 for `/api/v1/*`. | OPEN, backend and DNS dependency. Blocks real-device end-to-end testing outside the local development server. |

### P1, important functional defects

| # | Finding | Status |
|---|---|---|
| P1-1 | Raw server error text was shown to users for any status code, so a debug-mode backend could expose SQL or exception details. | FIXED. `Api.safeMessage` filters internal-looking text; 5xx always shows a generic message. Tested. |
| P1-2 | Timeouts, offline, 404, 429 and 5xx all produced the same vague message. | FIXED. `Api.messageFor` maps each case to a specific, actionable message. Tested. |
| P1-3 | If an account or company was deactivated while signed in, every screen returned 403 and only showed "Try again", with no explanation and no way to sign out. | FIXED. A 403 carrying `account_status` clears the token, signs out and shows the server's reason on the account-status screen. Tested. |
| P1-4 | A stored token for an inactive account showed a generic error card at startup instead of the account status. | FIXED, same mechanism. Tested via the notice provider. |
| P1-5 | Resuming the app while offline replaced the signed-in workspace with an error page, because the session re-check failure was treated as fatal. | FIXED. Network failures during the re-check keep the current account; only 401 and 403 sign out. Tested. |
| P1-6 | The dashboard awaited the local-notification sync before rendering. If the plugin stalled, the dashboard stayed on loading placeholders indefinitely. | FIXED. The sync runs in the background with a 15 second timeout. Covered by the dashboard widget test. |
| P1-7 | The Reject and Shift Stage sheets disposed their text controllers while the sheet was still animating closed, causing "TextEditingController used after being disposed" errors. | FIXED. New `showFormSheet` ties controller lifetime to the sheet widget. Covered by the reject and pipeline widget tests. |
| P1-8 | Dashboard and notification polling (every 30 seconds) continued while the app was in the background. | FIXED. Polling pauses when the app is paused or hidden and resumes on return. |
| P1-9 | Found on the phone: the Meetings tab failed to load when a meeting had `"metadata": []` (Laravel serializes empty objects as arrays). Account preferences had the same risk at sign-in. | FIXED. Tolerant nested-object reads in `models.dart`. Tested in `model_parsing_test.dart` and on the device (workflows_test). |
| P1-10 | Found on the phone: the keyboard stayed open after signing in, which hid the bottom navigation bar. | FIXED. Sign-in closes the keyboard on submit. |
| P1-11 | The previous tab stayed laid out after every tab switch, because the shell never rebuilt when the transition ended. | FIXED. |
| P1-12 | Found on the phone: pull-to-refresh while offline let a network error escape uncaught on every list screen. | FIXED. `AppRefresh` handles the failure; the screen already shows the error panel. Regression test fails without the fix. |
| P1-13 | Local test API returned HTML fatal errors ("Cannot instantiate interface RecursiveIterator") while Artisan worked. | FIXED in local tooling only: corrupted Windows OPcache shared memory across several `php -S` processes. The start script now disables OPcache for dev servers and checks for JSON. See LOCAL_BACKEND_TROUBLESHOOTING.md. |

### P2, minor issues and improvements

| # | Finding | Status |
|---|---|---|
| P2-1 | Golden-test failure images (`test/failures/*.png`) were committed. | FIXED. Removed and `**/test/failures/` added to `.gitignore`. |
| P2-2 | iOS `CFBundleName` was `schedio_mobile`. | FIXED, now `Schedio`. |
| P2-3 | Android application ID `live.schedio.schedio_mobile` and iOS bundle ID `live.schedio.schedioMobile` differ and include the project folder name. | OPEN, product decision. Changing an ID after store release is not possible, so decide before the first upload. |
| P2-4 | Debug builds only allowed cleartext to emulator and localhost addresses, so Wi-Fi testing against a PC on the LAN was impossible. | FIXED for debug builds only (`android/app/src/debug`). Release manifests keep `usesCleartextTraffic="false"`. |
| P2-5 | Calendar rescheduling is done through the edit form. There is no drag-to-reschedule in the day view. | OPEN, enhancement. The server contract supports it (`PUT meetings/{id}`). |
| P2-6 | JetBrains Mono is referenced but not bundled, so monospace text uses the platform font. | OPEN, cosmetic. |
| P2-7 | Push notifications (FCM) are not implemented. Device alerts are local notifications raised when the app refreshes. | OPEN, backend dependency: there is no device-token registration endpoint. |
| P2-8 | The environment and server host were not visible in the app, which makes tester reports ambiguous. | FIXED. The Profile screen shows the environment and server host. |

## Security review

| Check | Result |
|---|---|
| Token storage | Sanctum token kept in `flutter_secure_storage` (Keychain or EncryptedSharedPreferences). Never logged. |
| Token scope | Bearer header is not sent to `public/*` or `auth/login`. Covered by an existing test. |
| Logout | Server token revoked first; if revocation fails because of the network, the token is kept so revocation can be retried. Covered by an existing test. |
| Cleartext | Release `AndroidManifest.xml` sets `usesCleartextTraffic="false"`; the permissive network config exists only in the debug source set. |
| Backups | `android:allowBackup="false"`. |
| Hardcoded credentials | None in `lib/`, assets or Android or iOS config. Test logins are only read from `--dart-define` in integration tests. |
| Request logging | No Dio logging interceptor; request bodies are never printed. |
| Deep links | None are registered, so there is no deep-link attack surface. |
| Permissions | Android: `INTERNET`, `POST_NOTIFICATIONS`. iOS: no usage descriptions needed by current features. |

## Feature coverage

See `MOBILE_RELEASE_CHECKLIST.md` for per-feature status with evidence.
