<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable()->unique()->after('email');
            $table->string('booking_headline')->nullable()->after('title');
            $table->text('booking_bio')->nullable()->after('booking_headline');
            $table->json('booking_durations')->nullable()->after('booking_bio');
            $table->string('default_meeting_link')->nullable()->after('booking_durations');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'username',
                'booking_headline',
                'booking_bio',
                'booking_durations',
                'default_meeting_link',
            ]);
        });
    }
};
