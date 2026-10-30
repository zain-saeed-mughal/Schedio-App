<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\MeetingRequest;
use App\Http\Resources\MobileRecordResource;
use App\Models\{AuditLog, Client, Meeting, Room, User};
use App\Services\{ConflictDetectionService, MobileVisibility, NotificationDispatchService, ReminderEngineService};
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class MeetingController extends Controller
{
    public function __construct(private MobileVisibility $visibility) {}

    public function index(Request $request)
    {
        $request->validate(['search' => 'nullable|string|max:200', 'status' => 'nullable|string|max:30',
            'page' => 'nullable|integer|min:1']);
        $query = $this->visibility->meetings($request->user())->with(['organizer', 'participants']);
        if ($request->filled('search')) { $query->where('title', 'like', '%'.$request->search.'%'); }
        if ($request->filled('status')) { $query->where('status', $request->status); }
        if ($request->input('period') === 'upcoming') { $query->where('start_time', '>=', now()); }
        if ($request->input('period') === 'past') { $query->where('start_time', '<', now()); }
        return MobileRecordResource::collection($query->orderBy('start_time')->paginate(25));
    }

    public function show(Request $request, int $id)
    {
        return new MobileRecordResource($this->visibility->meetings($request->user())
            ->with(['organizer', 'participants', 'department', 'room'])->findOrFail($id));
    }

    public function save(MeetingRequest $request, ?int $id = null)
    {
        $u = $request->user();
        $meeting = $id ? $this->visibility->meetings($u)->findOrFail($id) : null;
        abort_if($meeting && ! $u->isSuperAdmin() && $meeting->organizer_id !== $u->id, 403);
        app(WorkspaceController::class)->references($request);
        $data = $request->validated();
        $organizer = $meeting?->organizer_id ?? $u->id;
        $participants = array_values(array_unique([...($data['participant_ids'] ?? []), $organizer]));
        $meeting = DB::transaction(function () use ($request, $data, $meeting, $u, $organizer, $participants) {
            // Deterministic participant locks serialize competing API bookings.
            User::whereIn('id', $participants)->orderBy('id')->lockForUpdate()->get();
            if (! empty($data['room_id'])) {
                Room::where('is_active', true)->lockForUpdate()->findOrFail($data['room_id']);
            }
            $start = Carbon::parse($data['start_time'])->utc();
            $end = Carbon::parse($data['end_time'])->utc();
            $check = app(ConflictDetectionService::class)->checkAvailability(
                $start, $end, $data['room_id'] ?? null, $participants, $meeting?->id);
            if ($check['has_conflicts']) {
                throw ValidationException::withMessages(['start_time' => 'A room or participant is already booked. Please choose another time.']);
            }
            $old = $meeting?->toArray();
            $oldStart = $meeting?->start_time?->copy();
            $values = collect($data)->only(['title', 'description', 'timezone', 'type', 'meeting_link',
                'location', 'is_private', 'department_id', 'room_id', 'client_id'])->all();
            $values['start_time'] = $start;
            $values['end_time'] = $end;
            $values['metadata'] = array_replace($meeting?->metadata ?? [],
                collect($data)->only(['is_client_meeting', 'client_name', 'client_email', 'client_company'])->all());
            if (! $meeting) {
                if ($request->boolean('save_as_client')) {
                    $client = Client::create([
                        'company_id' => $u->company_id,
                        'company_name' => $data['client_company'],
                        'contact_name' => $data['client_name'] ?? $data['client_company'],
                        'contact_email' => $data['client_email'] ?? null,
                        'campaign' => $data['campaign'] ?? 'Direct Outreach',
                        'progress' => "Meeting scheduled for {$start->format('M d, Y h:i A')}.",
                        'status' => Client::STATUS_SCHEDULED,
                        'created_by' => $u->id, 'assigned_to' => $u->id,
                        'last_activity_at' => now(),
                    ]);
                    $values['client_id'] = $client->id;
                }
                $values['organizer_id'] = $organizer;
                $values['company_id'] = $u->company_id;
                $values['status'] = 'scheduled';
                if (($data['recurrence_frequency'] ?? 'none') !== 'none') {
                    $values['recurrence'] = ['frequency' => $data['recurrence_frequency'], 'interval' => 1];
                }
                $meeting = Meeting::create($values);
            } else {
                $meeting->update($values);
            }
            $existing = $meeting->participants()->pluck('users.id')->all();
            $sync = [];
            foreach ($participants as $participant) {
                $sync[$participant] = $participant === $organizer
                    ? ['role' => 'host', 'status' => 'accepted', 'responded_at' => now()]
                    : (in_array($participant, $existing) ? [] : ['role' => 'attendee', 'status' => 'pending']);
            }
            $meeting->participants()->sync($sync);
            $removed = array_diff($existing, $participants);
            if ($removed) {
                $meeting->reminders()->whereIn('user_id', $removed)->whereIn('status', ['pending', 'queued'])
                    ->update(['status' => 'dismissed']);
            }
            if ($meeting->client_id) {
                $client = Client::whereKey($meeting->client_id)->lockForUpdate()->first();
                if ($client && $client->status === Client::STATUS_DISCOVERY) {
                    $oldStatus = $client->status;
                    $client->update([
                        'status' => Client::STATUS_SCHEDULED,
                        'progress' => "Meeting scheduled for {$start->format('M d, Y h:i A')}. Automatic reminders active.",
                        'last_activity_at' => now(),
                    ]);
                    AuditLog::create([
                        'user_id' => $u->id,
                        'action' => 'client_status_changed',
                        'auditable_type' => Client::class,
                        'auditable_id' => $client->id,
                        'description' => "Pipeline stage for '{$client->company_name}' advanced from Discovery to Scheduled via meeting scheduling by {$u->name}.",
                        'old_values' => ['status' => $oldStatus],
                        'new_values' => ['status' => Client::STATUS_SCHEDULED, 'progress' => $client->progress],
                    ]);
                }
            }
            $reminders = app(ReminderEngineService::class);
            if ($oldStart && ! $oldStart->equalTo($start)) { $reminders->handleMeetingRescheduled($meeting, $oldStart); }
            if (! $old) { $reminders->scheduleMeetingReminders($meeting, $data['reminder_minutes'] ?? 15); }
            AuditLog::create(['user_id' => $u->id, 'action' => $old ? 'meeting_updated' : 'meeting_created',
                'auditable_type' => Meeting::class, 'auditable_id' => $meeting->id,
                'old_values' => $old, 'new_values' => $meeting->toArray()]);
            DB::afterCommit(function () use ($meeting, $old) {
                $notifications = app(NotificationDispatchService::class);
                if ($old) { $notifications->notifyMeetingUpdated($meeting, ['details']); }
                else { $notifications->notifyMeetingInvitation($meeting); }
            });
            return $meeting;
        }, 3);
        return (new MobileRecordResource($meeting->load(['organizer', 'participants'])))->response()->setStatusCode($id ? 200 : 201);
    }

    public function action(Request $request, int $id, string $action)
    {
        $meeting = $this->visibility->meetings($request->user())->findOrFail($id);
        $controller = app(\App\Http\Controllers\MeetingController::class);
        if ($action === 'rsvp') {
            abort_unless($meeting->participants()->where('users.id', $request->user()->id)->exists(), 403);
            $controller->rsvp($request, $meeting);
        } elseif ($action === 'cancel') { $controller->cancel($request, $meeting); }
        elseif ($action === 'delete') { $controller->destroy($meeting); }
        else { abort(404); }
        return response()->json(['message' => 'Meeting updated.']);
    }

    public function availability(Request $request)
    {
        app(WorkspaceController::class)->references($request);
        $request->validate(['start_time' => 'required|date', 'end_time' => 'required|date|after:start_time']);
        $result = app(ConflictDetectionService::class)->checkAvailability(
            Carbon::parse($request->start_time)->utc(), Carbon::parse($request->end_time)->utc(),
            $request->input('room_id'), $request->input('participant_ids', []), $request->input('exclude_meeting_id'));
        // Return occupancy, never the titles/IDs of private meetings.
        if (isset($result['room']['conflict'])) { unset($result['room']['conflict']); }
        $result['participants'] = array_map(fn ($p) => [
            'user_id' => $p['user_id'], 'name' => $p['name'], 'status' => $p['status'],
        ], $result['participants']);
        return response()->json(['data' => $result]);
    }

    public function suggestions(Request $request)
    {
        app(WorkspaceController::class)->references($request);
        $request->validate(['date' => 'required|date_format:Y-m-d',
            'duration_minutes' => 'required|integer|min:15|max:480']);
        $cursor = Carbon::parse($request->date, $request->user()->timezone ?: 'UTC')->setTime(9, 0);
        $closing = $cursor->copy()->setTime(18, 0);
        $duration = $request->integer('duration_minutes');
        $slots = [];
        while ($cursor->copy()->addMinutes($duration)->lte($closing) && count($slots) < 5) {
            $end = $cursor->copy()->addMinutes($duration);
            $result = app(ConflictDetectionService::class)->checkAvailability(
                $cursor->copy()->utc(), $end->copy()->utc(), $request->input('room_id'),
                $request->input('participant_ids', []), $request->input('exclude_meeting_id'));
            if ($cursor->isFuture() && ! $result['has_conflicts']) {
                $slots[] = ['start_time' => $cursor->toIso8601String(), 'end_time' => $end->toIso8601String()];
            }
            $cursor->addMinutes(30);
        }
        return response()->json(['data' => $slots]);
    }
}
