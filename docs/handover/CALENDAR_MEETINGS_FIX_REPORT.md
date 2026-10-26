# Calendar Hub and My Meetings Fix Report

2026-10-27. Production (`https://schedio.live`), Schedio HQ (company 1). Phone: Xiaomi 2404ARN45A, signed in as Hammad Developer (user 3, account timezone UTC, phone clock Asia/Karachi). All production access was read-only (GET only). No records were created, changed or deleted. The fixes are in the working tree only: not committed and not in a release build. r9 is reinstalled on the phone (fingerprint `20d9f9ba…f22e39` verified).

## 1. My Meetings "could not read" error: root cause

| Item | Finding |
|---|---|
| Screen | My Meetings → tap any meeting (meeting detail) |
| Request | `GET /api/v1/meetings/{id}` |
| Response | **HTTP 200**, `application/json`, for meeting 11 and meeting 28 |
| Failing field | `notes`: now a **list of note objects** (keys `id, meeting_id, user_id, agenda, discussion, decisions, action_items, follow_up_date, attachments, can_manage, author, created_at, updated_at`). Meeting 11 has 1 note, meeting 28 has 0 |
| App code | `Record.fromJson` read `notes = j['notes'] as String?`, which throws a TypeError on a list. `friendlyError` shows TypeError and FormatException as "The server sent a response this app could not read." |
| Scope | **Every** meeting detail (11 and 28, so all meetings), not one bad record. The list (`GET meetings`, all status filters) parsed correctly |
| How it was found | Read-only probe on the phone (`integration_test/meetings_probe_test.dart`). It nulls one field at a time and re-parses; only `notes` made both meetings parse. Only ids, field names and types were logged |
| Not the cause | Not malformed JSON, not auth, not a missing record, not a 500 |
| Meeting 11 | **No longer returns 500** (K-26 closed). It now fails only because of the `notes` list. It was not modified |

**Fix (`lib/core/models.dart`):**
- `notes` is read as text only when it is text (clients still send text).
- A meeting's `notes` list is parsed into a new `meetingNotes` field, and the detail shows "Meeting notes (N)".
- All optional text fields use a new type-tolerant `asText()`, so one unexpected type (an object or number where text was expected) can no longer break a whole screen.
- Participants that aren't objects are skipped.

Required fields and real errors are still reported: a list that isn't a list still shows the read error, and a 500 still shows the server error.

**Error handling (verified):**

| Case | Result |
|---|---|
| Retry | Refetches and shows the loading state |
| HTTP 500 | Shown as "The Schedio server had a problem…" |
| Network failure | "Could not reach the Schedio server…", after 3 automatic retries |
| Parse error | Its own message |
| Real empty list | The empty state, not an error |
| After a successful retry | No stale error remains |

## 2. Calendar Hub defects fixed

| # | Defect | Fix |
|---|---|---|
| C-1 | The month grid's "today" highlight used the phone clock, not the account timezone (wrong day between midnight and 05:00 PKT for a UTC account, as at test time) | `currentDay` is set to today in the account timezone |
| C-2 | After a week swipe, the title and "This week" list stayed on the old week | Selection follows the swiped page; month swipes select today (if shown) or the 1st |
| C-3 | **On the phone, a week swipe jumped to "Mar 4 to 10" in another year** after Next, Today or view switches. Cause: table_calendar 3.3.0 loses its page index after programmatic page changes | The grid is keyed per shown week or month, and repeat page reports are ignored |
| C-4 | The calendar ended on 1 Jan 2100, so Feb 2100 could not be shown; navigating near the end could fail | Range is 1900 to 2199, and navigation is clamped |
| C-5 | Day grid placed events by elapsed time, so on DST days a 10:00 meeting was drawn at 9:00 or 11:00 | Placement uses wall-clock minutes in the account timezone |
| C-6 | The month view blanked the whole grid while a month's events loaded; a retry after an error did not show loading | The grid stays visible; loading, error and retry show below it |
| C-7 | Agenda matched by month number only; multi-day events spanning a whole month were missing | Overlap with the month's real start and end instants |
| C-8 | Zero-length events were not shown on any day | Shown on their start day |
| C-9 | Week list said "This week" for any week; cross-year week titles had no year | "Week of Oct 26" when not the current week; "Dec 28, 2026 to Jan 3, 2027" |
| C-10 | Booking date strip used the phone's date instead of the host's timezone | Strip and first request use today in the host's timezone |
| C-11 | Task, meeting, event and availability date pickers stopped at 1 Jan 2100 | Extended to 31 Dec 2199 |

Week start is Monday everywhere (grid, week view, titles). Months start on their real weekday. The date maths is in `lib/features/calendar/calendar_math.dart`: dates are held as UTC midnights, events are exact instants placed in the account timezone, and Asia/Karachi is not hardcoded.

## 3. Timezone coordination

`lib/core/api_time.dart` and its 26 tests are unchanged and still pass. The calendar feed still sends its range through `encodeApiTime`. Display and selection use the account timezone. No new meetings were created. Sync test 06 and the `API_WALL_CLOCK_ZONE` decision are still on hold (see BACKEND_TIMEZONE_FIX.md).

