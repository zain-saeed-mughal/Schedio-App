# Schedio Mobile API Requirements

Every HTTP call made by the Flutter app, checked against `Schedio-main/routes/api.php` at commit `8bd453a`. The backend was read, not modified.

Base URL: `<host>/api/v1/`, set per environment (see "Environments" below). All requests send `Accept: application/json`. "Bearer" means the Sanctum token from `auth/login` is sent as `Authorization: Bearer <token>`. Every bearer route except `auth/logout` also passes the `MobileAccess` middleware, which returns 403 with `account_status` when the user or company is inactive or unapproved.

Integration status: VERIFIED means the route exists with the same method and the app's request and response handling matches the controller. Status reflects code review plus automated tests against a fake backend; it is not a substitute for testing against a live server.

## Authentication

| Method | Endpoint | Auth | Request | Response used by app | Status |
|---|---|---|---|---|---|
| POST | `auth/login` | None (throttled 6/min in production) | `email`, `password`, `device_name` | `token`, `user` (MobileUserResource). 401 wrong credentials; 403 with `account_status` (`pending`, `rejected`, `inactive`) and the rejection reason as `message` | VERIFIED |
| POST | `auth/register` | None | `name`, `email`, `password`, `password_confirmation`, `title`, `phone`, `registration_notes`, `registration_type` (`company_super_admin` or `employee`), plus `company_name` or `company_id` and optional `department_id` | Success message; the app then shows the pending-review screen | VERIFIED |
| GET | `auth/registration-options` | None | none | `data.companies[]`, `data.departments[]` with `company_id` | VERIFIED |
| GET | `auth/me` | Bearer | none | `data`: the account, including `role`, `timezone`, `booking_url`, `booking_username`, `can_administer`, `can_manage_rooms`, `notification_preferences` | VERIFIED |
| POST | `auth/logout` | Bearer | none | Revokes the current token | VERIFIED |

## Workspace

| Method | Endpoint | Auth | Request | Response used by app | Status |
|---|---|---|---|---|---|
| GET | `dashboard` | Bearer | none | `data.today_meetings`, `upcoming_meetings`, `pending_tasks`, `unread_notifications`, `meetings[]` (next 8) | VERIFIED |
| GET | `lookups` | Bearer | none | `data.users[]`, `departments[]`, `rooms[]`, `clients[]` (`id`, `name`) | VERIFIED |
| GET | `calendar/feed` | Bearer | `start`, `end` (UTC ISO 8601) | `data[]`: `id`, `title`, `entity_type` (`meeting` or event), `start_time`, `end_time` | VERIFIED |

## Meetings

| Method | Endpoint | Auth | Request | Response | Status |
|---|---|---|---|---|---|
| GET | `meetings` | Bearer | `page`, `search`, `status` | Paginated `data[]`, `meta.current_page`, `meta.last_page`, `meta.total` | VERIFIED |
| GET | `meetings/{id}` | Bearer | none | `data` including `participants[]` with `status`, `can_manage`, `can_rsvp`, `metadata` (client fields) | VERIFIED |
| POST | `meetings` | Bearer | `title`, `description`, `location`, `meeting_link`, `type`, `start_time`, `end_time`, `timezone`, `department_id`, `room_id`, `client_id`, `participant_ids[]`, `is_private`, `is_client_meeting`, `client_name`, `client_email`, `client_company`, `campaign`, `save_as_client`, `reminder_minutes`, `recurrence_frequency` | 201. 422 with `errors` on validation or scheduling conflict | VERIFIED |
| PUT | `meetings/{id}` | Bearer, organizer or admin | Same fields as create | 200 | VERIFIED |
| PATCH | `meetings/{id}/cancel` | Bearer, organizer or admin | none | 200 | VERIFIED |
| DELETE | `meetings/{id}` | Bearer, organizer or admin | none | 200 | VERIFIED |
| POST | `meetings/{id}/rsvp` | Bearer, participant | `status` (`accepted`, `tentative`, `declined`) | 200 | VERIFIED |
| GET | `meetings/{id}/notes` | Bearer | `page` | Paginated notes | VERIFIED |
| POST | `meetings/{id}/notes` | Bearer | `agenda`, `discussion`, `decisions`, `action_items`, `attachments_text`, `follow_up_date` | 201 | VERIFIED |
| GET, PUT, DELETE | `meeting-notes/{id}` | Bearer, author or organizer for writes | PUT: same fields as create | `data` or 200 | VERIFIED |
| POST | `availability/check` | Bearer | `start_time`, `end_time`, `room_id`, `participant_ids[]` | `data.has_conflicts`, `data.participants[]` (`name`, `status`) | VERIFIED |
| GET | `availability/suggestions` | Bearer | `date`, `duration_minutes`, `room_id`, `participant_ids[]` | `data[]` of `start_time`, `end_time` | VERIFIED |
| GET | `clients/{id}/meetings` | Bearer | `page` | Paginated meetings for one client | VERIFIED |

## Clients, rooms, events, tasks

The backend exposes these four through a generic `{module}` route. Allowed operations differ per module.

