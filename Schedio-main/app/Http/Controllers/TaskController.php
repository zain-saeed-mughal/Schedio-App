<?php

namespace App\Http\Controllers;

use App\Models\Task;
use App\Models\User;
use App\Services\NotificationDispatchService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class TaskController extends Controller
{
    /**
     * Store a newly created task (action item).
     */
    public function store(Request $request): RedirectResponse
    {
        $user = Auth::user();

        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'assigned_to' => ['nullable', 'exists:users,id'],
            'department_id' => ['nullable', 'exists:departments,id'],
            'meeting_id' => ['nullable', 'exists:meetings,id'],
            'priority' => ['required', 'string', 'in:low,medium,high,urgent'],
            'due_date' => ['nullable', 'date'],
        ]);

        $task = Task::create([
            'title' => $validated['title'],
            'description' => $validated['description'] ?? null,
            'assigned_to' => $validated['assigned_to'] ?? null,
            'created_by' => $user->id,
            'department_id' => $validated['department_id'] ?? null,
            'meeting_id' => $validated['meeting_id'] ?? null,
            'priority' => $validated['priority'],
            'status' => 'todo',
            'due_date' => $validated['due_date'] ?? null,
        ]);

        if ($task->assigned_to) {
            app(NotificationDispatchService::class)->notifyTaskActivity($task, 'assigned', $user);
        }

        return back()->with('success', 'Action item created successfully.');
    }

    /**
     * Update task status (e.g. todo -> in_progress -> completed).
     */
    public function updateStatus(Request $request, Task $task): RedirectResponse
    {
        $user = Auth::user();

        // Ensure user is super admin, creator, or assigned
        if (!$user->isSuperAdmin() && $task->created_by !== $user->id && $task->assigned_to !== $user->id) {
            abort(403, 'Unauthorized to modify this task.');
        }

        $validated = $request->validate([
            'status' => ['required', 'string', 'in:todo,in_progress,review,completed,cancelled'],
        ]);

        $oldStatus = $task->status;
        $newStatus = $validated['status'];

        $task->update([
            'status' => $newStatus,
            'completed_at' => $newStatus === 'completed' ? now() : null,
        ]);

        $activityType = $newStatus === 'completed' ? 'completed' : 'status_changed';
        $detail = "Status changed from " . strtoupper($oldStatus) . " to " . strtoupper($newStatus);

        app(NotificationDispatchService::class)->notifyTaskActivity($task, $activityType, $user, $detail);

        return back()->with('success', 'Task status updated.');
    }
}
