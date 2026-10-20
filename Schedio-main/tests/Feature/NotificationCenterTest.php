<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Meeting;
use App\Models\MeetingParticipant;
use App\Models\Reminder;
use App\Models\Room;
use App\Models\Task;
use App\Models\User;
use App\Notifications\MeetingCancelledNotification;
use App\Notifications\MeetingInvitationNotification;
use App\Notifications\MeetingUpdatedNotification;
use App\Notifications\ParticipantResponseNotification;
use App\Notifications\SessionReminderNotification;
use App\Notifications\TaskActivityNotification;
use App\Services\NotificationDispatchService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class NotificationCenterTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;
    private User $user1;
    private User $user2;
    private Department $department;
    private Room $room;

    protected function setUp(): void
    {
        parent::setUp();

        $this->department = Department::create([
            'name' => 'Engineering',
            'code' => 'ENG',
            'is_active' => true,
        ]);

        $this->admin = User::factory()->create([
            'name' => 'Admin Boss',
            'email' => 'admin@schedio.test',
            'role' => User::ROLE_SUPER_ADMIN,
            'approval_status' => User::STATUS_APPROVED,
            'department_id' => $this->department->id,
        ]);

        $this->user1 = User::factory()->create([
            'name' => 'Alice Dev',
            'email' => 'alice@schedio.test',
            'role' => User::ROLE_EMPLOYEE,
            'approval_status' => User::STATUS_APPROVED,
            'department_id' => $this->department->id,
        ]);

        $this->user2 = User::factory()->create([
            'name' => 'Bob Lead',
            'email' => 'bob@schedio.test',
            'role' => User::ROLE_MANAGER,
            'approval_status' => User::STATUS_APPROVED,
            'department_id' => $this->department->id,
        ]);

        $this->room = Room::create([
            'name' => 'Apex Pod',
            'code' => 'ROOM-APEX',
            'capacity' => 6,
            'color' => '#6366f1',
            'is_active' => true,
        ]);
    }

    public function test_notification_center_page_renders_successfully(): void
    {
        $response = $this->actingAs($this->user1)->get(route('notifications.index'));
        $response->assertStatus(200);
        $response->assertSee('Notification Center');
        $response->assertSee('Delivery Preferences');
    }

    public function test_meeting_creation_dispatches_invitations_to_participants(): void
    {
        Notification::fake();

        $meetingData = [
            'title' => 'Sprint Planning Kickoff',
            'start_time' => now()->addDay()->format('Y-m-d H:i:s'),
            'end_time' => now()->addDay()->addHour()->format('Y-m-d H:i:s'),
            'timezone' => 'America/New_York',
            'type' => 'in_person',
            'room_id' => $this->room->id,
            'department_id' => $this->department->id,
            'participant_ids' => [$this->user1->id, $this->user2->id],
            'reminder_minutes' => 15,
        ];

        $response = $this->actingAs($this->admin)->post(route('meetings.store'), $meetingData);
        $response->assertRedirect();

        Notification::assertSentTo(
            [$this->user1, $this->user2],
            MeetingInvitationNotification::class
        );

        Notification::assertNotSentTo(
            $this->admin,
            MeetingInvitationNotification::class
        );
    }

    public function test_meeting_update_and_cancellation_dispatch_notifications(): void
    {
        Notification::fake();

        $meeting = Meeting::create([
            'title' => 'Design Sync',
            'organizer_id' => $this->admin->id,
            'department_id' => $this->department->id,
            'start_time' => now()->addDays(2),
            'end_time' => now()->addDays(2)->addHour(),
            'timezone' => 'UTC',
            'type' => 'in_person',
            'status' => 'scheduled',
        ]);

        MeetingParticipant::create([
            'meeting_id' => $meeting->id,
            'user_id' => $this->admin->id,
            'role' => 'host',
            'status' => 'accepted',
        ]);

        MeetingParticipant::create([
            'meeting_id' => $meeting->id,
            'user_id' => $this->user1->id,
            'role' => 'attendee',
            'status' => 'pending',
        ]);

        // 1. Test Update
        $this->actingAs($this->admin)->put(route('meetings.update', $meeting), [
            'title' => 'Design Sync (Rescheduled)',
            'start_time' => now()->addDays(3)->format('Y-m-d H:i:s'),
            'end_time' => now()->addDays(3)->addHour()->format('Y-m-d H:i:s'),
            'timezone' => 'UTC',
            'type' => 'in_person',
            'participant_ids' => [$this->user1->id],
        ]);

        Notification::assertSentTo($this->user1, MeetingUpdatedNotification::class);

        // 2. Test Cancellation
        $this->actingAs($this->admin)->patch(route('meetings.cancel', $meeting));
        Notification::assertSentTo($this->user1, MeetingCancelledNotification::class);
    }

    public function test_participant_rsvp_notifies_meeting_organizer(): void
    {
        Notification::fake();

        $meeting = Meeting::create([
            'title' => 'One-on-One Sync',
            'organizer_id' => $this->admin->id,
            'department_id' => $this->department->id,
            'start_time' => now()->addDays(1),
            'end_time' => now()->addDays(1)->addMinutes(30),
            'timezone' => 'UTC',
            'type' => 'virtual',
            'status' => 'scheduled',
        ]);

        MeetingParticipant::create([
            'meeting_id' => $meeting->id,
            'user_id' => $this->user1->id,
            'role' => 'attendee',
            'status' => 'pending',
        ]);

        $this->actingAs($this->user1)->post(route('meetings.rsvp', $meeting), [
            'status' => 'accepted',
            'response_notes' => 'Looking forward to it!',
        ]);

        Notification::assertSentTo($this->admin, ParticipantResponseNotification::class);
    }

    public function test_task_activity_dispatches_notification_to_assignee(): void
    {
        Notification::fake();

        $this->actingAs($this->admin)->post(route('tasks.store'), [
            'title' => 'Deploy Redis Cluster',
            'priority' => 'high',
            'assigned_to' => $this->user1->id,
            'due_date' => now()->addDays(4)->format('Y-m-d H:i:s'),
        ]);

        $task = Task::where('title', 'Deploy Redis Cluster')->firstOrFail();
        $this->assertNotNull($task);

        Notification::assertSentTo($this->user1, TaskActivityNotification::class);

        // Test Task Complete
        $this->actingAs($this->user1)->patch(route('tasks.update-status', $task), [
            'status' => 'completed',
        ]);

        Notification::assertSentTo($this->admin, TaskActivityNotification::class);
    }

    public function test_user_notification_preferences_controls_channels(): void
    {
        // Set user preferences to disable email for invitations
        $this->user1->update([
            'notification_preferences' => [
                'channels' => [
                    'in_app' => true,
                    'email' => false,
                ],
                'categories' => [
                    'meeting_invitations' => ['in_app' => true, 'email' => false],
                ],
            ],
        ]);

        $channels = $this->user1->getNotificationChannelsFor('meeting_invitations');
        $this->assertContains('database', $channels);
        $this->assertNotContains('mail', $channels);

        // Turn off all
        $this->user1->update([
            'notification_preferences' => [
                'channels' => [
                    'in_app' => false,
                    'email' => false,
                ],
            ],
        ]);

        $channelsOff = $this->user1->getNotificationChannelsFor('meeting_invitations');
        $this->assertEmpty($channelsOff);
    }

    public function test_mark_as_read_and_unread_actions_and_feed_api(): void
    {
        $meeting = Meeting::create([
            'title' => 'Tech Talk',
            'organizer_id' => $this->admin->id,
            'department_id' => $this->department->id,
            'start_time' => now()->addDay(),
            'end_time' => now()->addDay()->addHour(),
            'timezone' => 'UTC',
            'type' => 'in_person',
            'status' => 'scheduled',
        ]);

        // Send real notification to DB
        $this->user1->notify(new MeetingInvitationNotification($meeting));

        $this->assertEquals(1, $this->user1->unreadNotifications()->count());
        $notification = $this->user1->unreadNotifications()->first();

        // Feed API
        $response = $this->actingAs($this->user1)->getJson(route('notifications.feed'));
        $response->assertStatus(200);
        $response->assertJsonPath('unread_count', 1);

        // Mark as read
        $markResponse = $this->actingAs($this->user1)->patchJson(route('notifications.mark-read', $notification->id));
        $markResponse->assertStatus(200);
        $this->assertEquals(0, $this->user1->unreadNotifications()->count());

        // Mark as unread
        $unreadResponse = $this->actingAs($this->user1)->patchJson(route('notifications.mark-unread', $notification->id));
        $unreadResponse->assertStatus(200);
        $this->assertEquals(1, $this->user1->unreadNotifications()->count());

        // Mark all as read
        $allReadResponse = $this->actingAs($this->user1)->postJson(route('notifications.mark-all-read'));
        $allReadResponse->assertStatus(200);
        $this->assertEquals(0, $this->user1->unreadNotifications()->count());

        // Delete
        $deleteResponse = $this->actingAs($this->user1)->deleteJson(route('notifications.destroy', $notification->id));
        $deleteResponse->assertStatus(200);
        $this->assertEquals(0, $this->user1->notifications()->count());
    }
}
