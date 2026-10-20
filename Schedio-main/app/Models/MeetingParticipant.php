<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MeetingParticipant extends Model
{
    use HasFactory;

    protected $table = 'meeting_participants';

    protected $fillable = [
        'meeting_id',
        'user_id',
        'status',
        'role',
        'response_notes',
        'responded_at',
    ];

    protected function casts(): array
    {
        return [
            'responded_at' => 'datetime',
        ];
    }

    /**
     * The meeting being attended.
     */
    public function meeting(): BelongsTo
    {
        return $this->belongsTo(Meeting::class);
    }

    /**
     * The participant user.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
