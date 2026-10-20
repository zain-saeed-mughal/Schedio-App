<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Company;
use App\Models\Department;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

class RegistrationRequestController extends Controller
{
    /**
     * Display listing of pending, approved, and rejected registration requests.
     */
    public function index(Request $request): View
    {
        $admin = Auth::user();
        $status = $request->query('status', User::STATUS_PENDING);
        $type = $request->query('type', 'all');

        $query = User::withoutGlobalScopes()->with(['company', 'department', 'approver'])
            ->where('role', '!=', User::ROLE_DEVELOPER);

        if (! $admin->isDeveloper()) {
            // Company Super Admin can only see registration requests for their own company
            $query->where('company_id', $admin->company_id)
                ->where('role', '!=', User::ROLE_SUPER_ADMIN);
        } else {
            // Platform Developer can view all or filter by type
            if ($type === 'companies') {
                $query->where('role', User::ROLE_SUPER_ADMIN);
            } elseif ($type === 'staff') {
                $query->where('role', '!=', User::ROLE_SUPER_ADMIN);
            }
        }

        if (in_array($status, [User::STATUS_PENDING, User::STATUS_APPROVED, User::STATUS_REJECTED], true)) {
            $query->where('approval_status', $status);
        }

        $requests = $query->latest()->paginate(15)->withQueryString();

        // Calculate count metrics scoped by admin authority
        $countsQuery = User::withoutGlobalScopes()->where('role', '!=', User::ROLE_DEVELOPER);
        if (! $admin->isDeveloper()) {
            $countsQuery->where('company_id', $admin->company_id)
                ->where('role', '!=', User::ROLE_SUPER_ADMIN);
        } elseif ($type === 'companies') {
            $countsQuery->where('role', User::ROLE_SUPER_ADMIN);
        } elseif ($type === 'staff') {
            $countsQuery->where('role', '!=', User::ROLE_SUPER_ADMIN);
        }

        $counts = [
            'pending' => (clone $countsQuery)->where('approval_status', User::STATUS_PENDING)->count(),
            'approved' => (clone $countsQuery)->where('approval_status', User::STATUS_APPROVED)->count(),
            'rejected' => (clone $countsQuery)->where('approval_status', User::STATUS_REJECTED)->count(),
        ];

        // Developer company counts
        $pendingCompanyCount = $admin->isDeveloper()
            ? User::withoutGlobalScopes()->where('role', User::ROLE_SUPER_ADMIN)->where('approval_status', User::STATUS_PENDING)->count()
            : 0;

        $departments = Department::where('is_active', true)->orderBy('name')->get();

        return view('admin.registration-requests.index', compact('requests', 'counts', 'status', 'type', 'departments', 'admin', 'pendingCompanyCount'));
    }

    /**
     * Approve a pending user or company super admin registration request.
     */
    public function approve(Request $request, User $user): RedirectResponse
    {
        $admin = Auth::user();

        // Authorization check: non-developers can only approve requests in their own company
        if (! $admin->isDeveloper() && $user->company_id !== $admin->company_id) {
            abort(403, 'Unauthorized. You can only authorize staff in your own company.');
        }

        // Only Developer can approve a Company Super Admin
        if ($user->isCompanySuperAdmin() && ! $admin->isDeveloper()) {
            abort(403, 'Unauthorized. Only Platform Developer can authorize new Company Super Admins.');
        }

        $validated = $request->validate([
            'role' => ['nullable', 'string', 'in:super_admin,manager,employee,client'],
            'department_id' => ['nullable', 'exists:departments,id'],
            'title' => ['nullable', 'string', 'max:150'],
        ]);

        $oldStatus = $user->approval_status;
        $roleToSet = $validated['role'] ?? $user->role;

        $user->update([
            'role' => $roleToSet,
            'department_id' => $validated['department_id'] ?? $user->department_id,
            'title' => $validated['title'] ?? $user->title,
            'approval_status' => User::STATUS_APPROVED,
            'approved_at' => now(),
            'approved_by' => $admin->id,
            'rejection_reason' => null,
            'is_active' => true,
        ]);

        // If approving a Company Super Admin, activate their company workspace!
        if ($user->isCompanySuperAdmin() && $user->company_id) {
            $company = Company::find($user->company_id);
            if ($company) {
                $company->update(['status' => Company::STATUS_ACTIVE]);
            }
        }

        // Audit log
        AuditLog::create([
            'company_id' => $user->company_id,
            'user_id' => $admin->id,
            'action' => 'user_approved',
            'auditable_type' => User::class,
            'auditable_id' => $user->id,
            'description' => "{$admin->role_label} {$admin->name} approved registration for {$user->name} ({$user->email}) with role {$user->role}.",
            'old_values' => ['approval_status' => $oldStatus],
            'new_values' => [
                'approval_status' => User::STATUS_APPROVED,
                'role' => $user->role,
                'approved_by' => $admin->id,
            ],
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        $msg = $user->isCompanySuperAdmin()
            ? "Company workspace and Super Admin account for {$user->name} ({$user->company?->name}) has been activated successfully!"
            : "Registration request for {$user->name} was approved successfully.";

        return back()->with('success', $msg);
    }

    /**
     * Reject a user or company super admin registration request.
     */
    public function reject(Request $request, User $user): RedirectResponse
    {
        $admin = Auth::user();

        if (! $admin->isDeveloper() && $user->company_id !== $admin->company_id) {
            abort(403, 'Unauthorized. You can only manage staff in your own company.');
        }

        if ($user->isCompanySuperAdmin() && ! $admin->isDeveloper()) {
            abort(403, 'Unauthorized. Only Platform Developer can reject Company Super Admins.');
        }

        $validated = $request->validate([
            'rejection_reason' => ['nullable', 'string', 'max:500'],
        ]);

        $oldStatus = $user->approval_status;

        $user->update([
            'approval_status' => User::STATUS_REJECTED,
            'rejection_reason' => $validated['rejection_reason'] ?? 'Registration criteria not met.',
            'approved_at' => null,
            'approved_by' => $admin->id,
        ]);

        // If Company Super Admin was rejected, reject the company
        if ($user->isCompanySuperAdmin() && $user->company_id) {
            $company = Company::find($user->company_id);
            if ($company) {
                $company->update(['status' => Company::STATUS_REJECTED]);
            }
        }

        // Audit log
        AuditLog::create([
            'company_id' => $user->company_id,
            'user_id' => $admin->id,
            'action' => 'user_rejected',
            'auditable_type' => User::class,
            'auditable_id' => $user->id,
            'description' => "{$admin->role_label} {$admin->name} rejected registration for {$user->name} ({$user->email}).",
            'old_values' => ['approval_status' => $oldStatus],
            'new_values' => [
                'approval_status' => User::STATUS_REJECTED,
                'rejection_reason' => $user->rejection_reason,
            ],
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
        ]);

        return back()->with('success', "Registration request for {$user->name} was marked as rejected.");
    }
}