| Method | Endpoint | Modules | Request | Status |
|---|---|---|---|---|
| GET | `{module}` | clients, rooms, events, tasks | `page`, `search` (matches `company_name` for clients, `name` for rooms, `title` otherwise), `status` (clients and tasks only), `per_page` (1 to 100; the pipeline board uses 100) | VERIFIED |
| GET | `{module}/{id}` | all four | none | VERIFIED |
| POST | `{module}` | all four | Clients: `company_name`, `contact_name`, `contact_email`, `contact_phone`, `contact_role`, `campaign`, `progress`, `notes`, `deal_value`, `status`, `assigned_to`. Rooms: `name`, `code`, `location`, `capacity`, `amenities_text`, `is_active`. Events: `title`, `description`, `location`, `category`, `department_id`, `is_all_day`, `is_company_wide`, `start_time`, `end_time`. Tasks: `title`, `description`, `priority`, `assigned_to`, `department_id`, `due_date`, `meeting_id` | VERIFIED |
| PUT, DELETE | `{module}/{id}` | clients, rooms, events only | Same fields as create | VERIFIED. The app hides edit and delete for tasks, matching the server. |
| PATCH | `{module}/{id}/status` | clients, tasks | `status`. Clients also accept `progress`, `deal_value`, `notes` (used by Shift Stage) | VERIFIED |

Pipeline status values used by the app match the server validation: `discovery`, `scheduled`, `paperwork_onboarding`, `onboarded`, `deadend`, `pause`. Task status values: `todo`, `in_progress`, `review`, `completed`, `cancelled`.

## Notifications

| Method | Endpoint | Auth | Request | Status |
|---|---|---|---|---|
| GET | `notifications` | Bearer | `page`, `status=unread` | VERIFIED |
| PATCH | `notifications/{id}/read`, `notifications/{id}/unread` | Bearer | none. The app marks a notification read when it is opened. | VERIFIED |
| DELETE | `notifications/{id}` | Bearer | none | VERIFIED |
| POST | `notifications/mark-all-read` | Bearer | none | VERIFIED |
| POST | `notifications/preferences` | Bearer | `channel_in_app`, `channel_email`, `categories{key: {in_app, email}}` | VERIFIED |

## Administration

| Method | Endpoint | Auth | Request | Status |
|---|---|---|---|---|
| GET | `admin/registration-requests` | Bearer, super_admin or developer | `status` (`pending`, `approved`, `rejected`), `page` | VERIFIED. Response has `id`, `name`, `email`, `title`, `role`, `company_id`, `department_id`, `approval_status`, `registration_notes`, `created_at`. |
| GET | `admin/registration-requests/{id}/options` | Bearer, admin | none | VERIFIED. `roles[]` (developer also gets `super_admin`) and `departments[]`. |
| PATCH | `admin/registration-requests/{id}/approve` | Bearer, admin | optional `role`, `department_id`, `title` | VERIFIED |
| PATCH | `admin/registration-requests/{id}/reject` | Bearer, admin | `rejection_reason` | VERIFIED |

## Public booking

| Method | Endpoint | Auth | Request | Status |
|---|---|---|---|---|
| GET | `public/booking/{username}` | None, bearer deliberately not sent | none | VERIFIED. `name`, `headline`, `bio`, `timezone`, `durations[]`. |
| GET | `public/booking/{username}/slots` | None | `date` (`yyyy-MM-dd`), `duration` | VERIFIED |
| POST | `public/booking/{username}` | None (throttled 6/min) | `client_name`, `client_email`, `client_company`, `notes`, `start_time`, `duration_minutes` | VERIFIED. Response `data.calendar_export_url` (signed iCal link). |

## Roles

Server role values (from `App\Models\User`): `developer`, `super_admin`, `bd_manager`, `bd_rep`, `manager`, `employee`, `client`. The app does not hardcode permissions per role. It uses the server's `can_administer`, `can_manage_rooms`, `can_manage` and `can_rsvp` flags, and every write is still authorized by the server.

## Outstanding backend dependencies

These are needed for production but are outside the mobile scope. They are listed here for the backend owner; nothing was changed in the web project.

1. **Deploy the mobile API to the production host.** `https://schedio.live/api/v1/*` currently returns an HTML 404. The production build expects the routes above, Laravel Sanctum, and the `MobileAccess` and `scheduling_guard` middleware at `https://schedio.live/api/v1/`.
2. **Finish the staging host.** `staging.schedio.live` needs its DNS A record and HTTPS certificate before staging builds can be tested on real devices without a local PC server.
3. **Push notifications.** The app already calls `POST /api/v1/devices` (`token`, `platform`) after sign-in and `DELETE /api/v1/devices/{token}` before logout when built with `PUSH_ENABLED=true`. These endpoints do not exist yet; the full contract is in BACKEND_INTEGRATION_HANDOFF.md section 9.
4. **Unread count endpoint (optional).** The bell badge reads `unread_notifications` from `dashboard`. A lightweight `GET notifications/unread-count` would make the 30 second poll cheaper.

## Environments

Configured in `lib/core/env.dart` with build-time defines. No secrets are embedded.

| Profile | How to build | API URL | Rules |
|---|---|---|---|
| Development | `--dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://<PC LAN IP>:8090/api/v1/` | Required, no default | HTTP and private addresses allowed, debug builds only |
| Staging | `--dart-define=APP_ENV=staging` | Default `https://staging.schedio.live/api/v1/`, overridable | HTTPS and a public host required |
| Production | `--dart-define=APP_ENV=production`, or no defines | Default `https://schedio.live/api/v1/`, overridable | HTTPS and a public host required |

Any release build enforces the staging and production rules, even if `APP_ENV=development` is passed. Builds made with only `API_BASE_URL` pointing at a private address are treated as development in debug mode, so the existing local scripts keep working.
