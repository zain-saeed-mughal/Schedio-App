# Schedio mobile integration audit

Source: supplied `Schedio-main.zip`, extracted into `Schedio-main/`. The supplied prompt is a requirements reference; the Laravel source determines existing behavior.

## Existing modules and mobile mapping

| Module | Verified implementation | Mobile screens / API work |
|---|---|---|
| Authentication | Session login, employee/company registration, pending approval, active-company check | Login, registration, account status; Sanctum bearer tokens |
| Dashboard | Visible meetings, tasks, events, reminders, audit activity | Home with server-derived counts and upcoming schedule |
| Meetings | CRUD, cancellation, RSVP, host/attendee pivot, client metadata, reminders | Lists, filters, detail, editor, RSVP |
| Calendar | Meeting/event feed; create, time update, delete | Month/week/day/agenda and native editors |
| Availability | Room/participant overlap, event busy state, 09:00–18:00 suggestions | Server-authoritative availability form |
| CRM | Assigned/created deals, search, campaign filter, six stages, meeting scheduling | Pipeline, client details/editor, scheduling |
| Rooms | Company rooms, capacity, amenities, availability; admin writes | Room list/detail/editor |
| Events | Personal, department and company events; owner/admin writes | Event list/detail/editor |
| Tasks | Creation, status changes, optional meeting, assignee and due date | Task list/detail/create/status |
| Notes | Agenda, discussion, decisions, action items, follow-up and linked attachments | Meeting workspace and note editor |
| Notifications | Database inbox, read/unread/delete, preferences | Inbox and preferences |
| Public booking | Host profile, working-day slots, guest booking, confirmation, ICS | Booking profile/link, slots and booking form |
| Administration | Developer/company-admin approval and rejection | Requests and decisions |
| Profile | User fields exist; no web profile editor route | Profile display; editing requires an additive contract |

## Schema and relationships

The existing migrations are authoritative. No replacement business database is needed.

- Company: name, slug, domain, status, created_by, settings; owns users, departments, rooms, meetings, events, tasks and clients.
- User: name, email, password, title, phone, role, department_id, company_id, approval_status, approved_at/by, rejection_reason, registration_notes, avatar_url, timezone, notification_preferences, is_active, username, booking_headline/bio/durations, default_meeting_link. Soft-deleted.
- Department: company, name, code, description, manager, active flag. Soft-deleted.
- Meeting: company, title, description, organizer, department, room, client, start/end, timezone, status, type, meeting_link, location, privacy, recurrence and metadata. Soft-deleted.
- MeetingParticipant: unique meeting/user pair, status, role, response_notes, responded_at.
- Client: company_name, contact_name/email/phone/role, campaign, progress, status, assigned_to, created_by, deal_value, notes, last_activity_at, tenant. Soft-deleted.
- Room: tenant, name, code, location, capacity, amenities, color, active flag. Soft-deleted.
- Event: tenant, title, description, user, department, category, start/end, all-day, color, location, company-wide flag, recurrence. Soft-deleted.
- Task: tenant, title, description, assignee, creator, department, meeting, status, priority, due_date, completed_at. Soft-deleted.
- MeetingNote: tenant, meeting, author, agenda, discussion, decisions, action_items, follow_up_date, attachments. Soft-deleted.
- Reminder: user, title/message, polymorphic parent, remind_at, channel, status, sent_at, payload.
- AuditLog: user, tenant column, action, polymorphic parent, description, old/new values, IP/user-agent, metadata. Its current fillable list omits company_id.
- Notifications use Laravel's database-notification schema; sessions, jobs, cache and reset tokens are infrastructure tables.

## Exact roles and visibility

`developer`, `super_admin`, `bd_manager`, `bd_rep`, `manager`, `employee`, `client`.
Developer bypasses CompanyScope. Company super-admin has administrative access inside their company. Other users see meetings they organize/participate in and deals they create/own. Manager/BD role helpers do not grant blanket meeting/deal visibility. Room writes require super-admin/developer. Event writes require owner/admin; only admin can create company-wide events. Task status requires creator/assignee/admin. Notes require meeting participation to create; author/organizer/admin to modify.

Approval states are pending/approved/rejected; inactive is a separate boolean. Company states are pending/active/suspended/rejected. Only developer approves company super-admins. Staff approval is company scoped.

## Routes and services

`routes/web.php` defines session authentication, resource routes for meetings/clients/rooms/events, calendar feed/create/time/delete, availability check/suggestions, notification operations, task creation/status, meeting-note operations, admin requests/approve/reject, and `/book/{username}` profile/slots/store/confirmed/export-ical.

There is no `routes/api.php`, no Sanctum dependency, no mobile bearer-token layer, and no standalone task-list endpoint.

Reuse `ConflictDetectionService`, `NotificationDispatchService`, `ReminderEngineService`, notification classes and `ProcessReminderJob`. Keep the existing scheduler/queue. Recurrence is stored metadata, not expanded into recurring instances.

Client stages: discovery, scheduled, paperwork_onboarding, onboarded, deadend, pause. The backend accepts any of these transitions; MAIN_PIPELINE is presentation guidance, not an enforced transition graph.

## Design and architecture

Existing CSS uses charcoal `#15181D`, amber `#f59e0b` / `#d97706`, rounded translucent cards, Plus Jakarta Sans and JetBrains Mono. Adapt to Material 3 with Home/Calendar/Meetings/Tasks/More navigation.

Separate `schedio_mobile/`: Dart, Riverpod, GoRouter, Dio, secure storage, typed models, feature screens, shared UI and theme. Laravel remains authoritative. UTC transport with explicit timezone labels; no offline mutation queue. Invalidate fetched data after mutations and on resume.

Implementation order: API authentication/security → API business resources/tests → Flutter foundation/auth/home → meetings/calendar → business modules → notifications/booking/admin → regression/build/release verification.

## Risks requiring explicit verification

- Default local PHP is 8.0.30; supplied lock includes dependencies requiring PHP >=8.4.1. Installed Flutter cache reports 3.47.4 / Dart 3.13.3.
- Existing meeting/calendar writes do not call conflict detection. Public booking checks outside its transaction. Cross-channel concurrency needs shared locking in every writer; API-only locking cannot guarantee safety against legacy web writers.
- `exists` validation is often not tenant constrained; API must validate all referenced records explicitly.
- Existing RSVP can create a participant record for an uninvited caller; API must reject this.
- Event department visibility with a null department can expose unrelated events; API must guard null department comparisons.
- Conflict results include private meeting titles. Mobile availability must redact these.
- `busy` event results do not set the service's `has_conflicts`; preserve/document existing semantics rather than silently claiming events block booking.
- Admin approval accepts `super_admin` as a role; mobile must prohibit company-admin privilege escalation.
- Existing public confirmation/export is addressed by sequential meeting ID; do not expose arbitrary private records through new endpoints.
- Existing reminder cancellation uses SQL concatenation syntax that needs production database compatibility testing.
- Production API deployment, actual web/mobile parity, Android signing, and iOS/macOS signing are not verified by source implementation.
- Firebase is not supplied. Push is not complete until configured and exercised.

## Implementation follow-through

The initial audit findings above describe the supplied source, not the final implementation status. The added API enforces scoped references, excludes deleted logins, protects RSVP and notes, rejects admin escalation, redacts availability, checks active companies, uses signed booking calendar exports, and preserves external meeting metadata on edit. A narrow shared scheduling middleware now protects both existing browser meeting writers and mobile writers with company-row locking and final conflict checks. Existing web controllers and UI files remain intact. See FEATURE_PARITY.md and test logs for current evidence and limits.
