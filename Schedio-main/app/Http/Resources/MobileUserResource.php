<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MobileUserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id, 'name' => $this->name, 'email' => $this->email,
            'phone' => $this->phone, 'title' => $this->title, 'role' => $this->role,
            'timezone' => $this->timezone ?: 'UTC', 'avatar_url' => $this->avatar_url,
            'company' => $this->company?->only(['id', 'name']),
            'department' => $this->department?->only(['id', 'name']),
            'approval_status' => $this->approval_status, 'is_active' => $this->is_active,
            'booking_url' => $this->getPublicBookingUrl(),
            'booking_username' => $this->username ?: (string) $this->id,
            'notification_preferences' => $this->getPreferences(),
            'can_administer' => $this->isSuperAdmin(),
            'can_manage_rooms' => $this->isSuperAdmin(),
        ];
    }
}
