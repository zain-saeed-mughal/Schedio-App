<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Company;
use App\Models\Department;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\View\View;

class AuthController extends Controller
{
    /**
     * Show login form.
     */
    public function showLogin(): View|RedirectResponse
    {
        if (Auth::check()) {
            return redirect()->route('dashboard');
        }

        return view('auth.login');
    }

    /**
     * Authenticate user.
     */
    public function login(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);

        $remember = $request->boolean('remember');

        $user = User::withoutGlobalScopes()->where('email', $credentials['email'])->first();

        if (!$user || !Hash::check($credentials['password'], $user->password)) {
            return back()->withInput($request->only('email', 'remember'))
                ->withErrors(['email' => 'The provided credentials do not match our records.']);
        }

        // Validate approval and company status
        if (!$user->canLogin()) {
            $msg = $user->isCompanySuperAdmin() && $user->isPending()
                ? 'Your company Super Admin registration is currently pending Developer approval.'
                : ($user->isPending()
                    ? 'Your account registration request is currently pending review.'
                    : ($user->isRejected()
                        ? 'Your registration request was rejected' . ($user->rejection_reason ? ": {$user->rejection_reason}" : '.')
                        : 'Your account or company workspace is currently inactive. Please contact the platform developer.'));

            return back()->withInput($request->only('email'))
                ->withErrors(['email' => $msg]);
        }

        Auth::login($user, $remember);
        $request->session()->regenerate();

        // Record audit log for login
        AuditLog::create([
            'company_id' => $user->company_id,
            'user_id' => $user->id,
            'action' => 'login',
            'auditable_type' => User::class,
            'auditable_id' => $user->id,
            'description' => "User {$user->name} ({$user->email}) logged into Schedio.",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'metadata' => ['role' => $user->role],
        ]);

        return redirect()->intended(route('dashboard'));
    }

    /**
     * Show registration request form.
     */
    public function showRegister(): View|RedirectResponse
    {
        if (Auth::check()) {
            return redirect()->route('dashboard');
        }

        $companies = Company::where('status', Company::STATUS_ACTIVE)->orderBy('name')->get();
        $departments = Department::withoutGlobalScopes()->where('is_active', true)->orderBy('name')->get();

        return view('auth.register', compact('companies', 'departments'));
    }

    /**
     * Submit new user registration request.
     */
    public function register(Request $request): RedirectResponse
    {
        $regType = $request->input('registration_type');
        if (! $regType) {
            $regType = $request->filled('company_name') ? 'company_super_admin' : 'employee';
        }

        $rules = [
            'registration_type' => ['nullable', 'string', 'in:company_super_admin,employee'],
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'confirmed', Password::defaults()],
            'title' => ['nullable', 'string', 'max:150'],
            'phone' => ['nullable', 'string', 'max:30'],
            'registration_notes' => ['nullable', 'string', 'max:1000'],
        ];

        if ($regType === 'company_super_admin') {
            $rules['company_name'] = ['required', 'string', 'max:255'];
        } else {
            $rules['company_id'] = ['nullable', 'exists:companies,id'];
            $rules['department_id'] = ['nullable', 'exists:departments,id'];
        }

        $validated = $request->validate($rules);

        if ($regType === 'company_super_admin') {
            // 1. Create Pending Company
            $company = Company::create([
                'name' => $validated['company_name'],
                'status' => Company::STATUS_PENDING,
            ]);

            // 2. Create Pending Super Admin (CEO) for this Company
            $user = User::create([
                'company_id' => $company->id,
                'name' => $validated['name'],
                'email' => $validated['email'],
                'password' => Hash::make($validated['password']),
                'title' => $validated['title'] ?: 'Chief Executive Officer (CEO)',
                'phone' => $validated['phone'] ?? null,
                'role' => User::ROLE_SUPER_ADMIN,
                'approval_status' => User::STATUS_PENDING,
                'registration_notes' => $validated['registration_notes'] ?? null,
                'is_active' => true,
                'timezone' => 'UTC',
            ]);

            $company->update(['created_by' => $user->id]);

            // Audit log for developer review
            AuditLog::create([
                'company_id' => $company->id,
                'user_id' => null,
                'action' => 'company_registration_requested',
                'auditable_type' => Company::class,
                'auditable_id' => $company->id,
                'description' => "Company Super Admin registration requested for '{$company->name}' by {$user->name} ({$user->email}). Routed to Developer for approval.",
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'new_values' => [
                    'company_name' => $company->name,
                    'ceo_name' => $user->name,
                    'ceo_email' => $user->email,
                ],
            ]);

            return redirect()->route('login')->with(
                'status',
                "Your registration request for '{$company->name}' has been submitted! The Platform Developer will review and activate your company workspace shortly."
            );
        }

        // Mode B: Employee joining existing company
        $companyId = $validated['company_id'] ?? Company::where('status', Company::STATUS_ACTIVE)->value('id');

        $user = User::create([
            'company_id' => $companyId,
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'title' => $validated['title'] ?? null,
            'department_id' => $validated['department_id'] ?? null,
            'phone' => $validated['phone'] ?? null,
            'role' => User::ROLE_EMPLOYEE,
            'approval_status' => User::STATUS_PENDING,
            'registration_notes' => $validated['registration_notes'] ?? null,
            'is_active' => true,
            'timezone' => 'UTC',
        ]);

        AuditLog::create([
            'company_id' => $user->company_id,
            'user_id' => null,
            'action' => 'registration_requested',
            'auditable_type' => User::class,
            'auditable_id' => $user->id,
            'description' => "Registration request submitted by {$user->name} ({$user->email}) for company ID {$user->company_id}.",
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'new_values' => [
                'name' => $user->name,
                'email' => $user->email,
                'department_id' => $user->department_id,
                'company_id' => $user->company_id,
            ],
        ]);

        return redirect()->route('login')->with(
            'status',
            'Your staff registration request has been submitted successfully! Your Company Super Admin will review and approve your account shortly.'
        );
    }

    /**
     * Logout user.
     */
    public function logout(Request $request): RedirectResponse
    {
        $user = Auth::user();

        if ($user) {
            AuditLog::create([
                'user_id' => $user->id,
                'action' => 'logout',
                'auditable_type' => User::class,
                'auditable_id' => $user->id,
                'description' => "User {$user->name} logged out.",
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
        }

        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
