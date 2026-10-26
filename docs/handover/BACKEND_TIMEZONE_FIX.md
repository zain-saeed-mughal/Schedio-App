# Schedio Timezone Fix (Laravel) and Mobile Coordination

Prepared 2026-10-27 from read-only inspection of the deployed backend commit `04b0e99` (public repository `hammad5001/Schedio`) and sanitized production evidence. No production code or data was changed.

## 1. Symptom

Times submitted to the API or the website lose their timezone. Whatever offset is sent, the wall-clock part is stored as **Asia/Karachi** time.

| Sent | Stored and returned | Evidence |
|---|---|---|
| `2026-12-20T10:00:00.000Z` (event, API) | `2026-12-20T10:00:00+05:00` | Event time test, 2026-10-23 |
| `2026-12-20T10:00:00+05:00` (event, API) | `2026-12-20T10:00:00+05:00` | Same test |
| `2026-12-20 10:00:00` (event, API) | `2026-12-20T10:00:00+05:00` | Same test |
| Website: 10:00, timezone "UTC Universal" (meeting 28) | `2026-10-27T10:00:00+05:00`, while the meeting record says `timezone: UTC` | Sync test 04b, 2026-10-26 |
| `created_at` on the same records | `…+00:00` (UTC) | Event and task responses |

## 2. Root cause

| Fact | Where |
|---|---|
| App timezone is `UTC` | `config/app.php` line 68 |
| Database is PostgreSQL | `.env.example`: `DB_CONNECTION=pgsql` |
| Start, end and due columns are `timestamp with time zone` | Migrations `create_meetings_table` (`dateTimeTz('start_time')`, `dateTimeTz('end_time')`), `create_events_table` (same), `create_tasks_table` (`dateTimeTz('due_date')`); `created_at`/`updated_at` are plain `timestamps()` |
| The pgsql connection sets no `timezone` | `config/database.php`, so the database's own default session timezone applies (evidently Asia/Karachi on production) |
| Controllers parse correctly, then hand Carbon objects to `datetime` casts | `Api/v1/MeetingController` lines 142–143 and 275–276; `Api/v1/EventController` 133–134 and 192–193; `Api/v1/TaskController` 114 and 188; `Api/v1/PublicBookingController` 146; web `MeetingController` 134–135 and 331–332 |

How it goes wrong:

1. `Carbon::parse('2026-10-29T10:00:00+00:00')` keeps the offset. Parsing is correct.
2. Eloquent's `datetime` cast writes the attribute with the connection's date format, `Y-m-d H:i:s`, in the Carbon object's own timezone. The offset is dropped: `2026-10-29 10:00:00`.
3. PostgreSQL receives a `timestamptz` value without an offset and interprets it in the session timezone (Asia/Karachi): stored as 10:00+05.
4. On read, PostgreSQL returns `2026-10-29 10:00:00+05`, so `toIso8601String()` gives `+05:00`. That is why `start_time` shows +05:00 while `created_at` (plain timestamp, written in UTC) shows +00:00.
5. The website's `<input type="datetime-local">` sends no offset at all, and `Carbon::parse($validated['start_time'])` ignores the selected `timezone`. Every web time is therefore Karachi wall-clock, whatever timezone is chosen.

Likely side effect, not yet verified: comparisons between Laravel-generated UTC values (`now()`) and these columns are also interpreted in the session timezone, shifting them by 5 hours. This may explain why reminder pushes were not sent at the due time (mobile QA K-25). Please check `ReminderEngineService` after the fix.

## 3. Recommended backend fix

Apply A, B and C together in one deployment.

**A. Fix the database session timezone** (`config/database.php`, pgsql connection):

```php
'pgsql' => [
    // ...
    'timezone' => env('DB_TIMEZONE', 'UTC'),
],
```

Laravel's PostgreSQL connector then runs `set time zone 'UTC'` on every connection. Existing `timestamptz` values are unaffected (they are instants); only the offset shown in responses changes from +05:00 to +00:00.

