# Local verification — 20 October 2026

- Separate file-backed SQLite compatibility phase passed: 64 live HTTP checks, queued notification/calendar workflows, concurrent booking protection and the native Android workflow. See `PHASE_SQLITE.md` for the discovered locking issue, fix, queue retry qualification and runtime differences.

- Laravel regression suite: **101 tests, 484 assertions, passing**, using an isolated in-memory SQLite database.
- Flutter tests: **18 passing**, including calendar mode switching at standard and fractional screen densities.
- Flutter static analysis: **No issues found**.
- Android debug APK: **built successfully**, including the optional local notification plugin.
- Current normal emulator artifact targets x86_64 and the local API. Its dark startup and sign-in screens are recorded in `android-splash.png` and `android-emulator.png`.
- Live local PostgreSQL staging HTTP verification: **64 checks passed**, covering all three proposed identities, role restrictions, tenant isolation for meetings/tasks/clients/events/rooms, invitation RSVP, web/API changes and revoked-token rejection.
- Actual Laravel staging connection: PostgreSQL 17.11, database `schedio_staging`, host `127.0.0.1`, port 55432. Three fixture users, local mail log transport, zero failed queue jobs at verification.
- Extended PostgreSQL API checks passed for note edits/refetch, participant and company visibility, queued invitation delivery, notification read/unread state, RSVP and calendar cancellation.
- Concurrent PostgreSQL booking check passed through two independent local Laravel server processes: one creation, one conflict, one persisted meeting.
- Earlier native Android baseline: **1 end-to-end test passed on Android 16 / API 36 against the former local SQLite staging setup**, with all three UI logins and logouts, UI task creation, an authenticated web-route status edit, Android pull-to-refresh displaying that edit, and role/task-isolation checks through the real app client.
- Current PostgreSQL native workflow: **passed on Android 16/API 36**, covering UI client create/edit, meeting edit, notes create/edit, all four calendar modes, queued RSVP notification read and saved preferences after reopening Settings. The fixture meeting and employee RSVP use real API calls; this is not a claim of UI meeting creation or UI RSVP acceptance.
- Staging fixture seeder: guarded against production and unrecognized databases; repeated local seeding succeeded without creating duplicate identities.
- Normal local-development APK installed and launch screen visually checked (`android-emulator.png`). The emulator's System UI briefly stalled after a pause/resume; it recovered after reducing rendering load and releasing idle build memory. The native test had passed before that pause.
- Generated test passwords were scanned for in the normal APK and packaged source: none found. Private environment and credential files are excluded.
- Original ZIP comparison: five original files changed (User model, bootstrap routing, Composer manifest/lock and web scheduling middleware registration); no original files missing. New API files and Flutter source are additive.

See the adjacent test/build logs and `web-preservation.txt` for evidence. The source package excludes downloaded runtimes, dependencies, build caches, local environment files and signing secrets.

The original `Schedio-debug.apk` targets `https://schedio.live/api/v1/`; the new API must be deployed before that original build can authenticate. The local-development build targets `http://10.0.2.2:8088/api/v1/`, which is only usable by an emulator with the local Laravel server running. Test credentials are supplied only to the ignored integration-test build, not to the normal application build.

Current-phase evidence: `postgres-environment.json`, `postgres-http.txt`, `postgres-workflows.txt`, `postgres-contention.txt`, `backend-postgres-phase.txt`, `flutter-postgres-phase.txt`, `flutter-postgres-analysis.txt` and `android-postgres-workflows.txt`. The expanded Android workflow passed after correcting test-driver timing, avoiding build/ADB transport contention and fixing a real fractional-width calendar rendering assertion. See `PHASE_POSTGRES.md` for the complete phase report. Earlier baseline evidence remains in `android-staging-integration.txt` and `backend-regression.txt/xml`.

No production deployment or production data changes were made. The local API now uses the isolated PostgreSQL staging database; the user has verified production uses SQLite (PHP 8.4.26). Separate local SQLite compatibility results are recorded in `PHASE_SQLITE.md`. Remote HTTPS staging is proposed but not provisioned. Physical-device integration, local device-alert delivery, comprehensive native acceptance, iOS compilation and signed store releases remain unverified. Background push is not implemented. `FEATURE_PARITY.md` records remaining UI differences and acceptance work.
