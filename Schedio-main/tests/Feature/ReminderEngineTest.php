<?php

namespace Tests\Feature;

use App\Jobs\ProcessReminderJob;
use App\Models\Meeting;
use App\Models\Reminder;
use App\Models\User;
use App\Notifications\SessionReminderNotification;
use App\Services\ReminderEngineService;
use Carbon\Carbon;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class ReminderEngineTest extends TestCase
{
    use RefreshDatabase;

    protected ReminderEngineService $reminderEngine;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        $this->reminderEngine = app(ReminderEngineService::class);
    }

    public function test_schedule_meeting_reminders_creates_records_for_participants(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $employee = User::where('email', 'marcus.v@schedio.com')->first();

        $start = Carbon::now()->addHours(2);
        $end = Carbon::now()->addHours(3);

        $meeting = Meeting::create([
            'title' => 'DevOps Architecture Sync',
            'organizer_id' => $superAdmin->id,
            'start_time' => $start,
            'end_time' => $end,
            'status' => 'scheduled',
            'type' => 'hybrid',
        ]);
        $meeting->participants()->attach($employee->id, ['status' => 'accepted', 'role' => 'attendee']);

        // Schedule 15-minute reminder
        $reminders = $this->reminderEngine->scheduleMeetingReminders($meeting, 15, 'both');

        $this->assertCount(2, $reminders); // Organizer + Employee

        $this->assertDatabaseHas('reminders', [
            'user_id' => $superAdmin->id,
            'remindable_id' => $meeting->id,
            'remind_at' => $start->copy()->subMinutes(15),
            'status' => 'pending',
        ]);

        $this->assertDatabaseHas('reminders', [
            'user_id' => $employee->id,
            'remindable_id' => $meeting->id,
            'remind_at' => $start->copy()->subMinutes(15),
            'status' => 'pending',
        ]);
    }

    public function test_duplicate_reminders_are_prevented(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $meeting = Meeting::first();

        // Run schedule twice
        $this->reminderEngine->scheduleMeetingReminders($meeting, 30, 'both');
        $secondRun = $this->reminderEngine->scheduleMeetingReminders($meeting, 30, 'both');

        $this->assertCount(0, $secondRun); // No duplicates created
    }

    public function test_dispatch_due_reminders_queues_jobs(): void
    {
        Queue::fake();

        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $meeting = Meeting::first();

        $reminder = Reminder::create([
            'user_id' => $superAdmin->id,
            'title' => 'Due Reminder Test',
            'remindable_type' => Meeting::class,
            'remindable_id' => $meeting->id,
            'remind_at' => Carbon::now()->subMinute(), // Past due
            'channel' => 'both',
            'status' => 'pending',
        ]);

        $dispatched = $this->reminderEngine->dispatchDueReminders();

        $this->assertGreaterThanOrEqual(1, $dispatched);
        Queue::assertPushed(ProcessReminderJob::class, function ($job) use ($reminder) {
            return $job->reminderId === $reminder->id;
        });
    }

    public function test_process_reminder_job_sends_notification_and_updates_status(): void
    {
        Notification::fake();

        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $meeting = Meeting::first();

        $reminder = Reminder::create([
            'user_id' => $superAdmin->id,
            'title' => 'Test Notification Delivery',
            'message' => 'Meeting in 15 minutes',
            'remindable_type' => Meeting::class,
            'remindable_id' => $meeting->id,
            'remind_at' => Carbon::now()->subMinute(),
            'channel' => 'both',
            'status' => 'pending',
        ]);

        $job = new ProcessReminderJob($reminder->id);
        $job->handle();

        $reminder->refresh();
        $this->assertEquals('sent', $reminder->status);
        $this->assertNotNull($reminder->sent_at);

        Notification::assertSentTo(
            [$superAdmin],
            SessionReminderNotification::class
        );
    }

    public function test_cancelled_meeting_dismisses_pending_reminders(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $meeting = Meeting::first();

        $reminder = Reminder::create([
            'user_id' => $superAdmin->id,
            'title' => 'Will Be Dismissed',
            'remindable_type' => Meeting::class,
            'remindable_id' => $meeting->id,
            'remind_at' => Carbon::now()->addHour(),
            'channel' => 'both',
            'status' => 'pending',
        ]);

        $this->reminderEngine->handleMeetingCancelled($meeting);

        $reminder->refresh();
        $this->assertEquals('dismissed', $reminder->status);
    }

    public function test_rescheduled_meeting_updates_reminder_time(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $start = Carbon::now()->addHours(2);
        $meeting = Meeting::create([
            'title' => 'Sprint Sync',
            'organizer_id' => $superAdmin->id,
            'start_time' => $start,
            'end_time' => $start->copy()->addHour(),
            'status' => 'scheduled',
            'type' => 'in_person',
        ]);

        $reminder = Reminder::create([
            'user_id' => $superAdmin->id,
            'title' => 'Upcoming Sprint Sync',
            'remindable_type' => Meeting::class,
            'remindable_id' => $meeting->id,
            'remind_at' => $start->copy()->subMinutes(15),
            'channel' => 'both',
            'status' => 'pending',
            'payload' => ['minutes_before' => 15],
        ]);

        $newStart = Carbon::now()->addDays(2)->setTime(14, 0, 0);
        $meeting->update(['start_time' => $newStart, 'end_time' => $newStart->copy()->addHour()]);

        $this->reminderEngine->handleMeetingRescheduled($meeting, $start);

        $reminder->refresh();
        $this->assertEquals($newStart->copy()->subMinutes(15)->toDateTimeString(), $reminder->remind_at->toDateTimeString());
    }

    public function test_artisan_process_reminders_command(): void
    {
        $this->artisan('schedio:process-reminders')
            ->expectsOutputToContain('Scanning for due reminders...')
            ->assertExitCode(0);
    }
}
