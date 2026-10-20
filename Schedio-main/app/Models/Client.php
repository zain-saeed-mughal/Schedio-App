<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class Client extends Model
{
    use BelongsToTenant, HasFactory, SoftDeletes;

    public const STATUS_DISCOVERY = 'discovery';
    public const STATUS_SCHEDULED = 'scheduled';
    public const STATUS_PAPERWORK_ONBOARDING = 'paperwork_onboarding';
    public const STATUS_ONBOARDED = 'onboarded';
    public const STATUS_DEADEND = 'deadend';
    public const STATUS_PAUSE = 'pause';

    public const STATUSES = [
        self::STATUS_DISCOVERY => [
            'label' => 'Discovery',
            'bg' => 'bg-[#78350F]',
            'text' => 'text-amber-100',
            'border' => 'border-amber-600/40',
            'badge_style' => 'background-color: #6a2b07; color: #fef3c7; border: 1px solid #92400e;',
            'dot' => 'bg-amber-500',
        ],
        self::STATUS_SCHEDULED => [
            'label' => 'Scheduled',
            'bg' => 'bg-sky-200/90',
            'text' => 'text-sky-900',
            'border' => 'border-sky-300',
            'badge_style' => 'background-color: #bae6fd; color: #0369a1; border: 1px solid #7dd3fc;',
            'dot' => 'bg-sky-500',
        ],
        self::STATUS_PAPERWORK_ONBOARDING => [
            'label' => 'Paperwork/onboarding',
            'bg' => 'bg-blue-600',
            'text' => 'text-white',
            'border' => 'border-blue-500',
            'badge_style' => 'background-color: #1d4ed8; color: #ffffff; border: 1px solid #3b82f6;',
            'dot' => 'bg-blue-300',
        ],
        self::STATUS_ONBOARDED => [
            'label' => 'onboarded',
            'bg' => 'bg-emerald-700',
            'text' => 'text-emerald-50',
            'border' => 'border-emerald-600',
            'badge_style' => 'background-color: #166534; color: #ecfdf5; border: 1px solid #22c55e;',
            'dot' => 'bg-emerald-400',
        ],
        self::STATUS_DEADEND => [
            'label' => 'Deadend',
            'bg' => 'bg-red-700',
            'text' => 'text-white',
            'border' => 'border-red-600',
            'badge_style' => 'background-color: #b91c1c; color: #ffffff; border: 1px solid #ef4444;',
            'dot' => 'bg-rose-400',
        ],
        self::STATUS_PAUSE => [
            'label' => 'Pause',
            'bg' => 'bg-slate-200',
            'text' => 'text-slate-800',
            'border' => 'border-slate-300',
            'badge_style' => 'background-color: #e2e8f0; color: #1e293b; border: 1px solid #cbd5e1;',
            'dot' => 'bg-slate-400',
        ],
    ];

    protected $fillable = [
        'company_id',
        'company_name',
        'contact_name',
        'contact_email',
        'contact_phone',
        'contact_role',
        'campaign',
        'progress',
        'status',
        'assigned_to',
        'created_by',
        'deal_value',
        'notes',
        'last_activity_at',
    ];

    protected function casts(): array
    {
        return [
            'deal_value' => 'decimal:2',
            'last_activity_at' => 'datetime',
        ];
    }

    /**
     * BD Representative assigned to this client.
     */
    public function assignedTo(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    /**
     * User who added this client.
     */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * Meetings scheduled with this client.
     */
    public function meetings(): HasMany
    {
        return $this->hasMany(Meeting::class)->orderBy('start_time', 'desc');
    }

    /**
     * Next upcoming scheduled meeting.
     */
    public function upcomingMeeting(): HasOne
    {
        return $this->hasOne(Meeting::class)
            ->where('start_time', '>=', now())
            ->where('status', 'scheduled')
            ->oldestOfMany('start_time');
    }

    /**
     * Human readable status label.
     */
    public function getStatusLabelAttribute(): string
    {
        return self::STATUSES[$this->status]['label'] ?? ucfirst($this->status);
    }

    /**
     * Core 4-step linear pipeline order.
     */
    public const MAIN_PIPELINE = [
        self::STATUS_DISCOVERY,
        self::STATUS_SCHEDULED,
        self::STATUS_PAPERWORK_ONBOARDING,
        self::STATUS_ONBOARDED,
    ];

    /**
     * Get the next natural status in the sales pipeline.
     */
    public function getNextStatusAttribute(): ?string
    {
        return match ($this->status) {
            self::STATUS_DISCOVERY => self::STATUS_SCHEDULED,
            self::STATUS_SCHEDULED => self::STATUS_PAPERWORK_ONBOARDING,
            self::STATUS_PAPERWORK_ONBOARDING => self::STATUS_ONBOARDED,
            self::STATUS_PAUSE, self::STATUS_DEADEND => self::STATUS_DISCOVERY,
            default => null,
        };
    }

    /**
     * Action label for advancing to the next status.
     */
    public function getNextActionLabelAttribute(): ?string
    {
        return match ($this->status) {
            self::STATUS_DISCOVERY => 'Shift to Scheduled',
            self::STATUS_SCHEDULED => 'Advance to Paperwork',
            self::STATUS_PAPERWORK_ONBOARDING => 'Mark Onboarded',
            self::STATUS_PAUSE => 'Reactivate Deal',
            self::STATUS_DEADEND => 'Reopen Deal',
            default => null,
        };
    }

    /**
     * Pipeline step index (1-based for 4 core steps, 0 for pause/deadend).
     */
    public function getPipelineStepIndexAttribute(): int
    {
        return match ($this->status) {
            self::STATUS_DISCOVERY => 1,
            self::STATUS_SCHEDULED => 2,
            self::STATUS_PAPERWORK_ONBOARDING => 3,
            self::STATUS_ONBOARDED => 4,
            default => 0,
        };
    }

    /**
     * Status styling configuration array.
     */
    public function getStatusMetaAttribute(): array
    {
        return self::STATUSES[$this->status] ?? self::STATUSES[self::STATUS_DISCOVERY];
    }
}