## 4. Tests

| Suite | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | **291 passed, 0 failed** (202 before; 89 new) |
| `test/calendar_math_test.dart` (new, 42) | Every month of 1900, 2000, 2024–2029 and 2100 checked against an independent Zeller weekday formula. Leap years 2024, 2028, 2100 (not leap) and 2000. Months starting Sunday, Monday, Wednesday and Saturday. Feb 2026 vs Feb 2028. Dec 2026 ↔ Jan 2027. 24 months without skips. Cross-month and cross-year weeks. UTC vs Asia/Karachi. America/New_York DST |
| `test/calendar_hub_test.dart` (new, 38) | Rendered grid equals the calendar for all months of 2026 and 2027 plus Feb 2024, 2028, 2100 and 2000. Today highlight. Screen navigation: 14 months forward and back, Today, week buttons plus swipe, day and agenda. Feed range in Karachi. Event placed on the local day. Error → retry. DST day-grid position |
| `test/my_meetings_test.dart` (new, 9) | Production `notes` list shape (meetings 11 and 28). Clients' text notes. Tolerance. My Meetings → meeting 11 detail. 500 → retry. Parse, network and server messages distinct. Empty state |
| `test/support/fake_backend.dart` | The test harness now uses the app's `schedioRetry` |
| `test/robustness_test.dart` | Booking test uses the host's date |
| API contract checker (production) | 60 endpoints, 0 missing, 0 problems |

## 5. Phone verification

**Method:** a read-only integration-test build of the same app code, driven through the app's screens (adb taps are blocked). Installed with `adb install -r`; the session was kept; r9 was reinstalled afterwards. Result: **52 checks passed, 0 failed** (final run, 01:29 PKT). Screenshots are in `calendar-meetings-evidence/`.

| Area | Checks | Result |
|---|---|---|
| My Meetings list | Loads meetings 11 and 28, no error | PASS |
| Meeting 11 detail | Opens, "Meeting notes (1)", actions shown | PASS |
| Meeting 28 detail | Opens, "Action items (2)", notes and actions shown | PASS |
| Network failure | Wi-Fi and data turned off: network error shown (not a read error); back online → Try again loads, no stale error | PASS |
| Keyboard | My Meetings search with the keyboard open (303 dp): no overflow | PASS |
| Calendar months | Jan–Dec 2026: title and every cell match the calendar (e.g. Jan starts Thursday, Jun Monday, Aug Saturday; Mar, Aug and Nov use 6 rows); no layout errors | PASS (24 checks) |
| Year change and leap year | Dec 2026 → Jan 2027; Feb 2028 with 29 days; tapping 29 Feb 2028 selects "Tuesday, Feb 29" | PASS |
| Today | Account today 26 Oct (UTC) while the phone showed 27 Oct 01:xx PKT; week and day views open on 26 Oct; Today returns | PASS |
| Views | Week (Mon–Sun), day (and Next), agenda | PASS |
| Swipes | Week swipe; Next then swipe; Today then swipe; three swipes; month swipes Nov → Dec → Jan 2027 and back | PASS (failed in the first run, C-3; passes after the fix) |

Not covered on the phone:
- **No genuine backend failure exists right now.** Meeting 11 no longer returns 500, so 500 handling is covered by widget tests only.
- **The calendar has only one event in range.** Overlapping, multi-day and long-title events are covered by widget tests.

## 6. Backend notes

| Item | Status |
|---|---|
| `GET meetings/11` 500 (K-26) | Resolved on the server (HTTP 200) |
| `GET meetings/{id}` changed shape: embeds `notes` (list) and `tasks` | Not documented in the API handoff; r9 users get "could not read" on every meeting detail until the next app build ships. **Ask the backend team to announce response-shape changes** |
| Timezone storage (BACKEND_TIMEZONE_FIX.md) | Still open |

## 7. Files changed (working tree, uncommitted)

- `lib/core/models.dart`: `asText`, `meetingNotes`, type-tolerant parsing
- `lib/features/calendar/calendar_math.dart` (new)
- `lib/features/calendar/calendar_screen.dart`
- `lib/features/workspace/records_screen.dart`: "Meeting notes (N)"
- `lib/features/booking/booking_screen.dart`: host-timezone date strip
- `lib/features/workspace/editor.dart`, `lib/features/availability/availability_screen.dart`: picker range
- Tests:
  - New: `test/calendar_math_test.dart`, `test/calendar_hub_test.dart`, `test/my_meetings_test.dart`
  - Updated: `test/support/fake_backend.dart`, `test/robustness_test.dart`
- `integration_test/meetings_probe_test.dart`, `integration_test/calendar_meetings_device_test.dart` (new, read-only)

Backup of the pre-change working tree: `.local-backups/20261027-0024-pre-calendar/`.

## 8. Release

r10 (`Schedio-1.0.0-production-push-20261027-r10.apk` and `.aab`) contains these fixes; r9 is untouched. Built with the same flags as r9 (no `API_WALL_CLOCK_ZONE`). The `API_WALL_CLOCK_ZONE` decision is still open (see BACKEND_TIMEZONE_FIX.md section 5).
