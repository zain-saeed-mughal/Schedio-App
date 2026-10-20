<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Department;
use App\Models\Event;
use App\Models\Meeting;
use App\Models\MeetingParticipant;
use App\Models\Room;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class CalendarController extends Controller
{
    /**
     * Display the FullCalendar view with filter controls and modal forms.
     */
    public function index(Request $request): View
    {
        $user = Auth::user();
        $departments = Department::where('is_active', true)->orderBy('name')->get();
        $users = User::where('approval_status', User::STATUS_APPROVED)->where('is_active', true)->orderBy('name')->get();

        return view('calendar.index', compact('user', 'departments', 'users'));
    }

    /**
     * JSON feed for FullCalendar.js (supports date ranges, category filters, department filters, room filters, and search).
     */
    public function feed(Request $request): JsonResponse
    {
        $user = Auth::user();
        
        $request->validate([
            'start' => ['required', 'string'],
            'end' => ['required', 'string'],
            'type' => ['nullable', 'string'], // all, meetings, events, holidays
            'department_id' => ['nullable', 'string'],
            'search' => ['nullable', 'string'],
        ]);

        $start = Carbon::parse($request->input('start'));
        $end = Carbon::parse($request->input('end'));
        $typeFilter = $request->input('type', 'all');
        $departmentFilter = $request->input('department_id');
        $search = $request->input('search');

        $calendarEvents = [];

        // 1. Fetch Meetings
        if ($typeFilter === 'all' || $typeFilter === 'meetings') {
            $meetingQuery = Meeting::with(['organizer', 'department', 'participants'])
                ->where('status', '!=', 'cancelled')
                ->where(function ($q) use ($start, $end) {
                    $q->whereBetween('start_time', [$start, $end])
                      ->orWhereBetween('end_time', [$start, $end])
                      ->orWhere(function ($sub) use ($start, $end) {
                          $sub->where('start_time', '<=', $start)
                              ->where('end_time', '>=', $end);
                      });
                });

            // Visibility / Permissions: Non-super admin can ONLY see meetings where they are organizer or participant
            if (!$user->isSuperAdmin()) {
                $meetingQuery->where(function ($q) use ($user) {
                    $q->where('organizer_id', $user->id)
                      ->orWhereHas('participants', function ($p) use ($user) {
                          $p->where('users.id', $user->id);
                      });
                });
            }

            if ($departmentFilter) {
                $meetingQuery->where('department_id', $departmentFilter);
            }

            if ($search) {
                $meetingQuery->where(function ($q) use ($search) {
                    $q->where('title', 'like', "%{$search}%")
                      ->orWhere('description', 'like', "%{$search}%");
                });
            }

            $meetings = $meetingQuery->get();

            foreach ($meetings as $meeting) {
                $canEdit = $user->isSuperAdmin() || $meeting->organizer_id === $user->id;
                $isClient = $meeting->metadata['is_client_meeting'] ?? false;
                $color = $isClient ? '#a855f7' : '#6366f1';

                $calendarEvents[] = [
                    'id' => 'meeting_' . $meeting->id,
                    'title' => $meeting->title,
                    'start' => $meeting->start_time->toIso8601String(),
                    'end' => $meeting->end_time->toIso8601String(),
                    'allDay' => false,
                    'backgroundColor' => $color,
                    'borderColor' => $color,
                    'textColor' => '#ffffff',
                    'editable' => $canEdit,
                    'extendedProps' => [
                        'entity_type' => 'meeting',
                        'entity_id' => $meeting->id,
                        'description' => $meeting->description,
                        'meeting_type' => $meeting->type,
                        'status' => $meeting->status,
                        'is_private' => $meeting->is_private,
                        'meeting_link' => $meeting->meeting_link,
                        'location' => $meeting->location,
                        'client_name' => $meeting->metadata['client_name'] ?? null,
                        'client_email' => $meeting->metadata['client_email'] ?? null,
                        'client_company' => $meeting->metadata['client_company'] ?? null,
                        'reminder_minutes' => $meeting->metadata['reminder_minutes'] ?? 15,
                        'room' => null,
                        'organizer' => [
                            'id' => $meeting->organizer->id,
                            'name' => $meeting->organizer->name,
                            'email' => $meeting->organizer->email,
                        ],
                        'department' => $meeting->department ? [
                            'id' => $meeting->department->id,
                            'name' => $meeting->department->name,
                        ] : null,
                        'participants' => $meeting->participants->map(fn($p) => [
                            'id' => $p->id,
                            'name' => $p->name,
                            'role' => $p->pivot->role,
                            'status' => $p->pivot->status,
                        ]),
                        'can_edit' => $canEdit,
                        'can_delete' => $canEdit,
                    ],
                ];
            }
        }

        // 2. Fetch Events & Company Holidays
        if ($typeFilter === 'all' || $typeFilter === 'events' || $typeFilter === 'holidays') {
            $eventQuery = Event::with(['user', 'department'])
                ->where(function ($q) use ($start, $end) {
                    $q->whereBetween('start_time', [$start, $end])
                      ->orWhereBetween('end_time', [$start, $end])
                      ->orWhere(function ($sub) use ($start, $end) {
                          $sub->where('start_time', '<=', $start)
                              ->where('end_time', '>=', $end);
                      });
                });

            if ($typeFilter === 'holidays') {
                $eventQuery->where('category', 'company_holiday');
            } elseif ($typeFilter === 'events') {
                $eventQuery->where('category', '!=', 'company_holiday');
            }

            // Visibility / Permissions
            if (!$user->isSuperAdmin()) {
                $eventQuery->where(function ($q) use ($user) {
                    $q->where('is_company_wide', true)
                      ->orWhere('user_id', $user->id)
                      ->orWhere('department_id', $user->department_id);
                });
            }

            if ($departmentFilter) {
                $eventQuery->where(function ($q) use ($departmentFilter) {
                    $q->where('department_id', $departmentFilter)
                      ->orWhere('is_company_wide', true);
                });
            }

            if ($search) {
                $eventQuery->where(function ($q) use ($search) {
                    $q->where('title', 'like', "%{$search}%")
                      ->orWhere('description', 'like', "%{$search}%");
                });
            }

            $events = $eventQuery->get();

            foreach ($events as $event) {
                $canEdit = $user->isSuperAdmin() || $event->user_id === $user->id;

                $calendarEvents[] = [
                    'id' => 'event_' . $event->id,
                    'title' => $event->title,
                    'start' => $event->start_time->toIso8601String(),
                    'end' => $event->end_time->toIso8601String(),
                    'allDay' => $event->is_all_day,
                    'backgroundColor' => $event->color ?: '#3b82f6',
                    'borderColor' => $event->color ?: '#3b82f6',
                    'textColor' => '#ffffff',
                    'editable' => $canEdit,
                    'extendedProps' => [
                        'entity_type' => 'event',
                        'entity_id' => $event->id,
                        'description' => $event->description,
                        'category' => $event->category,
                        'is_all_day' => $event->is_all_day,
                        'is_company_wide' => $event->is_company_wide,
                        'location' => $event->location,
                        'user' => [
                            'id' => $event->user->id,
                            'name' => $event->user->name,
                        ],
                        'department' => $event->department ? [
                            'id' => $event->department->id,
                            'name' => $event->department->name,
                        ] : null,
                        'can_edit' => $canEdit,
                        'can_delete' => $canEdit,
                    ],
                ];
            }
        }

        return response()->json($calendarEvents);
    }

    /**
     * Store new calendar meeting or event.
     */
    public function store(Request $request): JsonResponse
    {
        $user = Auth::user();
        $entityType = $request->input('entity_type', 'meeting');

        if ($entityType === 'meeting') {
            $validated = $request->validate([
                'title' => ['required', 'string', 'max:255'],
                'description' => ['nullable', 'string'],
                'start_time' => ['required', 'date'],
                'end_time' => ['required', 'date', 'after:start_time'],
                'department_id' => ['nullable', 'exists:departments,id'],
                'type' => ['nullable', 'string', 'in:in_person,virtual,hybrid'],
                'meeting_link' => ['nullable', 'url', 'max:255'],
                'location' => ['nullable', 'string', 'max:255'],
                'is_private' => ['boolean'],
                'client_name' => ['nullable', 'string', 'max:255'],
                'client_email' => ['nullable', 'email', 'max:255'],
                'client_company' => ['nullable', 'string', 'max:255'],
                'reminder_minutes' => ['nullable', 'integer', 'min:0', 'max:10080'],
                'participant_ids' => ['nullable', 'array'],
                'participant_ids.*' => ['exists:users,id'],
            ]);

            $meeting = DB::transaction(function () use ($validated, $user) {
                $isClient = !empty($validated['client_name']) || !empty($validated['client_email']);
                $metadata = [
                    'is_client_meeting' => $isClient,
                    'client_name' => $validated['client_name'] ?? null,
                    'client_email' => $validated['client_email'] ?? null,
                    'client_company' => $validated['client_company'] ?? null,
                    'reminder_minutes' => $validated['reminder_minutes'] ?? 15,
                ];

                $meeting = Meeting::create([
                    'title' => $validated['title'],
                    'description' => $validated['description'] ?? null,
                    'organizer_id' => $user->id,
                    'department_id' => $validated['department_id'] ?? $user->department_id,
                    'room_id' => null,
                    'start_time' => Carbon::parse($validated['start_time']),
                    'end_time' => Carbon::parse($validated['end_time']),
                    'timezone' => $user->timezone ?: 'UTC',
                    'type' => $validated['type'] ?? 'virtual',
                    'meeting_link' => $validated['meeting_link'] ?? null,
                    'location' => $validated['location'] ?? null,
                    'is_private' => $validated['is_private'] ?? false,
                    'metadata' => $metadata,
                    'status' => 'scheduled',
                ]);

                // Create reminder if specified via ReminderEngineService
                $reminderMinutes = (int)($validated['reminder_minutes'] ?? 15);
                if ($reminderMinutes > 0) {
                    app(\App\Services\ReminderEngineService::class)->scheduleMeetingReminders($meeting, $reminderMinutes);
                }

                // Always attach organizer as host
                MeetingParticipant::create([
                    'meeting_id' => $meeting->id,
                    'user_id' => $user->id,
                    'role' => 'host',
                    'status' => 'accepted',
                    'responded_at' => now(),
                ]);

                // Attach additional participants
                if (!empty($validated['participant_ids'])) {
                    foreach ($validated['participant_ids'] as $participantId) {
                        if ($participantId != $user->id) {
                            MeetingParticipant::create([
                                'meeting_id' => $meeting->id,
                                'user_id' => $participantId,
                                'role' => 'attendee',
                                'status' => 'pending',
                            ]);
                        }
                    }
                }

                AuditLog::create([
                    'user_id' => $user->id,
                    'action' => 'meeting_created',
                    'auditable_type' => Meeting::class,
                    'auditable_id' => $meeting->id,
                    'description' => "Meeting '{$meeting->title}' scheduled by {$user->name}.",
                    'new_values' => $meeting->toArray(),
                ]);

                // Dispatch Invitations
                app(\App\Services\NotificationDispatchService::class)->notifyMeetingInvitation($meeting);

                return $meeting;
            });

            return response()->json([
                'success' => true,
                'message' => 'Meeting scheduled successfully.',
                'item' => $meeting,
            ]);
        } else {
            // Event / Holiday
            $validated = $request->validate([
                'title' => ['required', 'string', 'max:255'],
                'description' => ['nullable', 'string'],
                'start_time' => ['required', 'date'],
                'end_time' => ['required', 'date', 'after_or_equal:start_time'],
                'department_id' => ['nullable', 'exists:departments,id'],
                'category' => ['required', 'string', 'in:company_holiday,deadline,training,milestone,out_of_office,general'],
                'is_all_day' => ['boolean'],
                'color' => ['nullable', 'string', 'max:20'],
                'location' => ['nullable', 'string', 'max:255'],
                'is_company_wide' => ['boolean'],
            ]);

            $event = Event::create([
                'title' => $validated['title'],
                'description' => $validated['description'] ?? null,
                'user_id' => $user->id,
                'department_id' => $validated['department_id'] ?? null,
                'category' => $validated['category'],
                'start_time' => Carbon::parse($validated['start_time']),
                'end_time' => Carbon::parse($validated['end_time']),
                'is_all_day' => $validated['is_all_day'] ?? false,
                'color' => $validated['color'] ?? '#3b82f6',
                'location' => $validated['location'] ?? null,
                'is_company_wide' => $user->isSuperAdmin() ? ($validated['is_company_wide'] ?? false) : false,
            ]);

            AuditLog::create([
                'user_id' => $user->id,
                'action' => 'event_created',
                'auditable_type' => Event::class,
                'auditable_id' => $event->id,
                'description' => "Event '{$event->title}' created by {$user->name}.",
                'new_values' => $event->toArray(),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Event created successfully.',
                'item' => $event,
            ]);
        }
    }

    /**
     * Update meeting or event time (called during drag-and-drop or resize in FullCalendar).
     */
    public function updateTime(Request $request, string $type, int $id): JsonResponse
    {
        $user = Auth::user();

        $validated = $request->validate([
            'start_time' => ['required', 'date'],
            'end_time' => ['required', 'date', 'after:start_time'],
        ]);

        if ($type === 'meeting') {
            $meeting = Meeting::findOrFail($id);

            if (!$user->isSuperAdmin() && $meeting->organizer_id !== $user->id) {
                return response()->json(['message' => 'Unauthorized to modify this meeting.'], 403);
            }

            $oldTimes = ['start' => $meeting->start_time, 'end' => $meeting->end_time];

            $meeting->update([
                'start_time' => Carbon::parse($validated['start_time']),
                'end_time' => Carbon::parse($validated['end_time']),
            ]);

            AuditLog::create([
                'user_id' => $user->id,
                'action' => 'meeting_rescheduled',
                'auditable_type' => Meeting::class,
                'auditable_id' => $meeting->id,
                'description' => "Meeting '{$meeting->title}' rescheduled to {$meeting->start_time->toDayDateTimeString()}.",
                'old_values' => $oldTimes,
                'new_values' => ['start' => $meeting->start_time, 'end' => $meeting->end_time],
            ]);

            // Sync reminders & dispatch notifications
            app(\App\Services\ReminderEngineService::class)->handleMeetingRescheduled($meeting, Carbon::parse($oldTimes['start']));
            app(\App\Services\NotificationDispatchService::class)->notifyMeetingUpdated($meeting, ['time']);

            return response()->json([
                'success' => true,
                'message' => 'Meeting schedule updated.',
            ]);
        } elseif ($type === 'event') {
            $event = Event::findOrFail($id);

            if (!$user->isSuperAdmin() && $event->user_id !== $user->id) {
                return response()->json(['message' => 'Unauthorized to modify this event.'], 403);
            }

            $event->update([
                'start_time' => Carbon::parse($validated['start_time']),
                'end_time' => Carbon::parse($validated['end_time']),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Event schedule updated.',
            ]);
        }

        return response()->json(['message' => 'Invalid entity type.'], 400);
    }

    /**
     * Delete meeting or event.
     */
    public function destroy(string $type, int $id): JsonResponse
    {
        $user = Auth::user();

        if ($type === 'meeting') {
            $meeting = Meeting::findOrFail($id);

            if (!$user->isSuperAdmin() && $meeting->organizer_id !== $user->id) {
                return response()->json(['message' => 'Unauthorized to delete this meeting.'], 403);
            }

            $meeting->update(['status' => 'cancelled']);
            app(\App\Services\ReminderEngineService::class)->handleMeetingCancelled($meeting);
            app(\App\Services\NotificationDispatchService::class)->notifyMeetingCancelled($meeting, $user->name);
            $meeting->delete();

            AuditLog::create([
                'user_id' => $user->id,
                'action' => 'meeting_deleted',
                'auditable_type' => Meeting::class,
                'auditable_id' => $meeting->id,
                'description' => "Meeting '{$meeting->title}' deleted by {$user->name}.",
            ]);

            return response()->json(['success' => true, 'message' => 'Meeting deleted successfully.']);
        } elseif ($type === 'event') {
            $event = Event::findOrFail($id);

            if (!$user->isSuperAdmin() && $event->user_id !== $user->id) {
                return response()->json(['message' => 'Unauthorized to delete this event.'], 403);
            }

            $event->delete();

            AuditLog::create([
                'user_id' => $user->id,
                'action' => 'event_deleted',
                'auditable_type' => Event::class,
                'auditable_id' => $event->id,
                'description' => "Event '{$event->title}' deleted by {$user->name}.",
            ]);

            return response()->json(['success' => true, 'message' => 'Event deleted successfully.']);
        }

        return response()->json(['message' => 'Invalid entity type.'], 400);
    }
}
