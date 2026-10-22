# Schedio Backend Integration Handoff

From: the mobile team. To: the developer who owns the Schedio Laravel backend and `schedio.live`.

The Flutter app has no database, user system or scheduling engine of its own. It reads and writes everything through the Laravel API, so web and mobile share the same users, companies, meetings, clients, tasks, events, bookings, reminders and notifications. This document lists what the mobile app needs from the backend. The mobile team has not changed and will not change the backend.

Companion documents:
- `docs/MOBILE_API_REQUIREMENTS.md`: every endpoint, field and status code the app uses today.
- `docs/BACKEND_DEPLOYMENT_REQUIREMENTS.md`: server, environment and acceptance-check details.
- `docs/OFFICIAL_API_INTEGRATION_CHECKLIST.md`: the 58-endpoint matrix, decisions, sync dependencies and joint acceptance tests to confirm against your code.

Repository note: the official Laravel backend is maintained by you in a separate repository. The mobile repository (`zain-saeed-mughal/Schedio-App`) also contains a Laravel **development copy** in `Schedio-main/`, which the mobile team used to build and test the app locally. It is a reference implementation of the contract below, **not** the official backend, and it may differ from what runs on `schedio.live`. Section 14 compares the two. Mobile changes are kept inside `schedio_mobile/` and these docs.

## 1. API location and version

| Environment | Base URL | Status on 2026-10-22 |
|---|---|---|
| Staging | `https://staging.schedio.live/api/v1/` (to be confirmed by you) | Hostname does not resolve. A staging server at `203.215.161.245` answers for this host name over plain HTTP, but it runs the mobile repository's development copy, not your official backend (see section 14) |
| Production | `https://schedio.live/api/v1/` (confirmed in your documentation) | Live since 2026-10-22: 39 of the app's 58 routes present; 19 missing (see `OFFICIAL_API_INTEGRATION_CHECKLIST.md` section 0). Responses not yet verified with a token |

Requirements: HTTPS with a public certificate, JSON on every response (including errors), and versioned routes under `/api/v1/`. The app rejects HTTP and private addresses in release builds.

## 2. Authentication

The app is built for **Laravel Sanctum personal access tokens** (bearer tokens with a `mobile` ability and a 30 day expiry in the development copy). Please confirm this is the official mechanism, or tell the mobile team what the official backend uses.

| Step | Request | Response the app relies on |
|---|---|---|
| Sign in | `POST auth/login` with `email`, `password`, `device_name` | 200 `{"token": "...", "user": {...}}`; 401 wrong credentials; 403 with `account_status` (`pending`, `rejected`, `inactive`) and the reason in `message`; 422 validation; 429 throttled |
| Current user | `GET auth/me` with `Authorization: Bearer <token>` | 200 `{"data": {user}}` |
| Sign out | `POST auth/logout` | 200, and the token is revoked |
| Any protected call | Bearer token | 401 if the token is missing, expired or revoked; 403 with `account_status` if the user or company was deactivated |

Example sign-in response:

```json
{
  "token": "12|9f3c...",
  "user": {
    "id": 1,
    "name": "Ayesha Khan",
    "email": "ayesha@example.com",
    "role": "super_admin",
    "timezone": "Asia/Karachi",
    "company": {"id": 1, "name": "Example Co"},
    "department": {"id": 3, "name": "Sales"},
    "booking_url": "https://schedio.live/book/ayesha",
    "booking_username": "ayesha",
    "can_administer": true,
    "can_manage_rooms": true,
    "notification_preferences": {
      "channels": {"in_app": true, "email": true},
      "categories": {"meetings": {"in_app": true, "email": false}}
    }
  }
}
```

Mobile behavior: the token is stored in Keychain or EncryptedSharedPreferences, sent only to non-public routes, and removed on 401 or on a 403 that carries `account_status`. The user then sees the server's message. Sign-out revokes the token on the server first.

## 3. Permissions and companies

The app does not decide permissions itself. It shows or hides actions using the flags the server sends: `can_administer`, `can_manage_rooms`, and per-record `can_manage` and `can_rsvp`. Every write must still be authorized by the server, and company isolation must be enforced by the server for every query. Verified on the local test server: an employee gets 403 on admin routes and 404 on another company's records.

Roles the app recognizes: `developer`, `super_admin`, `bd_manager`, `bd_rep`, `manager`, `employee`, `client`.

## 4. Meetings and calendar

The app uses: `GET meetings`, `GET meetings/{id}`, `POST meetings`, `PUT meetings/{id}`, `PATCH meetings/{id}/cancel`, `DELETE meetings/{id}`, `POST meetings/{id}/rsvp`, `GET calendar/feed?start=&end=`, `POST availability/check`, `GET availability/suggestions`, and the notes routes. All fields are listed in `MOBILE_API_REQUIREMENTS.md`.

