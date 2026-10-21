# Backend Deployment Requirements for the Schedio Mobile App

Audience: the backend team that owns the Laravel application. The mobile team has not changed and will not change the web project. This document lists what must be live on a server before the Android and iOS apps can work there.

Reference contract: `docs/MOBILE_API_REQUIREMENTS.md` lists every endpoint, method, field and response the app uses.

## 1. Target hosts

| Environment | Base URL the app calls | Current state (2026-10-21) |
|---|---|---|
| Staging | `https://staging.schedio.live/api/v1/` | No DNS record for `staging.schedio.live`, so the host is unreachable. The server-side install is partly done: the HTTPS certificate, queue worker and scheduler are not set up yet. |
| Production | `https://schedio.live/api/v1/` | Reachable, but every `/api/v1/*` request returns an HTML 404 page. The mobile API is not deployed. |

The app accepts only HTTPS URLs on public hosts in staging and production builds. The base URL must end in `/api/v1/`.

## 2. Code that must be deployed

All of these already exist in `Schedio-main/` on the `main` branch (commit `8bd453a`). Deploy them as they are.

| Area | Files |
|---|---|
| Routes | `routes/api.php` (the `v1` group) |
| Bootstrap | `bootstrap/app.php`: registers `routes/api.php`, the `scheduling_guard` middleware alias, and JSON error rendering for `api/*` |
| API controllers | `app/Http/Controllers/Api/{AuthController, ActivityController, BookingController, MeetingController, WorkspaceController}.php` |
| Middleware | `app/Http/Middleware/MobileAccess.php`, `app/Http/Middleware/SerializeScheduling.php` |
| Requests and resources | `app/Http/Requests/Api/*`, `app/Http/Resources/MobileUserResource.php`, `app/Http/Resources/MobileRecordResource.php` |
| Services | `app/Services/MobileVisibility.php` (plus the existing conflict, notification and reminder services the controllers call) |
| Package | `laravel/sanctum` ^4.0 in `composer.json` and `composer.lock` |
| Migration | `database/migrations/2026_10_20_000001_create_personal_access_tokens_table.php` |
| Config | `config/staging_tests.php` (must stay disabled in production, see section 4) |

The API controllers delegate to the web controllers (`ClientController`, `TaskController`, `RoomController`, `EventController`, `MeetingNoteController`, `Admin/RegistrationRequestController`), so those must be the same version.

## 3. Database

1. Back up the production database.
2. Run `php artisan migrate --pretend --force` and review the SQL. The mobile API needs at least `personal_access_tokens`. It also relies on `2026_10_14_232000_add_booking_fields_to_users_table`, `2026_10_15_033000_create_clients_table` and `2026_10_15_033100_add_client_id_to_meetings_table` if production does not already have them.
3. Run `php artisan migrate --force`.

No mobile-specific database is used. The app works only through the API, against the same database as the website.

## 4. Environment settings

| Setting | Required value | Why |
|---|---|---|
| `APP_ENV` | `production` | `routes/api.php` applies production throttles (6 logins per minute, 120 API calls per minute) only when the environment is `production`. |
| `APP_DEBUG` | `false` | Prevents stack traces in API error responses. The app also filters these, but they must not leave the server. |
| `APP_URL` | `https://schedio.live` (or the staging URL) | Used to build the signed iCal links returned by public booking. A wrong value breaks "Add to calendar". |
| `STAGING_TESTS_ENABLED` | `false` or unset | Keeps the test-account seeder locked. Never set `STAGING_TEST_CREDENTIALS_FILE` in production. |
| Queue | A real driver (`database` or `redis`) with a running worker | Invitations, RSVP updates and reminders are dispatched as jobs and notifications. Without a worker, the app's inbox stays empty. |
| Scheduler | Cron running `php artisan schedule:run` every minute | Runs `schedio:process-reminders`. |

Sanctum tokens are created with the `mobile` ability and a 30 day expiry in `Api\AuthController@login`. No extra Sanctum configuration is needed for bearer tokens. CORS is not needed, because native apps do not send browser origin checks.

## 5. Web server

1. Serve HTTPS with a valid public certificate. The app does not accept self-signed certificates.
2. Route `/api/*` to Laravel's `public/index.php`, the same front controller as the website.
3. Pass the `Authorization` header through to PHP. Nginx with `fastcgi_params` does this by default. Apache needs Laravel's stock `.htaccess` rule for `HTTP_AUTHORIZATION`.
4. Do not cache `/api/*` responses at the proxy or CDN.

## 6. Acceptance checks

Run these against the target host after deploying. Every response must be JSON (`Content-Type: application/json`), never an HTML page.

| # | Request | Expected |
|---|---|---|
| 1 | `GET /up` | 200 |
| 2 | `GET /api/v1/auth/registration-options` | 200, JSON with `data.companies` and `data.departments` |
| 3 | `POST /api/v1/auth/login` with a wrong password (`email`, `password`, `device_name`) | 401, JSON `{"message": "The email or password is incorrect."}` |
| 4 | `GET /api/v1/auth/me` without a token | 401, JSON |
| 5 | `POST /api/v1/auth/login` with a real approved account | 200, JSON with `token` and `user` |
| 6 | `GET /api/v1/dashboard` with `Authorization: Bearer <token>` | 200, JSON `data.today_meetings` etc. |
| 7 | `GET /api/v1/meetings` with the token | 200, paginated JSON with `meta.total` |
| 8 | Same login request 7 times within a minute (production) | The 7th returns 429 |
| 9 | `POST /api/v1/auth/logout` with the token, then repeat check 6 | 200, then 401 |

Example for check 3:

```bash
curl -s -i -X POST https://schedio.live/api/v1/auth/login -H "Accept: application/json" -d "email=nobody@example.com&password=wrong&device_name=check"
```

When checks 1 to 9 pass on staging, the mobile team will run the device test sheet in `docs/MOBILE_RELEASE_CHECKLIST.md` against staging. After that, production can follow.

## 7. Optional improvements requested by the mobile team

These are not required for the first release.

1. **Push notifications:** authenticated `POST /api/v1/devices` (`token`, `platform`) and `DELETE /api/v1/devices/{token}`, plus sending through FCM and APNs. Today the app raises local notifications when it refreshes.
2. **Unread count:** `GET /api/v1/notifications/unread-count` returning `{"data": {"count": n}}`, so the 30-second badge refresh doesn't need the full dashboard payload.
3. **Empty objects as `{}`:** some fields, for example `metadata` and notification `categories`, are sent as `[]` when empty, because PHP serializes empty arrays that way. The app now tolerates this, but returning `{}` (for example with `(object) []` or a cast) would make the contract cleaner.
