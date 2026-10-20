<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Department;
use App\Models\Event;
use App\Models\Meeting;
use App\Models\MeetingParticipant;
use App\Models\Reminder;
use App\Models\Room;
use App\Models\Task;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DatabaseSchemaAndRelationshipsTest extends TestCase
{
    use RefreshDatabase;

    public function test_database_seeder_runs_successfully_and_populates_core_data(): void
    {
        $this->seed(DatabaseSeeder::class);

        $this->assertDatabaseCount('departments', 3);
        $this->assertDatabaseCount('users', 7); // 6 Schedio HQ users + 1 Apex Global CEO
        $this->assertDatabaseCount('rooms', 4); // 3 Schedio rooms + 1 Apex room
        $this->assertDatabaseCount('meetings', 3); // 2 Schedio meetings + 1 Apex meeting
        $this->assertDatabaseCount('meeting_participants', 5);
        $this->assertDatabaseCount('events', 1);
        $this->assertDatabaseCount('tasks', 1);
        $this->assertDatabaseCount('reminders', 1);
        $this->assertDatabaseCount('audit_logs', 2);
    }

    public function test_user_relationships_work_correctly(): void
    {
        $this->seed(DatabaseSeeder::class);

        $admin = User::where('email', 'admin@schedio.com')->firstOrFail();
        
        $this->assertNotNull($admin->department);
        $this->assertEquals('ENG', $admin->department->code);
        $this->assertCount(2, $admin->organizedMeetings);
        $this->assertCount(2, $admin->participatingMeetings);
        $this->assertCount(1, $admin->events);
        $this->assertCount(1, $admin->createdTasks);
        $this->assertCount(1, $admin->auditLogs);
    }

    public function test_meeting_relationships_and_participants_work(): void
    {
        $this->seed(DatabaseSeeder::class);

        $meeting = Meeting::where('title', 'Q4 Sprint Planning & Architecture Review')->firstOrFail();

        $this->assertNotNull($meeting->organizer);
        $this->assertNotNull($meeting->department);
        $this->assertNotNull($meeting->room);
        $this->assertCount(3, $meeting->participants);
        $this->assertCount(1, $meeting->tasks);
        $this->assertCount(1, $meeting->reminders);
        
        $firstParticipant = $meeting->participants->first();
        $this->assertNotEmpty($firstParticipant->pivot->role);
        $this->assertNotEmpty($firstParticipant->pivot->status);
    }

    public function test_polymorphic_relationships_work(): void
    {
        $this->seed(DatabaseSeeder::class);

        $reminder = Reminder::firstOrFail();
        $this->assertNotNull($reminder->remindable);
        $this->assertNotNull($reminder->user);

        $auditLog = AuditLog::firstOrFail();
        $this->assertNotNull($auditLog->auditable);
        $this->assertNotNull($auditLog->user);
    }
}
