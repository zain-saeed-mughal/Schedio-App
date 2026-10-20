<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class MobileAccess
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();
        if (! $user || $user->trashed() || ! $user->canLogin()) {
            return response()->json([
                'message' => 'Your account or company is not currently active and approved.',
                'account_status' => $user?->is_active ? $user->approval_status : 'inactive',
            ], 403);
        }
        return $next($request);
    }
}
