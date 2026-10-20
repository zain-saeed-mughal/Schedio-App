<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Client;
use App\Models\Meeting;
use App\Models\MeetingParticipant;
use App\Models\User;
use App\Services\NotificationDispatchService;
use App\Services\ReminderEngineService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

class ClientController extends Controller
{
    /**
     * Display the BD Client & Deal Pipeline (Kanban Board & Spreadsheet views).
     */
    public function index(Request $request): View
    {
        $user = Auth::user();
        $query = Client::with(['assignedTo', 'upcomingMeeting', 'meetings'])->latest('last_activity_at');

        // Strict Data Isolation: Standard users ONLY see their own assigned/created deals
        if (!$user->isSuperAdmin()) {
            $query->where(function ($q) use ($user) {
                $q->where('assigned_to', $user->id)
                  ->orWhere('created_by', $user->id);
            });
        }

        // Search filter
        if ($request->filled('search')) {
            $term = '%' . trim($request->search) . '%';
            $query->where(function ($q) use ($term) {
                $q->where('company_name', 'like', $term)
                  ->orWhere('contact_name', 'like', $term)
                  ->orWhere('contact_email', 'like', $term)
                  ->orWhere('campaign', 'like', $term)
                  ->orWhere('progress', 'like', $term);
            });
        }

        // Campaign filter
        if ($request->filled('campaign') && $request->campaign !== 'all') {
            $query->where('campaign', $request->campaign);
        }

        // Assigned BD filter (Developer can filter by rep; regular users see only theirs)
        if ($user->isSuperAdmin() && $request->filled('assigned_to') && $request->assigned_to !== 'all') {
            $query->where('assigned_to', $request->assigned_to);
        }

        // Status filter (for sheet view or filtering board)
        if ($request->filled('status') && $request->status !== 'all') {
            $query->where('status', $request->status);
        }

        $allClients = $query->get();

        // Group by status for the visual Pipeline/Kanban columns
        $clientsByStatus = [
            Client::STATUS_DISCOVERY => $allClients->where('status', Client::STATUS_DISCOVERY),
            Client::STATUS_SCHEDULED => $allClients->where('status', Client::STATUS_SCHEDULED),
            Client::STATUS_PAPERWORK_ONBOARDING => $allClients->where('status', Client::STATUS_PAPERWORK_ONBOARDING),
            Client::STATUS_ONBOARDED => $allClients->where('status', Client::STATUS_ONBOARDED),
            Client::STATUS_DEADEND => $allClients->where('status', Client::STATUS_DEADEND),
            Client::STATUS_PAUSE => $allClients->where('status', Client::STATUS_PAUSE),
        ];

        // Overall pipeline metrics scoped strictly to authorized user
        $metricsBase = Client::query();
        if (!$user->isSuperAdmin()) {
            $metricsBase->where(function ($q) use ($user) {
                $q->where('assigned_to', $user->id)
                  ->orWhere('created_by', $user->id);
            });
        }

        $metrics = [
            'total_clients' => (clone $metricsBase)->count(),
            'total_pipeline_value' => (clone $metricsBase)->sum('deal_value') ?? 0,
            'discovery_count' => (clone $metricsBase)->where('status', Client::STATUS_DISCOVERY)->count(),
            'scheduled_count' => (clone $metricsBase)->where('status', Client::STATUS_SCHEDULED)->count(),
            'paperwork_count' => (clone $metricsBase)->where('status', Client::STATUS_PAPERWORK_ONBOARDING)->count(),
            'onboarded_count' => (clone $metricsBase)->where('status', Client::STATUS_ONBOARDED)->count(),
            'deadend_count' => (clone $metricsBase)->where('status', Client::STATUS_DEADEND)->count(),
            'pause_count' => (clone $metricsBase)->where('status', Client::STATUS_PAUSE)->count(),
        ];

        $campaigns = Client::whereNotNull('campaign')
            ->when(!$user->isSuperAdmin(), fn($q) => $q->where(fn($sub) => $sub->where('assigned_to', $user->id)->orWhere('created_by', $user->id)))
            ->distinct()
            ->pluck('campaign')
            ->filter()
            ->values();

        $bdUsers = $user->isSuperAdmin()
            ? User::where('approval_status', User::STATUS_APPROVED)->orderBy('name')->get()
            : collect([$user]);

        return view('clients.index', compact(
            'allClients',
            'clientsByStatus',
            'metrics',
            'campaigns',
            'bdUsers',
            'user'
        ));
    }

