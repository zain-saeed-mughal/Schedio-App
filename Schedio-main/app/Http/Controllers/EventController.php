<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Department;
use App\Models\Event;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

class EventController extends Controller
{
    /**
     * Display listing of company events, holidays, trainings, and department milestones.
     */
    public function index(Request $request): View
    {
        $user = Auth::user();
        $category = $request->query('category', 'all');
        $departmentId = $request->query('department_id');
        $search = $request->query('search');

        $query = Event::with(['user', 'department'])
            ->orderBy('start_time', 'asc');

        // Scoping & Permission
        if (!$user->isSuperAdmin()) {
            $query->where(function ($q) use ($user) {
                $q->where('is_company_wide', true)
                  ->orWhere('user_id', $user->id)
                  ->orWhere('department_id', $user->department_id);
            });
        }

        if ($category !== 'all') {
            $query->where('category', $category);
        }

        if ($departmentId) {
            $query->where('department_id', $departmentId);
        }

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%")
                  ->orWhere('location', 'like', "%{$search}%");
            });
        }

        $events = $query->paginate(15)->withQueryString();

        $departments = Department::where('is_active', true)->orderBy('name')->get();

        $counts = [
            'all' => Event::count(),
            'holidays' => Event::where('category', 'company_holiday')->count(),
            'trainings' => Event::where('category', 'training')->count(),
            'milestones' => Event::where('category', 'milestone')->count(),
            'deadlines' => Event::where('category', 'deadline')->count(),
        ];

        return view('events.index', compact('events', 'departments', 'counts', 'category', 'search', 'user'));
    }

    /**
     * Store newly created company event or training.
     */
    public function store(Request $request): RedirectResponse
    {
        $user = Auth::user();

        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'category' => ['required', 'string', 'in:company_holiday,deadline,training,milestone,out_of_office,general'],
            'start_time' => ['required', 'date'],
            'end_time' => ['required', 'date', 'after_or_equal:start_time'],
            'is_all_day' => ['boolean'],
            'department_id' => ['nullable', 'exists:departments,id'],
            'location' => ['nullable', 'string', 'max:255'],
            'color' => ['nullable', 'string', 'max:20'],
            'is_company_wide' => ['boolean'],
        ]);

        $isCompanyWide = $user->isSuperAdmin() ? $request->boolean('is_company_wide') : false;

        $categoryColors = [
            'company_holiday' => '#ec4899', // Pink / Rose
            'training' => '#8b5cf6',        // Purple
            'milestone' => '#f59e0b',       // Amber
            'deadline' => '#ef4444',        // Red
            'out_of_office' => '#64748b',   // Slate
            'general' => '#3b82f6',         // Blue
        ];

        $event = Event::create([
            'title' => $validated['title'],
            'description' => $validated['description'] ?? null,
            'user_id' => $user->id,
            'department_id' => $validated['department_id'] ?? null,
            'category' => $validated['category'],
            'start_time' => Carbon::parse($validated['start_time']),
            'end_time' => Carbon::parse($validated['end_time']),
            'is_all_day' => $request->boolean('is_all_day'),
            'color' => (!empty($validated['color'])) ? $validated['color'] : ($categoryColors[$validated['category']] ?? '#3b82f6'),
            'location' => $validated['location'] ?? null,
            'is_company_wide' => $isCompanyWide,
        ]);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'event_created',
            'auditable_type' => Event::class,
            'auditable_id' => $event->id,
            'description' => "Company event '{$event->title}' ({$event->category}) scheduled by {$user->name}.",
            'new_values' => $event->toArray(),
        ]);

        return redirect()->route('events.index')->with('success', "Event '{$event->title}' created and synced with the calendar.");
    }

    /**
     * Update existing event details.
     */
    public function update(Request $request, Event $event): RedirectResponse
    {
        $user = Auth::user();

        if (!$user->isSuperAdmin() && $event->user_id !== $user->id) {
            abort(403, 'Unauthorized to modify this company event.');
        }

        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'category' => ['required', 'string', 'in:company_holiday,deadline,training,milestone,out_of_office,general'],
            'start_time' => ['required', 'date'],
            'end_time' => ['required', 'date', 'after_or_equal:start_time'],
            'is_all_day' => ['boolean'],
            'department_id' => ['nullable', 'exists:departments,id'],
            'location' => ['nullable', 'string', 'max:255'],
            'color' => ['nullable', 'string', 'max:20'],
            'is_company_wide' => ['boolean'],
        ]);

        $isCompanyWide = $user->isSuperAdmin() ? $request->boolean('is_company_wide') : $event->is_company_wide;
        $oldValues = $event->toArray();

        $event->update([
            'title' => $validated['title'],
            'description' => $validated['description'] ?? null,
            'department_id' => $validated['department_id'] ?? null,
            'category' => $validated['category'],
            'start_time' => Carbon::parse($validated['start_time']),
            'end_time' => Carbon::parse($validated['end_time']),
            'is_all_day' => $request->boolean('is_all_day'),
            'color' => (!empty($validated['color'])) ? $validated['color'] : $event->color,
            'location' => $validated['location'] ?? null,
            'is_company_wide' => $isCompanyWide,
        ]);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'event_updated',
            'auditable_type' => Event::class,
            'auditable_id' => $event->id,
            'description' => "Event '{$event->title}' updated by {$user->name}.",
            'old_values' => $oldValues,
            'new_values' => $event->fresh()->toArray(),
        ]);

        return redirect()->route('events.index')->with('success', 'Event updated successfully.');
    }

    /**
     * Delete company event.
     */
    public function destroy(Event $event): RedirectResponse
    {
        $user = Auth::user();

        if (!$user->isSuperAdmin() && $event->user_id !== $user->id) {
            abort(403, 'Unauthorized.');
        }

        $title = $event->title;
        $event->delete();

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'event_deleted',
            'auditable_type' => Event::class,
            'auditable_id' => $event->id,
            'description' => "Event '{$title}' removed by {$user->name}.",
        ]);

        return redirect()->route('events.index')->with('success', "Event '{$title}' removed.");
    }
}
