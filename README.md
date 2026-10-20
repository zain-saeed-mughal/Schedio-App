# Schedio mobile integration

Native Flutter/Dart application for Android and iOS, connected to the existing Laravel database through an additive REST API.

- `Schedio-main/` — original Laravel application plus mobile API, Sanctum and shared scheduling protection.
- `schedio_mobile/` — native Flutter application, Android/iOS projects, tests and bundled branding.
- `docs/TECHNICAL_AUDIT.md` — source-based feature, schema, role and risk audit.
- `docs/API.md` — implemented API contract.
- `docs/FEATURE_PARITY.md` — implementation coverage and remaining acceptance work.
- `docs/RELEASE.md` — staging, testing, signing and release instructions.
- `docs/PHASE_SQLITE.md` — latest compatibility phase report, evidence and remaining work.
- `docs/PHASE_POSTGRES.md` — primary local staging and mobile workflow phase report.
- `scripts/verify_staging.py` — live HTTP tests of web/API synchronization, roles and tenant isolation on isolated targets.
- `schedio_mobile/integration_test/staging_test.dart` — native Android login, task creation, web-to-mobile refresh and access checks.
- `schedio_mobile/integration_test/workflows_test.dart` — native client, meeting, notes, calendar, inbox and preferences checks.
- `scripts/start_local_staging.ps1` — restart the isolated local PostgreSQL/Laravel services.
- `scripts/start_local_sqlite.ps1` — restart the separate SQLite compatibility API and queue worker.
- `scripts/verify_local_postgres.php` — inspect actual local database isolation without exposing credentials.
- `scripts/verify_postgres_contention.py` — simultaneous booking requests through two local Laravel servers.

The production website and production database were not accessed for changes. Deploy and validate the API on staging before pointing a mobile release at production.

Selected toolchain: Flutter 3.47.4 / Dart 3.13.3, PHP 8.5.11 for local testing. Preserve the supplied lockfiles.

```sh
cd schedio_mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://your-staging-host/api/v1/
```

Use the existing user's credentials after the backend API is deployed. The application has no embedded credentials or independent mobile business database.

Local staging uses PostgreSQL 17.11, database `schedio_staging` at `127.0.0.1:55432`, and guarded `StagingTestSeeder` accounts for the three requested `@demo.schedio.test` identities. Flutter communicates only with Laravel at the emulator host URL `http://10.0.2.2:8088/api/v1/`. Credentials are in ignored local configuration, never in application source. The remote Ubuntu staging topology is proposed in `docs/RELEASE.md`; production remains untouched.
