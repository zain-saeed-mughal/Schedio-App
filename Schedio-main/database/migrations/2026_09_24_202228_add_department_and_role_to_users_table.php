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
            $table->foreignId('department_id')->nullable()->after('id')->constrained('departments')->nullOnDelete();
            $table->string('role', 30)->default('employee')->index()->after('email'); // admin, manager, employee, guest
            $table->string('title')->nullable()->after('name');
            $table->string('phone', 30)->nullable()->after('email');
            $table->string('avatar_url')->nullable()->after('password');
            $table->string('timezone', 50)->default('UTC');
            $table->boolean('is_active')->default(true)->index();
            $table->softDeletes();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['department_id']);
            $table->dropColumn([
                'department_id',
                'role',
                'title',
                'phone',
                'avatar_url',
                'timezone',
                'is_active',
                'deleted_at',
            ]);
        });
    }
};
