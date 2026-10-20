<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\Meeting;
use App\Models\Room;
use App\Models\User;
use App\Services\ConflictDetectionService;
use Carbon\Carbon;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConflictDetectionServiceTest extends TestCase
{
    use RefreshDatabase;

    protected ConflictDetectionService $conflictService;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
        $this->conflictService = app(ConflictDetectionService::class);
    }

    public function test_room_conflict_is_detected_accurately(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $room = Room::first();

        $start = Carbon::now()->addDays(5)->setTime(10, 0, 0);
        $end = Carbon::now()->addDays(5)->setTime(11, 0, 0);

        Meeting::create([
            'title' => 'Room Lock Session',
            'organizer_id' => $superAdmin->id,
            'room_id' => $room->id,
            'start_time' => $start,
            'end_time' => $end,
            'status' => 'scheduled',
            'type' => 'in_person',
        ]);

        // Overlap test
        $check = $this->conflictService->checkAvailability(
            $start->copy()->addMinutes(15),
            $end->copy()->addMinutes(15),
            $room->id,
            []
        );

        $this->assertTrue($check['has_conflicts']);
        $this->assertEquals('conflict', $check['room']['status']);
        $this->assertEquals('Room Lock Session', $check['room']['conflict']['title']);
    }

    public function test_participant_meeting_conflict_is_detected(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $employee = User::where('email', 'marcus.v@schedio.com')->first();

        $start = Carbon::now()->addDays(6)->setTime(14, 0, 0);
        $end = Carbon::now()->addDays(6)->setTime(15, 0, 0);

        // Schedule meeting for employee
        $meeting = Meeting::create([
            'title' => 'Core Architecture Review',
            'organizer_id' => $superAdmin->id,
            'start_time' => $start,
            'end_time' => $end,
            'status' => 'scheduled',
            'type' => 'virtual',
        ]);
        $meeting->participants()->attach($employee->id, ['status' => 'accepted', 'role' => 'attendee']);

        // Check availability for employee during this window
        $check = $this->conflictService->checkAvailability(
            $start->copy()->addMinutes(10),
            $end->copy()->addMinutes(10),
            null,
            [$employee->id]
        );

        $this->assertTrue($check['has_conflicts']);
        $participantResult = collect($check['participants'])->firstWhere('user_id', $employee->id);
        $this->assertEquals('conflict', $participantResult['status']);
        $this->assertStringContainsString('Core Architecture Review', $participantResult['reason']);
    }

    public function test_participant_event_busy_status_is_detected(): void
    {
        $employee = User::where('email', 'marcus.v@schedio.com')->first();

        $start = Carbon::now()->addDays(7)->setTime(13, 0, 0);
        $end = Carbon::now()->addDays(7)->setTime(14, 30, 0);

        Event::create([
            'title' => 'DevOps Certification Workshop',
            'user_id' => $employee->id,
            'start_time' => $start,
            'end_time' => $end,
            'category' => 'training',
        ]);

        $check = $this->conflictService->checkAvailability(
            $start->copy()->addMinutes(15),
            $end->copy()->addMinutes(15),
            null,
            [$employee->id]
        );

        $participantResult = collect($check['participants'])->firstWhere('user_id', $employee->id);
        $this->assertEquals('busy', $participantResult['status']);
        $this->assertStringContainsString('DevOps Certification Workshop', $participantResult['reason']);
    }

    public function test_smart_suggestions_returns_conflict_free_slots(): void
    {
        $employee = User::where('email', 'marcus.v@schedio.com')->first();
        $targetDate = Carbon::now()->addDays(9);

        $slots = $this->conflictService->suggestAvailableSlots(
            $targetDate,
            60,
            null,
            [$employee->id]
        );

        $this->assertNotEmpty($slots);
        $this->assertLessThanOrEqual(5, count($slots));
        $this->assertArrayHasKey('formatted_start', $slots[0]);
        $this->assertArrayHasKey('formatted_end', $slots[0]);
    }

    public function test_availability_api_endpoints_work(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $employee = User::where('email', 'marcus.v@schedio.com')->first();

        $start = Carbon::now()->addDays(10)->setTime(10, 0, 0)->toIso8601String();
        $end = Carbon::now()->addDays(10)->setTime(11, 0, 0)->toIso8601String();

        // 1. Check API
        $checkRes = $this->actingAs($superAdmin)->postJson(route('availability.check'), [
            'start_time' => $start,
            'end_time' => $end,
            'participant_ids' => [$employee->id],
        ]);

        $checkRes->assertStatus(200);
        $checkRes->assertJsonStructure(['has_conflicts', 'participants']);

        // 2. Suggestions API
        $suggRes = $this->actingAs($superAdmin)->getJson(route('availability.suggestions', [
            'date' => Carbon::now()->addDays(10)->toDateString(),
            'duration_minutes' => 45,
            'participant_ids' => [$employee->id],
        ]));

        $suggRes->assertStatus(200);
        $suggRes->assertJsonStructure(['slots', 'count']);
    }
}
