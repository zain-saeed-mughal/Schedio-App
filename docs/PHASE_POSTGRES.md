# Local PostgreSQL and workflow phase — 20 October 2026

## Completed

- Initialized an isolated PostgreSQL 17.11 cluster on `127.0.0.1:55432` and created `schedio_staging`, with a separate restricted application role and generated, ignored local credentials.
- Applied all existing Laravel migrations and seeded the three approved, active test identities in the two requested test companies.
- Connected the local Laravel API and queue worker to PostgreSQL. Flutter uses only the Laravel REST API at `http://10.0.2.2:8088/api/v1/`; it has no database connection or database credentials.
- Fixed stale notification preference state after saving: the app refetches the authoritative account before displaying success.
- Added a tenant- and meeting-visibility-checked note detail endpoint and switched Flutter note details to refetch after edits.
- Fixed the calendar Week-view rendering assertion at fractional Android screen densities by giving its paged calendar a whole logical-pixel width.
- Added repeatable local service startup, connection verification, concurrent booking verification and native workflow tests.
- Preserved the existing Flutter branding and dark theme.
- Matched Android's cold-start window and system splash background to the same dark surface.

## API integration and tests

| Check | Result |
|---|---|
| Actual Laravel connection | PostgreSQL, `schedio_staging`, loopback port 55432; three users; mail logged locally; zero failed queue jobs at verification |
| Laravel automated regressions | 101 tests / 484 assertions passed, using PHPUnit's isolated in-memory SQLite database |
| Flutter regression tests | 18 passed, including standard and fractional-density calendar mode switching |
| Flutter analysis | No issues found |
| Real PostgreSQL HTTP workflows | 64 checks passed: three account logins, roles, tenant restrictions, meetings, RSVP, clients, tasks, events, rooms and logout |
| Extended PostgreSQL API workflows | Note edit/refetch, invited-user visibility, cross-company denial, calendar inclusion, queued invitation delivery, read/unread, RSVP and cancellation passed |
| Web/mobile synchronization | Actual browser session and CSRF routes confirmed web meeting/task edits through the API, and API cancellation/client-stage changes through rendered web pages |
| PostgreSQL booking contention | Two separate local Laravel servers submitted the same room/time concurrently: one HTTP 201, one HTTP 422, one persisted meeting |
| Android expanded workflow | Passed on Android 16/API 36 against PostgreSQL: UI client create/edit, meeting edit, note create/edit, Month/Week/Day/Agenda, queued RSVP inbox read and preferences persisted after reopening Settings |
| Development artifact | Normal x86_64 emulator APK built with the local API URL; source/APK packaging rejects actual test and database passwords; private configuration excluded |

Deliverables are `deliverables/Schedio-emulator-debug.apk`, `deliverables/Schedio-staging-development-source.zip` and `deliverables/Schedio-local-SHA256SUMS.txt`. The APK is a local emulator development build, not a signed production release.

Early expanded Android runs hit test-driver scrolling/save-timing errors and development-service failures. The helper now dismisses the keyboard, scrolls the actual list and waits for server-accepted saves. Running a prebuilt APK with Gradle stopped stabilized the connection. This exposed a real fractional-width Week-view rendering assertion, fixed with a targeted regression test. The final native workflow passed in 1 minute 55 seconds. Failed attempts are not counted as passing workflows.

The native meeting was created as a real API fixture, then edited in the UI. Its RSVP was submitted by the employee API client and verified in the organizer's native inbox. This run does not claim UI-driven meeting creation, RSVP, rescheduling, cancellation or every inbox operation; the broader API operations have separate PostgreSQL evidence.

## Remaining features and verification

Existing implemented modules include authentication/registration, dashboard, meetings, calendar, availability, clients, rooms, events, tasks, notes, notifications, public booking, registration decisions, profile and settings. API tests and native acceptance are distinct: broad API coverage does not establish that every screen has passed device testing.

Remaining work includes comprehensive native acceptance for all those modules, inline external-client creation in the meeting form, admin role/department reassignment UI, local-alert permission/delivery checks, offline/resume/accessibility/tablet checks and full iOS validation. `FEATURE_PARITY.md` tracks the detailed boundaries, including the agenda-based mobile calendar and list-based CRM.

## Blockers and isolation

Subsequent user verification confirmed production uses SQLite on PHP 8.4.26, with deployment user the production deployment account. PostgreSQL remains the primary isolated local development database. See `PHASE_SQLITE.md` for separate compatibility validation. No production server, deployment, credentials, database or uploaded files were changed in this phase.

Remote HTTPS staging is not provisioned. Background push needs a configured push service and platform credentials; current local alerts do not claim background delivery. iOS compilation/signing requires a macOS/Xcode environment. Store signing and physical-device acceptance remain outstanding. These are not reasons to stop local feature development, but they prevent claiming a complete production-ready Android/iOS release.
