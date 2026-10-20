# Build and deployment

## Verified local toolchain

- Flutter 3.47.4 stable / Dart 3.13.3.
- Portable PHP 8.5.11 used for tests. The original composer.lock includes packages requiring at least PHP 8.4.1, despite the root package's PHP ^8.2 constraint.
- Laravel 12.69.2, Sanctum 4.3.3. Existing Composer packages were preserved; only Sanctum was added.
- Exact Flutter transitive versions are recorded in `schedio_mobile/pubspec.lock`.

## Production compatibility

The user verified the deployed Laravel connection and driver are SQLite, running PHP 8.4.26 under the production deployment account. The PostgreSQL setting in `.env.example` is not the deployed configuration. Do not convert the production database or change its configuration. Flutter communicates exclusively with Laravel REST APIs. Local PostgreSQL remains the primary staging database; the separate SQLite compatibility environment is documented in `PHASE_SQLITE.md`. Production SQLite library version and PRAGMA settings have not been supplied; local results do not establish exact runtime parity.

## Backend staging

### Proposed Ubuntu staging topology (not deployed)

Production is `https://schedio.live`, on the user's Ubuntu 24.04 server at `<production-server>`, the private SSH port, with the current checkout at `<production-checkout>`. No SSH connection or server change is part of this local development work.

Propose the following isolated staging resources, to be provisioned in a later authorized deployment:

| Resource | Proposed staging configuration |
|---|---|
| DNS/TLS | `staging.schedio.live` A record to the server; separate certificate for that hostname |
| OS identity | Dedicated `schedio-staging` service user, without read/write access to production secrets/uploads |
| Code | `/srv/schedio-staging/releases/<release-id>` and its own `/srv/schedio-staging/current` symlink |
| Writable files | `/srv/schedio-staging/shared/storage`, logs, sessions and cache; never link production storage |
| Environment | `/srv/schedio-staging/shared/.env`, readable only by the staging service identity; newly generated APP_KEY |
| Database | PostgreSQL `schedio_staging`, owned by a new staging-only role with no production database privileges |
| PHP-FPM | Separate pool/socket under the staging identity; PHP compatible with the supplied lockfile (8.4.1+) |
| Web server | Separate Nginx server block for the exact staging hostname, rooted at staging `current/public` |
| Background work | Separate staging queue service and staging scheduler entry, both using the staging identity and checkout |
| Email | Local mail sink or log transport; no production mail credentials or real customer delivery |

Start the staging database empty and apply the existing migrations plus the additive Sanctum migration. Seed only `StagingTestSeeder`; do not import production records or execute the default demo seeder. The staging web and Flutter app must both use this one staging backend/database.

Create the staging TLS certificate using a staging-only ACME webroot and explicit hostname. Avoid certificate automation that rewrites existing production virtual hosts. Validate the new server configuration before any approved reload. Do not change production Nginx blocks, FPM pools, `.env`, database grants, symlinks, uploaded files or application code.

Restrict staging access at the network/VPN layer when practical; the emulator must have access. Allow API Authorization headers through the reverse proxy. Set secure staging session cookies with no shared `.schedio.live` cookie domain. Keep the staging queue/cache/session namespaces isolated even if using shared infrastructure.

This is a proposal, not evidence that remote HTTPS staging exists. PostgreSQL concurrency and remote TLS/reverse-proxy tests remain acceptance gates after provisioning.

Use a staging checkout and an isolated copy of the existing schema. Do not create a second production database for mobile. Set staging secrets outside version control.

1. Install PHP compatible with composer.lock and PostgreSQL PDO (the supplied environment example uses PostgreSQL).
2. `composer install --no-interaction`
3. Build original web assets: `npm ci`, then `npm run build`.
4. Review the additive token-table migration. Run `php artisan migrate` on staging. Never run migrate:fresh or database seeders against production.
5. Keep the existing HTTPS host, queue worker and scheduler operational.
6. `php artisan route:list --path=api/v1`
7. Run `php artisan test` using the test-only SQLite configuration. Tests need a test APP_KEY; set it in the test shell or an untracked `.env.testing`.
8. Exercise the staging acceptance scenarios below. Deploy only after resolving outstanding parity/security gates.

