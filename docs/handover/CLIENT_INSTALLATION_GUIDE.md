# Schedio for Android: Installation and Use

## Supported devices

- Android 7.0 (API 24) or newer. Tested on a Xiaomi phone running Android 16 (HyperOS).
- Google Play services must be installed and up to date. Push notifications depend on it.
- An internet connection. Schedio works with the live service at `https://schedio.live`.
- iPhone is not available yet (see Known Issues).

## Install

### Option A: Google Play (recommended for staff)

Upload the `.aab` file from the release manifest to Google Play Console, as an internal test track first, then production. Staff install Schedio from Play like any other app, and updates arrive automatically.

### Option B: direct install (testing)

1. Copy the `.apk` file from the release manifest to the phone.
2. Open it and allow "Install unknown apps" for the file manager or browser when Android asks.
3. Tap **Install**.
4. On some phones (Xiaomi, Oppo, Vivo) an extra "Install via USB" or security prompt appears; confirm it.

If an older Schedio build signed with a different key is installed, Android refuses the update. Uninstall the old app first, then sign in again.

## Sign in

1. Open Schedio and sign in with your Schedio work email and password (the same as the website).
2. New staff can use **Request Staff Access**. An administrator must approve the request in the Registration Queue (on the website or in the app) before the account can sign in.
3. Your session stays signed in until you sign out or an administrator deactivates the account.

## Notifications

1. On first sign-in Android asks to allow notifications: tap **Allow**.
2. Check **Settings → Channels**. It should read "Push notifications: On for this device".
   - "Setting up": Schedio is still connecting to Google Play services and keeps trying by itself.
   - "Off": notifications are blocked. Open Android Settings → Apps → Schedio → Notifications, allow them, then reopen Schedio.
3. Reminders and updates then arrive when Schedio is open, in the background, closed, or when the screen is locked. Tapping a notification opens Schedio at the related item or the inbox.
4. On Xiaomi and similar phones, also allow **Autostart** and set **Battery saver → No restrictions** for Schedio, otherwise the system may delay notifications when the app is closed.

Notification preferences (in-app and email, per category) are in **Settings** and are saved to your account.

## Using the app

- **Home**: today's meetings, upcoming items, pending tasks and quick actions.
- **Calendar**: month, week, day and agenda views of meetings and company events.
- **Meetings**: schedule, edit, reschedule, cancel, delete, RSVP and keep meeting notes.
- **Tasks** (My Tasks): create, assign, set a due date, change status, edit and delete. Edit and delete appear for administrators, the task creator and the assignee.
- **Pipeline**: clients as a board or spreadsheet; move clients between deal stages.
- **Quick actions** (centre button): schedule a meeting, reminders and alerts, my tasks, meeting suites (rooms), events and holidays, check availability, my booking page, registration queue (administrators) and settings.
- **Public booking link**: share it from your profile so others can book time with you.

Times are shown in the timezone set on your Schedio account (Profile). Change it on the website if it is wrong.

## Signing out

Profile → **Sign out**. This also stops push notifications to that phone.

## Support checklist

| Problem | What to do |
|---|---|
| "Could not connect" | Check the internet connection, then pull down to refresh |
| "Your session has ended" | Sign in again |
| No notifications | Check Settings shows "On for this device", Android notification permission, Autostart and battery settings |
| Wrong times | Check the timezone on your Schedio profile |
| "The Schedio server had a problem" | A server-side error; try again later and report the time and action to the Schedio administrator |
