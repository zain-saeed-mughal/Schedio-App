<?php

namespace Tests\Feature;

use App\Models\{Company, Meeting, Room, User};
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MobileApiTest extends TestCase
{
    use RefreshDatabase;

    private function user(array $attributes = []): User
    {
        $company = Company::create(['name' => fake()->company(), 'status' => 'active']);
        return User::factory()->create(['company_id' => $company->id, ...$attributes]);
    }
    private function payload(): array
    {
        return ['title' => 'Mobile planning', 'start_time' => '2030-10-21T10:00:00Z',
            'end_time' => '2030-10-21T11:00:00Z', 'timezone' => 'UTC', 'type' => 'virtual'];
    }
    public function test_login_issues_token_and_logout_revokes_it(): void
    {
        $u = $this->user();
        $token = $this->postJson('/api/v1/auth/login', ['email' => $u->email,
            'password' => 'password', 'device_name' => 'Test phone'])->assertOk()->json('token');
        $this->assertNotEmpty($token);
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk()->assertJsonPath('data.id', $u->id);
        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }
    public function test_note_detail_refresh_is_scoped_to_visible_meetings(): void
    {
        $organizer = $this->user();
        Sanctum::actingAs($organizer);
        $id = $this->postJson('/api/v1/meetings', $this->payload())->assertCreated()->json('data.id');
        $this->postJson("/api/v1/meetings/$id/notes", ['agenda' => 'Initial'])->assertCreated();
        $noteId = $this->getJson("/api/v1/meetings/$id/notes")->json('data.0.id');
        $this->putJson("/api/v1/meeting-notes/$noteId", ['agenda' => 'Revised'])->assertOk();
        $this->getJson("/api/v1/meeting-notes/$noteId")->assertOk()->assertJsonPath('data.agenda', 'Revised');
        $outsider = User::factory()->create(['company_id' => $organizer->company_id]);
        Sanctum::actingAs($outsider);
        $this->getJson("/api/v1/meeting-notes/$noteId")->assertNotFound();
        Sanctum::actingAs($this->user());
        $this->getJson("/api/v1/meeting-notes/$noteId")->assertNotFound();
    }
    public function test_pending_inactive_and_deleted_users_cannot_login(): void
    {
        foreach ([['approval_status' => 'pending'], ['is_active' => false], ['deleted_at' => now()]] as $state) {
            $u = $this->user($state);
            $this->postJson('/api/v1/auth/login', ['email' => $u->email,
                'password' => 'password', 'device_name' => 'Test'])->assertStatus(isset($state['deleted_at']) ? 401 : 403);
        }
    }
    public function test_revoked_approval_blocks_an_existing_session(): void
    {
        $u = $this->user();
        Sanctum::actingAs($u);
        $u->update(['approval_status' => 'rejected']);
        $this->getJson('/api/v1/meetings')->assertForbidden();
    }
    public function test_meeting_creation_conflict_and_web_record_parity(): void
    {
        $u = $this->user();
        Sanctum::actingAs($u);
        $id = $this->postJson('/api/v1/meetings', $this->payload())->assertCreated()->json('data.id');
        $this->assertDatabaseHas('meetings', ['id' => $id, 'organizer_id' => $u->id, 'company_id' => $u->company_id]);
        $this->postJson('/api/v1/meetings', $this->payload())->assertUnprocessable();
        $this->putJson("/api/v1/meetings/$id", [...$this->payload(), 'title' => 'Updated'])->assertOk();
        $this->patchJson("/api/v1/meetings/$id/cancel")->assertOk();
        $this->assertDatabaseHas('meetings', ['id' => $id, 'title' => 'Updated', 'status' => 'cancelled']);
    }
    public function test_cross_company_records_and_foreign_keys_are_rejected(): void
    {
        $a = $this->user(['role' => 'super_admin']);
        $b = $this->user();
        $meeting = Meeting::create([...$this->payload(), 'organizer_id' => $b->id, 'company_id' => $b->company_id]);
        Sanctum::actingAs($a);
        $this->getJson('/api/v1/meetings/'.$meeting->id)->assertNotFound();
        $this->getJson('/api/v1/meetings')->assertJsonCount(0, 'data');
        $this->postJson('/api/v1/meetings', [...$this->payload(), 'participant_ids' => [$b->id]])->assertUnprocessable();
        $this->postJson('/api/v1/tasks', ['title' => 'Leak', 'priority' => 'medium', 'assigned_to' => $b->id])->assertUnprocessable();
    }
    public function test_uninvited_user_cannot_rsvp_or_read_notes(): void
    {
        $a = $this->user();
        $b = User::factory()->create(['company_id' => $a->company_id]);
        $m = Meeting::create([...$this->payload(), 'organizer_id' => $b->id, 'company_id' => $a->company_id]);
        Sanctum::actingAs($a);
        $this->postJson("/api/v1/meetings/{$m->id}/rsvp", ['status' => 'accepted'])->assertNotFound();
        $this->getJson("/api/v1/meetings/{$m->id}/notes")->assertNotFound();
    }
    public function test_room_conflicts_and_private_titles_are_protected(): void
    {
        $u = $this->user();
        $room = Room::create(['company_id' => $u->company_id, 'name' => 'Suite', 'code' => 'SUITE',
            'location' => 'HQ', 'capacity' => 4, 'is_active' => true]);
        Sanctum::actingAs($u);
        $this->postJson('/api/v1/meetings', [...$this->payload(), 'room_id' => $room->id])->assertCreated();
        $this->postJson('/api/v1/availability/check', [...$this->payload(), 'room_id' => $room->id])
            ->assertOk()->assertJsonPath('data.has_conflicts', true)->assertJsonMissing(['title' => 'Mobile planning']);
    }
    public function test_company_admin_cannot_promote_staff_to_super_admin(): void
    {
        $u = $this->user(['role' => 'super_admin']);
        $staff = User::factory()->create(['company_id' => $u->company_id, 'approval_status' => 'pending']);
        Sanctum::actingAs($u);
        $this->patchJson("/api/v1/admin/registration-requests/{$staff->id}/approve",
            ['role' => 'super_admin'])->assertUnprocessable();
        $this->patchJson("/api/v1/admin/registration-requests/{$staff->id}/approve",
            ['role' => 'employee'])->assertOk();
    }
    public function test_task_and_client_workflows_use_existing_tables(): void
    {
        $u = $this->user();
        Sanctum::actingAs($u);
        $this->postJson('/api/v1/tasks', ['title' => 'Prepare agenda', 'priority' => 'high'])->assertCreated();
        $id = $this->getJson('/api/v1/tasks')->assertOk()->json('data.0.id');
        $this->patchJson("/api/v1/tasks/$id/status", ['status' => 'completed'])->assertOk();
        $this->postJson('/api/v1/clients', ['company_name' => 'Acme', 'contact_name' => 'Sam', 'status' => 'discovery'])->assertCreated();
        $id = $this->getJson('/api/v1/clients')->assertOk()->json('data.0.id');
        $this->patchJson("/api/v1/clients/$id/status", ['status' => 'onboarded'])->assertOk();
        $this->assertDatabaseHas('clients', ['id' => $id, 'status' => 'onboarded']);
    }
    public function test_public_booking_revalidates_slots_and_prevents_sequential_duplicates(): void
    {
        $u = $this->user(['username' => 'host', 'timezone' => 'UTC']);
        $payload = ['client_name' => 'Guest', 'client_email' => 'guest@example.test',
            'start_time' => '2030-10-21T10:00:00Z', 'duration_minutes' => 30];
        $result = $this->postJson('/api/v1/public/booking/host', $payload)->assertCreated();
        $export = $result->json('data.calendar_export_url');
        $this->get($export)->assertOk()->assertSee('BEGIN:VCALENDAR');
        $this->get('/api/v1/public/booking-confirmations/1/ical')->assertForbidden();
        $this->postJson('/api/v1/public/booking/host', $payload)->assertUnprocessable();
        $this->assertDatabaseHas('meetings', ['organizer_id' => $u->id, 'company_id' => $u->company_id]);
    }
    public function test_registration_cannot_choose_another_company_department(): void
    {
        $u = $this->user();
        $this->postJson('/api/v1/auth/register', ['registration_type' => 'employee',
            'company_id' => $u->company_id, 'name' => 'New User', 'email' => 'new@example.test',
            'password' => 'StrongPassword123', 'password_confirmation' => 'StrongPassword123'])
            ->assertCreated()->assertJsonPath('account_status', 'pending');
    }

    public function test_notification_operations_are_owner_scoped(): void
    {
        $a = $this->user();
        $b = $this->user();
        $notification = $b->notifications()->create([
            'id' => (string) \Illuminate\Support\Str::uuid(),
            'type' => 'test', 'data' => ['title' => 'Private notice'],
        ]);
        Sanctum::actingAs($a);
        $this->getJson('/api/v1/notifications')->assertJsonCount(0, 'data');
        $this->patchJson("/api/v1/notifications/{$notification->id}/read")->assertNotFound();
        $this->deleteJson("/api/v1/notifications/{$notification->id}")->assertNotFound();
        Sanctum::actingAs($b);
        $this->patchJson("/api/v1/notifications/{$notification->id}/read")->assertOk();
        $this->patchJson("/api/v1/notifications/{$notification->id}/unread")->assertOk();
        $this->postJson('/api/v1/notifications/mark-all-read')->assertOk();
        $this->deleteJson("/api/v1/notifications/{$notification->id}")->assertOk();
    }

    public function test_notes_events_and_rooms_obey_resource_permissions(): void
    {
        $u = $this->user();
        Sanctum::actingAs($u);
        $id = $this->postJson('/api/v1/meetings', $this->payload())->assertCreated()->json('data.id');
        $this->postJson("/api/v1/meetings/$id/notes", ['agenda' => 'Plan'])->assertCreated();
        $noteId = $this->getJson("/api/v1/meetings/$id/notes")->assertOk()->json('data.0.id');
        $this->putJson("/api/v1/meeting-notes/$noteId", ['decisions' => 'Agreed'])->assertOk();
        $this->deleteJson("/api/v1/meeting-notes/$noteId")->assertOk();
        $this->postJson('/api/v1/events', [...$this->payload(), 'category' => 'training', 'is_company_wide' => true])->assertCreated();
        $eventId = $this->getJson('/api/v1/events')->assertOk()->json('data.0.id');
        $this->assertDatabaseHas('events', ['id' => $eventId, 'is_company_wide' => false]);
        $this->deleteJson("/api/v1/events/$eventId")->assertOk();
        $this->postJson('/api/v1/rooms', ['name' => 'Suite', 'location' => 'HQ', 'capacity' => 4])->assertForbidden();
        $this->getJson('/api/v1/admin/registration-requests')->assertForbidden();
    }

    public function test_null_department_does_not_expose_other_users_events(): void
    {
        $a = $this->user(['department_id' => null]);
        $b = User::factory()->create(['company_id' => $a->company_id, 'department_id' => null]);
        \App\Models\Event::create([...$this->payload(), 'company_id' => $a->company_id,
            'user_id' => $b->id, 'category' => 'general', 'is_company_wide' => false]);
        Sanctum::actingAs($a);
        $this->getJson('/api/v1/events')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/calendar/feed?start=2030-10-21&end=2030-10-22')->assertJsonCount(0, 'data');
    }

    public function test_suspended_company_cannot_use_mobile_or_public_booking(): void
    {
        $u = $this->user(['username' => 'suspended']);
        $u->company->update(['status' => 'suspended']);
        $this->getJson('/api/v1/public/booking/suspended')->assertNotFound();
        Sanctum::actingAs($u);
        $this->getJson('/api/v1/dashboard')->assertForbidden();
    }

    public function test_browser_writer_revalidates_against_mobile_bookings(): void
    {
        $u = $this->user();
        Sanctum::actingAs($u);
        $this->postJson('/api/v1/meetings', $this->payload())->assertCreated();
        $this->actingAs($u, 'web')->post('/meetings', $this->payload())->assertSessionHasErrors('start_time');
        $this->assertDatabaseCount('meetings', 1);
    }

    public function test_suggestions_follow_the_account_timezone(): void
    {
        $u = $this->user(['timezone' => 'Asia/Karachi']);
        Sanctum::actingAs($u);
        $this->getJson('/api/v1/availability/suggestions?date=2030-10-21&duration_minutes=30')
            ->assertOk()->assertJsonPath('data.0.start_time', '2030-10-21T09:00:00+05:00');
    }

    public function test_meeting_changes_round_trip_between_browser_and_mobile_api(): void
    {
        $u = $this->user();
        Sanctum::actingAs($u);
        $id = $this->postJson('/api/v1/meetings', $this->payload())
            ->assertCreated()->json('data.id');
        $this->actingAs($u, 'web')->get("/meetings/$id")
            ->assertOk()->assertSee('Mobile planning');
        $this->put("/meetings/$id", [...$this->payload(), 'title' => 'Changed from browser'])
            ->assertRedirect()->assertSessionHasNoErrors();
        $this->getJson("/api/v1/meetings/$id")
            ->assertOk()->assertJsonPath('data.title', 'Changed from browser');
        $this->patchJson("/api/v1/meetings/$id/cancel")->assertOk();
        $this->get("/meetings/$id")->assertOk()->assertViewHas('meeting',
            fn ($meeting) => $meeting->id === $id && $meeting->status === 'cancelled');
        $this->assertDatabaseCount('meetings', 1);
    }

    public function test_browser_client_and_task_changes_are_visible_to_mobile(): void
    {
        $u = $this->user();
        $this->actingAs($u, 'web')->post('/clients', [
            'company_name' => 'Staging round trip', 'contact_name' => 'Test contact',
            'status' => 'discovery',
        ])->assertRedirect()->assertSessionHasNoErrors();
        Sanctum::actingAs($u);
        $clientId = $this->getJson('/api/v1/clients')->assertOk()
            ->assertJsonPath('data.0.company_name', 'Staging round trip')->json('data.0.id');
        $this->patchJson("/api/v1/clients/$clientId/status", ['status' => 'onboarded'])->assertOk();
        $this->get("/clients/$clientId")->assertOk()->assertViewHas('client',
            fn ($client) => $client->status === 'onboarded');
        $this->post('/tasks', ['title' => 'Browser action item', 'priority' => 'high'])
            ->assertRedirect()->assertSessionHasNoErrors();
        $taskId = $this->getJson('/api/v1/tasks')->assertOk()
            ->assertJsonPath('data.0.title', 'Browser action item')->json('data.0.id');
        $this->patchJson("/api/v1/tasks/$taskId/status", ['status' => 'completed'])->assertOk();
        $this->patch("/tasks/$taskId/status", ['status' => 'in_progress'])
            ->assertRedirect()->assertSessionHasNoErrors();
        $this->getJson("/api/v1/tasks/$taskId")->assertOk()->assertJsonPath('data.status', 'in_progress');
        $this->assertDatabaseCount('clients', 1);
        $this->assertDatabaseCount('tasks', 1);
    }
    public function test_inline_client_is_atomic_scoped_and_not_duplicated_on_edit(): void
    {
        $user = $this->user();
        Sanctum::actingAs($user);
        $payload = [...$this->payload(), 'is_client_meeting' => true, 'save_as_client' => true,
            'client_company' => 'Guest company', 'client_name' => 'Guest contact', 'client_email' => 'guest@example.test'];
        $meeting = $this->postJson('/api/v1/meetings', $payload)->assertCreated()->json('data');
        $this->assertDatabaseHas('clients', ['id' => $meeting['client_id'], 'company_id' => $user->company_id,
            'created_by' => $user->id, 'assigned_to' => $user->id, 'status' => 'scheduled']);
        $this->postJson('/api/v1/meetings', [...$payload, 'client_company' => 'Conflicting guest'])->assertUnprocessable();
        $this->assertDatabaseCount('clients', 1);
        $this->putJson('/api/v1/meetings/'.$meeting['id'], $payload)->assertUnprocessable();
        $this->assertDatabaseCount('clients', 1);
        Sanctum::actingAs($this->user());
        $this->getJson('/api/v1/clients/'.$meeting['client_id'])->assertNotFound();
    }

    public function test_inline_client_requires_company_and_rejects_existing_client_selection(): void
    {
        Sanctum::actingAs($this->user());
        $this->postJson('/api/v1/meetings', [...$this->payload(), 'save_as_client' => true])
            ->assertUnprocessable()->assertJsonValidationErrors('client_company');
        $this->postJson('/api/v1/meetings', [...$this->payload(), 'save_as_client' => true,
            'client_company' => 'Guest', 'client_id' => 99])->assertUnprocessable();
        $this->assertDatabaseCount('clients', 0);
        $this->assertDatabaseCount('meetings', 0);
    }

    public function test_approval_options_and_assignments_are_tenant_scoped(): void
    {
        $admin = $this->user(['role' => 'super_admin']);
        $applicant = User::factory()->create(['company_id' => $admin->company_id, 'approval_status' => 'pending']);
        $department = \App\Models\Department::create(['company_id' => $admin->company_id,
            'name' => 'Engineering', 'code' => 'ENG', 'is_active' => true]);
        $other = $this->user();
        Sanctum::actingAs($admin);
        $this->getJson('/api/v1/admin/registration-requests/'.$applicant->id.'/options')
            ->assertOk()->assertJsonPath('roles', ['manager', 'employee', 'client'])
            ->assertJsonPath('departments.0.id', $department->id);
        $this->getJson('/api/v1/admin/registration-requests/'.$other->id.'/options')->assertNotFound();
        $this->patchJson('/api/v1/admin/registration-requests/'.$applicant->id.'/approve',
            ['role' => 'super_admin'])->assertUnprocessable();
        $this->patchJson('/api/v1/admin/registration-requests/'.$applicant->id.'/approve',
            ['role' => 'manager', 'department_id' => $department->id, 'title' => 'Team lead'])->assertOk();
        $this->assertDatabaseHas('users', ['id' => $applicant->id, 'role' => 'manager',
            'department_id' => $department->id, 'title' => 'Team lead', 'approval_status' => 'approved']);
        Sanctum::actingAs($other);
        $this->getJson('/api/v1/admin/registration-requests/'.$applicant->id.'/options')->assertForbidden();
    }
}
