# Feature parity and verification

This is an implemented source delivery with automated test/build evidence, live local web/API round trips and an Android API 36 emulator integration test. It is **not yet production acceptance**: remote HTTPS staging, physical-device checks, full native workflow acceptance and signed store releases remain outstanding.

| Feature | Flutter and API implementation | Verification / boundary |
|---|---|---|
| Login and sessions | Sanctum token, secure storage, restore, expiry handling, logout/revocation | API/provider tests; all three staging identities logged in/out through native emulator UI |
| Registration | Employee/company registration, company/department selection, pending/rejected/inactive views | API registration/account-state tests; no production enrollment |
| Dashboard | Real counts, upcoming meetings, quick actions, refresh | Scoped API, no fabricated statistics |
| Meetings | Search/status list, details, create/edit/cancel/delete, participants, RSVP, room/client selection, timezone | API workflow/conflict/ownership tests; editor widget test; native editing against PostgreSQL passed |
| Shared scheduling | Company-row transaction lock and conflict revalidation for existing browser and API meeting writers | Existing web suite passes; sequential browser/mobile conflict test and real PostgreSQL concurrent API booking through two local servers passed |
| Recurrence | Existing recurrence preference metadata on creation | Explicitly does not create repeated instances; source web app does not implement expansion |
| Calendar | Month/week/day/agenda, item detail, create/edit/delete through resource workflows | Standard/fractional-density widget regressions and native PostgreSQL switching through all four modes passed; API visibility test. Native forms replace drag-and-drop |
| Availability | Participants, room, date/time/duration, redacted results and suggested alternatives | Account-timezone suggestion test; server revalidates on save |
| CRM | Client creation/edit/delete, stages, contact/deal/progress fields, search/filter, scheduling, meeting history | API workflow/ownership tests; editor widget test; native PostgreSQL client creation/editing passed |
| Rooms | Listing/detail, admin create/edit/delete; room selection and availability | Role test; existing room tests; editor widget test |
| Events | List/detail/create/edit/delete, category, department/company scope, calendar | API visibility/ownership tests; editor widget test |
| Tasks | List/detail/create/status/priority/assignee/deadline, related meeting | API tests; native UI creation and web-to-mobile status refresh passed. No unsupported standalone edit/delete |
| Notes | Agenda/discussion/decisions/action items, follow-up, attachment text, author/organizer edit/delete; fresh detail after edit | API authorization tests, editor widget test, real PostgreSQL note/participant/tenant checks and native creation/edit/refetch passed |
| Notifications | Inbox, read/unread/delete/all-read, preferences, meeting navigation; account preferences refreshed after save | Owner-isolation and operation tests; real PostgreSQL queued invitation delivery and read/unread persistence passed |
| Local device alerts | Explicit opt-in; generic alerts for newly received inbox activity on dashboard refresh | Source/native build verification only; permission/delivery requires a device. No independent reminder scheduler |
| Push | Not configured | Firebase project/configuration absent. Background push is not claimed |
| Public booking | Host profile, duration/date/slots, guest submission, confirmation, copy/share host link, signed calendar export | API duplicate-slot and signed-export tests |
| Administration | Admin-scoped listing, approval and rejection with reason | Role/tenant/anti-escalation tests |
| Profile/settings | Existing identity/company/department/role/timezone display, appearance, notification preferences, logout | Native saved notification preferences survive reopening Settings; read-only profile fields remain read-only |
| Synchronization | Same Laravel tables; refetch after mutations, pull-to-refresh and resume | Live PostgreSQL web/API meeting/client/task checks passed; prior native task web-edit/refresh passed. Remote staging and broader device acceptance remain |
| Android/iOS | Generated native projects, original logo icons, bundled font, HTTPS config, signing instructions | Debug build and Android 16/API 36 emulator test passed; no iOS compilation on Windows |

## Deliberate differences and outstanding refinement

- Calendar day/week views use native date navigation and agenda lists, not FullCalendar's desktop time grid. Editing a meeting reschedules it through the same validated API; drag-and-drop is not implemented.
- The CRM is a filterable mobile list with stage updates rather than a desktop spreadsheet/drag-and-drop Kanban.
- The meeting form links existing clients. The web's inline “save external guest as new client” convenience is not exposed; mobile users create a client first and then schedule/link its meeting. External-client metadata is supported by the API and preserved when editing an existing meeting.
- Admin decisions retain the applicant's existing role by default. Role/title/department reassignment fields exist in the guarded backend contract but are not exposed as a full user-management editor.
- Notification device alerts are refresh-triggered local presentation. They do not deliver when the application is closed; that requires push setup.
- Visual QA includes the rendered sign-in screen and phone-width editor tests. Complete device accessibility, landscape/tablet and platform sharing/Keychain tests remain.
- No universal/app-link association is deployed. Existing public browser booking URLs remain usable.
- PostgreSQL contention was verified with two independent local Laravel servers making simultaneous API bookings. Remote multi-worker browser/mobile load testing remains a deployment acceptance check.

## Automated evidence

`backend-regression.txt/xml`, `flutter-analysis.txt`, `flutter-tests.txt`, `local-staging-http.txt` and `android-staging-integration.txt` record local runs. Fixtures are confined to automated test databases and the isolated local staging database. The normal app does not ship mock data or test credentials.

The source is ready for staging integration and further acceptance work; do not label it a fully verified production release solely because the screens render or the APK builds.
