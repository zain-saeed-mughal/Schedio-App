# Mobile API v1

Base URL: `https://<your-staging-host>/api/v1/`. The production deployment has not been performed. All mobile endpoints return JSON. Send `Accept: application/json`, and `Authorization: Bearer <token>` for protected endpoints.

## Authentication

| Method | Path | Body / result |
|---|---|---|
| POST | auth/login | email, password, device_name → token, user |
| GET | auth/me | `{data: account}` |
| POST | auth/logout | Revokes the current token |
| GET | auth/registration-options | Active company and department identifiers/names |
| POST | auth/register | Existing registration fields; registration_type employee/company_super_admin. Employees must select an active company; department must belong to it. Returns pending, never an access token. |

Tokens expire after 30 days. Every protected module request rechecks approval, active user and active company. Logout remains available after approval revocation. The browser's session authentication stays separate.

## Resources

| Method | Path | Notes |
|---|---|---|
| GET | dashboard | Counts and upcoming meetings, scoped to the caller |
| GET | lookups | Approved users, active departments/rooms, accessible clients |
| GET/POST | meetings | Paginated listing / create |
| GET/PUT/DELETE | meetings/{id} | Visible detail / authorized full update / soft delete |
| PATCH | meetings/{id}/cancel | Organizer/admin |
| POST | meetings/{id}/rsvp | Invited participant only; accepted/declined/tentative |
| GET | clients/{id}/meetings | Client's meetings filtered by meeting visibility |
| GET/POST | clients, rooms, events, tasks | Paginated listing / create |
| GET | clients/{id}, rooms/{id}, events/{id}, tasks/{id} | Visible detail |
| PUT/DELETE | clients/{id}, rooms/{id}, events/{id} | Authorized update / delete |
| PATCH | clients/{id}/status, tasks/{id}/status | Exact existing status values |
| GET/POST | meetings/{id}/notes | Paginated notes / create |
| GET | meeting-notes/{id} | Fresh note detail after tenant and meeting visibility checks |
| PUT/DELETE | meeting-notes/{id} | Author/organizer/admin after meeting visibility check |
| GET | calendar/feed | start/end ISO dates, maximum 93-day range |
| POST | availability/check | start_time, end_time, optional room_id, participant_ids, exclude_meeting_id |
| GET | availability/suggestions | date (YYYY-MM-DD), duration_minutes, room_id, participant_ids; returns data of ISO slots in the account timezone |
| GET | notifications | Paginated inbox; status=unread supported |
| PATCH | notifications/{id}/read or unread | Owner scoped |
| DELETE | notifications/{id} | Owner scoped |
| POST | notifications/mark-all-read | Owner scoped |
| POST | notifications/preferences | channel_in_app, channel_email, categories with in_app/email booleans |
| GET | admin/registration-requests | Admin scoped, status defaults pending |
| PATCH | admin/registration-requests/{id}/approve or reject | Existing fields, with additional anti-escalation checks |

Resource lists support `page`, `search`, and applicable `status`. General resource lists allow `per_page` 1–100; meetings/notes/inbox use 25. Resource responses use `data`; paginated API resources include `links` and `meta`. Inbox/admin collections use Laravel paginator's top-level pagination fields. Flutter's repository decodes both shapes. Mutations that reuse web workflows return a success message; clients refetch authoritative records. Meeting saves return the saved resource.

Meeting fields: title, description, start_time/end_time **with UTC offset**, timezone (IANA), type (in_person/virtual/hybrid), meeting_link, location, department_id, room_id, client_id, is_private, participant_ids, reminder_minutes. Optional external-client metadata and recurrence_frequency preserve existing fields. Recurrence does not generate future instances.

Generic resource write validation remains in the existing controllers. The API boundary additionally validates referenced resources through tenant-aware queries. `company_id`, organizer and creator are never accepted as authority from the client.

Calendar creation/edit/deletion uses the same meeting/event resource endpoints. There is no duplicate calendar write implementation to bypass the meeting validator.

## Public booking

GET `public/booking/{username}` returns only public name/headline/bio/timezone/durations. Username or numeric ID is supported.

GET `public/booking/{username}/slots?date=YYYY-MM-DD&duration=30` returns start/end ISO instants.

POST the same profile path with client_name, client_email, optional client_company/notes, start_time with offset, duration_minutes. The server validates offered durations, future working-hour slots and availability again inside a transaction. The response contains only the confirmed booking summary.

API public booking never fabricates a video meeting URL when the host has none configured.

Booking confirmation also returns `calendar_export_url`, a signed one-hour link. GET `public/booking-confirmations/{meeting}/ical` requires that signature; unsigned enumeration is rejected.

## Errors and limits

- 401: invalid credentials, absent/expired/revoked token.
- 403: inactive/unapproved user, suspended company or unauthorized operation.
- 404: nonexistent or inaccessible record.
- 422: validation failure; `errors` maps fields to message arrays.
- 429: rate limit. Global v1 limit is 120/minute; login, registration and booking submission also use 6/minute.
- No automatic mutation retries in Flutter. Network failures must not be presented as successful bookings.

Availability hides conflicting meeting identities and titles. Existing event `busy` semantics remain advisory; only meeting/room collisions set has_conflicts.

## Shared scheduling and concurrency verification

The shared `SerializeScheduling` route middleware wraps existing web meeting creation/update, calendar meeting writes, client scheduling, public booking and API meeting writes in a transaction. It locks the company row (or a host row for a companyless developer) before availability revalidation, including when the calendar is empty. API writes also lock participants and rooms.

This closes the audit's API-only locking gap while leaving the web controllers/views intact. Existing web tests and a cross-channel sequential conflict test pass. SQLite tests do not prove actual PostgreSQL row-lock contention; concurrent staging acceptance is still required.
