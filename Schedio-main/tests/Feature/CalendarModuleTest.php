<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Meeting;
use App\Models\Room;
use App\Models\User;
use Carbon\Carbon;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CalendarModuleTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    public function test_calendar_page_renders_successfully(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();

        $response = $this->actingAs($superAdmin)->get(route('calendar.index'));

        $response->assertStatus(200);
        $response->assertSee('Calendar Workspace');
        $response->assertSee('FullCalendar');
    }

    public function test_calendar_feed_returns_json_events(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $start = Carbon::now()->subDays(5)->toIso8601String();
        $end = Carbon::now()->addDays(30)->toIso8601String();

        $response = $this->actingAs($superAdmin)->getJson(route('calendar.feed', [
            'start' => $start,
            'end' => $end,
            'type' => 'all',
        ]));

        $response->assertStatus(200);
        $response->assertJsonStructure([
            '*' => [
                'id',
                'title',
                'start',
                'end',
                'extendedProps' => [
                    'entity_type',
                    'entity_id',
                ],
            ],
        ]);
    }

    public function test_user_can_schedule_meeting_via_calendar_api(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $dept = Department::first();

        $startTime = Carbon::now()->addDays(4)->setTime(11, 0, 0)->toIso8601String();
        $endTime = Carbon::now()->addDays(4)->setTime(12, 0, 0)->toIso8601String();

        $response = $this->actingAs($superAdmin)->postJson(route('calendar.store'), [
            'entity_type' => 'meeting',
            'title' => 'DevOps Cloud Migration Sync',
            'description' => 'Review AWS multi-region cluster deploy.',
            'start_time' => $startTime,
            'end_time' => $endTime,
            'department_id' => $dept->id,
            'type' => 'virtual',
            'meeting_link' => 'https://meet.google.com/devops-sync',
        ]);

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);

        $this->assertDatabaseHas('meetings', [
            'title' => 'DevOps Cloud Migration Sync',
            'organizer_id' => $superAdmin->id,
        ]);
    }

    public function test_meeting_validation_requires_end_time_after_start_time(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $startTime = Carbon::now()->addDays(8)->setTime(14, 0, 0)->toIso8601String();
        $invalidEndTime = Carbon::now()->addDays(8)->setTime(13, 0, 0)->toIso8601String();

        $response = $this->actingAs($superAdmin)->postJson(route('calendar.store'), [
            'entity_type' => 'meeting',
            'title' => 'Invalid Time Meeting',
            'start_time' => $startTime,
            'end_time' => $invalidEndTime,
            'type' => 'virtual',
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['end_time']);
    }

    public function test_user_can_drag_and_drop_reschedule_meeting(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $meeting = Meeting::where('organizer_id', $superAdmin->id)->first();

        $newStart = Carbon::now()->addDays(10)->setTime(16, 0, 0)->toIso8601String();
        $newEnd = Carbon::now()->addDays(10)->setTime(17, 0, 0)->toIso8601String();

        $response = $this->actingAs($superAdmin)->patchJson(route('calendar.update-time', [
            'type' => 'meeting',
            'id' => $meeting->id,
        ]), [
            'start_time' => $newStart,
            'end_time' => $newEnd,
        ]);

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);

        $meeting->refresh();
        $this->assertEquals(Carbon::parse($newStart)->toDateTimeString(), $meeting->start_time->toDateTimeString());
    }

    public function test_user_can_delete_meeting(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $meeting = Meeting::where('organizer_id', $superAdmin->id)->first();

        $response = $this->actingAs($superAdmin)->deleteJson(route('calendar.destroy', [
            'type' => 'meeting',
            'id' => $meeting->id,
        ]));

        $response->assertStatus(200);
        $response->assertJson(['success' => true]);
        $this->assertSoftDeleted('meetings', ['id' => $meeting->id]);
    }
}
