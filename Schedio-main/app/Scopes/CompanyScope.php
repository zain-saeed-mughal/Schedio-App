<?php

namespace App\Scopes;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Scope;
use Illuminate\Support\Facades\Auth;

class CompanyScope implements Scope
{
    /**
     * Re-entrancy guard to prevent infinite loops when Auth::user() resolves the current user model.
     */
    protected static bool $resolvingUser = false;

    /**
     * Apply the scope to a given Eloquent query builder.
     */
    public function apply(Builder $builder, Model $model): void
    {
        if (static::$resolvingUser) {
            return;
        }

        static::$resolvingUser = true;

        try {
            // Don't enforce in CLI / Console unless an auth user is simulated
            if (app()->runningInConsole() && ! Auth::check()) {
                return;
            }

            // If no user is authenticated (e.g. public booking guest), allow model lookup
            if (! Auth::check()) {
                return;
            }

            $user = Auth::user();
            if (! $user) {
                return;
            }

            // Platform Developer has global master access across all companies
            if (method_exists($user, 'isDeveloper') && $user->isDeveloper()) {
                return;
            }

            // Tenant-scoped user or Company Super Admin
            if ($user->company_id) {
                $builder->where($model->getTable() . '.company_id', $user->company_id);
            } else {
                // Unassigned user gets zero records
                $builder->whereRaw('1 = 0');
            }
        } finally {
            static::$resolvingUser = false;
        }
    }
}
