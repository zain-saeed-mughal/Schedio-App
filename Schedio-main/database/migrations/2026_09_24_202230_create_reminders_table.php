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
        Schema::create('reminders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('title');
            $table->text('message')->nullable();
            $table->nullableMorphs('remindable'); // Meeting, Event, Task, etc.
            $table->dateTimeTz('remind_at')->index();
            $table->string('channel', 30)->default('in_app'); // in_app, email, push
            $table->string('status', 30)->default('pending')->index(); // pending, sent, failed, dismissed
            $table->dateTimeTz('sent_at')->nullable();
            $table->jsonb('payload')->nullable();
            $table->timestamps();

            $table->index(['status', 'remind_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('reminders');
    }
};
