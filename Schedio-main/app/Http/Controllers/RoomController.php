<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Meeting;
use App\Models\Room;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use Illuminate\View\View;

class RoomController extends Controller
{
    /**
     * Display a listing of meeting rooms & focus pods with live availability and schedule stats.
     */
    public function index(Request $request): View
    {
        $user = Auth::user();
        $search = $request->query('search');
        $status = $request->query('status', 'all'); // all, active, inactive

        $query = Room::withCount(['meetings as upcoming_meetings_count' => function ($q) {
            $q->where('start_time', '>=', now())->where('status', '!=', 'cancelled');
        }])->orderBy('name');

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('code', 'like', "%{$search}%")
                  ->orWhere('location', 'like', "%{$search}%");
            });
        }

        if ($status === 'active') {
            $query->where('is_active', true);
        } elseif ($status === 'inactive') {
            $query->where('is_active', false);
        }

        $rooms = $query->paginate(12)->withQueryString();

        $stats = [
            'total' => Room::count(),
            'active' => Room::where('is_active', true)->count(),
            'total_capacity' => Room::where('is_active', true)->sum('capacity'),
            'today_bookings' => Meeting::whereNotNull('room_id')
                ->whereDate('start_time', Carbon::today())
                ->where('status', '!=', 'cancelled')
                ->count(),
        ];

        return view('rooms.index', compact('rooms', 'stats', 'search', 'status', 'user'));
    }

    /**
     * Store a newly created room (Super Admin only).
     */
    public function store(Request $request): RedirectResponse
    {
        $user = Auth::user();
        if (!$user->isSuperAdmin()) {
            abort(403, 'Unauthorized. Only Super Administrators can configure meeting suites.');
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:150'],
            'code' => ['nullable', 'string', 'max:50', 'unique:rooms,code'],
            'location' => ['required', 'string', 'max:255'],
            'capacity' => ['required', 'integer', 'min:1', 'max:500'],
            'amenities' => ['nullable', 'array'],
            'amenities_text' => ['nullable', 'string'],
            'color' => ['nullable', 'string', 'max:20'],
            'is_active' => ['boolean'],
        ]);

        $code = !empty($validated['code'])
            ? Str::upper(Str::slug($validated['code']))
            : Str::upper('ROOM-' . Str::slug(substr($validated['name'], 0, 10)) . '-' . rand(100, 999));

        // Format amenities from checkboxes or comma-separated text
        $amenities = $validated['amenities'] ?? [];
        if (!empty($validated['amenities_text'])) {
            $extra = array_map('trim', explode(',', $validated['amenities_text']));
            $amenities = array_values(array_unique(array_merge($amenities, array_filter($extra))));
        }

        $room = Room::create([
            'name' => $validated['name'],
            'code' => $code,
            'location' => $validated['location'],
            'capacity' => $validated['capacity'],
            'amenities' => $amenities,
            'color' => $validated['color'] ?? '#6366f1',
            'is_active' => $request->boolean('is_active', true),
        ]);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'room_created',
            'auditable_type' => Room::class,
            'auditable_id' => $room->id,
            'description' => "Meeting suite '{$room->name}' ({$room->code}) created by {$user->name}.",
            'new_values' => $room->toArray(),
        ]);

        return redirect()->route('rooms.index')->with('success', "Room '{$room->name}' added successfully.");
    }

    /**
     * Display room details, timeline and scheduled sessions.
     */
    public function show(Room $room): View
    {
        $room->load(['meetings' => function ($q) {
            $q->with('organizer')
              ->where('status', '!=', 'cancelled')
              ->where('start_time', '>=', now()->subDays(1))
              ->orderBy('start_time')
              ->take(20);
        }]);

        $user = Auth::user();

        return view('rooms.show', compact('room', 'user'));
    }

    /**
     * Update room configuration.
     */
    public function update(Request $request, Room $room): RedirectResponse
    {
        $user = Auth::user();
        if (!$user->isSuperAdmin()) {
            abort(403, 'Unauthorized. Only Super Administrators can modify meeting suites.');
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:150'],
            'code' => ['required', 'string', 'max:50', 'unique:rooms,code,' . $room->id],
            'location' => ['required', 'string', 'max:255'],
            'capacity' => ['required', 'integer', 'min:1', 'max:500'],
            'amenities' => ['nullable', 'array'],
            'amenities_text' => ['nullable', 'string'],
            'color' => ['nullable', 'string', 'max:20'],
            'is_active' => ['boolean'],
        ]);

        $amenities = $validated['amenities'] ?? [];
        if (!empty($validated['amenities_text'])) {
            $extra = array_map('trim', explode(',', $validated['amenities_text']));
            $amenities = array_values(array_unique(array_merge($amenities, array_filter($extra))));
        }

        $oldValues = $room->toArray();

        $room->update([
            'name' => $validated['name'],
            'code' => Str::upper($validated['code']),
            'location' => $validated['location'],
            'capacity' => $validated['capacity'],
            'amenities' => $amenities,
            'color' => $validated['color'] ?? $room->color,
            'is_active' => $request->boolean('is_active', true),
        ]);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'room_updated',
            'auditable_type' => Room::class,
            'auditable_id' => $room->id,
            'description' => "Meeting suite '{$room->name}' updated by {$user->name}.",
            'old_values' => $oldValues,
            'new_values' => $room->fresh()->toArray(),
        ]);

        return redirect()->route('rooms.index')->with('success', "Room '{$room->name}' updated successfully.");
    }

    /**
     * Remove or soft-delete room.
     */
    public function destroy(Room $room): RedirectResponse
    {
        $user = Auth::user();
        if (!$user->isSuperAdmin()) {
            abort(403, 'Unauthorized.');
        }

        $roomName = $room->name;
        $room->delete();

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'room_deleted',
            'auditable_type' => Room::class,
            'auditable_id' => $room->id,
            'description' => "Meeting suite '{$roomName}' deleted by {$user->name}.",
        ]);

        return redirect()->route('rooms.index')->with('success', "Room '{$roomName}' removed successfully.");
    }

    /**
     * JSON check for room schedule availability & double-booking prevention.
     */
    public function checkAvailability(Request $request, Room $room): JsonResponse
    {
        $validated = $request->validate([
            'start_time' => ['required', 'date'],
            'end_time' => ['required', 'date', 'after:start_time'],
            'exclude_meeting_id' => ['nullable', 'integer'],
        ]);

        $start = Carbon::parse($validated['start_time']);
        $end = Carbon::parse($validated['end_time']);

        $query = Meeting::where('room_id', $room->id)
            ->where('status', '!=', 'cancelled')
            ->where(function ($q) use ($start, $end) {
                $q->where('start_time', '<', $end)
                  ->where('end_time', '>', $start);
            });

        if (!empty($validated['exclude_meeting_id'])) {
            $query->where('id', '!=', $validated['exclude_meeting_id']);
        }

        $conflictMeeting = $query->with('organizer')->first();

        return response()->json([
            'available' => $conflictMeeting === null,
            'conflict' => $conflictMeeting ? [
                'meeting_id' => $conflictMeeting->id,
                'title' => $conflictMeeting->title,
                'start_time' => $conflictMeeting->start_time->format('h:i A'),
                'end_time' => $conflictMeeting->end_time->format('h:i A'),
                'organizer' => $conflictMeeting->organizer?->name,
            ] : null,
        ]);
    }
}
