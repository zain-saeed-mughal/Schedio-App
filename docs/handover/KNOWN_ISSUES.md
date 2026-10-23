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