The added token table is the only new database table. No existing core records are migrated, replaced or deleted by the new migration. Deploy the new backend before directing a mobile release to it. Web route groups gain a shared scheduling guard to close the cross-channel booking race; existing controllers, CSS, JavaScript, views and production environment values were not rewritten.

The API currently calls several existing controller workflows to preserve validation, auditing and notification behavior. A future shared application-service extraction can remove the browser response construction without changing contracts.

## Mobile development

```sh
cd schedio_mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://your-staging-host/api/v1/
```

Include the trailing slash. The URL is configuration, not a secret. No database credentials or API bearer tokens belong in Dart defines.

Release builds require HTTPS. The Android manifest also disables cleartext traffic; use a staging HTTPS endpoint for device development. There is no offline write queue.

## Android

Debug validation:

```sh
flutter build apk --debug --dart-define=API_BASE_URL=https://your-staging-host/api/v1/
```

For Play delivery, create your own upload keystore and copy `android/key.properties.example` to `android/key.properties`, replacing all values locally. Keystores and signing properties are ignored. Release configuration uses this upload key when present; it does not fall back to debug signing.

```sh
flutter build apk --release --dart-define=API_BASE_URL=https://schedio.live/api/v1/
flutter build appbundle --release --dart-define=API_BASE_URL=https://schedio.live/api/v1/
```

Validate application ID `live.schedio.schedio_mobile` before registering it in the store. Confirm the API deployment first. Generated icons use the supplied Schedio logo.

## iOS

Build on macOS with Xcode and the same Flutter version. Open the generated Runner project/workspace according to Flutter's current Xcode integration, select the intended Apple team and a unique bundle identifier, then resolve signing. Keep App Transport Security enabled. Verify secure-storage Keychain access and share-sheet behavior on a real iPhone and iPad.

```sh
flutter pub get
flutter build ios --no-codesign --dart-define=API_BASE_URL=https://your-staging-host/api/v1/
flutter build ipa --release --dart-define=API_BASE_URL=https://schedio.live/api/v1/
```

This Windows workspace cannot verify Xcode compilation or produce a signed IPA. TestFlight readiness is not claimed.

## Device and staging acceptance

### Staging deployment record

Before deployment, record the staging HTTPS URL, SSH/hosting access method, checkout path, current release identifier, PHP version, database engine and backup reference. Production details are known, but separate remote staging has not been provisioned. The staging web application and staging API must use the same staging database; keep that database isolated from production.

Use dedicated test users A and B in one staging company and user C in another. Configure outbound email to a test sink and disable external integrations that could contact real customers. Preserve the staging `APP_KEY` when upgrading an existing staging deployment. Set `APP_ENV=staging`, `APP_DEBUG=false` and the correct HTTPS `APP_URL`.

Inspect `php artisan migrate:status` and `php artisan migrate --pretend` before applying migrations. Stop if unexpected historical migrations are pending. Back up the staging database before applying the reviewed migration. Deploy the matching Composer lockfile, web assets and code together. Refresh configuration/routes using the host's existing deployment process, restart its queue workers, and verify `php artisan schedule:list` includes `schedio:process-reminders`. Do not use database reset/seed commands.

After deployment, check `/login` and `/up`, and confirm an unauthenticated `GET /api/v1/auth/me` returns JSON HTTP 401 rather than HTML or a redirect. Then authenticate a dedicated test user, verify the account/company returned by `/api/v1/auth/me`, and build the Android app against that exact staging HTTPS URL.

For rollback, restore the prior application release and its dependencies using the hosting platform's process. Retain the additive token table; do not blindly roll back database batches or restore an entire database over new user activity.

### End-to-end evidence to collect

Give created records a unique `STAGING-E2E-<timestamp>` prefix. Record the app build hash, test user, database record ID, exact action, expected value, observed value and screenshot for each step. Run these through the actual Android UI and browser; API-only checks do not establish device end-to-end success.

