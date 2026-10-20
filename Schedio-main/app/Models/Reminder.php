<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class Reminder extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'title',
        'message',
        'remindable_type',
        'remindable_id',
        'remind_at',
        'channel',
        'status',
        'sent_at',
        'payload',
    ];

    protected function casts(): array
    {
        return [
            'remind_at' => 'datetime',
            'sent_at' => 'datetime',
            'payload' => 'array',
        ];
    }

    /**
     * The user this reminder is addressed to.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Polymorphic parent model (Meeting, Task, Event, etc.).
     */
    public function remindable(): MorphTo
    {
        return $this->morphTo();
    }
}
