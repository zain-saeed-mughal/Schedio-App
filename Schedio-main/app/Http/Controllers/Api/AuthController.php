<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\LoginRequest;
use App\Http\Resources\MobileUserResource;
use App\Models\{Company, Department, User};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\{DB, Hash};
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    public function login(LoginRequest $request)
    {
        $user = User::withoutGlobalScopes()->whereNull('deleted_at')->where('email', $request->email)->first();
        if (! $user || ! Hash::check($request->password, $user->password)) {
            return response()->json(['message' => 'The email or password is incorrect.'], 401);
        }
        if (! $user->canLogin()) {
            return response()->json([
                'message' => $user->rejection_reason ?: 'Your account or company is awaiting approval or inactive.',
                'account_status' => ! $user->is_active ? 'inactive' : $user->approval_status,
            ], 403);
        }
        return response()->json([
            'token' => $user->createToken($request->device_name, ['mobile'], now()->addDays(30))->plainTextToken,
            'user' => new MobileUserResource($user),
        ]);
    }

    public function me(Request $request) { return new MobileUserResource($request->user()); }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();
        return response()->json(['message' => 'Signed out.']);
    }

    public function options()
    {
        return response()->json(['data' => [
            'companies' => Company::where('status', Company::STATUS_ACTIVE)->get(['id', 'name']),
            'departments' => Department::withoutGlobalScopes()->whereNull('deleted_at')
                ->where('is_active', true)->whereHas('company', fn ($q) => $q->where('status', 'active'))
                ->get(['id', 'company_id', 'name']),
        ]]);
    }

    public function register(Request $request)
    {
        $type = $request->input('registration_type', 'employee');
        $request->validate([
            'registration_type' => ['required', Rule::in(['employee', 'company_super_admin'])],
            'company_id' => [Rule::requiredIf($type === 'employee'), 'nullable',
                Rule::exists('companies', 'id')->where('status', 'active')],
            'department_id' => ['nullable', Rule::exists('departments', 'id')
                ->where('company_id', $request->company_id)->where('is_active', true)->whereNull('deleted_at')],
        ]);
        // Reuse the established registration workflow and its validation/audit behavior.
        $request->merge(['title' => $request->input('title')]);
        DB::transaction(fn () => app(\App\Http\Controllers\Auth\AuthController::class)->register($request));
        return response()->json(['message' => 'Registration submitted for approval.', 'account_status' => 'pending'], 201);
    }
}