| Scenario | Required observation |
|---|---|
| Android creates meeting with B invited | Browser shows the same record ID, title, participants and UTC instant |
| Browser changes meeting title/time | Android refresh and resume display the updated title and account-local time |
| Android cancels meeting | Browser shows cancelled status; availability no longer treats it as busy |
| Browser creates client; Android changes stage | Both interfaces show the same client and latest stage |
| Browser creates task; Android completes it | Browser shows completed; a subsequent browser status change appears after Android refresh |
| Meeting notes edited on each surface | Same note ID and latest saved text appear on the other surface |
| B responds to invitation | Organizer sees the response on web and Android; inbox updates agree |
| C requests another company's record | API denies access and neither interface lists the record |
| Simultaneous overlapping web/mobile meeting requests | One succeeds and one reports conflict on the actual staging database engine |
| Android loses connectivity, then resumes | Failed writes are reported without duplicates; refresh retrieves latest server state |
| Logout and disabled account | Token cannot be reused after logout; disabling the account blocks existing API access |

Synchronization is refresh/resume based, not live background streaming. Keep evidence for test records, then remove only records created by this test run through supported application actions. Do not perform blanket cleanup queries.

### Isolated local staging and emulator testing

Local development now uses PostgreSQL 17.11: database `schedio_staging`, bound to `127.0.0.1:55432`, with cluster files under `.tools/staging/pgdata`. Laravel uses `Schedio-main/.env.staging-local`; root `staging-test-credentials.local.json` contains the test identities. All private configuration is ignored. The environment file contains a separate random APP_KEY and local-only connection settings; the original `.env` is untouched. Credentials are random, not published defaults. The previous SQLite staging file is retained but no longer used by the local API.

The application role `schedio_staging_app` is not a cluster superuser and cannot create databases or roles. Cluster credentials are kept separately under `.tools/staging/`, never in Flutter's Dart defines. PostgreSQL was initialized with SCRAM authentication. Email uses the `log` transport; the local queue worker processes real database inbox notifications without sending external messages.

Restart the configured local services with `powershell -File scripts/start_local_staging.ps1` from the workspace root. `scripts/verify_local_postgres.php` checks the actual resolved Laravel connection, database, environment and mail transport without printing secrets. The second local API port, 8089, exists only for the contention test; Flutter uses port 8088. These scripts do not contact the production server.

`StagingTestSeeder` requires all of: a staging environment, `APP_ENV=staging` in configuration, `STAGING_TESTS_ENABLED=true`, a database named `schedio_staging` (PostgreSQL) or `schedio_staging.sqlite` (SQLite), a valid local credentials file, and no non-fixture companies/users. It is not wired into the default seeder. Explicit identities:

- `admin.a@demo.schedio.test`: approved, active super_admin, Schedio Test Company A.
- `employee.a@demo.schedio.test`: approved, active employee, Schedio Test Company A.
- `employee.b@demo.schedio.test`: approved, active employee, Schedio Test Company B.

Credential JSON keys are `ADMIN_A_EMAIL`, `ADMIN_A_PASSWORD`, `EMPLOYEE_A_EMAIL`, `EMPLOYEE_A_PASSWORD`, `EMPLOYEE_B_EMAIL`, `EMPLOYEE_B_PASSWORD`, and `API_BASE_URL`. Use cryptographically random passwords of at least 24 characters. `STAGING_TEST_CREDENTIALS_FILE` points to that file. Never copy this file to a source archive or share an integration-test APK: Dart test defines embed these test-only credentials in that APK.

From the Laravel directory, using the local PHP runtime:

```sh
php artisan migrate --env=staging-local --force
php artisan db:seed --env=staging-local --class=StagingTestSeeder --force
php artisan serve --env=staging-local --host=127.0.0.1 --port=8088 --no-reload
```

Run real HTTP checks from the workspace root:

```sh
python scripts/verify_staging.py --base-url http://127.0.0.1:8088 --credentials staging-test-credentials.local.json
```

This script tests real browser session/CSRF form routes and API tokens. It creates uniquely tagged records, removes its own removable fixtures, cancels tasks (there is no task deletion endpoint), and revokes its issued tokens. It refuses production hostnames.

