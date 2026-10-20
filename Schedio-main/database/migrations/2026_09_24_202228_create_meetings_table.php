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
        Schema::create('meetings', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('description')->nullable();
            $table->foreignId('organizer_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('department_id')->nullable()->constrained('departments')->nullOnDelete();
            $table->foreignId('room_id')->nullable()->constrained('rooms')->nullOnDelete();
            $table->dateTimeTz('start_time')->index();
            $table->dateTimeTz('end_time')->index();
            $table->string('timezone', 50)->default('UTC');
            $table->string('status', 30)->default('scheduled')->index(); // scheduled, in_progress, completed, cancelled, rescheduled
            $table->string('type', 30)->default('in_person'); // in_person, virtual, hybrid
            $table->string('meeting_link')->nullable();
            $table->string('location')->nullable();
            $table->boolean('is_private')->default(false);
            $table->jsonb('recurrence')->nullable(); // rules for recurring meetings (daily, weekly, etc.)
            $table->jsonb('metadata')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['room_id', 'start_time', 'end_time']);
            $table->index(['organizer_id', 'start_time']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('meetings');
    }
};
