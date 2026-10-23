# Schedio Mobile: Final Handover Checklist (r7, 2026-10-24)

## Done (mobile team)

- [x] Three reported bugs fixed (pipeline crash, settings push status/save, booking slots)
- [x] All screens audited and toured on the phone against production
- [x] API v2.1 independently verified on production: 60/60 routes; meeting reschedule, cancel and delete; task edit and delete; empty-note 422; room pagination; reminders follow meeting changes; backend cleanup removed nothing unrelated
- [x] Full live CRUD on the phone: 77/77 (run 1) and 17/17 after a fresh restart (run 2)
- [x] Task status, edit and delete available in the app; client and event edit/delete available when the server omits `can_manage`
- [x] Company isolation and role permissions verified
- [x] Timezone fix for every time sent to the server
- [x] Push: registration, retry, foreground, background, closed app, locked screen, tap routing; badge matches inbox; preferences persist
- [x] 163 automated tests, analyzer clean; method-aware API contract checker
- [x] Signed r7 APK and AAB with checksums (`RELEASE_MANIFEST.md`), installed and checked on the phone
- [x] Handover documents updated in `docs/handover/`

## Needs approval from you

- [ ] Commit and push the working tree to GitHub (nothing is committed yet; backup in `.local-backups/20261023-2326`)
- [ ] Upload the r7 AAB to Google Play (internal track first)
- [ ] Delete the remaining [TEST] meeting 11 and two completed [TEST] tasks in the sandbox
- [ ] Rotate the test account passwords that were shared in documents

## Needs the backend team (not blocking)

- [ ] Push text times in the recipient's timezone (B-8)
- [ ] Dashboard unread metric consistent with the inbox (B-7)
- [ ] Remove partial tokens from the test-push reply (B-9)
- [ ] Honour or document time offsets (B-10); optionally send `can_manage` on all records (B-12)
- [ ] Confirm whether organiser changes and bookings should create inbox notifications (N-1)

## Needs a tester

- [ ] Website ↔ mobile sync (plan below)
- [ ] Notification read/unread and mark all read with a real notification
- [ ] Approve/reject with an agreed test applicant
- [ ] A second Android phone (Samsung or Pixel) and an older Android version
- [ ] Optional: repeat closed-app and locked-screen push on r7

## Website ↔ mobile sync plan (sandbox company "Schedio HQ" only)

Use the same sandbox account on the website and on the phone. Title everything "[TEST] Sync ...". After each step, pull down to refresh in the app or reload the website.

| # | Do this | Where | Then check | Where |
|---|---|---|---|---|
| 1 | Create client "[TEST] Sync Client" in the first stage | Website | Appears in Pipeline board and spreadsheet | App |
| 2 | Move it to the next stage | App | New stage shown | Website |
| 3 | Edit its contact name | Website | New name in client detail | App |
| 4 | Create task "[TEST] Sync Task" assigned to yourself, due tomorrow | Website | In My Tasks with the same due date and time | App |
| 5 | Mark the task in progress, then completed | App | Status updated | Website |
| 6 | Schedule meeting "[TEST] Sync Meeting" tomorrow 3:00 PM | App | Same date and 3:00 PM | Website calendar |
| 7 | Schedule meeting "[TEST] Sync Web Meeting" tomorrow 4:00 PM | Website | Same date and 4:00 PM in Meetings and Calendar | App |
| 8 | Add a note to the app meeting | App | Note visible | Website |
| 9 | Create event "[TEST] Sync Event" | Website | In Events and the calendar | App |
| 10 | Create room "[TEST] Sync Room" with 2 amenities | App | Room and amenities | Website |
| 11 | Book a slot on the public booking page | Website (logged out) | Meeting appears at that time | App |
| 12 | Change an email preference | App | Same preference | Website settings |
| 13 | Edit the task title and due date, then delete the task | App | Edited, then gone | Website |
| 14 | Reschedule "[TEST] Sync Web Meeting" to 5:00 PM, then cancel it | App | 5:00 PM, then cancelled | Website |
| 15 | Delete "[TEST] Sync Meeting" | Website | Gone from Meetings and Calendar | App |
| 16 | Clean up: delete client, room, event and any remaining sync meeting | Either | Gone on both | Both |

Record each row as PASS or FAIL with a screenshot. Meeting edit, cancel and delete work since API v2.1 (verified 2026-10-24).
