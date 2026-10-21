# Schedio Backend Integration Handoff

From: the mobile team. To: the developer who owns the Schedio Laravel backend and `schedio.live`.

The Flutter app has no database, user system or scheduling engine of its own. It reads and writes everything through the Laravel API, so web and mobile share the same users, companies, meetings, clients, tasks, events, bookings, reminders and notifications. This document lists what the mobile app needs from the backend. The mobile team has not changed and will not change the backend.

Companion documents:
- `docs/MOBILE_API_REQUIREMENTS.md`: every endpoint, field and status code the app uses today.
- `docs/BACKEND_DEPLOYMENT_REQUIREMENTS.md`: server, environment and acceptance-check details.

Repository note: the GitHub repository `zain-saeed-mughal/Schedio-App` currently contains both the Laravel code (`Schedio-main/`) and the Flutter app (`schedio_mobile/`). The mobile API described here lives in `Schedio-main/` on `main`. Mobile changes are kept inside `schedio_mobile/` and these docs.

## 1. API location and version

| Environment | Base URL | Status on 2026-10-22 |
|---|---|---|
| Staging | `https://staging.schedio.live/api/v1/` (to be confirmed by you) | Hostname does not resolve |
| Production | `https://schedio.live/api/v1/` (to be confirmed by you) | Laravel is up (`/up` returns 200), but every `/api/v1/*` route returns 404 |

Requirements: HTTPS with a public certificate, JSON on every response (including errors), and versioned routes under `/api/v1/`. The app rejects HTTP and private addresses in release builds.

## 2. Authentication

The app is built for **Laravel Sanctum personal access tokens**, as implemented in `Schedio-main/app/Http/Controllers/Api/AuthController.php`. Please confirm this is the official mechanism.

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

Mobile side still needed once you're ready: a Firebase project with Android `google-services.json` and iOS `GoogleService-Info.plist`, an APNs key in Firebase, and then the mobile team adds the `firebase_messaging` transport and turns on `PUSH_ENABLED`.

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
| 1 | Deploy the mobile API at the production host (`/api/v1/*` currently 404) | Backend |
| 2 | Staging DNS, HTTPS and deployment, plus test accounts | Backend |
| 3 | Confirm the official base URLs and Sanctum as the authentication method | Backend |
| 4 | Queue worker and scheduler running on staging and production | Backend |
| 5 | Device token endpoints and FCM sending (needed only if push is in scope for release) | Backend, then mobile |
| 6 | Optional: send `{}` instead of `[]` for empty object fields (`metadata`, `categories`); the app already tolerates both | Backend |
