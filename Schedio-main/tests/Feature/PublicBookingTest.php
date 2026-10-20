<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Meeting;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PublicBookingTest extends TestCase
{
    use RefreshDatabase;

    protected User $host;
    protected Department $department;

    protected function setUp(): void
    {
        parent::setUp();

        $this->department = Department::create([
            'name' => 'Executive Consulting',
            'code' => 'EXEC',
            'is_active' => true,
        ]);

        $this->host = User::factory()->create([
            'name' => 'Alex Rivera',
            'email' => 'alex@schedio.com',
            'username' => 'alex',
            'role' => User::ROLE_SUPER_ADMIN,
            'approval_status' => User::STATUS_APPROVED,
            'is_active' => true,
            'department_id' => $this->department->id,
            'booking_headline' => 'Strategic Advisory Call',
            'booking_bio' => 'Book time with Alex.',
            'booking_durations' => [15, 30, 60],
            'default_meeting_link' => 'https://meet.google.com/test-room',
        ]);
    }

    public function test_public_booking_page_renders_successfully(): void
    {
        $response = $this->get('/book/alex');

        $response->assertStatus(200);
        $response->assertSee('Alex Rivera');
        $response->assertSee('Strategic Advisory Call');
        $response->assertSee('Warm welcome:)');
    }

    public function test_invalid_username_returns_404(): void
    {
        $response = $this->get('/book/nonexistent-user-12345');

        $response->assertStatus(404);
    }

    public function test_slots_endpoint_returns_json_with_available_slots(): void
    {
        $tomorrow = Carbon::tomorrow()->format('Y-m-d');

        $response = $this->getJson("/book/alex/slots?date={$tomorrow}&duration=30");

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'date',
            'duration',
            'morning',
            'afternoon',
            'total_available',
        ]);
        $this->assertGreaterThan(0, $response->json('total_available'));
    }

    public function test_client_can_book_meeting_via_public_link(): void
    {
        $tomorrow = Carbon::tomorrow()->setTime(10, 0, 0);

        $payload = [
            'client_name' => 'John Doe',
            'client_email' => 'john@clientcorp.com',
            'client_company' => 'Client Corp',
            'start_time' => $tomorrow->toIso8601String(),
            'duration_minutes' => 30,
            'notes' => 'Discuss enterprise contract terms',
        ];

        $response = $this->post('/book/alex', $payload);

        $meeting = Meeting::where('organizer_id', $this->host->id)->first();
        $this->assertNotNull($meeting);
        $this->assertEquals('Consultation: John Doe & Alex Rivera', $meeting->title);
        $this->assertEquals('Client Corp', $meeting->metadata['client_company']);
        $this->assertEquals('john@clientcorp.com', $meeting->metadata['client_email']);

        $response->assertRedirect(route('booking.confirmed', [
            'username' => 'alex',
            'meeting' => $meeting->id,
        ]));
    }

    public function test_public_booking_prevents_double_booking_conflicts(): void
    {
        $slotStart = Carbon::tomorrow()->setTime(14, 0, 0);
        $slotEnd = $slotStart->copy()->addMinutes(30);

        // Pre-create an existing meeting for the host at that time
        Meeting::create([
            'title' => 'Existing Conflicting Call',
            'organizer_id' => $this->host->id,
            'department_id' => $this->department->id,
            'start_time' => $slotStart,
            'end_time' => $slotEnd,
            'timezone' => 'UTC',
            'status' => 'scheduled',
            'type' => 'virtual',
        ]);

        $payload = [
            'client_name' => 'Second Client',
            'client_email' => 'second@client.com',
            'start_time' => $slotStart->toIso8601String(),
            'duration_minutes' => 30,
        ];

        $response = $this->post('/book/alex', $payload);

        $response->assertSessionHasErrors('start_time');
    }

    public function test_confirmation_page_renders_with_calendar_links(): void
    {
        $meeting = Meeting::create([
            'title' => 'Consultation: Elena & Alex',
            'organizer_id' => $this->host->id,
            'department_id' => $this->department->id,
            'start_time' => Carbon::tomorrow()->setTime(11, 0, 0),
            'end_time' => Carbon::tomorrow()->setTime(11, 30, 0),
            'timezone' => 'UTC',
            'status' => 'scheduled',
            'type' => 'virtual',
            'meeting_link' => 'https://meet.google.com/test-room',
            'metadata' => [
                'client_name' => 'Elena',
                'client_email' => 'elena@client.com',
            ],
        ]);

        $response = $this->get(route('booking.confirmed', [
            'username' => 'alex',
            'meeting' => $meeting->id,
        ]));

        $response->assertStatus(200);
        $response->assertSee('Confirmed & Scheduled', false);
        $response->assertSee('Add to Google Calendar');
        $response->assertSee('Download Outlook / iCal (.ics)');
    }

    public function test_ical_export_generates_valid_ics_file(): void
    {
        $meeting = Meeting::create([
            'title' => 'Consultation: Elena & Alex',
            'organizer_id' => $this->host->id,
            'department_id' => $this->department->id,
            'start_time' => Carbon::tomorrow()->setTime(11, 0, 0),
            'end_time' => Carbon::tomorrow()->setTime(11, 30, 0),
            'timezone' => 'UTC',
            'status' => 'scheduled',
            'type' => 'virtual',
            'meeting_link' => 'https://meet.google.com/test-room',
        ]);

        $response = $this->get(route('booking.export-ical', [
            'username' => 'alex',
            'meeting' => $meeting->id,
        ]));

        $response->assertStatus(200);
        $response->assertHeader('Content-Type', 'text/calendar; charset=utf-8');
        $this->assertStringContainsString('BEGIN:VCALENDAR', $response->getContent());
        $this->assertStringContainsString('SUMMARY:Consultation: Elena & Alex', $response->getContent());
    }
}
