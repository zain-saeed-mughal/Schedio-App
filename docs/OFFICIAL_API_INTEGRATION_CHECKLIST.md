# Official API Integration Checklist

For: the developer who owns the official Schedio Laravel backend and website.
From: the mobile team. Date: 2026-10-22. Mobile code: `main` at `3d949b1` plus the uncommitted test and documentation updates from this date.

The Flutter app has no database of its own. It becomes fully functional, and stays in sync with the website, only when the official backend serves the 58 endpoints below with the same behavior. Please go through each section and mark every item **Confirmed**, **Different** (with details) or **Not planned**.

Details for every field are in `MOBILE_API_REQUIREMENTS.md`. Push notification details are in `BACKEND_INTEGRATION_HANDOFF.md` section 9.

## How the columns were measured

- **Dev copy:** the Laravel development copy in this repository (`Schedio-main/`), run locally. "Verified" means a scripted request with real tokens returned the expected status and JSON on 2026-10-22.
- **Hosted copy:** the same development copy deployed at `203.215.161.245` under the `staging.schedio.live` host name, probed by IP over HTTP (no DNS or HTTPS yet). It only shows the route exists.
- **Official production:** `https://schedio.live/api/v1/`. The "Official prod" column in section 2 was measured before the official backend went live (all 404); section 0 has the current result (39 of 58 present).
- **Official staging:** not available to the mobile team.

Run the checker yourself on any server:

```bash
cd schedio_mobile
dart run tool/api_contract_check.dart https://<host>/api/v1/
```

## 0a. Contract v2 verification (2026-10-22, late evening)

Source: the project owner's "Complete Backend API Integration Contract" v2.0 plus read-only production probes. This section supersedes the route counts in section 0.

**Route presence: 58 of 58.** `dart run tool/api_contract_check.dart https://schedio.live/api/v1/` found no missing routes, no open protected routes and no non-JSON replies. The checker now reports `PRESENT (record not found)` separately from `MISSING` for 404s. Presence only proves a route exists.

**Credentials:** the v2 contract again publishes the admin and staff passwords in the shared document, so they are exposed. They must be rotated again and shared privately. The mobile team did not use them, so authenticated route-by-route checks and write tests are **BLOCKED**.

**Live evidence from the phone:** on 2026-10-22 the project owner signed in on the Android phone (production, push-enabled debug build). The app loaded the dashboard, the registration queue ("No one is waiting for approval") and the public booking link `https://schedio.live/book/8` from production without errors. That proves sign-in, `auth/me`, `dashboard` parsing, `admin/registration-requests` and the booking URL work for that account. No other screen was exercised.

### v2 contract compared with the app

| Area | v2 contract | App now | Status |
|---|---|---|---|
| Registration options | Top-level `companies`, `departments` | Production actually sends both `data` and top-level copies; the app reads either | PASS (public, verified) |
| Dashboard | `metrics` block plus `today_meetings`, `upcoming_meetings` lists, no `data` | Reads the v2 shape and the current one; production dashboard loaded on the phone | PASS (phone) |
| Lookups | Top-level lists, no `clients`, adds `task_statuses`, `task_priorities`, `event_categories` | Reads either shape; fetches `clients` separately when missing; uses the server's `task_statuses` for task actions | NOT TESTED (shape unverified) |
| Task statuses | Six: `todo`, `pending`, `in_progress`, `review`, `completed`, `cancelled` | Follows the server list from lookups; otherwise falls back to the earlier sets | NOT TESTED |
| Task priorities | `low`, `medium`, `high`, `urgent` | The app offers the same four | PASS (matches; values unverified on production) |
| CRM pipeline stages | `lead`, `discovery`, `proposal`, `won`, `lost` (route table only) | `discovery`, `scheduled`, `paperwork_onboarding`, `onboarded`, `deadend`, `pause` (matches the v1 official doc and the website copy) | **Conflict: backend must confirm the canonical list. Not changed** |
| Meeting notes | `agenda`, `discussion`, `decisions`, `action_items` (text or list), `follow_up_date`, `attachments` | Matches; lists are joined into text | NOT TESTED |
| Rooms create | `amenities` array, `color` | App sends `amenities_text`; no color | Needs confirmation that `amenities_text` is accepted |
| `204 No Content` | Deletes | Treated as success | PASS (unit tests) |
| Push devices | `POST devices`, `DELETE devices/{token}` | Implemented; notification permission granted on the phone | Registration and delivery NOT VERIFIED |

