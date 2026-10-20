<?php

namespace App\Http\Resources;

use App\Models\{Meeting, Client, Room, Event, Task, MeetingNote};
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MobileRecordResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $record = $this->resource;
        $data = $record->attributesToArray();
        unset($data['deleted_at']);
        $user = $request->user();
        $data['can_manage'] = $user->isSuperAdmin() || match (true) {
            $record instanceof Meeting => $record->organizer_id === $user->id,
            $record instanceof Client, $record instanceof Task =>
                $record->assigned_to === $user->id || $record->created_by === $user->id,
            $record instanceof Event => $record->user_id === $user->id,
            $record instanceof MeetingNote => $record->user_id === $user->id || $record->meeting?->organizer_id === $user->id,
            default => false,
        };
        foreach (['organizer', 'assignee', 'creator', 'assignedTo', 'author', 'department', 'room'] as $relation) {
            if ($record->relationLoaded($relation)) {
                $data[$relation] = $record->$relation?->only(['id', 'name']);
            }
        }
        if ($record instanceof Meeting && $record->relationLoaded('participants')) {
            $data['participants'] = $record->participants->map(fn ($p) => [
                'id' => $p->id, 'name' => $p->name, 'status' => $p->pivot->status, 'role' => $p->pivot->role,
            ]);
            $data['can_rsvp'] = $record->participants->contains('id', $user->id);
        }
        return $data;
    }
}
