# SQLite production compatibility phase — 20 October 2026

## Verified production context

The user independently verified Laravel's deployed connection and driver are `sqlite`, PHP CLI is 8.4.26, deployment user is the production deployment account, and the checkout is `<production-checkout>`. These facts supersede assumptions based on `.env.example`. No production connection, deployment, configuration change, database conversion or data access was performed in this phase.

## Completed and API integration

- PostgreSQL `schedio_staging` on loopback port 55432 remains the primary local development database. Its Laravel API uses ports 8088/8089.
- Added a separate SQLite file at `.tools/staging/sqlite-compat/schedio_staging.sqlite`, with ignored `.env.staging-sqlite-local`, independent APP_KEY/session cookie, local mail logging and separate database queue worker. Applied all existing migrations and seeded the three approved, active fixture users.
- SQLite Laravel API processes listen only on `127.0.0.1:8090` and `8091`. Flutter accesses that API through emulator host `10.0.2.2`; it never connects to either database.
- Added fail-closed SQLite metadata verification and a repeatable local service launcher. Extended the contention and notification workflow harnesses to explicitly select either local database.
- Fixed a demonstrated SQLite concurrency failure in the shared browser/mobile scheduling middleware. SQLite ignores `lockForUpdate()`: concurrent bookings previously produced HTTP 201 and HTTP 500. A no-value-change update now acquires SQLite's write reservation before transaction reads. PostgreSQL retains its existing row lock. The fix requires no schema or database configuration changes.

## Test evidence

| Check | Result |
|---|---|
| Existing migrations on fresh file-backed SQLite | Passed; foreign keys enabled, default DELETE journal mode |
| Laravel regressions after fix | 101 tests / 484 assertions passed on isolated in-memory SQLite |
| SQLite live HTTP checks | 64 passed: all three logins, roles, meeting creation/RSVP, calendar events, clients/pipeline, tasks, rooms, tenant isolation and token revocation |
| SQLite notification/calendar workflows | Passed: queued invitation, read/unread persistence, cross-company denial, note edit/refetch, invited calendar visibility, RSVP and cancellation |
| Actual web/API synchronization | Passed: authenticated web edits visible through REST, API cancellation/client pipeline visible on web |
| SQLite concurrent bookings | Passed after fix: two independent servers, one HTTP 201, one HTTP 422, exactly one persisted meeting |
| PostgreSQL concurrent bookings | Passed after shared middleware fix with the same expected result |
| Flutter regressions | 18 tests passed |
| Android 16 / API 36, SQLite API | Native workflow passed in 2 minutes 21 seconds: client create/edit, meeting edit, note create/edit, Month/Week/Day/Agenda, queued RSVP inbox read and preference persistence |
| SQLite queue health | Zero failed jobs after retrying the contention-run failures; see qualification below |

Logs: `backend-sqlite-phase.txt`, `flutter-sqlite-phase.txt`, `android-sqlite-workflows.txt`, `sqlite-http.txt`, `sqlite-workflows.txt`, `sqlite-contention.txt`, `postgres-contention.txt`, `sqlite-environment.json`.

The first Android attempt lost its ADB/VM-service connection. The retry completed successfully. As in the PostgreSQL workflow, the meeting fixture and employee RSVP were real API operations; meeting editing and notification reading were native UI actions. This does not claim native UI meeting creation or RSVP coverage.

Contention testing also exposed transient SQLite queue write failures with the local worker's single-attempt policy. The separate SQLite launcher now uses three attempts and a two-second backoff. Identified failed fixture jobs were retried successfully, with zero failed jobs remaining. This is a local worker adjustment, not a production configuration change or proof of exactly-once delivery. Queue retry/idempotency behavior under sustained load remains an integration gate.

The normal emulator APK was restored to the primary PostgreSQL API on port 8088. The credential-bearing integration-test APK is not a delivery artifact.

## Reproduce locally

From the workspace root, using the bundled PHP runtime:

```powershell
& .tools/php/php.exe scripts/configure_local_sqlite.php
& .tools/php/php.exe Schedio-main/artisan migrate --env=staging-sqlite-local --force
& .tools/php/php.exe Schedio-main/artisan db:seed --env=staging-sqlite-local --class=StagingTestSeeder --force
& scripts/start_local_sqlite.ps1
python scripts/verify_staging.py --base-url http://127.0.0.1:8090 --credentials staging-test-credentials.local.json
python scripts/verify_postgres_workflows.py --driver sqlite
python scripts/verify_postgres_contention.py --driver sqlite
```

The fixture credentials file must already exist locally; never commit or distribute it. Do not run the PHPUnit database-reset tests against either persistent staging database.

## Compatibility limits and remaining work

Laravel's `jsonb` migration declarations successfully map to SQLite storage. The query review found no PostgreSQL-only `ILIKE`, `DATE_FORMAT` or raw PostgreSQL casts in application queries. This is not a proof of every query path or migration upgrade on an existing populated database.

Local PHP is 8.5.11 and SQLite is 3.53.4. Production's SQLite library version and PRAGMA settings were not supplied. Exact PHP 8.4.26/runtime parity, a populated-schema upgrade rehearsal, longer mixed browser/mobile contention and concurrent reminder-worker delivery still require validation before production integration. SQLite serializes writers across the database, so its throughput differs from PostgreSQL even though the tested behavior matches.

Existing mobile feature and acceptance gaps remain in `FEATURE_PARITY.md`: full native acceptance across all modules, inline client creation in meeting forms, admin role/department assignment, local alert delivery, offline/resume/accessibility/tablet coverage and iOS build/signing. Remote HTTPS staging is not provisioned; background push needs platform configuration. No complete production-ready Android/iOS release is claimed.
