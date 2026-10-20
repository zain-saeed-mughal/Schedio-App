<?php

namespace App\Traits;

use App\Models\Company;
use App\Scopes\CompanyScope;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Auth;

trait BelongsToTenant
{
    /**
     * Boot the trait and register global tenant scope.
     */
    public static function bootBelongsToTenant(): void
    {
        static::addGlobalScope(new CompanyScope);

        static::creating(function ($model) {
            if (empty($model->company_id)) {
                if (Auth::check() && Auth::user()->company_id) {
                    $model->company_id = Auth::user()->company_id;
                } elseif (! empty($model->created_by)) {
                    $model->company_id = \App\Models\User::withoutGlobalScopes()->where('id', $model->created_by)->value('company_id');
                } elseif (! empty($model->user_id)) {
                    $model->company_id = \App\Models\User::withoutGlobalScopes()->where('id', $model->user_id)->value('company_id');
                } elseif (! empty($model->organizer_id)) {
                    $model->company_id = \App\Models\User::withoutGlobalScopes()->where('id', $model->organizer_id)->value('company_id');
                } elseif (! empty($model->assigned_to)) {
                    $model->company_id = \App\Models\User::withoutGlobalScopes()->where('id', $model->assigned_to)->value('company_id');
                } elseif (app()->runningUnitTests()) {
                    $firstCompany = Company::first();
                    if (! $firstCompany && ! ($model instanceof Company)) {
                        $firstCompany = Company::create([
                            'name' => 'Default Test Company',
                            'domain' => 'test-company.local',
                            'status' => Company::STATUS_ACTIVE,
                        ]);
                    }
                    $model->company_id = $firstCompany?->id;
                }
            }
        });
    }

    /**
     * Company relationship.
     */
    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }
}
