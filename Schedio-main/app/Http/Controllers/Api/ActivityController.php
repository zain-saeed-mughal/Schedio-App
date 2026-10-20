<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\{Department, User};
use App\Services\MobileVisibility;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ActivityController extends Controller
{
    public function notifications(Request $request)
    {
        $query = $request->user()->notifications()->latest();
        if ($request->input('status') === 'unread') { $query->whereNull('read_at'); }
        return response()->json([...$query->paginate(25)->toArray(), 'server_time' => now()->toIso8601String()]);
    }

    public function notification(Request $request, ?string $id = null, ?string $action = null)
    {
        $controller = app(\App\Http\Controllers\NotificationController::class);
        if ($action === 'mark-all-read') { return $controller->markAllAsRead($request); }
        if ($action === 'read') { return $controller->markAsRead($request, $id); }
        if ($action === 'unread') { return $controller->markAsUnread($request, $id); }
        return $controller->destroy($request, $id);
    }

    public function markAllRead(Request $request)
    {
        return app(\App\Http\Controllers\NotificationController::class)->markAllAsRead($request);
    }

    public function preferences(Request $request)
    {
        $request->validate(['channel_in_app' => 'required|boolean', 'channel_email' => 'required|boolean',
            'categories' => 'required|array', 'categories.*' => 'array',
            'categories.*.in_app' => 'required|boolean', 'categories.*.email' => 'required|boolean']);
        app(\App\Http\Controllers\NotificationController::class)->updatePreferences($request);
        return response()->json(['data' => $request->user()->fresh()->getPreferences()]);
    }

    private function requestsQuery(Request $request)
    {
        $admin = $request->user();
        abort_unless($admin->isSuperAdmin(), 403);
        return User::withoutGlobalScopes()->whereNull('deleted_at')->where('role', '!=', User::ROLE_DEVELOPER)
            ->when(! $admin->isDeveloper(), fn ($q) => $q->where('company_id', $admin->company_id)
                ->where('role', '!=', User::ROLE_SUPER_ADMIN));
    }

    public function requests(Request $request)
    {
        return response()->json($this->requestsQuery($request)
            ->where('approval_status', $request->input('status', 'pending'))
            ->select(['id', 'name', 'email', 'title', 'role', 'company_id', 'department_id',
                'approval_status', 'registration_notes', 'created_at'])->latest()->paginate(25));
    }

    public function decide(Request $request, int $id, string $action)
    {
        $user = $this->requestsQuery($request)->findOrFail($id);
        abort_if($user->id === $request->user()->id, 403);
        abort_unless(in_array($action, ['approve', 'reject']), 404);
        if ($request->filled('role')) {
            $allowed = ['manager', 'employee', 'client'];
            if ($request->user()->isDeveloper()) { $allowed[] = 'super_admin'; }
            $request->validate(['role' => [Rule::in($allowed)]]);
        }
        if ($request->filled('department_id')) {
            abort_unless(Department::withoutGlobalScopes()->whereNull('deleted_at')
                ->where('company_id', $user->company_id)->whereKey($request->department_id)->exists(), 422);
        }
        DB::transaction(fn () => app(\App\Http\Controllers\Admin\RegistrationRequestController::class)->$action($request, $user));
        if ($action === 'reject') { $user->tokens()->delete(); }
        return response()->json(['message' => 'Registration request updated.']);
    }

    public function approvalOptions(Request $request, int $id)
    {
        $user = $this->requestsQuery($request)->findOrFail($id);
        return response()->json([
            'roles' => $request->user()->isDeveloper()
                ? ['super_admin', 'manager', 'employee', 'client'] : ['manager', 'employee', 'client'],
            'departments' => Department::withoutGlobalScopes()->whereNull('deleted_at')
                ->where('company_id', $user->company_id)->where('is_active', true)
                ->orderBy('name')->get(['id', 'name']),
        ]);
    }

    public function calendar(Request $request, MobileVisibility $visibility)
    {
        $request->validate(['start' => 'required|date', 'end' => 'required|date|after:start']);
        $start = \Carbon\Carbon::parse($request->start)->utc();
        $end = \Carbon\Carbon::parse($request->end)->utc();
        abort_if($start->diffInDays($end) > 93, 422, 'Choose a range of at most 93 days.');
        $result = [];
        foreach (['meeting' => $visibility->meetings($request->user())->where('status', '!=', 'cancelled'),
            'event' => $visibility->events($request->user())] as $type => $query) {
            foreach ($query->where('start_time', '<', $end)->where('end_time', '>', $start)->get() as $item) {
                $result[] = ['id' => $item->id, 'entity_type' => $type, 'title' => $item->title,
                    'start_time' => $item->start_time->toIso8601String(),
                    'end_time' => $item->end_time->toIso8601String(),
                    'is_all_day' => (bool) $item->is_all_day];
            }
        }
        return response()->json(['data' => $result]);
    }
}
