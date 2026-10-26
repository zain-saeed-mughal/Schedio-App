# Schedio Mobile: Known Issues and Limitations (r7, 2026-10-24)

No known release-blocking defects remain in the Android app or in the API features it uses. The earlier blockers (meeting reschedule, cancel and delete errors; missing task edit and delete) were fixed by API v2.1 and verified on production on 2026-10-24.

## Not verified yet

| # | Item | Why | Next step |
|---|---|---|---|
| K-11 | Website ↔ mobile sync | No website tester or website access | Run the 13-step plan in `HANDOVER_CHECKLIST.md` |
| K-12 | Notification read/unread, mark all read | The account has no database notifications | Create a real notification for the test account (with another sandbox user's agreement), then test in the inbox |
| K-13 | Approve / reject registration requests | Needs an authorized test applicant | Agree a test applicant and recipients |
| K-14 | Logout and registration on production | Would end the live session / notify admins | Test with a spare account |
| K-15 | Meeting RSVP | No meeting from another organiser | Invite the test account from another sandbox user |
| K-16 | Form screens driven by taps on a real phone | adb taps are blocked on the test phone | Manual pass by a tester, or a second phone |
| K-17 | Other Android brands and versions | One phone tested (Xiaomi, Android 16) | Samsung or Pixel, and an Android 8–11 phone |
| K-22 | Closed-app and locked-screen push on r7 specifically | Verified manually on r3; push code unchanged since | Optional quick recheck with the backend test push |

## Backend, not blocking

| # | Issue | Impact | Owner |
|---|---|---|---|
| K-7 | Dashboard unread metric can disagree with the inbox | Handled in the app; the website may still show the wrong number | Laravel |
| K-8 | Push text shows times in UTC | A reminder for 7:09 PM says 2:09 PM | Laravel |
| K-9 | Server ignores time offsets | Handled by the app; other clients must send local wall-clock time | Laravel (fix or document) |
| K-10 | Test-push reply exposes part of the device token | Minor exposure on an admin/test endpoint | Laravel |
| K-23 | Tasks, clients and events do not send `can_manage` | The app infers permissions from role and ownership; the server still enforces them, so a mismatch only shows a "not allowed" message | Laravel (optional) |
| K-24 | No inbox notification for the organiser's own meeting changes or for bookings | Confirm this is intended | Laravel |

## Platform limitations

| # | Item |
|---|---|
| K-18 | iOS is not built: needs the Firebase iOS app config, an APNs key, an Apple developer account and a Mac |
| K-19 | Closed-app notifications on Xiaomi/Oppo/Vivo need Autostart and unrestricted battery for Schedio |
| K-20 | Firebase plugin warns about Flutter's upcoming built-in Kotlin change; no effect today; update `firebase_core` when a compatible version ships |
| K-21 | Play App Signing: add Google's signing fingerprints to Firebase after the first Play upload |

## Test data

[TEST] meeting 11 and two completed [TEST] tasks remain in sandbox company 1 (test account only). Delete them once cleanup is approved.

## Added 2026-10-26 (r8 phone QA)

| # | Item | Status |
|---|---|---|
| K-25 | Meeting reminder pushes are not sent by the server (a 15-minute reminder never arrived) | Backend, high |
| ~~K-26~~ | **Resolved 2026-10-27:** `GET meetings/11` now returns HTTP 200 (verified read-only on the phone). The response now embeds `notes` as a list, which r9 cannot read; see K-33 | Closed |
| K-27 | Closed-app push only partly verified: a fully closed app cannot trigger its own test push | Confirm with `php artisan firebase:test-push` while the app is closed |
| K-28 | Inbox read/unread and mark all read still untested: no database notification exists for the test account | Needs a real notification |
| Fixed | Try again stayed on the error after reconnecting (fixed in r8 and verified on the phone) | Done |

## Added 2026-10-26 (sync tests)

| # | Item | Status |
|---|---|---|
| K-29 | Website saves entered meeting times as Asia/Karachi whatever timezone is chosen ("10:00 UTC" stored as 10:00 +05:00); the app shows the stored moment in the account's timezone | Backend/website |
| K-30 | Website "+ Add Action Item" created a duplicate task (IDs 16 and 17) from one entry | Website |
| K-31 | Website has no standalone task page (tasks are created only as meeting action items) | Web UI, by design or gap |
| K-32 | Meeting "metadata.is_client_meeting" true with no linked client (meeting 28) | Backend/website |
| Fixed (r9) | App meeting detail now lists action items; meeting Agenda no longer shows the title | Done |

## Added 2026-10-27 (Calendar Hub and My Meetings)

| # | Issue | Owner |
|---|---|---|
| K-33 | **r9 shows "could not read" on every meeting detail.** Production `GET meetings/{id}` now embeds `notes` as a list of note objects; r9 expects text. Fixed in the working tree (not yet in a release build); see CALENDAR_MEETINGS_FIX_REPORT.md | App, fixed (needs next build) |
| K-34 | Calendar Hub: "today" followed the phone clock instead of the account timezone; week swipes could jump months after Next/Today; DST days drew events an hour off; the calendar stopped at 1 Jan 2100. Fixed in the working tree | App, fixed (needs next build) |
