<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Meeting;
use App\Models\Reminder;
use App\Models\Room;
use App\Models\User;
use Carbon\Carbon;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MeetingManagementModuleTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    public function test_meetings_index_page_renders(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();

        $response = $this->actingAs($superAdmin)->get(route('meetings.index'));

        $response->assertStatus(200);
        $response->assertSee('Meeting Management Hub');
    }

    public function test_user_can_create_internal_meeting_with_reminder(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $dept = Department::first();
        $employee = User::where('email', 'marcus.v@schedio.com')->first();

        $start = Carbon::now()->addDays(3)->setTime(10, 0, 0);
        $end = Carbon::now()->addDays(3)->setTime(11, 0, 0);

        $response = $this->actingAs($superAdmin)->post(route('meetings.store'), [
            'title' => 'Quarterly Infrastructure Audit',
            'description' => 'Review multi-tenant database indexing and redis cache hit rates.',
            'start_time' => $start->format('Y-m-d\TH:i'),
            'end_time' => $end->format('Y-m-d\TH:i'),
            'timezone' => 'America/New_York',
            'department_id' => $dept->id,
            'type' => 'virtual',
            'meeting_link' => 'https://meet.google.com/infra-audit',
            'reminder_minutes' => 15,
            'participant_ids' => [$employee->id],
        ]);

        $meeting = Meeting::where('title', 'Quarterly Infrastructure Audit')->first();
        $this->assertNotNull($meeting);
        $response->assertRedirect(route('meetings.show', $meeting));

        $this->assertNull($meeting->room_id);
        $this->assertEquals($superAdmin->id, $meeting->organizer_id);
        $this->assertTrue($meeting->participants()->where('users.id', $employee->id)->exists());

        // Verify reminder created
        $this->assertDatabaseHas('reminders', [
            'remindable_type' => Meeting::class,
            'remindable_id' => $meeting->id,
            'user_id' => $superAdmin->id,
        ]);
    }

    public function test_user_can_create_external_client_meeting_with_recurrence(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();

        $start = Carbon::now()->addDays(5)->setTime(15, 0, 0);
        $end = Carbon::now()->addDays(5)->setTime(16, 0, 0);

        $response = $this->actingAs($superAdmin)->post(route('meetings.store'), [
            'title' => 'Initech Corp — Bi-Weekly Strategy Sync',
            'description' => 'Joint vendor review.',
            'start_time' => $start->format('Y-m-d\TH:i'),
            'end_time' => $end->format('Y-m-d\TH:i'),
            'timezone' => 'America/New_York',
            'type' => 'virtual',
            'meeting_link' => 'https://meet.google.com/initech-sync',
            'is_client_meeting' => 1,
            'client_name' => 'Bill Lumbergh',
            'client_email' => 'bill@initech.com',
            'client_company' => 'Initech Corp',
            'recurrence_frequency' => 'biweekly',
        ]);

        $meeting = Meeting::where('title', 'Initech Corp — Bi-Weekly Strategy Sync')->first();
        $this->assertNotNull($meeting);
        $this->assertTrue($meeting->metadata['is_client_meeting']);
        $this->assertEquals('Initech Corp', $meeting->metadata['client_company']);
        $this->assertEquals('biweekly', $meeting->recurrence['frequency']);
    }

    public function test_meeting_creation_validation_requires_end_time_after_start_time(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();

        $start = Carbon::now()->addDays(6)->setTime(14, 0, 0);
        $invalidEnd = Carbon::now()->addDays(6)->setTime(13, 0, 0);

        $response = $this->actingAs($superAdmin)->from(route('meetings.create'))->post(route('meetings.store'), [
            'title' => 'Invalid Timing Attempt',
            'start_time' => $start->format('Y-m-d\TH:i'),
            'end_time' => $invalidEnd->format('Y-m-d\TH:i'),
            'timezone' => 'America/New_York',
            'type' => 'virtual',
        ]);

        $response->assertRedirect(route('meetings.create'));
        $response->assertSessionHasErrors(['end_time']);
    }

    public function test_user_can_edit_meeting(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $meeting = Meeting::where('organizer_id', $superAdmin->id)->first();

        $newStart = Carbon::now()->addDays(12)->setTime(11, 0, 0);
        $newEnd = Carbon::now()->addDays(12)->setTime(12, 30, 0);

        $response = $this->actingAs($superAdmin)->put(route('meetings.update', $meeting), [
            'title' => 'Updated Title Milestone Sync',
            'description' => 'Updated descriptions',
            'start_time' => $newStart->format('Y-m-d\TH:i'),
            'end_time' => $newEnd->format('Y-m-d\TH:i'),
            'timezone' => 'America/New_York',
            'type' => 'hybrid',
        ]);

        $response->assertRedirect(route('meetings.show', $meeting));
        $meeting->refresh();
        $this->assertEquals('Updated Title Milestone Sync', $meeting->title);
    }

    public function test_user_can_cancel_meeting(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $meeting = Meeting::where('organizer_id', $superAdmin->id)->first();

        $response = $this->actingAs($superAdmin)->patch(route('meetings.cancel', $meeting));

        $response->assertRedirect(route('meetings.index'));
        $meeting->refresh();
        $this->assertEquals('cancelled', $meeting->status);
    }

    public function test_participant_can_submit_rsvp(): void
    {
        $employee = User::where('email', 'marcus.v@schedio.com')->first();
        $meeting = Meeting::first();

        $response = $this->actingAs($employee)->post(route('meetings.rsvp', $meeting), [
            'status' => 'accepted',
            'response_notes' => 'Looking forward to the agenda.',
        ]);

        $response->assertRedirect();
        $participant = $meeting->participants()->where('users.id', $employee->id)->first();
        $this->assertEquals('accepted', $participant->pivot->status);
        $this->assertEquals('Looking forward to the agenda.', $participant->pivot->response_notes);
    }
}
