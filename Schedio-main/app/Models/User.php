<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use BelongsToTenant, HasFactory, Notifiable, SoftDeletes, \Laravel\Sanctum\HasApiTokens;

    public const ROLE_DEVELOPER = 'developer';
    public const ROLE_SUPER_ADMIN = 'super_admin';
    public const ROLE_BD_MANAGER = 'bd_manager';
    public const ROLE_BD = 'bd_rep';
    public const ROLE_MANAGER = 'manager';
    public const ROLE_EMPLOYEE = 'employee';
    public const ROLE_CLIENT = 'client';

    public const STATUS_PENDING = 'pending';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_REJECTED = 'rejected';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'company_id',
        'name',
        'title',
        'email',
        'phone',
        'password',
        'department_id',
        'role',
        'approval_status',
        'approved_at',
        'approved_by',
        'rejection_reason',
        'registration_notes',
        'avatar_url',
        'timezone',
        'notification_preferences',
        'is_active',
        'username',
        'booking_headline',
        'booking_bio',
        'booking_durations',
        'default_meeting_link',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'approved_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
            'notification_preferences' => 'array',
            'booking_durations' => 'array',
        ];
    }

    /**
     * Default notification preferences configuration.
     */
    public static function defaultNotificationPreferences(): array
    {
        return [
            'channels' => [
                'in_app' => true,
                'email' => true,
            ],
            'categories' => [
                'meeting_invitations' => ['in_app' => true, 'email' => true],
                'meeting_reminders' => ['in_app' => true, 'email' => true],
                'meeting_updates' => ['in_app' => true, 'email' => true],
                'meeting_cancellations' => ['in_app' => true, 'email' => true],
                'participant_responses' => ['in_app' => true, 'email' => false],
                'task_activity' => ['in_app' => true, 'email' => true],
            ],
        ];
    }

    /**
     * Get resolved notification preferences with fallbacks.
     */
    public function getPreferences(): array
    {
        $defaults = self::defaultNotificationPreferences();
        $userPrefs = $this->notification_preferences ?? [];

        return [
            'channels' => array_merge($defaults['channels'], $userPrefs['channels'] ?? []),
            'categories' => array_replace_recursive($defaults['categories'], $userPrefs['categories'] ?? []),
        ];
    }

    /**
     * Determine channels for a specific category based on preferences.
     *
     * @param string $category
     * @return array<string>
     */
    public function getNotificationChannelsFor(string $category): array
    {
        $prefs = $this->getPreferences();
        $channels = [];

        // Global master switches
        $inAppGlobal = $prefs['channels']['in_app'] ?? true;
        $emailGlobal = $prefs['channels']['email'] ?? true;

        $categoryConfig = $prefs['categories'][$category] ?? ['in_app' => true, 'email' => true];

        if ($inAppGlobal && ($categoryConfig['in_app'] ?? true)) {
            $channels[] = 'database';
        }

        if ($emailGlobal && ($categoryConfig['email'] ?? true)) {
            $channels[] = 'mail';
        }

        return $channels;
    }

    /**
     * Scope for pending approval requests.
     */
    public function scopePending(Builder $query): Builder
    {
        return $query->where('approval_status', self::STATUS_PENDING);
    }

    /**
     * Scope for approved users.
     */
    public function scopeApproved(Builder $query): Builder
    {
        return $query->where('approval_status', self::STATUS_APPROVED);
    }

    /**
     * Status & Role check helpers.
     */
    public function isDeveloper(): bool
    {
        return $this->role === self::ROLE_DEVELOPER;
    }

    public function isCompanySuperAdmin(): bool
    {
        return $this->role === self::ROLE_SUPER_ADMIN;
    }

    public function isSuperAdmin(): bool
    {
        return in_array($this->role, [self::ROLE_DEVELOPER, self::ROLE_SUPER_ADMIN], true);
    }

    public function isManager(): bool
    {
        return in_array($this->role, [self::ROLE_DEVELOPER, self::ROLE_SUPER_ADMIN, self::ROLE_MANAGER, self::ROLE_BD_MANAGER], true);
    }

    public function isBD(): bool
    {
        return in_array($this->role, [self::ROLE_DEVELOPER, self::ROLE_SUPER_ADMIN, self::ROLE_BD_MANAGER, self::ROLE_BD], true);
    }

    public function getRoleLabelAttribute(): string
    {
        return match ($this->role) {
            self::ROLE_DEVELOPER => 'Platform Developer',
            self::ROLE_SUPER_ADMIN => 'Company Super Admin (CEO)',
            self::ROLE_BD_MANAGER => 'BD Lead / Sales Manager',
            self::ROLE_BD => 'Business Developer (BD Rep)',
            self::ROLE_MANAGER => 'Department Manager',
            self::ROLE_CLIENT => 'Client / Partner',
            default => 'Team Member',
        };
    }

    public function isApproved(): bool
    {
        return $this->approval_status === self::STATUS_APPROVED;
    }

    public function isPending(): bool
    {
        return $this->approval_status === self::STATUS_PENDING;
    }

    /**
     * Retrieve the model for a bound value without tenant scoping so authorization controllers can verify ownership and return 403.
     */
    public function resolveRouteBinding($value, $field = null)
    {
        return $this->withoutGlobalScopes()->where($field ?? $this->getRouteKeyName(), $value)->first();
    }

    public function isRejected(): bool
    {
        return $this->approval_status === self::STATUS_REJECTED;
    }

    public function canLogin(): bool
    {
        if (! $this->is_active) {
            return false;
        }

        // Platform Developer can always log in
        if ($this->isDeveloper()) {
            return true;
        }

        // Must be approved by Developer (for Super Admin) or by Company Super Admin (for staff)
        if (! $this->isApproved()) {
            return false;
        }

        // If user belongs to a company, company must be active
        if ($this->company_id && $this->company && ! $this->company->isActive()) {
            return false;
        }

        return true;
    }

    /**
     * Company relationship.
     */
    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    /**
     * Approver relationship.
     */
    public function approver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    /**
     * Get the department the user belongs to.
     */
    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class);
    }

    /**
     * Meetings organized by this user.
     */
    public function organizedMeetings(): HasMany
    {
        return $this->hasMany(Meeting::class, 'organizer_id');
    }

    /**
     * Meeting participation pivot records.
     */
    public function meetingParticipants(): HasMany
    {
        return $this->hasMany(MeetingParticipant::class);
    }

    /**
     * Meetings this user participates in.
     */
    public function participatingMeetings(): BelongsToMany
    {
        return $this->belongsToMany(Meeting::class, 'meeting_participants')
            ->withPivot(['status', 'role', 'response_notes', 'responded_at'])
            ->withTimestamps();
    }

    /**
     * Calendar events created by or for this user.
     */
    public function events(): HasMany
    {
        return $this->hasMany(Event::class);
    }

    /**
     * Tasks assigned to this user.
     */
    public function assignedTasks(): HasMany
    {
        return $this->hasMany(Task::class, 'assigned_to');
    }

    /**
     * Tasks created by this user.
     */
    public function createdTasks(): HasMany
    {
        return $this->hasMany(Task::class, 'created_by');
    }

    /**
     * Reminders configured for this user.
     */
    public function reminders(): HasMany
    {
        return $this->hasMany(Reminder::class);
    }

    /**
     * Audit log actions performed by this user.
     */
    public function auditLogs(): HasMany
    {
        return $this->hasMany(AuditLog::class);
    }

    /**
     * Get booking durations offered by user.
     */
    public function getBookingDurations(): array
    {
        return !empty($this->booking_durations) ? $this->booking_durations : [15, 30, 45, 60];
    }

    /**
     * Get public booking URL for this user.
     */
    public function getPublicBookingUrl(): string
    {
        return route('booking.show', ['username' => $this->username ?: $this->id]);
    }
}
