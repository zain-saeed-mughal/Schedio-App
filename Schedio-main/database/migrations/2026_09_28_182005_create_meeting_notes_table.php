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
        Schema::create('meeting_notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('meeting_id')->constrained('meetings')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete(); // Author
            $table->text('agenda')->nullable();
            $table->text('discussion')->nullable();
            $table->text('decisions')->nullable();
            $table->text('action_items')->nullable();
            $table->dateTimeTz('follow_up_date')->nullable();
            $table->json('attachments')->nullable(); // metadata of linked docs, file URLs, cloud references
            $table->timestamps();
            $table->softDeletes();

            $table->index(['meeting_id', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('meeting_notes');
    }
};
