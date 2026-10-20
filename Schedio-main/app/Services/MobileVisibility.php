<?php

namespace App\Services;

use App\Models\{Meeting, Client, Task, Event, User};
use Illuminate\Database\Eloquent\Builder;

class MobileVisibility
{
    public function meetings(User $user): Builder
    {
        return Meeting::query()->when(! $user->isSuperAdmin(), fn ($q) =>
            $q->where(fn ($q) => $q->where('organizer_id', $user->id)
                ->orWhereHas('participants', fn ($p) => $p->where('users.id', $user->id))));
    }
    public function clients(User $user): Builder
    {
        return Client::query()->when(! $user->isSuperAdmin(), fn ($q) =>
            $q->where(fn ($q) => $q->where('assigned_to', $user->id)->orWhere('created_by', $user->id)));
    }
    public function tasks(User $user): Builder
    {
        return Task::query()->when(! $user->isSuperAdmin(), fn ($q) =>
            $q->where(fn ($q) => $q->where('assigned_to', $user->id)->orWhere('created_by', $user->id)));
    }
    public function events(User $user): Builder
    {
        return Event::query()->when(! $user->isSuperAdmin(), fn ($q) =>
            $q->where(function ($q) use ($user) {
                $q->where('user_id', $user->id)->orWhere('is_company_wide', true);
                if ($user->department_id) { $q->orWhere('department_id', $user->department_id); }
            }));
    }
}