## 0. Production verification after the official documentation (2026-10-22, evening)

Source of truth used: `hammad5001/Schedio` `docs/MOBILE_API_DOCUMENTATION.md` and the integration handbook, plus read-only probes of `https://schedio.live/api/v1/` (no token, GET only, no writes). Staging `staging.schedio.live` still does not resolve.

Security: the documentation and handbook publish a live password for a developer-role account and a live API token. Both must be treated as compromised: rotate the password, revoke the token (`personal_access_tokens`), and share replacements privately. The mobile team did not use either. Because of this, **no authenticated production check was run**: every "present" route below only proves the route exists (it answered 401 or 405), not that its response matches.

### Route presence on production: 39 of 58 present

| Result | Endpoints |
|---|---|
| Present (401 or 405 without a token) | `auth/login`, `auth/me`, `auth/logout`, `calendar/feed`, all 7 `meetings` routes, `meetings/{id}/notes` (GET, POST), `availability/check`, `availability/suggestions`, all 7 `clients` routes, all 4 `tasks` routes, `rooms` (GET, POST), all 6 `notifications` routes, the 3 `public/booking` routes, `devices` (POST), `devices/{token}` (DELETE) |
| Missing (Laravel route not found) | `auth/register`, `auth/registration-options`, `dashboard`, `lookups`, `meeting-notes/{id}` (GET, PUT, DELETE), `rooms/{id}` (GET, PUT, DELETE), all 5 `events` routes, all 4 `admin/registration-requests` routes |
| Present but not in the app's list | `departments`, `users`, `notifications/preferences` (GET) |

### How the app handles each gap (implemented 2026-10-22)

| Gap | App behavior now | Backend action |
|---|---|---|
| `dashboard` missing | Rebuilt on the device from `calendar/feed` (today and next 30 days), `tasks?status=pending` and `notifications?filter=unread`. Only used when the server says the route does not exist | Add `GET dashboard`, or confirm the composed numbers match the website |
| `lookups` missing | Rebuilt from `users`, `departments`, `rooms` and `clients` (`per_page=100`); any one failing leaves that list empty instead of breaking the form | Confirm those four lists are scoped to the user's company |
| `rooms/{id}`, `meeting-notes/{id}` detail missing | Detail screen shows the record already loaded from the list. Edit and delete show "not available on the connected server yet" | Add the routes, or confirm rooms and notes are read-only on mobile |
| `events` missing | Events list and "New event" show the same message; events still appear through `calendar/feed` | Add the events routes |
| Registration and approvals missing | Registration and the approval queue show the same message; users can register on the website | Add the routes, or confirm registration is website-only |
| `DELETE` returns `204 No Content` | Empty replies now count as success (before, a successful delete was shown as a failure) | none |

### Documented shapes that differ from the app (all unverified on production)

| Area | Official documentation | App before | App now |
|---|---|---|---|
| `availability/check` | Top-level `has_conflicts`, `room`, `participants[]` with `user_id` and `status` | Read `data.participants[].name` | Reads with or without `data`; names come from `name` or the user list |
| `availability/suggestions` | `{ "slots": [...], "count": n }` | Read `data` | Reads `data` or `slots` |
| Task statuses | `pending`, `in_progress`, `completed` | `todo`, `in_progress`, `review`, `completed`, `cancelled` | Shows the official set when a task uses `pending`; please confirm the full list |
| Meeting notes | `title`, `content`, `action_items` as a list | `agenda`, `discussion`, `decisions`, `action_items` as text | Reads both. Creating notes still sends the app's fields: **needs confirmation** |
| Notification filter | `filter=unread` | `status=unread` | Sends both |
| Preferences update | `channels: {in_app, email}` | `channel_in_app`, `channel_email` | Sends both |
| RSVP | Optional `response_notes` | Not sent | Unchanged (optional) |
| Calendar feed | Adds `count`, `color`, `organizer`, `room` | Ignored extra fields | Unchanged |

