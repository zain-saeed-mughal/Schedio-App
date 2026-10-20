<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Meeting extends Model
{
    use BelongsToTenant, HasFactory, SoftDeletes;

    protected $fillable = [
        'company_id',
        'title',
        'description',
        'organizer_id',
        'department_id',
        'room_id',
        'client_id',
        'start_time',
        'end_time',
        'timezone',
        'status',
        'type',
        'meeting_link',
        'location',
        'is_private',
        'recurrence',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'start_time' => 'datetime',
            'end_time' => 'datetime',
            'is_private' => 'boolean',
            'recurrence' => 'array',
            'metadata' => 'array',
        ];
    }

    /**
     * User organizing this meeting.
     */
    public function organizer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'organizer_id');
    }

    /**
     * Client / Deal company this meeting is held with.
     */
    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class);
    }

    /**
     * Department associated with this meeting.
     */
    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class);
    }

    /**
     * Physical room reserved for this meeting.
     */
    public function room(): BelongsTo
    {
        return $this->belongsTo(Room::class);
    }

    /**
     * Meeting participant pivot records.
     */
    public function participantRecords(): HasMany
    {
        return $this->hasMany(MeetingParticipant::class);
    }

    /**
     * Users invited or participating in this meeting.
     */
    public function participants(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'meeting_participants')
            ->withPivot(['status', 'role', 'response_notes', 'responded_at'])
            ->withTimestamps();
    }

    /**
     * Follow-up action items/tasks generated from this meeting.
     */
    public function tasks(): HasMany
    {
        return $this->hasMany(Task::class);
    }

    /**
     * Meeting notes, discussions, decisions, and agendas.
     */
    public function notes(): HasMany
    {
        return $this->hasMany(MeetingNote::class);
    }

    /**
     * Polymorphic reminders for this meeting.
     */
    public function reminders(): MorphMany
    {
        return $this->morphMany(Reminder::class, 'remindable');
    }

    /**
     * Polymorphic audit trail entries for this meeting.
     */
    public function auditLogs(): MorphMany
    {
        return $this->morphMany(AuditLog::class, 'auditable');
    }
}
