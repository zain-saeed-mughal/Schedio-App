# Mobile feature completion phase — 20 October 2026

## Completed

- Flutter meeting forms now capture external guest name, email and company, preserving that metadata on edit.
- New meetings can save the external guest as a scheduled CRM client. Laravel uses existing Client/Meeting models, authenticated tenant/owner fields and the existing scheduling transaction. Conflicting bookings create neither a second meeting nor an orphan client. Choosing an existing client and creating a new one are mutually exclusive.
- Registration approval now has a native review screen with role, department and job title. Options come from a guarded API scoped to the applicant company. Company admins cannot promote a user to super-admin; platform-developer authority remains controlled by Laravel.
- Fixed applicant display names being replaced by their job titles when decoding registration records.
- Added local-only fixture preparation/restoration and native acceptance coverage for meeting creation and approval assignment.
- Added repeatable public-source preparation with secret checks and private-file exclusions. Raw logs, environment metadata, databases, credentials and build artifacts stay local.

## API and test evidence

- Laravel: 104 tests / 505 assertions passed on isolated SQLite, including atomic client creation, rejected invalid combinations, tenant isolation and guarded approval assignments.
- Real PostgreSQL and SQLite APIs: inline client/meeting persistence, scheduled client stage, cross-company denial and no duplicate client after a booking conflict passed.
- Approval widget tests verify that selected role, department and title are submitted to the existing approval API.
- Flutter: 20 tests passed; static analysis reported no issues.
- Android 16 / API 36 emulator: native acceptance passed in 1 minute 17 seconds. The test entered meeting dates and guest details in the UI, saved the new client with the meeting, and verified the persisted client stage/metadata through REST. It then approved the local employee through the review screen and verified the saved role, title and department through REST.
- The local test employee's original state was restored after acceptance. PostgreSQL staging still has three fixture users and zero failed queue jobs.

Automated logs are retained locally and deliberately excluded from the public repository. An initial native test selector matched underlying form fields as well as the date dialog; the selector was scoped to the dialog. A subsequent ADB disconnect required a retry. The final native run passed; failed attempts are not counted as passing coverage.

## Remaining scope and blockers

This phase closes the two explicit form gaps in `FEATURE_PARITY.md`. Comprehensive native acceptance for availability, public booking, room/event workflows, device notification permission/delivery, offline/resume, accessibility and tablet layouts remains. Background push requires platform configuration; iOS compilation/signing requires macOS/Xcode. Remote HTTPS staging and signed store releases remain outstanding.

Production remains untouched. Flutter continues to communicate only with Laravel REST APIs. PostgreSQL is primary local staging, and separate SQLite tests protect production-database compatibility.
