<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsApproved
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = Auth::user();

        if (!$user) {
            return redirect()->route('login');
        }

        // Platform Developer always has access
        if ($user->isDeveloper()) {
            return $next($request);
        }

        // Check if user is approved
        if (!$user->isApproved() || !$user->is_active) {
            Auth::logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            $message = $user->isCompanySuperAdmin()
                ? 'Your company Super Admin registration is currently pending Developer approval.'
                : ($user->isPending()
                    ? 'Your registration request is currently pending review.'
                    : ($user->isRejected()
                        ? 'Your registration request was rejected' . ($user->rejection_reason ? ': ' . $user->rejection_reason : '.')
                        : 'Your account is currently inactive. Please contact the administrator.'));

            return redirect()->route('login')->withErrors(['email' => $message]);
        }

        // If user belongs to a company, ensure the company is active
        if ($user->company_id && $user->company && ! $user->company->isActive()) {
            Auth::logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()->route('login')->withErrors([
                'email' => 'Your company workspace is currently ' . $user->company->status . '. Please contact the platform developer.',
            ]);
        }

        return $next($request);
    }
}
