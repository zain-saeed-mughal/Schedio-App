<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\{AuditLog, Meeting, MeetingParticipant, User};
use App\Services\{ConflictDetectionService, ReminderEngineService};
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class BookingController extends Controller
{
    private function host(string $username): User
    {
        $host = User::withoutGlobalScopes()->whereNull('deleted_at')
            ->where('is_active', true)->approved()
            ->where(fn ($q) => $q->where('username', $username)
                ->when(ctype_digit($username), fn ($q) => $q->orWhere('id', (int) $username)))
            ->firstOrFail();
        abort_unless($host->canLogin(), 404);
        return $host;
    }

    public function show(string $username)
    {
        $host = $this->host($username);
        return response()->json(['data' => [
            'name' => $host->name, 'headline' => $host->booking_headline, 'bio' => $host->booking_bio,
            'timezone' => $host->timezone ?: 'UTC', 'durations' => $host->getBookingDurations(),
        ]]);
    }

    public function slots(Request $request, string $username)
    {
        $host = $this->host($username);
        $request->validate(['date' => 'required|date_format:Y-m-d',
            'duration' => ['required', 'integer', Rule::in($host->getBookingDurations())]]);
        return response()->json(['data' => $this->available($host, $request->date, $request->integer('duration'))]);
    }

    private function available(User $host, string $date, int $duration): array
    {
        $cursor = Carbon::parse($date, $host->timezone ?: 'UTC')->setTime(9, 0);
        $end = $cursor->copy()->setTime(18, 0);
        $slots = [];
        while ($cursor->copy()->addMinutes($duration)->lte($end)) {
            $finish = $cursor->copy()->addMinutes($duration);
            $check = app(ConflictDetectionService::class)->checkAvailability(
                $cursor->copy()->utc(), $finish->copy()->utc(), null, [$host->id]);
            if ($cursor->isFuture() && ! $check['has_conflicts']) {
                $slots[] = ['start_time' => $cursor->toIso8601String(), 'end_time' => $finish->toIso8601String()];
            }
            $cursor->addMinutes(min(30, $duration));
        }
        return $slots;
    }

    public function store(Request $request, string $username)
    {
        $host = $this->host($username);
        $data = $request->validate([
            'client_name' => 'required|string|max:150', 'client_email' => 'required|email|max:150',
            'client_company' => 'nullable|string|max:150', 'notes' => 'nullable|string|max:1000',
            'start_time' => ['required', 'date', 'regex:/(Z|[+-]\d{2}:\d{2})$/'],
            'duration_minutes' => ['required', 'integer', Rule::in($host->getBookingDurations())],
        ]);
        $meeting = DB::transaction(function () use ($host, $data) {
            User::withoutGlobalScopes()->whereKey($host->id)->lockForUpdate()->firstOrFail();
            $start = Carbon::parse($data['start_time'])->setTimezone($host->timezone ?: 'UTC');
            $slots = $this->available($host, $start->toDateString(), (int) $data['duration_minutes']);
            if (! collect($slots)->contains(fn ($s) => Carbon::parse($s['start_time'])->equalTo($start))) {
                throw ValidationException::withMessages(['start_time' => 'This slot is unavailable. Choose another time.']);
            }
            $meeting = Meeting::create([
                'company_id' => $host->company_id, 'organizer_id' => $host->id,
                'department_id' => $host->department_id,
                'title' => "Consultation: {$data['client_name']} & {$host->name}",
                'description' => $data['notes'] ?? null,
                'start_time' => $start->copy()->utc(), 'end_time' => $start->copy()->addMinutes($data['duration_minutes'])->utc(),
                'timezone' => $host->timezone ?: 'UTC', 'status' => 'scheduled', 'type' => 'virtual',
                'meeting_link' => $host->default_meeting_link, 'is_private' => false,
                'metadata' => ['is_client_meeting' => true, 'client_name' => $data['client_name'],
                    'client_email' => $data['client_email'], 'client_company' => $data['client_company'] ?? null,
                    'booked_via' => 'public_portal', 'duration_minutes' => $data['duration_minutes']],
            ]);
            MeetingParticipant::create(['meeting_id' => $meeting->id, 'user_id' => $host->id,
                'role' => 'host', 'status' => 'accepted', 'responded_at' => now()]);
            app(ReminderEngineService::class)->scheduleMeetingReminders($meeting, 15);
            if (in_array('database', $host->getNotificationChannelsFor('meeting_invitations'), true)) {
                $host->notifications()->create([
                    'id' => (string) \Illuminate\Support\Str::uuid(),
                    'type' => 'App\\Notifications\\NewBookingNotification',
                    'data' => ['title' => 'New client appointment',
                        'message' => "{$data['client_name']} booked a meeting.",
                        'meeting_id' => $meeting->id, 'category' => 'meeting_invitations'],
                ]);
            }
            AuditLog::create(['user_id' => $host->id, 'action' => 'meeting_created',
                'auditable_type' => Meeting::class, 'auditable_id' => $meeting->id,
                'description' => 'Public mobile booking confirmed.']);
            return $meeting;
        }, 3);
        return response()->json(['data' => [
            ...$meeting->only(['title', 'start_time', 'end_time', 'timezone', 'meeting_link']),
            'calendar_export_url' => \Illuminate\Support\Facades\URL::temporarySignedRoute(
                'api.booking.ical', now()->addHour(), ['meeting' => $meeting->id]),
        ],
            'message' => 'Your booking is confirmed.'], 201);
    }

    public function export(Meeting $meeting)
    {
        $escape = fn ($s) => str_replace(["\\", "\r", "\n", ";", ","], ["\\\\", "", "\\n", "\\;", "\\,"], (string) $s);
        $lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Schedio//Mobile Booking//EN',
            'BEGIN:VEVENT', 'UID:schedio-'.$meeting->id.'@schedio.live',
            'DTSTAMP:'.now()->utc()->format('Ymd\THis\Z'),
            'DTSTART:'.$meeting->start_time->utc()->format('Ymd\THis\Z'),
            'DTEND:'.$meeting->end_time->utc()->format('Ymd\THis\Z'),
            'SUMMARY:'.$escape($meeting->title), 'LOCATION:'.$escape($meeting->meeting_link),
            'END:VEVENT', 'END:VCALENDAR', ''];
        return response(implode("\r\n", $lines), 200, [
            'Content-Type' => 'text/calendar; charset=utf-8',
            'Content-Disposition' => 'attachment; filename="schedio-booking.ics"',
        ]);
    }
}