Requirements for consistency with the website:
- **Conflicts:** Laravel must reject conflicting meetings with 422 (or 409) and a message in `errors`. The app shows that message and offers alternatives from `availability/suggestions`. The app never decides conflicts itself.
- **Times:** send ISO 8601 with an offset or `Z`. The app displays them in the user's `timezone`.
- **Calendar feed:** include both meetings and company events with `entity_type`.

## 5. Clients pipeline

The app uses `GET clients?status=&search=&per_page=100`, `GET clients/{id}`, `POST clients`, `PUT clients/{id}`, `DELETE clients/{id}`, `PATCH clients/{id}/status` (with optional `progress`, `deal_value`, `notes`) and `GET clients/{id}/meetings`. Stage values must stay: `discovery`, `scheduled`, `paperwork_onboarding`, `onboarded`, `deadend`, `pause`. Please include `meta.total` in paginated responses; the board's column counts use it.

## 6. Tasks

The app uses `GET tasks`, `GET tasks/{id}`, `POST tasks` and `PATCH tasks/{id}/status`. The server does not allow editing or deleting tasks, and the app follows that. Include `assignee` and `meeting_id` so the app can show the assignee and link to the meeting.

## 7. Public booking

The app uses `GET public/booking/{username}`, `GET public/booking/{username}/slots?date=&duration=` and `POST public/booking/{username}`. No bearer token is sent. The `POST` response must include `data.calendar_export_url`, a signed HTTPS link; set `APP_URL` correctly so this link works. Verified locally: booking returns 201 and the slot then disappears.

## 8. Reminders and in-app notifications

The backend owns the reminder schedule (`schedio:process-reminders`, queue jobs, notifications). The app does not schedule reminders of its own. It shows the server's notifications and meeting data.

The app uses `GET notifications`, `PATCH notifications/{id}/read` and `/unread`, `DELETE notifications/{id}`, `POST notifications/mark-all-read` and `POST notifications/preferences`. For deep links, each notification's `data` should include `title`, `message`, `type`, and `meeting_id` or `task_id` where relevant.

On the server this needs a running queue worker and a cron entry for `schedule:run`.

## 9. Push notifications (new endpoints needed)

The app has push scaffolding ready but disabled (build flag `PUSH_ENABLED`). It needs these endpoints plus Firebase Cloud Messaging (with APNs for iOS):

### Register or refresh a device

```
POST /api/v1/devices
Authorization: Bearer <token>
Content-Type: application/json

{"token": "<FCM registration token>", "platform": "android" | "ios"}
```

Response: `201` on create, `200` if the token already exists. Upsert by `token`, set `user_id` to the authenticated user, and update `platform` and `last_seen_at`. One token belongs to one user; registering it for a new user moves it.

### Unregister on sign-out

```
DELETE /api/v1/devices/{token}
Authorization: Bearer <token>
```

Response: `204`. Only the owner can delete. The app calls this before `auth/logout`.

### Suggested table

`device_tokens`: `id`, `user_id` (foreign key, cascade on delete), `token` (unique, string 255+), `platform`, `last_seen_at`, timestamps.

### Sending

- Send from the existing reminder and notification jobs, through a new FCM channel, honoring `notification_preferences`.
- Use **data-only or minimal** payloads. Don't put private meeting details in the push body. The app fetches details after the tap.

```json
{
  "notification": {"title": "Meeting in 15 minutes", "body": "Open Schedio for details"},
  "data": {"notification_id": "<database notification uuid>", "type": "meeting_reminder", "meeting_id": "11"}
}
```

- Supported `type` values: `meeting_reminder`, `meeting_invitation`, `meeting_updated`, `meeting_cancelled`, `rsvp`, `task_assigned`, `task_updated`. The app opens the meeting or task, and anything else opens the inbox.
- Include `notification_id` so the app can mark it read and avoid showing duplicates.
- When FCM answers that a token is invalid (`UNREGISTERED`, `INVALID_ARGUMENT`), delete that token row.
- Prevent duplicate sends for the same reminder, for example with a unique (reminder, device) send log, so retries don't notify twice.

Status 2026-10-22: the Firebase project `schedio-app-bc57b` exists and its Android `google-services.json` (package `live.schedio.schedio_mobile`) is in the mobile repository, git-ignored. Mobile side still needed once you're ready: the iOS `GoogleService-Info.plist`, an APNs key in Firebase, and then the mobile team adds the `firebase_messaging` transport and turns on `PUSH_ENABLED`.

## 10. Synchronization model

There is one database, so a change made on the web or on mobile is stored once and read by both. The app refreshes when:
- the app returns to the foreground (full refresh),
- the user pulls to refresh on any list,
- the user completes an action (the affected lists are refreshed), and
- the unread badge and dashboard are re-fetched every 30 seconds while the app is open.

