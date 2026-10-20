<?php

namespace App\Http\Middleware;

use App\Models\{Company, Meeting, User};
use App\Services\ConflictDetectionService;
use Carbon\Carbon;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Shared serialization boundary for browser and mobile meeting writes.
 * A company row is locked before availability is checked, including for empty
 * calendars where locking a conflicting meeting row would lock nothing.
 */
class SerializeScheduling
{
    public function handle(Request $request, Closure $next)
    {
        $action = $request->route()?->getActionName() ?? '';
        $scheduling = [
            'App\\Http\\Controllers\\MeetingController@store',
            'App\\Http\\Controllers\\MeetingController@update',
            'App\\Http\\Controllers\\CalendarController@store',
            'App\\Http\\Controllers\\CalendarController@updateTime',
            'App\\Http\\Controllers\\ClientController@scheduleMeeting',
            'App\\Http\\Controllers\\PublicBookingController@store',
            'App\\Http\\Controllers\\Api\\MeetingController@save',
            'App\\Http\\Controllers\\Api\\BookingController@store',
        ];
        if (! in_array($action, $scheduling, true)) { return $next($request); }
        if (str_contains($action, 'CalendarController') &&
            ($request->input('entity_type') === 'event' || $request->route('type') === 'event')) {
            return $next($request);
        }
        $public = str_contains($action, 'BookingController@store');
        $existing = null;
        if (str_ends_with($action, '@update') || str_ends_with($action, '@updateTime') ||
            (str_ends_with($action, '@save') && $request->route('id'))) {
            $bound = $request->route('meeting');
            $existing = $bound instanceof Meeting ? $bound : Meeting::findOrFail($request->route('id'));
            $actor = $request->user();
            abort_unless($actor && ($actor->isSuperAdmin() || $existing->organizer_id === $actor->id), 403);
        }
        if ($public) {
            $identifier = (string) $request->route('username');
            $hosts = User::withoutGlobalScopes()->whereNull('deleted_at')->approved()->where('is_active', true);
            $host = (clone $hosts)->where('username', $identifier)->first();
            if (! $host && ctype_digit($identifier)) { $host = (clone $hosts)->find((int) $identifier); }
            if (! $host) { $host = (clone $hosts)->where('email', 'like', $identifier.'@%')->first(); }
            abort_unless($host && $host->canLogin(), 404);
        } else {
            $host = $existing?->organizer ?? $request->user();
        }
        abort_unless($host, 401);
        return DB::transaction(function () use ($request, $next, $host, $existing, $public) {
            // SQLite ignores SELECT ... FOR UPDATE. Acquire its write reservation
            // before any transaction reads, avoiding a deferred read-to-write
            // upgrade that can fail with SQLITE_BUSY under simultaneous bookings.
            // This changes no values or timestamps and uses the same transaction.
            if (DB::connection()->getDriverName() === 'sqlite') {
                DB::table($host->company_id ? 'companies' : 'users')
                    ->where('id', $host->company_id ?: $host->id)
                    ->update(['id' => DB::raw('id')]);
            }
            if ($host->company_id) {
                Company::whereKey($host->company_id)->lockForUpdate()->firstOrFail();
            } else {
                User::withoutGlobalScopes()->whereKey($host->id)->lockForUpdate()->firstOrFail();
            }
            $rules = ['start_time' => 'required|date'];
            if ($public) { $rules['duration_minutes'] = 'required|integer|min:1|max:480'; }
            else { $rules['end_time'] = 'required|date|after:start_time'; }
            $validated = $request->validate($rules);
            $start = Carbon::parse($validated['start_time'])->utc();
            $end = $public ? $start->copy()->addMinutes((int) $validated['duration_minutes'])
                : Carbon::parse($validated['end_time'])->utc();
            $request->validate(['participant_ids' => 'nullable|array|max:100', 'participant_ids.*' => 'integer|distinct']);
            $participants = $request->input('participant_ids',
                $existing ? $existing->participants()->pluck('users.id')->all() : []);
            $participants[] = $host->id;
            $room = $request->input('room_id', $existing?->room_id);
            // Same tenant references also protect browser writes from foreign-key injection.
            foreach (array_unique($participants) as $id) {
                if (! User::withoutGlobalScopes()->whereNull('deleted_at')->where('company_id', $host->company_id)
                    ->whereKey($id)->exists()) {
                    throw ValidationException::withMessages(['participant_ids' => 'Participants must belong to the meeting workspace.']);
                }
            }
            if ($room && ! \App\Models\Room::where('company_id', $host->company_id)->whereKey($room)->exists()) {
                throw ValidationException::withMessages(['room_id' => 'Room is not available in this workspace.']);
            }
            $availability = app(ConflictDetectionService::class)->checkAvailability(
                $start, $end, $room ? (int) $room : null, array_values(array_unique($participants)), $existing?->id);
            if ($availability['has_conflicts']) {
                throw ValidationException::withMessages(['start_time' => 'A room or participant is already booked. Please choose another time.']);
            }
            return $next($request);
        }, 3);
    }
}