## 1. Decisions needed first

| # | Question | Answer |
|---|---|---|
| 1 | Official base URLs for staging and production (proposed `https://staging.schedio.live/api/v1/` and `https://schedio.live/api/v1/`) | |
| 2 | Authentication: Laravel Sanctum personal access tokens with a `mobile` ability? Token lifetime? | |
| 3 | Will the dev copy's `routes/api.php`, `Api\*` controllers, `MobileAccess` and `scheduling_guard` middleware be merged into the official repository, or reimplemented? | |
| 4 | Should the staging server run the official backend instead of the dev copy now deployed there? | |
| 5 | Is push notification delivery in scope for the first release? | |
| 6 | Who provides staging test accounts for two companies (an admin and an employee each), and how are they shared privately? | |

## 2. Endpoint matrix

Auth: **None**, **Bearer** (any signed-in user), **Admin** (`super_admin` or `developer`), **Organizer** (organizer or admin), **Manager** (server `can_manage` flag).

### Authentication

| Method | Endpoint | Auth | Dev copy | Hosted copy | Official prod | Required action |
|---|---|---|---|---|---|---|
| POST | `auth/login` | None | Verified: 200 token, 401 wrong password, 403 `pending`, `rejected`, `inactive` | Present | 404 | Deploy; confirm the 403 `account_status` field |
| POST | `auth/register` | None | Verified: 201 `pending`, 422 duplicate email | Present | 404 | Deploy |
| GET | `auth/registration-options` | None | Verified | Present | 404 | Deploy |
| GET | `auth/me` | Bearer | Verified: 200; 401 missing, invalid, expired or revoked token; 403 `inactive` after deactivation | Present | 404 | Deploy |
| POST | `auth/logout` | Bearer | Verified: token revoked, then 401 | Present | 404 | Deploy |

### Workspace and calendar

| Method | Endpoint | Auth | Dev copy | Hosted copy | Official prod | Required action |
|---|---|---|---|---|---|---|
| GET | `dashboard` | Bearer | Verified | Present | 404 | Deploy |
| GET | `lookups` | Bearer | Verified | Present | 404 | Deploy |
| GET | `calendar/feed` | Bearer | Verified: meetings and events with `entity_type`; cancelled meetings drop out | Present | 404 | Deploy |

### Meetings, notes and availability

| Method | Endpoint | Auth | Dev copy | Hosted copy | Official prod | Required action |
|---|---|---|---|---|---|---|
| GET | `meetings` | Bearer | Verified | Present | 404 | Deploy; keep `meta.total` |
| POST | `meetings` | Bearer | Verified: 201; room clash rejected with 422 on `start_time` | Present | 404 | Deploy; confirm conflicts return 422 or 409 with `errors` |
| GET | `meetings/{id}` | Bearer | Verified: participant 200, other company 404 | Present | 404 | Deploy |
| PUT | `meetings/{id}` | Organizer | Verified earlier on device | Present | 404 | Deploy |
| PATCH | `meetings/{id}/cancel` | Organizer | Verified: participant 403, organizer 200, status `cancelled`, slot freed | Present | 404 | Deploy |
| DELETE | `meetings/{id}` | Organizer | Verified: participant 403, organizer 200, then 404 | Present | 404 | Deploy |
| POST | `meetings/{id}/rsvp` | Participant | Verified earlier on device | Present | 404 | Deploy |
| GET | `meetings/{id}/notes` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| POST | `meetings/{id}/notes` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| GET | `meeting-notes/{id}` | Bearer | Present | Present | 404 | Deploy |
| PUT | `meeting-notes/{id}` | Author or organizer | Present | Present | 404 | Deploy |
| DELETE | `meeting-notes/{id}` | Author or organizer | Present | Present | 404 | Deploy |
| POST | `availability/check` | Bearer | Verified: busy slot `has_conflicts: true`, free slot `false`, invalid range 422; private meeting details hidden | Present | 404 | Deploy |
| GET | `availability/suggestions` | Bearer | Verified: free slots returned | Present | 404 | Deploy |