Instant updates would need server events, for example Laravel Reverb or Pusher broadcasting on private per-user and per-company channels, plus push. That isn't required for release, and the app does not claim real-time sync today.

## 11. Staging requirements

1. DNS `A` record for `staging.schedio.live`, and an HTTPS certificate.
2. Deploy `main` with the items in `BACKEND_DEPLOYMENT_REQUIREMENTS.md` (Sanctum, `personal_access_tokens` migration, `routes/api.php`, middleware registration).
3. `APP_ENV=production`-style settings with `APP_DEBUG=false`, a separate staging database, a queue worker and the scheduler.
4. Test accounts for at least two companies (an admin and an employee each). Send the credentials to the mobile team privately, never in the repository.
5. Tell the mobile team the final base URL. They will run the device test sheet against it.

## 12. Production acceptance checks

Run the 9 checks in `BACKEND_DEPLOYMENT_REQUIREMENTS.md` section 6 (JSON 404s, login 401/200, protected 401/200, throttling 429, logout revocation). Then the mobile team signs off after:

- sign-in, dashboard and logout with a real account,
- creating a meeting on mobile and seeing it on the website, and the reverse,
- a scheduling conflict rejected by the server,
- a public booking with a working iCal link,
- notifications listing and marking read, and
- company isolation between two companies.

## 13. Backend items blocking the mobile release

| # | Item | Owner |
|---|---|---|
| 1 | All 58 routes now exist (route check 2026-10-22). Still needed: confirm the canonical CRM stages (v2 lists `lead`, `discovery`, `proposal`, `won`, `lost`; v1 and the website use six different stages), whether rooms accept `amenities_text`, and the real `lookups` shape | Backend |
| 2 | Staging DNS, HTTPS and deployment, plus test accounts | Backend |
| 3 | Confirm the official base URLs, the authentication method, and the answers in section 14 | Backend |
| 4 | Queue worker and scheduler running on staging and production | Backend |
| 5 | Device token routes are live on production (route check only). Still needed: confirm FCM sending uses the classic FCM registration token the app sends, plus the iOS Firebase file and APNs key | Backend, then mobile |
| 6 | Optional: send `{}` instead of `[]` for empty object fields (`metadata`, `categories`); the app already tolerates both | Backend |

## 14. Development copy versus official backend

The mobile team cannot see your repository, so the comparison is done from the outside with the contract checker in the mobile repository:

```bash
cd schedio_mobile
dart run tool/api_contract_check.dart https://<host>/api/v1/
```

It probes all 58 endpoints the app uses (54 until 2026-10-22, when `GET` and `DELETE` for `rooms/{id}` and `events/{id}` were added) with side-effect-free `GET` requests and no token. An existing protected route answers 401, a write-only route answers 405, and a missing route answers Laravel's "route could not be found" or an HTML 404. With `SCHEDIO_TOKEN` set to a test account's token, it also checks that the read-only collection endpoints return 200 JSON with the expected top-level fields. It never sends writes.

Results on 2026-10-22:

| Server | Routes present | Authenticated reads | Notes |
|---|---|---|---|
| Development copy, `http://127.0.0.1:8090/api/v1/` | 56 of 58 | 13 of 13 OK | Missing only `POST devices` and `DELETE devices/{token}` (push, not built anywhere yet) |
| Official production, `https://schedio.live/api/v1/` | 0 of 58 | not run | Re-checked later on 2026-10-22: every route is still a JSON 404 |
| Hosted staging server, `http://203.215.161.245/api/v1/` with `SCHEDIO_HOST=staging.schedio.live` | 56 of 58 | not run | Same result as the development copy, because that is what it runs. HTTP only until DNS and HTTPS exist |
| Official staging, `https://staging.schedio.live/api/v1/` | not reachable | not run | Hostname does not resolve |

To probe a server by IP before its DNS exists, set `SCHEDIO_HOST` to the host name; the checker then sends it as the `Host` header.

**Important:** the staging server that exists today was set up from the mobile repository's development copy (`Schedio-main/`), so a pass there proves the app works with that copy on a real server. It does not prove the official backend matches. Please decide whether staging should run your official backend instead, so that web and mobile are tested against the same code that will run in production.

Once official staging is up, please run the checker (or ask the mobile team to), and send the output with any intentional differences. To make the comparison complete, please answer:

1. The official base URLs for staging and production.
2. Whether authentication is Sanctum bearer tokens, and the token lifetime.
3. Whether the routes and fields in `MOBILE_API_REQUIREMENTS.md` match the official code. List any renamed fields, extra required fields or different status codes.
4. Whether `routes/api.php`, `Api\*` controllers, `MobileAccess` and `SerializeScheduling` from the development copy should be merged into the official repository, or reimplemented there.
5. Whether push notifications (section 9) are in scope for the first release.
6. Who provides staging test accounts for at least two companies, and how they are shared securely.