From `schedio_mobile`, with the emulator running:

```sh
flutter test integration_test/staging_test.dart -d emulator-5554 --dart-define-from-file=../staging-test-credentials.local.json
flutter test integration_test/workflows_test.dart -d emulator-5554 --dart-define-from-file=../staging-test-credentials.local.json
```

On this Windows host, running a prebuilt integration APK avoids intermittent ADB/Dart-service disconnects during the build/test handoff. The expanded workflow can instead be run with:

```sh
flutter build apk --debug --target=integration_test/workflows_test.dart --dart-define-from-file=../staging-test-credentials.local.json
# Stop the idle Gradle daemon before running the emulator test:
android/gradlew.bat --stop
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/workflows_test.dart --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk -d emulator-5554 --no-dds --no-pub
```

Keep this credential-bearing integration APK inside the ignored build directory. Build `lib/main.dart` again before packaging a distributable development APK. `scripts/package_local_delivery.py` scans source and uncompressed APK entries for the actual local test/database secrets and refuses to package them.

The configured AVD is `Schedio_API_36`, using Android 16/API 36 Google APIs x86_64. It is registered with the local Android SDK and stores its writable data under `.tools/avd/`. It was tested with WHPX hardware acceleration and software rendering. To start it again, run `emulator -avd Schedio_API_36 -gpu software`; add `-no-window` for a background test session. Start the local Laravel server separately before using the app.

The native integration test passed at the original 1080×2400 resolution. For smoother continued development on this host, the running emulator now uses a 720×1600 display override, density 280 and disabled system animations. The normal app launch screen was visually verified at that size. Avoid pausing a busy guest during long builds; stop idle build daemons when memory is constrained.

Build a normal emulator-development APK without embedding test credentials:

```sh
flutter build apk --debug --target-platform=android-x64 --target=lib/main.dart --dart-define=API_BASE_URL=http://10.0.2.2:8088/api/v1/
```

The emulator reaches this machine at `http://10.0.2.2:8088/api/v1/`. Debug-only Android network policy allows HTTP solely for loopback/emulator host aliases; release builds retain HTTPS-only policy. The native test signs in all three accounts through the UI, creates a task through the UI, updates it through an authenticated web session/form route, verifies the new status after native pull-to-refresh, checks roles/access with the same app API client, and signs out through the UI. It is not a substitute for full meeting/calendar/device accessibility acceptance.

`flutter test integration_test/app_test.dart -d <device-id>` exercises clean-device startup and form validation. Use a clean install without a persisted session.

Required manual staging checks:

- Existing web user logs into mobile with the same credentials.
- Meeting created/edited/cancelled on mobile appears on web; web updates appear after mobile refresh/resume.
- Client creation/status, assigned tasks and meeting notes update the same records.
- Invitations, RSVP, reminders and notification preferences behave through the existing queue/scheduler.
- Multiple company users cannot access each other's records by ID.
- Rejected/inactive users and suspended companies lose API access immediately.
- Concurrent mobile/mobile and mobile/web submissions cannot double-book on the production database engine.
- Large text, keyboard, landscape, tablet, poor network, DST transitions and background/resume behavior are exercised.

## External dependencies and outstanding gates

Firebase configuration was not supplied; background push delivery is not implemented or claimed. In-app notifications use the existing database inbox and server reminder engine. Optional local device alerts present new inbox activity on dashboard refresh after explicit OS permission; they do not schedule reminders or run a background polling service.

Remote staging provisioning, app-store signing identities, release approval and physical-device access remain external dependencies. See `FEATURE_PARITY.md` for implementation gaps that also require work before calling the complete product production-ready.

The original web `npm ci` reported 3 dependency advisories (1 high, 2 critical). Existing packages were not silently upgraded during mobile integration; review them separately before release.

References: [Laravel Sanctum](https://laravel.com/docs/12.x/sanctum), [Google Fonts source/license](https://github.com/google/fonts/tree/main/ofl/plusjakartasans), [Android platform releases](https://developer.android.com/tools/releases/platforms), [Android network security configuration](https://developer.android.com/privacy-and-security/security-config).
