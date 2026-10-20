<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Meeting;
use App\Models\MeetingParticipant;
use App\Models\Reminder;
use App\Models\User;
use App\Services\ConflictDetectionService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Notifications\DatabaseNotification;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\View\View;

class PublicBookingController extends Controller
{
    public function __construct(
        protected ConflictDetectionService $conflictService
    ) {}

    /**
     * Resolve the host user by username, ID, or email prefix.
     */
    protected function resolveHost(string $identifier): User
    {
        $query = User::where('is_active', true)
            ->where('approval_status', User::STATUS_APPROVED);

        $host = (clone $query)->where('username', $identifier)->first();

        if (!$host && is_numeric($identifier)) {
            $host = (clone $query)->where('id', (int) $identifier)->first();
        }

        if (!$host) {
            $host = (clone $query)->where('email', 'like', "{$identifier}@%")->first();
        }

        if (!$host) {
            abort(404, 'The requested booking calendar was not found or is currently inactive.');
        }

        return $host;
    }

    /**
     * Show public booking calendar page.
     */
    public function show(string $username): View
    {
        $host = $this->resolveHost($username);
        $durations = $host->getBookingDurations();
        $defaultDuration = $durations[1] ?? ($durations[0] ?? 30);

        // Pre-generate next 14 days for the horizontal date selector
        $dates = [];
        $cursor = Carbon::now($host->timezone ?: 'UTC')->startOfDay();
        for ($i = 0; $i < 14; $i++) {
            $day = $cursor->copy()->addDays($i);
            // Skip weekends by default if desired or include all
            $dates[] = [
                'date_string' => $day->format('Y-m-d'),
                'day_number' => $day->format('j'),
                'day_name' => strtoupper($day->format('D')),
                'month_name' => $day->format('M'),
                'is_weekend' => $day->isWeekend(),
                'is_today' => $i === 0,
            ];
        }

        return view('booking.show', compact('host', 'durations', 'defaultDuration', 'dates'));
    }

    /**
     * Get available live slots for a specific date and duration.
     */
    public function slots(Request $request, string $username): JsonResponse
    {
        $host = $this->resolveHost($username);

        $validated = $request->validate([
            'date' => ['required', 'date_format:Y-m-d'],
            'duration' => ['nullable', 'integer', 'in:15,30,45,60,90'],
        ]);

        $duration = (int) ($validated['duration'] ?? 30);
        $timezone = $host->timezone ?: 'UTC';
        $targetDate = Carbon::parse($validated['date'], $timezone)->startOfDay();

        // Standard working hours: 09:00 to 18:00
        $workStart = $targetDate->copy()->setTime(9, 0, 0);
        $workEnd = $targetDate->copy()->setTime(18, 0, 0);

        $now = Carbon::now($timezone);

        $morningSlots = [];
        $afternoonSlots = [];

        $cursor = $workStart->copy();
        $stepMinutes = min(30, $duration);

        while ($cursor->copy()->addMinutes($duration)->lte($workEnd)) {
            $slotStart = $cursor->copy();
            $slotEnd = $cursor->copy()->addMinutes($duration);

            // Skip if in the past
            if ($slotStart->lte($now)) {
                $cursor->addMinutes($stepMinutes);
                continue;
            }

            // Check host availability
            $check = $this->conflictService->checkAvailability(
                $slotStart,
                $slotEnd,
                null,
                [$host->id]
            );

            if (!$check['has_conflicts']) {
                $slotData = [
                    'start_time' => $slotStart->toIso8601String(),
                    'end_time' => $slotEnd->toIso8601String(),
                    'formatted_time' => $slotStart->format('h:i a'),
                    'time_24' => $slotStart->format('H:i'),
                ];

                if ($slotStart->hour < 12) {
                    $morningSlots[] = $slotData;
                } else {
                    $afternoonSlots[] = $slotData;
                }
            }

            $cursor->addMinutes($stepMinutes);
        }

        return response()->json([
            'date' => $targetDate->format('l, F j, Y'),
            'duration' => $duration,
            'morning' => $morningSlots,
            'afternoon' => $afternoonSlots,
            'total_available' => count($morningSlots) + count($afternoonSlots),
        ]);
    }

