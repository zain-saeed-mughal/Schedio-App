<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MobileRecordResource;
use App\Models\{Client, Department, Event, Meeting, MeetingNote, Room, Task, User};
use App\Services\MobileVisibility;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * JSON boundary around established workflows. Explicit allowlists prevent arbitrary
 * model/controller dispatch. Browser redirects are never sent to the mobile client.
 */
class WorkspaceController extends Controller
{
    public const MODULES = [
        'clients' => [Client::class, \App\Http\Controllers\ClientController::class],
        'rooms' => [Room::class, \App\Http\Controllers\RoomController::class],
        'events' => [Event::class, \App\Http\Controllers\EventController::class],
        'tasks' => [Task::class, \App\Http\Controllers\TaskController::class],
    ];

    public function __construct(private MobileVisibility $visibility) {}

    public function query(string $module, User $user)
    {
        abort_unless(isset(self::MODULES[$module]), 404);
        return match ($module) {
            'clients' => $this->visibility->clients($user)->with('assignedTo'),
            'events' => $this->visibility->events($user),
            'tasks' => $this->visibility->tasks($user)->with(['assignee', 'creator']),
            'rooms' => Room::query(),
        };
    }

    public function index(Request $request, string $module)
    {
        $query = $this->query($module, $request->user());
        $request->validate(['search' => 'nullable|string|max:200', 'status' => 'nullable|string|max:40',
            'page' => 'nullable|integer|min:1', 'per_page' => 'nullable|integer|min:1|max:100']);
        if ($request->filled('search')) {
            $field = match ($module) { 'clients' => 'company_name', 'rooms' => 'name', default => 'title' };
            $query->where($field, 'like', '%'.$request->search.'%');
        }
        if ($request->filled('status') && in_array($module, ['clients', 'tasks'])) {
            $query->where('status', $request->status);
        }
        return MobileRecordResource::collection($query->latest('id')->paginate($request->integer('per_page', 25)));
    }

    public function show(Request $request, string $module, int $id)
    {
        return new MobileRecordResource($this->query($module, $request->user())->findOrFail($id));
    }

    public function clientMeetings(Request $request, int $id)
    {
        $this->visibility->clients($request->user())->findOrFail($id);
        return MobileRecordResource::collection($this->visibility->meetings($request->user())
            ->where('client_id', $id)->with(['organizer', 'participants'])->orderByDesc('start_time')->paginate(25));
    }

    public function references(Request $request): void
    {
        // Raw SQL exists rules bypass Eloquent scopes; verify each foreign key through scoped models.
        foreach (['department_id' => Department::class, 'room_id' => Room::class,
            'assigned_to' => User::class, 'client_id' => Client::class,
            'meeting_id' => Meeting::class, 'exclude_meeting_id' => Meeting::class] as $key => $class) {
            if (! $request->filled($key)) { continue; }
            $record = $class::find($request->input($key));
            if (! $record) { throw ValidationException::withMessages([$key => 'This selection is not available.']); }
            if ($record instanceof Meeting) {
                $this->visibility->meetings($request->user())->findOrFail($record->id);
            }
            if ($record instanceof Client) {
                $this->visibility->clients($request->user())->findOrFail($record->id);
            }
        }
        $request->validate(['participant_ids' => 'nullable|array|max:100',
            'participant_ids.*' => 'integer|distinct']);
        foreach ($request->input('participant_ids', []) as $id) {
            if (! User::where('is_active', true)->approved()->whereKey($id)->exists()) {
                throw ValidationException::withMessages(['participant_ids' => 'A participant is unavailable.']);
            }
        }
    }

    public function mutate(Request $request, string $module, ?int $id = null, ?string $action = null)
    {
        abort_unless(isset(self::MODULES[$module]), 404);
        $this->references($request);
        $record = $id ? $this->query($module, $request->user())->findOrFail($id) : null;
        $method = $action === 'status' ? 'updateStatus' : match ($request->method()) {
            'POST' => 'store', 'PUT' => 'update', 'DELETE' => 'destroy', default => abort(405),
        };
        abort_if($module === 'tasks' && ! in_array($method, ['store', 'updateStatus']), 405);
        abort_if($method === 'updateStatus' && ! in_array($module, ['tasks', 'clients']), 405);
        $controller = app(self::MODULES[$module][1]);
        DB::transaction(function () use ($controller, $method, $request, $record) {
            if ($method === 'destroy') { $controller->destroy($record); }
            elseif ($record) { $controller->$method($request, $record); }
            else { $controller->store($request); }
        });
        return response()->json(['message' => 'Saved successfully.'], $method === 'store' ? 201 : 200);
    }

    public function lookups(Request $request)
    {
        return response()->json(['data' => [
            'users' => User::approved()->where('is_active', true)->orderBy('name')->get(['id', 'name']),
            'departments' => Department::where('is_active', true)->get(['id', 'name']),
            'rooms' => Room::where('is_active', true)->get(['id', 'name']),
            'clients' => $this->visibility->clients($request->user())->orderBy('company_name')->get(['id', 'company_name']),
        ]]);
    }

    public function dashboard(Request $request)
    {
        $u = $request->user();
        $meetings = $this->visibility->meetings($u)->where('status', '!=', 'cancelled');
        $start = now($u->timezone ?: 'UTC')->startOfDay()->utc();
        $end = $start->copy()->setTimezone($u->timezone ?: 'UTC')->addDay()->utc();
        return response()->json(['data' => [
            'today_meetings' => (clone $meetings)->where('start_time', '>=', $start)->where('start_time', '<', $end)->count(),
            'upcoming_meetings' => (clone $meetings)->where('start_time', '>=', now())->count(),
            'pending_tasks' => $this->visibility->tasks($u)->whereNotIn('status', ['completed', 'cancelled'])->count(),
            'unread_notifications' => $u->unreadNotifications()->count(),
            'meetings' => MobileRecordResource::collection((clone $meetings)->with('organizer')
                ->where('start_time', '>=', now())->orderBy('start_time')->limit(8)->get()),
        ]]);
    }

    public function notes(Request $request, int $id)
    {
        $meeting = $this->visibility->meetings($request->user())->findOrFail($id);
        if ($request->isMethod('GET')) {
            return MobileRecordResource::collection($meeting->notes()->with('author')->latest()->paginate(25));
        }
        app(\App\Http\Controllers\MeetingNoteController::class)->store($request, $meeting);
        return response()->json(['message' => 'Note saved.'], 201);
    }

    public function note(Request $request, int $id)
    {
        $note = MeetingNote::findOrFail($id);
        $this->visibility->meetings($request->user())->findOrFail($note->meeting_id);
        if ($request->isMethod('GET')) {
            return new MobileRecordResource($note->load('author'));
        }
        $controller = app(\App\Http\Controllers\MeetingNoteController::class);
        if ($request->isMethod('DELETE')) { $controller->destroy($note); }
        else { $controller->update($request, $note); }
        return response()->json(['message' => 'Note saved.']);
    }
}
