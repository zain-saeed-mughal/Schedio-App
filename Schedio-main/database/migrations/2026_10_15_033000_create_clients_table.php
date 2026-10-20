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
        Schema::create('clients', function (Blueprint $table) {
            $table->id();
            $table->string('company_name')->index();
            $table->string('contact_name')->index();
            $table->string('contact_email')->nullable()->index();
            $table->string('contact_phone', 50)->nullable();
            $table->string('contact_role', 100)->nullable(); // e.g. CTO, VP Marketing, Founder
            $table->string('campaign', 100)->nullable()->index(); // e.g. Outbound Q4, Cold Email, Referral
            $table->text('progress')->nullable(); // Current progress summary or next step
            $table->string('status', 40)->default('discovery')->index(); // discovery, scheduled, paperwork_onboarding, onboarded, deadend, pause
            $table->foreignId('assigned_to')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->decimal('deal_value', 12, 2)->nullable();
            $table->text('notes')->nullable();
            $table->dateTime('last_activity_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('clients');
    }
};
