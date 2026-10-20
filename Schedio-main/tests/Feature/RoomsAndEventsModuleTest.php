<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Event;
use App\Models\Meeting;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RoomsAndEventsModuleTest extends TestCase
{
    use RefreshDatabase;

    private User $superAdmin;
    private User $employee;
    private Department $dept;

    protected function setUp(): void
    {
        parent::setUp();

        $this->dept = Department::create([
            'name' => 'Design & Research',
            'code' => 'DES',
            'is_active' => true,
        ]);

        $this->superAdmin = User::factory()->create([
            'name' => 'Super Admin',
            'email' => 'admin@schedio.test',
            'role' => User::ROLE_SUPER_ADMIN,
            'approval_status' => User::STATUS_APPROVED,
            'department_id' => $this->dept->id,
        ]);

        $this->employee = User::factory()->create([
            'name' => 'Regular Dev',
            'email' => 'dev@schedio.test',
            'role' => User::ROLE_EMPLOYEE,
            'approval_status' => User::STATUS_APPROVED,
            'department_id' => $this->dept->id,
        ]);
    }

    public function test_company_events_module_crud_and_calendar_visibility(): void
    {
        // 1. View events listing
        $indexResponse = $this->actingAs($this->employee)->get(route('events.index'));
        $indexResponse->assertStatus(200);
        $indexResponse->assertSee('Company Events', false);
        $indexResponse->assertSee('Holidays', false);

        // 2. Create company holiday as Super Admin
        $eventResponse = $this->actingAs($this->superAdmin)->post(route('events.store'), [
            'title' => 'National Technology Day',
            'category' => 'company_holiday',
            'start_time' => now()->addDays(10)->setTime(0, 0, 0)->format('Y-m-d H:i:s'),
            'end_time' => now()->addDays(10)->setTime(23, 59, 59)->format('Y-m-d H:i:s'),
            'is_all_day' => '1',
            'is_company_wide' => '1',
            'description' => 'Paid company-wide holiday for all engineering & design departments.',
        ]);

        $eventResponse->assertRedirect(route('events.index'));
        $this->assertDatabaseHas('events', [
            'title' => 'National Technology Day',
            'category' => 'company_holiday',
            'is_company_wide' => true,
        ]);

        $holiday = Event::where('title', 'National Technology Day')->first();

        // 3. Verify event appears in calendar JSON feed for employee
        $feedResponse = $this->actingAs($this->employee)->getJson(route('calendar.feed', [
            'start' => now()->addDays(5)->toIso8601String(),
            'end' => now()->addDays(15)->toIso8601String(),
            'type' => 'holidays',
        ]));

        $feedResponse->assertStatus(200);
        $this->assertTrue(collect($feedResponse->json())->contains(function ($item) {
            return $item['title'] === 'National Technology Day';
        }));

        // 4. Update Event
        $updateResponse = $this->actingAs($this->superAdmin)->put(route('events.update', $holiday), [
            'title' => 'National Tech & Innovation Day',
            'category' => 'company_holiday',
            'start_time' => $holiday->start_time->format('Y-m-d H:i:s'),
            'end_time' => $holiday->end_time->format('Y-m-d H:i:s'),
            'is_all_day' => '1',
            'is_company_wide' => '1',
        ]);

        $updateResponse->assertRedirect(route('events.index'));
        $this->assertDatabaseHas('events', ['title' => 'National Tech & Innovation Day']);

        // 5. Delete Event
        $deleteResponse = $this->actingAs($this->superAdmin)->delete(route('events.destroy', $holiday));
        $deleteResponse->assertRedirect(route('events.index'));
        $this->assertSoftDeleted('events', ['id' => $holiday->id]);
    }

    public function test_room_management_and_availability_checks(): void
    {
        // 1. Employee can view room listing
        $indexResponse = $this->actingAs($this->employee)->get(route('rooms.index'));
        $indexResponse->assertStatus(200);
        $indexResponse->assertSee('Meeting Suites', false);

        // 2. Super admin creates new room
        $createResponse = $this->actingAs($this->superAdmin)->post(route('rooms.store'), [
            'name' => 'Zenith Innovation Boardroom',
            'code' => 'ROOM-ZENITH-01',
            'location' => 'Floor 4, West Wing',
            'capacity' => 16,
            'amenities_text' => '4K Dual Displays, Conference Phone, Whiteboard',
            'color' => '#10b981',
            'is_active' => '1',
        ]);

        $createResponse->assertRedirect(route('rooms.index'));
        $this->assertDatabaseHas('rooms', [
            'name' => 'Zenith Innovation Boardroom',
            'code' => 'ROOM-ZENITH-01',
            'capacity' => 16,
        ]);

        $room = \App\Models\Room::where('code', 'ROOM-ZENITH-01')->first();

        // 3. View room details
        $showResponse = $this->actingAs($this->employee)->get(route('rooms.show', $room));
        $showResponse->assertStatus(200);
        $showResponse->assertSee('Zenith Innovation Boardroom', false);

        // 4. Check room availability JSON endpoint (free slot)
        $availResponse = $this->actingAs($this->employee)->postJson(route('rooms.check-availability', $room), [
            'start_time' => now()->addDays(1)->setTime(10, 0)->toIso8601String(),
            'end_time' => now()->addDays(1)->setTime(11, 0)->toIso8601String(),
        ]);
        $availResponse->assertStatus(200);
        $availResponse->assertJson(['available' => true]);

        // 5. Super admin updates room
        $updateResponse = $this->actingAs($this->superAdmin)->put(route('rooms.update', $room), [
            'name' => 'Zenith Executive Suite',
            'code' => 'ROOM-ZENITH-01',
            'location' => 'Floor 4, West Wing',
            'capacity' => 20,
            'is_active' => '1',
        ]);
        $updateResponse->assertRedirect(route('rooms.index'));
        $this->assertDatabaseHas('rooms', ['id' => $room->id, 'name' => 'Zenith Executive Suite', 'capacity' => 20]);

        // 6. Super admin deletes room
        $deleteResponse = $this->actingAs($this->superAdmin)->delete(route('rooms.destroy', $room));
        $deleteResponse->assertRedirect(route('rooms.index'));
        $this->assertSoftDeleted('rooms', ['id' => $room->id]);
    }
}