    /**
     * Store a newly created client.
     */
    public function store(Request $request): RedirectResponse
    {
        $user = Auth::user();

        $validated = $request->validate([
            'company_name' => ['required', 'string', 'max:255'],
            'contact_name' => ['required', 'string', 'max:255'],
            'contact_email' => ['nullable', 'email', 'max:255'],
            'contact_phone' => ['nullable', 'string', 'max:50'],
            'contact_role' => ['nullable', 'string', 'max:100'],
            'campaign' => ['nullable', 'string', 'max:100'],
            'progress' => ['nullable', 'string'],
            'status' => ['required', 'string', 'in:discovery,scheduled,paperwork_onboarding,onboarded,deadend,pause'],
            'deal_value' => ['nullable', 'numeric', 'min:0'],
            'assigned_to' => ['nullable', 'exists:users,id'],
            'notes' => ['nullable', 'string'],
        ]);

        // Standard users always own their newly created deals
        $assignedTo = $user->isSuperAdmin() ? ($validated['assigned_to'] ?? $user->id) : $user->id;

        $client = Client::create([
            ...$validated,
            'created_by' => $user->id,
            'assigned_to' => $assignedTo,
            'last_activity_at' => now(),
        ]);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'client_created',
            'auditable_type' => Client::class,
            'auditable_id' => $client->id,
            'description' => "Client '{$client->company_name}' ({$client->contact_name}) added by {$user->name}.",
            'new_values' => $client->toArray(),
        ]);

        return redirect()->route('clients.index')->with('success', "Client '{$client->company_name}' added to BD Pipeline.");
    }

    /**
     * Display specific client details, scheduled meetings, and activity.
     */
    public function show(Client $client): View
    {
        $user = Auth::user();

        // Data isolation guard
        if (!$user->isSuperAdmin() && $client->assigned_to !== $user->id && $client->created_by !== $user->id) {
            abort(403, 'Unauthorized access to this deal.');
        }

        $client->load(['assignedTo', 'creator', 'meetings.organizer', 'meetings.participantRecords']);
        $bdUsers = $user->isSuperAdmin()
            ? User::where('approval_status', User::STATUS_APPROVED)->orderBy('name')->get()
            : collect([$user]);

        return view('clients.show', compact('client', 'bdUsers'));
    }

    /**
     * Update client details.
     */
    public function update(Request $request, Client $client): RedirectResponse
    {
        $user = Auth::user();

        if (!$user->isSuperAdmin() && $client->assigned_to !== $user->id && $client->created_by !== $user->id) {
            abort(403, 'Unauthorized access to this deal.');
        }

        $validated = $request->validate([
            'company_name' => ['required', 'string', 'max:255'],
            'contact_name' => ['required', 'string', 'max:255'],
            'contact_email' => ['nullable', 'email', 'max:255'],
            'contact_phone' => ['nullable', 'string', 'max:50'],
            'contact_role' => ['nullable', 'string', 'max:100'],
            'campaign' => ['nullable', 'string', 'max:100'],
            'progress' => ['nullable', 'string'],
            'status' => ['required', 'string', 'in:discovery,scheduled,paperwork_onboarding,onboarded,deadend,pause'],
            'deal_value' => ['nullable', 'numeric', 'min:0'],
            'assigned_to' => ['nullable', 'exists:users,id'],
            'notes' => ['nullable', 'string'],
        ]);

        $oldValues = $client->toArray();

        // Standard user cannot reassign deals away from themselves
        if (!$user->isSuperAdmin()) {
            unset($validated['assigned_to']);
        }

        $client->update([
            ...$validated,
            'last_activity_at' => now(),
        ]);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'client_updated',
            'auditable_type' => Client::class,
            'auditable_id' => $client->id,
            'description' => "Client '{$client->company_name}' updated by {$user->name}.",
            'old_values' => $oldValues,
            'new_values' => $client->toArray(),
        ]);

        return back()->with('success', "Client '{$client->company_name}' updated successfully.");
    }

    /**
     * Update client status (quick 1-click status change or pipeline drag-and-drop).
     */
    public function updateStatus(Request $request, Client $client): JsonResponse|RedirectResponse
    {
        $user = Auth::user();

        if (!$user->isSuperAdmin() && $client->assigned_to !== $user->id && $client->created_by !== $user->id) {
            if ($request->wantsJson() || $request->ajax()) {
                return response()->json(['success' => false, 'message' => 'Unauthorized deal.'], 403);
            }
            abort(403, 'Unauthorized access to this deal.');
        }

        $validated = $request->validate([
            'status' => ['required', 'string', 'in:discovery,scheduled,paperwork_onboarding,onboarded,deadend,pause'],
            'progress' => ['nullable', 'string', 'max:500'],
            'deal_value' => ['nullable', 'numeric', 'min:0'],
            'notes' => ['nullable', 'string'],
        ]);

        $oldStatus = $client->status;
        $newStatus = $validated['status'];

        $updateData = [
            'status' => $newStatus,
            'last_activity_at' => now(),
        ];

        if (array_key_exists('progress', $validated) && $validated['progress'] !== null) {
            $updateData['progress'] = $validated['progress'];
        }

        if (array_key_exists('deal_value', $validated) && $validated['deal_value'] !== null) {
            $updateData['deal_value'] = $validated['deal_value'];
        }

        if (array_key_exists('notes', $validated) && $validated['notes'] !== null) {
            $updateData['notes'] = $validated['notes'];
        }

        $client->update($updateData);

        AuditLog::create([
            'user_id' => $user->id,
            'action' => 'client_status_changed',
            'auditable_type' => Client::class,
            'auditable_id' => $client->id,
            'description' => "Pipeline stage for '{$client->company_name}' advanced from " . (Client::STATUSES[$oldStatus]['label'] ?? $oldStatus) . " to " . ($client->status_label) . " by {$user->name}.",
            'old_values' => ['status' => $oldStatus],
            'new_values' => ['status' => $newStatus, 'progress' => $client->progress],
        ]);

        if ($request->wantsJson() || $request->ajax()) {
            $metricsBase = Client::query();
            if (!$user->isSuperAdmin()) {
                $metricsBase->where(function ($q) use ($user) {
                    $q->where('assigned_to', $user->id)
                      ->orWhere('created_by', $user->id);
                });
            }

            $counts = [
                Client::STATUS_DISCOVERY => (clone $metricsBase)->where('status', Client::STATUS_DISCOVERY)->count(),
                Client::STATUS_SCHEDULED => (clone $metricsBase)->where('status', Client::STATUS_SCHEDULED)->count(),
                Client::STATUS_PAPERWORK_ONBOARDING => (clone $metricsBase)->where('status', Client::STATUS_PAPERWORK_ONBOARDING)->count(),
                Client::STATUS_ONBOARDED => (clone $metricsBase)->where('status', Client::STATUS_ONBOARDED)->count(),
                Client::STATUS_DEADEND => (clone $metricsBase)->where('status', Client::STATUS_DEADEND)->count(),
                Client::STATUS_PAUSE => (clone $metricsBase)->where('status', Client::STATUS_PAUSE)->count(),
            ];

            return response()->json([
                'success' => true,
                'client_id' => $client->id,
                'status' => $newStatus,
                'old_status' => $oldStatus,
                'label' => $client->status_label,
                'meta' => $client->status_meta,
                'next_status' => $client->next_status,
                'next_action_label' => $client->next_action_label,
                'pipeline_step_index' => $client->pipeline_step_index,
                'progress' => $client->progress,
                'deal_value' => $client->deal_value ? number_format($client->deal_value) : null,
                'counts' => $counts,
                'message' => "'{$client->company_name}' moved to {$client->status_label}.",
            ]);
        }

        return back()->with('success', "Status of '{$client->company_name}' updated to {$client->status_label}.");
    }

    /**
     * Schedule a meeting with this client and register automated reminders.
     */
    public function scheduleMeeting(Request $request, Client $client): RedirectResponse
    {
        $user = Auth::user();

        if (!$user->isSuperAdmin() && $client->assigned_to !== $user->id && $client->created_by !== $user->id) {
            abort(403, 'Unauthorized access to this deal.');
        }

        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'start_time' => ['required', 'date'],
            'end_time' => ['required', 'date', 'after:start_time'],
            'type' => ['required', 'string', 'in:in_person,virtual,hybrid'],
            'meeting_link' => ['nullable', 'url', 'max:255'],
            'reminder_minutes' => ['nullable', 'integer', 'in:0,5,10,15,30,60,1440'],
        ]);

        $startTime = Carbon::parse($validated['start_time']);
        $endTime = Carbon::parse($validated['end_time']);

        $meeting = DB::transaction(function () use ($validated, $user, $client, $startTime, $endTime) {
            $meeting = Meeting::create([
                'title' => $validated['title'],
                'description' => $validated['description'] ?? null,
                'organizer_id' => $user->id,
                'department_id' => $user->department_id,
                'client_id' => $client->id,
                'start_time' => $startTime,
                'end_time' => $endTime,
                'timezone' => $user->timezone ?? 'America/New_York',
                'status' => 'scheduled',
                'type' => $validated['type'],
                'meeting_link' => $validated['meeting_link'] ?? null,
                'location' => $validated['type'] === 'virtual' ? ($validated['meeting_link'] ?? 'Virtual Meeting') : 'In-Person',
                'is_private' => false,
                'metadata' => [
                    'is_client_meeting' => true,
                    'client_id' => $client->id,
                    'client_company' => $client->company_name,
                    'client_name' => $client->contact_name,
                    'client_email' => $client->contact_email,
                    'campaign' => $client->campaign,
                ],
            ]);

            // Add Organizer as Host
            MeetingParticipant::create([
                'meeting_id' => $meeting->id,
                'user_id' => $user->id,
                'role' => 'host',
                'status' => 'accepted',
                'responded_at' => now(),
            ]);

            // Automatically register reminders using Reminder Engine (15m, 1h before)
            $reminderMinutes = (int) ($validated['reminder_minutes'] ?? 15);
            if ($reminderMinutes > 0) {
                app(ReminderEngineService::class)->scheduleMeetingReminders(
                    $meeting,
                    $reminderMinutes,
                    'both'
                );
            }

            // If client was in Discovery, auto-advance to Scheduled
            if ($client->status === Client::STATUS_DISCOVERY) {
                $client->update([
                    'status' => Client::STATUS_SCHEDULED,
                    'progress' => "Meeting scheduled for {$startTime->format('M d, Y h:i A')}. Automatic reminders active.",
                    'last_activity_at' => now(),
                ]);
            } else {
                $client->update([
                    'last_activity_at' => now(),
                ]);
            }

            AuditLog::create([
                'user_id' => $user->id,
                'action' => 'client_meeting_scheduled',
                'auditable_type' => Meeting::class,
                'auditable_id' => $meeting->id,
                'description' => "Meeting scheduled with {$client->company_name} ({$client->contact_name}) by {$user->name}. Reminder set for {$reminderMinutes}m before.",
            ]);

            return $meeting;
        });

        return redirect()->route('clients.show', $client)->with('success', "Meeting scheduled for {$client->company_name}! Automated reminders have been armed.");
    }

    /**
     * Remove client.
     */
    public function destroy(Client $client): RedirectResponse
    {
        $user = Auth::user();

        if (!$user->isSuperAdmin() && $client->assigned_to !== $user->id && $client->created_by !== $user->id) {
            abort(403, 'Unauthorized access to this deal.');
        }

        $name = $client->company_name;
        $client->delete();

        return redirect()->route('clients.index')->with('success', "Client '{$name}' removed from pipeline.");
    }
}
