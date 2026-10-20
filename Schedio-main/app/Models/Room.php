<?php

namespace App\Models;

use App\Traits\BelongsToTenant;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Room extends Model
{
    use BelongsToTenant, HasFactory, SoftDeletes;

    protected $fillable = [
        'company_id',
        'name',
        'code',
        'location',
        'capacity',
        'amenities',
        'color',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'capacity' => 'integer',
            'amenities' => 'array',
            'is_active' => 'boolean',
        ];
    }

    /**
     * Meetings scheduled in this room.
     */
    public function meetings(): HasMany
    {
        return $this->hasMany(Meeting::class);
    }
}