### Clients and tasks

| Method | Endpoint | Auth | Dev copy | Hosted copy | Official prod | Required action |
|---|---|---|---|---|---|---|
| GET | `clients` | Bearer | Verified | Present | 404 | Deploy; keep `meta.total` |
| POST | `clients` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| GET | `clients/{id}` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| PUT | `clients/{id}` | Manager | Verified earlier on device | Present | 404 | Deploy |
| DELETE | `clients/{id}` | Manager | Present | Present | 404 | Deploy |
| PATCH | `clients/{id}/status` | Manager | Verified earlier on device | Present | 404 | Deploy; keep the six stage values |
| GET | `clients/{id}/meetings` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| GET | `tasks` | Bearer | Verified | Present | 404 | Deploy |
| POST | `tasks` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| GET | `tasks/{id}` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| PATCH | `tasks/{id}/status` | Assignee or manager | Verified earlier on device | Present | 404 | Deploy |

### Rooms and events

| Method | Endpoint | Auth | Dev copy | Hosted copy | Official prod | Required action |
|---|---|---|---|---|---|---|
| GET | `rooms` | Bearer | Verified | Present | 404 | Deploy |
| POST | `rooms` | `can_manage_rooms` | Verified: admin 201, employee 403 | Present | 404 | Deploy. Optional: return the created record in `data` |
| GET | `rooms/{id}` | Bearer | Verified: same company 200, other company 404 | Present | 404 | Deploy |
| PUT | `rooms/{id}` | `can_manage_rooms` | Verified | Present | 404 | Deploy |
| DELETE | `rooms/{id}` | `can_manage_rooms` | Verified: 200, then 404 | Present | 404 | Deploy |
| GET | `events` | Bearer | Verified | Present | 404 | Deploy |
| POST | `events` | Bearer | Verified: 201, appears in the calendar feed | Present | 404 | Deploy. Optional: return the created record in `data` |
| GET | `events/{id}` | Bearer | Verified: same company 200, other company 404 | Present | 404 | Deploy |
| PUT | `events/{id}` | Manager | Verified | Present | 404 | Deploy |
| DELETE | `events/{id}` | Manager | Verified: employee refused, admin 200 | Present | 404 | Deploy |

### Notifications

| Method | Endpoint | Auth | Dev copy | Hosted copy | Official prod | Required action |
|---|---|---|---|---|---|---|
| GET | `notifications` | Bearer | Verified | Present | 404 | Deploy; include `title`, `message`, `type`, `meeting_id` or `task_id` in `data` |
| POST | `notifications/mark-all-read` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| POST | `notifications/preferences` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| PATCH | `notifications/{id}/read` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| PATCH | `notifications/{id}/unread` | Bearer | Verified earlier on device | Present | 404 | Deploy |
| DELETE | `notifications/{id}` | Bearer | Present | Present | 404 | Deploy |

### Registration approvals

| Method | Endpoint | Auth | Dev copy | Hosted copy | Official prod | Required action |
|---|---|---|---|---|---|---|
| GET | `admin/registration-requests` | Admin | Verified: admin 200, employee 403 | Present | 404 | Deploy |
| GET | `admin/registration-requests/{id}/options` | Admin | Verified | Present | 404 | Deploy |
| PATCH | `admin/registration-requests/{id}/approve` | Admin | Verified: approved user can sign in | Present | 404 | Deploy |
| PATCH | `admin/registration-requests/{id}/reject` | Admin | Verified: user then gets 403 `rejected`. A missing reason is accepted and replaced by a default, like the website; the app always asks for one | Present | 404 | Deploy; confirm the official rule for the reason |

### Public booking

| Method | Endpoint | Auth | Dev copy | Hosted copy | Official prod | Required action |
|---|---|---|---|---|---|---|
| GET | `public/booking/{username}` | None | Verified earlier on device | Present | 404 | Deploy |
| GET | `public/booking/{username}/slots` | None | Verified earlier on device | Present | 404 | Deploy |
| POST | `public/booking/{username}` | None | Verified earlier on device: 201, slot disappears | Present | 404 | Deploy; set `APP_URL` so `calendar_export_url` works |

