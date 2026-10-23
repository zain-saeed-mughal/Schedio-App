# Schedio Backend Integration Report

Production `https://schedio.live/api/v1/` (nginx/1.24.0), API v2.1. The backend team reports deployed commit `04b0e99ff5e68250ef6cf81688191d7a48bda104`. Every claim below was checked independently on 2026-10-24 against the live server; GitHub was not used as evidence. The mobile team changed no production code, configuration or data outside [TEST] records in the sandbox company.

## API v2.1 fixes: independent verification

Sandbox account "Mobile App Tester" (user 8), company 1 "Schedio HQ", via `integration_test/crud_live_test.dart` (`CRUD_PHASE=final`) on the phone, using the app's own API client.

| Claim | Production evidence (2026-10-24) | Result |
|---|---|---|
| 60 routes | Method-aware contract check: 60 endpoints, 0 missing, 0 problems; `PUT tasks/{id}` and `DELETE tasks/{id}` answer 401 without a token (yesterday 405) | VERIFIED PASS |
| Meeting reschedule no longer 500 | `PUT meetings/{id}` with a new time: success; re-read shows the new start (v2.1 chain and full CRUD) | VERIFIED PASS |
| Meeting cancel no longer 500 | `PATCH meetings/{id}/cancel`: success; status `cancelled`; slot freed in `availability/check` | VERIFIED PASS |
| Meeting delete returns 204 | `DELETE meetings/{id}`: success with no body; `GET` then 404 (meetings 12 and today's test meetings) | VERIFIED PASS |
| Task PUT and DELETE active | `PUT tasks/{id}` updated title, priority, assignee and due date (read back exactly); empty title → 422; `DELETE` → then 404 | VERIFIED PASS |
| Empty note returns 422 | `POST meetings/{id}/notes` with `{}` → 422 | VERIFIED PASS |
| Rooms pagination metadata | `GET rooms` returns `data`, `meta` (current_page, last_page, per_page, total) and `links` | VERIFIED PASS |
| Reminders follow meeting changes | Dashboard reminders: create → 1 for the meeting; after reschedule → still 1; after cancel → 0; after delete → 0 | VERIFIED PASS (count; reminder time after reschedule not inspected) |
| Cleanup of 10 meetings and 6 tasks | Meetings 1–10 and tasks 1–6 are gone | VERIFIED PASS |
| Cleanup removed nothing unrelated | Company 1 still has its 1 non-test client; no non-test meetings, rooms, events or tasks existed before or after | VERIFIED PASS |

Note: on the first v2.1 run a reschedule returned 422 "Scheduling conflict detected for the updated time slot". Cause: the new time overlapped [TEST] meeting 11, left from the previous day and not included in the backend cleanup. The 422 was correct behaviour; the rerun with a free slot passed.

## Full CRUD regression (2026-10-24)

Run 1: **77 pass, 0 fail**. Run 2 (fresh app process): **17 pass, 0 fail**.

| Area | Endpoints | Result |
|---|---|---|
| Clients and pipeline | `GET/POST clients`, `GET/PUT/DELETE clients/{id}`, `PATCH clients/{id}/status`, `GET clients/{id}/meetings` | VERIFIED PASS; 422 on empty name and invalid stage |
| Tasks | `GET/POST tasks`, `GET/PUT/DELETE tasks/{id}`, `PATCH tasks/{id}/status` | VERIFIED PASS; 422 on missing title and invalid status |
| Meetings | `GET/POST meetings`, `GET/PUT/DELETE meetings/{id}`, `PATCH .../cancel` | VERIFIED PASS; 422 on end before start and on overlap |
| Notes | `GET/POST meetings/{id}/notes`, `GET/PUT/DELETE meeting-notes/{id}` | VERIFIED PASS; empty note 422 |
| Calendar and availability | `calendar/feed`, `availability/check`, `availability/suggestions` | VERIFIED PASS |
| Rooms | `GET/POST rooms`, `GET/PUT/DELETE rooms/{id}` | VERIFIED PASS; double booking 422; pagination meta present |
| Events | `GET/POST events`, `GET/PUT/DELETE events/{id}` | VERIFIED PASS |
| Public booking | `public/booking/{u}`, `.../slots`, `POST public/booking/{u}` | VERIFIED PASS; booked at the chosen slot; booking meeting deleted afterwards |
| Notifications | `GET notifications`, `POST notifications/preferences`, `POST devices`, `POST notifications/test-push` | VERIFIED PASS |
| Notifications | `PATCH .../read`, `.../unread`, `POST mark-all-read` | NOT TESTED: no database notification exists for the account (see N-1) |
| Admin | `GET admin/registration-requests` (all statuses), `.../options` | VERIFIED PASS (read-only) |
| Isolation and roles | Company 2 employee account | VERIFIED PASS (2026-10-24): company 1 records 404, admin queue 403, no company 1 rows in lists |

## Contract facts the app relies on

| Fact | Handling in the app |
|---|---|
| Tasks, clients and events do not include `can_manage` (meetings do) | r7 decides from role and ownership when the field is absent; the server still enforces permissions |
| Tasks return `assignee: {id, name}` and `creator: {id, name}` | Read by the model |
| The server stores the wall-clock part of submitted times and ignores the offset | The app sends wall-clock time in the account timezone with offset (verified for meetings, events, tasks, bookings) |
| `dashboard.metrics.unread_notifications` can disagree with the inbox | The badge uses `GET notifications` → `meta.unread_count` |

## Remaining backend items

| # | Issue | Evidence | Severity |
|---|---|---|---|
| N-1 | No in-app (database) notification is created for the organiser's own meeting changes or for public bookings, so the inbox stays empty for single-user tests | Inbox 0 after create, reschedule, cancel and a booking | Low (confirm intended) |
| B-7 | `dashboard.metrics.unread_notifications` disagrees with `GET notifications` (11 vs 0 on 2026-10-23) | Inbox probe | Medium (app works around it) |
| B-8 | Push text formats times in UTC ("2:09 PM" for 19:09 Pakistan time) | Push of 2026-10-23 | Medium |
| B-9 | `notifications/test-push` reply includes the first 16 characters of each device token | Test-push reply | Low |
| B-10 | Submitted time offsets are ignored; honour them or document "wall-clock in the user's timezone" | Event time test | Medium |
| B-12 | Consider sending `can_manage` on tasks, clients, events and rooms like meetings, so every client applies the same rules | Task detail keys | Low |

Leftover [TEST] records (sandbox company 1, test account only, not deleted because no further cleanup was approved): meeting 11 (scheduled, 2026-12-15 20:00 +05:00) and completed task 8, plus one completed [TEST] task from the final run. They can be deleted from the app or API now that deletion works.

## How to re-verify

1. `dart run tool/api_contract_check.dart https://schedio.live/api/v1/` → 60/60.
2. Build the QA test APK (`flutter build apk --profile -t integration_test/crud_live_test.dart --dart-define=CRUD_PHASE=final --dart-define=SANDBOX_COMPANY_ID=1 --dart-define=APP_ENV=production --dart-define=PUSH_ENABLED=true`, signed with the same key as the installed app), install it with `adb install -r` (never let a tool uninstall the app), launch it twice and read the `CRUD` lines from `adb logcat -s flutter:I`.