**B. Store exact instants from the API.** Normalise every incoming date-time to UTC before saving:

```php
$startTime = Carbon::parse($validated['start_time'])->utc();
$endTime   = Carbon::parse($validated['end_time'])->utc();
```

Apply this in `Api/v1/MeetingController` (store, update), `Api/v1/EventController` (store, update), `Api/v1/TaskController` (`due_date` in store, update), `Api/v1/MeetingNoteController` (`follow_up_date`), `Api/v1/PublicBookingController` (`start_time`) and the availability check/suggestions parsing.

A reusable cast does the same in one place:

```php
// app/Casts/UtcDateTime.php
class UtcDateTime implements CastsAttributes
{
    public function get($model, string $key, $value, array $attributes) {
        return $value === null ? null : Carbon::parse($value)->utc();
    }
    public function set($model, string $key, $value, array $attributes) {
        return $value === null ? null : Carbon::parse($value)->utc()->format('Y-m-d H:i:sP');
    }
}
// Meeting::casts(): 'start_time' => UtcDateTime::class, 'end_time' => UtcDateTime::class (same for Event, Task due_date)
```

**C. Website forms: read entered times in the chosen timezone.** In the web `MeetingController` (and event/task forms):

```php
$startTime = Carbon::parse($validated['start_time'], $validated['timezone'])->utc();
$endTime   = Carbon::parse($validated['end_time'], $validated['timezone'])->utc();
```

When showing them, convert back with `->setTimezone($meeting->timezone)` (or the user's timezone).

Optional: reject API date-times without an offset (`date_format:Y-m-d\TH:i:sP`) so ambiguous values cannot be stored.

## 4. Verifying after deployment (sandbox only)

1. `php artisan tinker --execute="dump(DB::select('show timezone'))"` returns UTC.
2. API: create a [TEST] event with `start_time` `2026-11-02T10:00:00+00:00`; `GET` returns `2026-11-02T10:00:00+00:00`.
3. API: `2026-11-02T15:00:00+05:00` returns `2026-11-02T10:00:00+00:00` (same moment).
4. Website: create a [TEST] meeting at 10:00 with timezone "UTC Universal"; the API returns `…T10:00:00+00:00`. With "Asia/Karachi", it returns `…T05:00:00+00:00`.
5. Old meetings keep their moment; only the displayed offset changes.
6. A [TEST] meeting with a 15-minute reminder triggers the reminder push at the right time.

## 5. Mobile app coordination

The app chooses times in the account's timezone and shows them in the account's timezone, for any timezone. Every time it sends goes through one encoder, `lib/core/api_time.dart` (`encodeApiTime`):

| Build setting | What is sent | Correct on today's backend | Correct after A + B + C |
|---|---|---|---|
| `--dart-define=API_WALL_CLOCK_ZONE=Asia/Karachi` (temporary) | Wall-clock time in Asia/Karachi with its offset, e.g. `2026-10-29T15:00:00+05:00` | Yes | Yes. It is an exact instant, so it cannot be converted twice |
| No define (default) | UTC instant, e.g. `2026-10-29T10:00:00+00:00` | No (shifted by the session timezone) | Yes |

- **Until A + B + C are live:** production mobile builds must use `API_WALL_CLOCK_ZONE=Asia/Karachi`, the database's current session timezone.
- **After deployment:** build without the define. A build that still has it keeps working, because B honours the offset.
- **Unsafe order:** do not deploy A without B. Once the session timezone is UTC but offsets are still dropped, any client sending +05:00 wall-clock would be off by 5 hours.

Regression tests (`test/timezone_encoding_test.dart`) cover account timezones UTC, Asia/Karachi, America/New_York, America/Los_Angeles, Europe/London and Asia/Kolkata. They also cover daylight-saving changes, and check each case against both a server that drops offsets and one that honours them.