### Push devices (not built anywhere yet)

| Method | Endpoint | Auth | Dev copy | Hosted copy | Official prod | Required action |
|---|---|---|---|---|---|---|
| POST | `devices` | Bearer | Missing | Missing | 404 | Build, if push is in scope |
| DELETE | `devices/{token}` | Bearer | Missing | Missing | 404 | Build, if push is in scope |

## 3. Behavior the app relies on

- [ ] Every response, including errors and 404s, is JSON.
- [ ] 401 for a missing, invalid, expired or revoked token. The app signs the user out.
- [ ] 403 with `account_status` (`pending`, `rejected`, `inactive`) and a readable `message` when an account or company is not active. The app signs out and shows the message.
- [ ] 422 with `errors` for validation and scheduling conflicts. The app shows the message and offers `availability/suggestions`.
- [ ] Times in ISO 8601 with an offset or `Z`. The app shows them in the user's `timezone`.
- [ ] Paginated lists include `meta.current_page`, `meta.last_page` and `meta.total`.
- [ ] Records include `can_manage` and, for meetings, `can_rsvp`. The app shows or hides actions from these flags only.
- [ ] Company isolation enforced on every query: another company's record returns 404.
- [ ] Cancelled meetings return `status: cancelled`, free their room and participants, and leave the calendar feed.
- [ ] Optional: send `{}` instead of `[]` for empty object fields such as `metadata` and `categories`. The app tolerates both.

## 4. Dependencies for complete web and mobile synchronization

| # | Dependency | Why it matters | Owner | Status |
|---|---|---|---|---|
| 1 | Mobile API on the official backend, same database as the website | Without it there is nothing shared to sync | Backend | BLOCKED |
| 2 | Same `users`, `companies` and Sanctum `personal_access_tokens` tables as the website | One login for web and mobile; no separate user database | Backend | BLOCKED |
| 3 | Website and API apply the same permission and visibility rules | A record visible on one must be visible on the other | Backend | NOT TESTED |
| 4 | Staging with DNS, HTTPS, the official code and two-company test accounts | Needed to run the web-to-mobile checks in section 5 | Backend and domain owner | BLOCKED |
| 5 | Queue worker and scheduler (`schedule:run`) on staging and production | Reminders and notifications are produced by Laravel, not by the app | Backend | BLOCKED |
| 6 | Notification `data` keys (`title`, `message`, `type`, `meeting_id`, `task_id`) | The app opens the right screen from a notification | Backend | NOT TESTED on official |
| 7 | Device token endpoints and FCM sending (Firebase project `schedio-app-bc57b` exists; Android config received, iOS config and APNs key still needed) | Push reminders while the app is closed | Backend, then mobile | BLOCKED |
| 8 | Optional: broadcasting (Reverb or Pusher) | Instant updates. Without it the app refreshes on resume, on pull, after actions and every 30 seconds for the dashboard and badge | Backend | Not required |

## 5. Joint acceptance tests on official staging

Run together once sections 1 to 3 are confirmed. Record PASS or FAIL for each.

1. Sign in on web and mobile with the same account; sign out on mobile and confirm the token no longer works.
2. Create a meeting on the website; it appears in the app after pull to refresh.
3. Create a meeting in the app; it appears on the website.
4. Update, then cancel, a meeting on one side; both sides show the change, and the slot is free again.
5. Create a task on the website; change its status in the app; the website shows the new status.
6. Create and edit a client on either side; both sides match, including the pipeline stage.
7. Calendar month, week and day views match the website for the same user and timezone.
8. A public booking blocks that slot for new meetings on both sides.
9. A notification created on the server shows in the app and can be marked read on either side.
10. A Company B account cannot see or open any Company A record, by list or by ID.
11. A deactivated account is signed out of the app on its next request, with the reason shown.
12. A meeting reminder is delivered with the app in the foreground, the background and closed (push only).
