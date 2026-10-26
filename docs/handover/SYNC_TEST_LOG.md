# Schedio Website ↔ Mobile Sync Test Log

Live production (`https://schedio.live`), Schedio HQ (company 1). Phone: Xiaomi 2404ARN45A running **r8** (APK SHA-256 `b1633104…3dfa14`, verified on the device), signed in as **Hammad Developer (user 3)**. Website: tester signed in on schedio.live in Chrome. Evidence files are in `sync-evidence/`.

| # | Direction | Action | Verified on | Result | Evidence |
|---|---|---|---|---|---|
| 01 | Website → mobile | Tester created client **[TEST] Sync Client 01** (Discovery, rep Hammad Developer, contact "Test Contact", campaign "QA Sync Test") on the website | Phone, r8: Pipeline Board and Spreadsheet after refresh; API record | **PASS** | `01-board-test-sync-client-01.png`, `02-spreadsheet-test-sync-client-01.png`, `03-api-test-sync-client-01.txt` (record **ID 14**) |
| 02 | Mobile → website | Client 14 moved **Discovery → Scheduled** in the app's Pipeline workflow (Shift Stage → Scheduled → Move Deal), driven by an integration test because adb taps are blocked on the phone; the app sent `PATCH clients/14/status {status: scheduled}` | API (status `scheduled`, ID 14, other fields unchanged); phone Board after refresh; **website (tester)** | **PASS** | `04`–`07` screenshots, `08-api-sync02-stage-scheduled.txt`; tester confirmed on the live website: client 14 in Scheduled |
| 03 | Website → mobile | Tester changed client 14's contact on the website from "Test Contact" to **"Test Contact Updated"** (stage left as scheduled) | Phone, r8 code: Pipeline refreshed, Board card and client detail screen (read-only integration test, no writes); API record | **PASS** | `09-sync03-board.png`, `09-sync03-detail.png`, `10-api-sync03-contact-updated.txt` |

Test 03 details:
- **API:** ID 14; contact "Test Contact Updated"; status scheduled; company name, representative (Hammad Developer, user 3) and campaign "QA Sync Test" unchanged; no deal value.
- **Progress field:** reads "Website to Mobile synchronization test". It was not captured in tests 01–02, so it can't be shown as unchanged.
- **Phone:** after refresh, the Board shows the card in Scheduled with the new contact; the detail screen shows SCHEDULED, owner Hammad Developer, contact Test Contact Updated, campaign QA Sync Test (15/15 checks).
- **Method:** the check ran from a read-only test build of the same app code (taps are blocked on the phone); r8 was reinstalled afterwards and verified by fingerprint.
| 04 | Website → mobile | Standalone task creation on the website ("My Tasks" / "Create Task") | Deployed web code and live routes (read-only) | **BLOCKED BY WEB UI** (not a sync failure) | See test 04 details |

Test 04 details: task creation on the website.

| Where | Finding |
|---|---|
| Live site (no sign-in, read-only) | `GET /tasks` → **405** (only POST is defined, so there is no page); `GET /tasks/create` → **404**; `GET /my-tasks` → **404** |
| Web routes at deployed commit `04b0e99` (`routes/web.php` lines 85–87) | Only `POST /tasks` (`tasks.store`) and `PATCH /tasks/{task}/status` (`tasks.update-status`); no task list, create or edit page |
| Sidebar (`resources/views/layouts/partials/sidebar.blade.php`) | Calendar Hub, Schedule (meetings.create), My Meetings, Clients & Pipeline, My Booking Page, Today's Overview (dashboard), Reminders & Alerts, Meeting Suites, Events & Holidays, User Approvals. **No Tasks entry** |
| Today's Overview (`dashboard.blade.php`) | No task content or quick action |
| Where tasks can be created on the website | Only inside a meeting: **My Meetings → open a meeting → "Action Items & Tasks" tab → "+ Add Action Item"** (`meetings/show.blade.php`, 3 buttons). The modal posts to `tasks.store` with the meeting's `meeting_id`, so every web-created task is a meeting action item |

The app's standalone task creation (My Tasks → New Task) has no website equivalent, so standalone Website → mobile task sync is **BLOCKED BY WEB UI**. Task sync can still be tested through the supported web workflow: create a [TEST] meeting on the website, add an action item assigned to Hammad Developer, then check it appears in the app's My Tasks and on the meeting. No task was created through the API for this check.
| 04b | Website → mobile | Tester created meeting **[TEST] Sync Meeting 01** on the website (10:00–10:30 on 27 Oct, timezone "UTC Universal" chosen), then added action item **[TEST] Sync Task 01** (Hammad Developer, medium, due 28 Oct) through the meeting's "+ Add Action Item" | Phone, r8 code: Meetings list, meeting detail, My Tasks (read-only test); API | **PASS** for meeting and task sync; **FAIL (website/backend)** for the time saved; **app gaps** below | `11-sync04-meetings-list.png`, `12-sync04-meeting-detail.png`, `14-sync04-my-tasks.png`, `15-api-sync04-meeting-task.txt` |

