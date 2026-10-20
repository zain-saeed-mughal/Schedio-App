<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Department;
use App\Models\Meeting;
use App\Models\Reminder;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ClientPipelineTest extends TestCase
{
    use RefreshDatabase;

    protected User $user;
    protected Department $department;

    protected function setUp(): void
    {
        parent::setUp();

        $this->department = Department::create([
            'name' => 'Sales & Business Development',
            'code' => 'BD',
            'is_active' => true,
        ]);

        $this->user = User::factory()->create([
            'role' => 'user',
            'department_id' => $this->department->id,
            'approval_status' => User::STATUS_APPROVED,
            'email_verified_at' => now(),
        ]);
    }

    public function test_client_pipeline_index_renders_successfully(): void
    {
        Client::create([
            'company_name' => 'Acme Corporation',
            'contact_name' => 'John Doe',
            'contact_email' => 'john@acme.com',
            'campaign' => 'Outbound Q4',
            'progress' => 'Introductory email sent',
            'status' => Client::STATUS_DISCOVERY,
            'created_by' => $this->user->id,
        ]);

        $response = $this->actingAs($this->user)->get(route('clients.index'));

        $response->assertOk();
        $response->assertSee('Business Development Pipeline');
        $response->assertSee('Acme Corporation');
        $response->assertSee('John Doe');
        $response->assertSee('Outbound Q4');
        $response->assertSee('Discovery');
        $response->assertSee('Spreadsheet View');
    }

    public function test_user_can_create_client_with_all_spreadsheet_fields(): void
    {
        $payload = [
            'company_name' => 'Starlight Media Technologies',
            'contact_name' => 'Elena Rostova',
            'contact_email' => 'elena@starlight.tv',
            'contact_phone' => '+1 (555) 901-2345',
            'contact_role' => 'VP of Strategic Partnerships',
            'campaign' => 'LinkedIn Outreach',
            'progress' => 'Cold outreach responded positively. Requested architecture demo.',
            'status' => Client::STATUS_DISCOVERY,
            'deal_value' => 45000,
        ];

        $response = $this->actingAs($this->user)
            ->post(route('clients.store'), $payload);

        $response->assertRedirect(route('clients.index'));
        $response->assertSessionHas('success');

        $this->assertDatabaseHas('clients', [
            'company_name' => 'Starlight Media Technologies',
            'contact_name' => 'Elena Rostova',
            'campaign' => 'LinkedIn Outreach',
            'status' => Client::STATUS_DISCOVERY,
        ]);
    }

    public function test_user_can_update_client_status(): void
    {
        $client = Client::create([
            'company_name' => 'Alpha Dynamics',
            'contact_name' => 'Marcus Vance',
            'status' => Client::STATUS_DISCOVERY,
            'created_by' => $this->user->id,
        ]);

        // Form post status update
        $response = $this->actingAs($this->user)
            ->patch(route('clients.update-status', $client), [
                'status' => Client::STATUS_PAPERWORK_ONBOARDING,
            ]);

        $response->assertRedirect();
        $this->assertDatabaseHas('clients', [
            'id' => $client->id,
            'status' => Client::STATUS_PAPERWORK_ONBOARDING,
        ]);

        // JSON status update for inline cards
        $responseJson = $this->actingAs($this->user)
            ->json('PATCH', route('clients.update-status', $client), [
                'status' => Client::STATUS_ONBOARDED,
            ]);

        $responseJson->assertOk();
        $responseJson->assertJson([
            'success' => true,
            'status' => 'onboarded',
            'label' => 'onboarded',
        ]);

        $this->assertEquals('onboarded', $client->fresh()->status);
    }

    public function test_scheduling_meeting_with_client_creates_reminders_and_updates_status(): void
    {
        $client = Client::create([
            'company_name' => 'Horizon Healthcare',
            'contact_name' => 'Dr. Robert Miller',
            'contact_email' => 'rmiller@horizon.org',
            'campaign' => 'Healthcare Enterprise',
            'status' => Client::STATUS_DISCOVERY,
            'created_by' => $this->user->id,
        ]);

        $startTime = now()->addDays(2)->setHour(14)->setMinute(0);
        $endTime = now()->addDays(2)->setHour(14)->setMinute(45);

        $response = $this->actingAs($this->user)
            ->post(route('clients.schedule-meeting', $client), [
                'title' => 'Executive Architecture Pitch: Horizon Healthcare',
                'start_time' => $startTime->format('Y-m-d H:i:s'),
                'end_time' => $endTime->format('Y-m-d H:i:s'),
                'type' => 'virtual',
                'meeting_link' => 'https://meet.google.com/abc-horizon-pitch',
                'reminder_minutes' => 15,
                'description' => 'Demo platform capabilities and SLA compliance.',
            ]);

        $response->assertRedirect(route('clients.show', $client));
        $response->assertSessionHas('success');

        // Meeting is linked to client
        $meeting = Meeting::where('client_id', $client->id)->first();
        $this->assertNotNull($meeting);
        $this->assertEquals('Executive Architecture Pitch: Horizon Healthcare', $meeting->title);

        // Status auto-advanced to scheduled
        $this->assertEquals(Client::STATUS_SCHEDULED, $client->fresh()->status);

        // Reminder was scheduled in reminders table
        $reminder = Reminder::where('remindable_type', Meeting::class)
            ->where('remindable_id', $meeting->id)
            ->first();

        $this->assertNotNull($reminder);
        $this->assertEquals('pending', $reminder->status);
        $this->assertEquals($this->user->id, $reminder->user_id);
    }

    public function test_client_show_page_renders_with_scheduled_meetings(): void
    {
        $client = Client::create([
            'company_name' => 'Apex Cloud Inc',
            'contact_name' => 'Michael Chang',
            'contact_email' => 'mchang@apexcloud.co',
            'status' => Client::STATUS_SCHEDULED,
            'created_by' => $this->user->id,
        ]);

        $meeting = Meeting::create([
            'title' => 'Apex Demo Call',
            'organizer_id' => $this->user->id,
            'client_id' => $client->id,
            'start_time' => now()->addDay(),
            'end_time' => now()->addDay()->addHour(),
            'status' => 'scheduled',
            'type' => 'virtual',
        ]);

        $response = $this->actingAs($this->user)->get(route('clients.show', $client));

        $response->assertOk();
        $response->assertSee('Apex Cloud Inc');
        $response->assertSee('Michael Chang');
        $response->assertSee('Apex Demo Call');
        $response->assertSee('Scheduled Meetings');
    }

    public function test_user_can_update_progress_notes(): void
    {
        $client = Client::create([
            'company_name' => 'Vanguard Logistics',
            'contact_name' => 'Sara Connor',
            'progress' => 'Awaiting initial pitch deck feedback',
            'status' => Client::STATUS_DISCOVERY,
            'created_by' => $this->user->id,
        ]);

        $response = $this->actingAs($this->user)->put(route('clients.update', $client), [
            'company_name' => 'Vanguard Logistics',
            'contact_name' => 'Sara Connor',
            'progress' => 'Pitch deck approved. Moving to contract review.',
            'status' => Client::STATUS_PAPERWORK_ONBOARDING,
        ]);

        $response->assertRedirect();
        $this->assertDatabaseHas('clients', [
            'id' => $client->id,
            'progress' => 'Pitch deck approved. Moving to contract review.',
            'status' => Client::STATUS_PAPERWORK_ONBOARDING,
        ]);
    }

    public function test_meeting_create_page_renders_with_both_modes(): void
    {
        $response = $this->actingAs($this->user)->get(route('meetings.create'));

        $response->assertOk();
        $response->assertSee('Existing Client (1-Click Fast)');
        $response->assertSee('Enter Details Manually');
        $response->assertSee('Automated Pre-Meeting Reminders');
    }

    public function test_manual_meeting_scheduling_with_save_as_client_creates_pipeline_lead(): void
    {
        $startTime = now()->addDays(3)->setHour(11)->setMinute(0);
        $endTime = now()->addDays(3)->setHour(12)->setMinute(0);

        $payload = [
            'title' => 'Initial Discovery: Quantum AI Labs',
            'client_company' => 'Quantum AI Labs',
            'client_name' => 'Dr. Alan Vance',
            'client_email' => 'alan@quantumai.io',
            'campaign' => 'Cold Email Campaign #1',
            'save_as_client' => '1',
            'start_time' => $startTime->format('Y-m-d H:i:s'),
            'end_time' => $endTime->format('Y-m-d H:i:s'),
            'timezone' => 'UTC',
            'type' => 'virtual',
            'meeting_link' => 'https://meet.google.com/qntm-ai-demo',
            'reminder_minutes' => 15,
        ];

        $response = $this->actingAs($this->user)
            ->post(route('meetings.store'), $payload);

        $response->assertRedirect();

        // Check that new client was auto-created in clients table
        $this->assertDatabaseHas('clients', [
            'company_name' => 'Quantum AI Labs',
            'contact_name' => 'Dr. Alan Vance',
            'contact_email' => 'alan@quantumai.io',
            'campaign' => 'Cold Email Campaign #1',
            'status' => Client::STATUS_SCHEDULED,
        ]);

        $createdClient = Client::where('company_name', 'Quantum AI Labs')->first();
        $meeting = Meeting::where('title', 'Initial Discovery: Quantum AI Labs')->first();

        $this->assertNotNull($meeting);
        $this->assertEquals($createdClient->id, $meeting->client_id);
    }
}