    /**
     * Store appointment booked by public guest/client.
     */
    public function store(Request $request, string $username): RedirectResponse
    {
        $host = $this->resolveHost($username);

        $validated = $request->validate([
            'client_name' => ['required', 'string', 'max:150'],
            'client_email' => ['required', 'email', 'max:150'],
            'client_company' => ['nullable', 'string', 'max:150'],
            'start_time' => ['required', 'date'],
            'duration_minutes' => ['required', 'integer', 'in:15,30,45,60,90'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $startTime = Carbon::parse($validated['start_time']);
        $duration = (int) $validated['duration_minutes'];
        $endTime = $startTime->copy()->addMinutes($duration);

        // Anti-double-booking recheck
        $check = $this->conflictService->checkAvailability($startTime, $endTime, null, [$host->id]);
        if ($check['has_conflicts']) {
            return back()->withInput()->withErrors([
                'start_time' => 'Sorry, this time slot was just booked by someone else. Please choose another slot.',
            ]);
        }

        $meeting = DB::transaction(function () use ($validated, $host, $startTime, $endTime, $duration) {
            $meetingLink = $host->default_meeting_link ?: ('https://meet.schedio.com/room-' . strtolower(Str::random(10)));

            $meeting = Meeting::create([
                'title' => "Consultation: {$validated['client_name']} & {$host->name}",
                'description' => $validated['notes'] ?? "Public booking via client scheduling portal.",
                'organizer_id' => $host->id,
                'department_id' => $host->department_id,
                'room_id' => null,
                'start_time' => $startTime,
                'end_time' => $endTime,
                'timezone' => $host->timezone ?: 'UTC',
                'status' => 'scheduled',
                'type' => 'virtual',
                'meeting_link' => $meetingLink,
                'location' => 'Video Conference',
                'is_private' => false,
                'metadata' => [
                    'is_client_meeting' => true,
                    'client_name' => $validated['client_name'],
                    'client_email' => $validated['client_email'],
                    'client_company' => $validated['client_company'] ?? null,
                    'duration_minutes' => $duration,
                    'booked_via' => 'public_portal',
                    'reminder_minutes' => 15,
                ],
            ]);

            // Host participant record
            MeetingParticipant::create([
                'meeting_id' => $meeting->id,
                'user_id' => $host->id,
                'role' => 'host',
                'status' => 'accepted',
                'responded_at' => now(),
            ]);

            // Schedule Reminders for Host using Reminder Engine
            app(\App\Services\ReminderEngineService::class)->scheduleMeetingReminders(
                $meeting,
                15,
                'both'
            );

            // Create notification for host
            DatabaseNotification::create([
                'id' => (string) Str::uuid(),
                'type' => 'App\\Notifications\\NewBookingNotification',
                'notifiable_type' => User::class,
                'notifiable_id' => $host->id,
                'data' => [
                    'title' => 'New Client Appointment Booked!',
                    'message' => "{$validated['client_name']} booked a {$duration}-minute call on {$startTime->format('M d, Y \\a\\t h:i A')}.",
                    'meeting_id' => $meeting->id,
                    'category' => 'meeting_invitations',
                    'color' => 'amber',
                ],
            ]);

            // Audit Trail
            AuditLog::create([
                'user_id' => $host->id,
                'action' => 'meeting_created',
                'auditable_type' => Meeting::class,
                'auditable_id' => $meeting->id,
                'description' => "Meeting '{$meeting->title}' booked by {$validated['client_name']} via public scheduling link.",
                'new_values' => $meeting->toArray(),
            ]);

            return $meeting;
        });

        return redirect()->route('booking.confirmed', [
            'username' => $host->username ?: $host->id,
            'meeting' => $meeting->id,
        ])->with('success', 'Your appointment has been confirmed successfully!');
    }

    /**
     * Show booking confirmed success screen.
     */
    public function confirmed(string $username, Meeting $meeting): View
    {
        $host = $this->resolveHost($username);

        if ($meeting->organizer_id !== $host->id) {
            abort(404);
        }

        // Google Calendar URL generator
        $googleCalUrl = $this->generateGoogleCalendarLink($meeting, $host);

        return view('booking.confirmed', compact('host', 'meeting', 'googleCalUrl'));
    }

    /**
     * Export meeting as .ics file for Apple/Outlook calendar.
     */
    public function exportIcal(string $username, Meeting $meeting): Response
    {
        $host = $this->resolveHost($username);

        if ($meeting->organizer_id !== $host->id) {
            abort(404);
        }

        $dtStart = $meeting->start_time->utc()->format('Ymd\THis\Z');
        $dtEnd = $meeting->end_time->utc()->format('Ymd\THis\Z');
        $dtStamp = now()->utc()->format('Ymd\THis\Z');
        $summary = addcslashes($meeting->title, ",;\\");
        $description = addcslashes($meeting->description . "\nVideo link: " . $meeting->meeting_link, ",;\\");
        $location = addcslashes($meeting->meeting_link ?: 'Online Video Call', ",;\\");

        $ics = "BEGIN:VCALENDAR\r\n" .
               "VERSION:2.0\r\n" .
               "PRODID:-//Schedio//Scheduling Portal//EN\r\n" .
               "CALSCALE:GREGORIAN\r\n" .
               "METHOD:REQUEST\r\n" .
               "BEGIN:VEVENT\r\n" .
               "UID:schedio-" . $meeting->id . "@schedio.com\r\n" .
               "DTSTAMP:{$dtStamp}\r\n" .
               "DTSTART:{$dtStart}\r\n" .
               "DTEND:{$dtEnd}\r\n" .
               "SUMMARY:{$summary}\r\n" .
               "DESCRIPTION:{$description}\r\n" .
               "LOCATION:{$location}\r\n" .
               "STATUS:CONFIRMED\r\n" .
               "END:VEVENT\r\n" .
               "END:VCALENDAR\r\n";

        return response($ics, 200, [
            'Content-Type' => 'text/calendar; charset=utf-8',
            'Content-Disposition' => 'attachment; filename="appointment-' . $meeting->id . '.ics"',
        ]);
    }

    /**
     * Helper to build Google Calendar template link.
     */
    protected function generateGoogleCalendarLink(Meeting $meeting, User $host): string
    {
        $start = $meeting->start_time->utc()->format('Ymd\THis\Z');
        $end = $meeting->end_time->utc()->format('Ymd\THis\Z');

        $params = [
            'action' => 'TEMPLATE',
            'text' => $meeting->title,
            'dates' => "{$start}/{$end}",
            'details' => ($meeting->description ? $meeting->description . "\n\n" : "") .
                         "Video Call: " . ($meeting->meeting_link ?? 'Online Meeting') .
                         "\nHost: " . $host->name . " (" . $host->email . ")",
            'location' => $meeting->meeting_link ?? 'Video Conference',
        ];

        return 'https://calendar.google.com/calendar/render?' . http_build_query($params);
    }
}
