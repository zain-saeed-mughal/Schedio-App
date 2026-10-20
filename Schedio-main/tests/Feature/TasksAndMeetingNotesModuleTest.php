<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Meeting;
use App\Models\MeetingNote;
use App\Models\Task;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TasksAndMeetingNotesModuleTest extends TestCase
{
    use RefreshDatabase;

    protected User $organizer;
    protected User $attendee;
    protected User $otherUser;
    protected Department $department;
    protected Meeting $meeting;

    protected function setUp(): void
    {
        parent::setUp();

        $this->department = Department::create([
            'name' => 'Engineering',
            'code' => 'ENG',
            'is_active' => true,
        ]);

        $this->organizer = User::factory()->create([
            'role' => 'user',
            'department_id' => $this->department->id,
            'email_verified_at' => now(),
        ]);

        $this->attendee = User::factory()->create([
            'role' => 'user',
            'department_id' => $this->department->id,
            'email_verified_at' => now(),
        ]);

        $this->otherUser = User::factory()->create([
            'role' => 'user',
            'department_id' => $this->department->id,
            'email_verified_at' => now(),
        ]);

        $this->meeting = Meeting::create([
            'title' => 'Q4 Sprint Retrospective',
            'department_id' => $this->department->id,
            'organizer_id' => $this->organizer->id,
            'start_time' => now()->addDays(2)->setHour(14)->setMinute(0),
            'end_time' => now()->addDays(2)->setHour(14)->setMinute(45),
            'status' => 'scheduled',
            'type' => 'in_person',
        ]);

        $this->meeting->participants()->attach($this->attendee->id, [
            'role' => 'required',
            'status' => 'accepted',
        ]);
    }

    public function test_attendee_can_view_meeting_workspace(): void
    {
        $response = $this->actingAs($this->attendee)->get(route('meetings.show', $this->meeting));

        $response->assertOk();
        $response->assertSee('Q4 Sprint Retrospective');
        $response->assertSee('Meeting Workspace');
        $response->assertSee('Meeting Notes');
        $response->assertSee('Action Items');
    }

    public function test_organizer_can_create_meeting_notes(): void
    {
        $payload = [
            'agenda' => "1. Review KPIs\n2. Blockers discussion\n3. Next sprint planning",
            'discussion' => 'Team discussed API latency bottlenecks in the checkout workflow.',
            'decisions' => 'Agreed to implement Redis caching on query endpoints.',
            'action_items' => "- John to benchmark queries\n- Alice to deploy cache layer",
            'follow_up_date' => now()->addDays(5)->format('Y-m-d H:i:s'),
            'attachments_text' => "https://docs.schedio.internal/kpis\nArchitecture Diagram - https://diagrams.schedio.internal/cache",
        ];

        $response = $this->actingAs($this->organizer)
            ->from(route('meetings.show', $this->meeting))
            ->post(route('meetings.notes.store', $this->meeting), $payload);

        $response->assertRedirect(route('meetings.show', $this->meeting));
        $response->assertSessionHas('success', 'Meeting notes recorded successfully.');

        $this->assertDatabaseHas('meeting_notes', [
            'meeting_id' => $this->meeting->id,
            'user_id' => $this->organizer->id,
            'agenda' => "1. Review KPIs\n2. Blockers discussion\n3. Next sprint planning",
            'decisions' => 'Agreed to implement Redis caching on query endpoints.',
        ]);

        $note = MeetingNote::where('meeting_id', $this->meeting->id)->first();
        $this->assertNotNull($note);
        $this->assertCount(2, $note->attachments);
        $this->assertEquals('https://docs.schedio.internal/kpis', $note->attachments[0]['url']);
    }

    public function test_author_can_update_meeting_notes(): void
    {
        $note = MeetingNote::create([
            'meeting_id' => $this->meeting->id,
            'user_id' => $this->organizer->id,
            'agenda' => 'Initial Agenda',
            'discussion' => 'Initial Discussion',
            'decisions' => 'Initial Decision',
        ]);

        $response = $this->actingAs($this->organizer)
            ->from(route('meetings.show', $this->meeting))
            ->put(route('meetings.notes.update', $note), [
                'agenda' => 'Updated Agenda items',
                'discussion' => 'Updated discussion points',
                'decisions' => 'Updated decision finalized',
                'action_items' => 'Updated action items',
            ]);

        $response->assertRedirect(route('meetings.show', $this->meeting));
        $this->assertDatabaseHas('meeting_notes', [
            'id' => $note->id,
            'agenda' => 'Updated Agenda items',
            'decisions' => 'Updated decision finalized',
        ]);
    }

    public function test_author_or_admin_can_delete_meeting_notes(): void
    {
        $note = MeetingNote::create([
            'meeting_id' => $this->meeting->id,
            'user_id' => $this->organizer->id,
            'agenda' => 'To be deleted',
            'discussion' => 'Discussion',
        ]);

        $response = $this->actingAs($this->organizer)
            ->from(route('meetings.show', $this->meeting))
            ->delete(route('meetings.notes.destroy', $note));

        $response->assertRedirect(route('meetings.show', $this->meeting));
        $this->assertSoftDeleted('meeting_notes', ['id' => $note->id]);
    }

    public function test_user_can_create_task_from_meeting_workspace(): void
    {
        $payload = [
            'meeting_id' => $this->meeting->id,
            'title' => 'Optimize DB queries for sprint report',
            'description' => 'Add indexes to meetings and tasks tables to speed up dashboard metrics.',
            'assigned_to' => $this->attendee->id,
            'priority' => 'high',
            'due_date' => now()->addDays(3)->format('Y-m-d'),
        ];

        $response = $this->actingAs($this->organizer)
            ->from(route('meetings.show', $this->meeting))
            ->post(route('tasks.store'), $payload);

        $response->assertRedirect(route('meetings.show', $this->meeting));
        $response->assertSessionHas('success', 'Action item created successfully.');

        $this->assertDatabaseHas('tasks', [
            'meeting_id' => $this->meeting->id,
            'title' => 'Optimize DB queries for sprint report',
            'assigned_to' => $this->attendee->id,
            'priority' => 'high',
            'status' => 'todo',
        ]);
    }

    public function test_task_status_can_transition_from_pending_to_in_progress_and_completed(): void
    {
        $task = Task::create([
            'meeting_id' => $this->meeting->id,
            'department_id' => $this->department->id,
            'created_by' => $this->organizer->id,
            'assigned_to' => $this->attendee->id,
            'title' => 'Implement Cache Layer',
            'priority' => 'urgent',
            'status' => 'todo',
            'due_date' => now()->addDays(4),
        ]);

        // Transition to in_progress
        $response = $this->actingAs($this->attendee)
            ->patch(route('tasks.update-status', $task), [
                'status' => 'in_progress',
            ]);

        $response->assertRedirect();
        $this->assertDatabaseHas('tasks', [
            'id' => $task->id,
            'status' => 'in_progress',
        ]);

        // Transition to completed
        $response2 = $this->actingAs($this->attendee)
            ->patch(route('tasks.update-status', $task), [
                'status' => 'completed',
            ]);

        $response2->assertRedirect();
        $this->assertDatabaseHas('tasks', [
            'id' => $task->id,
            'status' => 'completed',
        ]);
    }

    public function test_unauthorized_user_cannot_create_task_or_notes_for_unrelated_meeting(): void
    {
        $response = $this->actingAs($this->otherUser)
            ->post(route('meetings.notes.store', $this->meeting), [
                'agenda' => 'Unauthorized Agenda',
            ]);

        $response->assertForbidden();
    }
}