Test 04b details:
- **API:** meeting **ID 28** (organiser Hammad Developer, scheduled, virtual); tasks **ID 16 and 17**, both linked to meeting 28, assignee Hammad Developer, medium, todo, due 28 Oct.
- **Phone, meetings:** the Meetings list shows "[TEST] Sync Meeting 01" (Host Hammad Developer).
- **Phone, tasks:** My Tasks shows both tasks (2 on screen = 2 in the API), due Wed Oct 28, todo, medium.
- **Duplicate task (website):** the website created two identical action items from one entry (IDs 16 and 17), so the form may not prevent a second submit (or Save was clicked twice). Both are left in place.
- **Time saved (website/backend):** the tester chose 10:00 with timezone "UTC Universal", but the server stored `2026-10-27T10:00:00+05:00` (10:00 Pakistan time = 05:00 UTC) while keeping `timezone: UTC` on the meeting. The phone correctly shows the stored moment in the account's timezone (UTC): **5:00–5:30 AM, Tue Oct 27**. The website and backend treat entered times as Asia/Karachi whatever timezone is chosen. This matches backend item B-10 and also affects the app for accounts whose timezone is not Asia/Karachi.
- **App gap: meeting detail has no action-item list.** It offers "Create action item" but does not list the meeting's existing tasks (the website does). The tasks themselves synced and appear in My Tasks.
- **App bug: meeting "Agenda" shows the title.** For meetings the app falls back to the title when there is no `agenda` field; the website's agenda text arrives as the description and shows correctly in the header.
- **"Client meeting" badge:** shown because the server sets `metadata.is_client_meeting: true`, but no client is linked (`client: null`).

Notes:
- **Test 02 spreadsheet:** the spreadsheet view was not checked; the test's tap on the Spreadsheet toggle missed because it was scrolled off screen. The Board and the website confirm the stage.
- **Records:** no other records were created, changed or deleted. [TEST] Sync Client 01 (ID 14) remains for the next tests.

## App fixes from test 04b (release r9, 2026-10-26)

| Fix | Verified on the phone (production, meeting 28) | Evidence |
|---|---|---|
| Meeting detail lists its action items ("Action items (N)", tap opens the task) | **PASS**: "Action items (2)" with both [TEST] Sync Task 01 rows (Todo · Medium · Due Wed, Oct 28) | `16-r9-meeting-action-items.png`, `17-api-r9-meeting-action-items.txt` |
| Meeting "Agenda" no longer shows the meeting title | **PASS**: no Agenda block for meeting 28 (it has no agenda text) | Same |

r9 (`Schedio-1.0.0-production-push-20261026-r9.apk`, SHA-256 `20d9f9ba…f22e39`) is installed on the phone and verified by fingerprint. Screenshots `11`, `12`, `13` and `14` were re-captured by this r9-code run and show the fixed screens. The task rows inside the meeting show no assignee, because the meeting response's task items carry none.

## Test 05: mobile → website, task status (2026-10-26)

| # | Direction | Action | Verified on | Result | Evidence |
|---|---|---|---|---|---|
| 05 | Mobile → website | Task **16** "[TEST] Sync Task 01" moved **todo → in_progress** in the app's task workflow (My Tasks → task 16, picked by record ID → Update status → In Progress), driven by an integration test because adb taps are blocked on the phone (not tapped by hand). The app sent `PATCH tasks/16/status {status: in_progress}` | Production status list; API before/after; phone My Tasks after refresh | **PASS**: phone side, and the tester confirmed on the live website that task 16 is In Progress and task 17 is Todo | `18`–`21` screenshots, `22-api-sync05-task16-in-progress.txt` |

Test 05 details:
- **Account:** Hammad Developer (user 3), Schedio HQ company 1.
- **Status contract:** production task statuses are todo, pending, in_progress, review, completed and cancelled, so `in_progress` is supported.
- **App:** confirmed "Status updated".
- **API, task 16:** status in_progress; title, priority, due date (2026-10-28 23:06 +05:00), meeting 28 and assignee unchanged; completed_at null.
- **API, task 17:** unchanged (todo, same fields).
- **Phone:** after refresh, My Tasks shows task 16 as "in progress" and task 17 as "todo".
- **Records:** no other record was changed; r9 is reinstalled on the phone (fingerprint `20d9f9ba…f22e39`).
