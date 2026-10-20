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
        // 1. Users
        Schema::table('users', function (Blueprint $table) {
            $table->foreignId('company_id')->nullable()->after('id')->index()->constrained('companies')->nullOnDelete();
        });

        // 2. Departments
        Schema::table('departments', function (Blueprint $table) {
            $table->foreignId('company_id')->nullable()->after('id')->index()->constrained('companies')->cascadeOnDelete();
        });

        // 3. Rooms
        Schema::table('rooms', function (Blueprint $table) {
            $table->foreignId('company_id')->nullable()->after('id')->index()->constrained('companies')->cascadeOnDelete();
        });

        // 4. Meetings
        Schema::table('meetings', function (Blueprint $table) {
            $table->foreignId('company_id')->nullable()->after('id')->index()->constrained('companies')->cascadeOnDelete();
        });

        // 5. Events
        Schema::table('events', function (Blueprint $table) {
            $table->foreignId('company_id')->nullable()->after('id')->index()->constrained('companies')->cascadeOnDelete();
        });

        // 6. Tasks
        Schema::table('tasks', function (Blueprint $table) {
            $table->foreignId('company_id')->nullable()->after('id')->index()->constrained('companies')->cascadeOnDelete();
        });

        // 7. Clients (Deals Pipeline)
        Schema::table('clients', function (Blueprint $table) {
            $table->foreignId('company_id')->nullable()->after('id')->index()->constrained('companies')->cascadeOnDelete();
        });

        // 8. Meeting Notes
        Schema::table('meeting_notes', function (Blueprint $table) {
            $table->foreignId('company_id')->nullable()->after('id')->index()->constrained('companies')->cascadeOnDelete();
        });

        // 9. Audit Logs
        Schema::table('audit_logs', function (Blueprint $table) {
            $table->foreignId('company_id')->nullable()->after('id')->index()->constrained('companies')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('audit_logs', function (Blueprint $table) {
            $table->dropConstrainedForeignId('company_id');
        });

        Schema::table('meeting_notes', function (Blueprint $table) {
            $table->dropConstrainedForeignId('company_id');
        });

        Schema::table('clients', function (Blueprint $table) {
            $table->dropConstrainedForeignId('company_id');
        });

        Schema::table('tasks', function (Blueprint $table) {
            $table->dropConstrainedForeignId('company_id');
        });

        Schema::table('events', function (Blueprint $table) {
            $table->dropConstrainedForeignId('company_id');
        });

        Schema::table('meetings', function (Blueprint $table) {
            $table->dropConstrainedForeignId('company_id');
        });

        Schema::table('rooms', function (Blueprint $table) {
            $table->dropConstrainedForeignId('company_id');
        });

        Schema::table('departments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('company_id');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropConstrainedForeignId('company_id');
        });
    }
};
