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
        Schema::create('events', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('description')->nullable();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('department_id')->nullable()->constrained('departments')->nullOnDelete();
            $table->string('category', 50)->default('general')->index(); // company_holiday, deadline, training, milestone, out_of_office, general
            $table->dateTimeTz('start_time')->index();
            $table->dateTimeTz('end_time')->index();
            $table->boolean('is_all_day')->default(false);
            $table->string('color', 20)->default('#3b82f6');
            $table->string('location')->nullable();
            $table->boolean('is_company_wide')->default(false)->index();
            $table->jsonb('recurrence')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['user_id', 'start_time']);
            $table->index(['department_id', 'start_time']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('events');
    }
};
