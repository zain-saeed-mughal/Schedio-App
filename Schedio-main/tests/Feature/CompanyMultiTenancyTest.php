<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\Department;
use App\Models\Meeting;
use App\Models\Room;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CompanyMultiTenancyTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    public function test_new_company_super_admin_registration_requires_developer_approval(): void
    {
        $developer = User::where('email', 'admin@schedio.com')->first();

        // 1. Applicant registers a new company workspace as CEO
        $response = $this->post(route('register.post'), [
            'registration_type' => 'company_super_admin',
            'company_name' => 'Nova Robotics Inc',
            'name' => 'Liam Sterling',
            'email' => 'liam@novarobotics.com',
            'password' => 'SecurePass123!',
            'password_confirmation' => 'SecurePass123!',
            'title' => 'Chief Executive Officer',
            'phone' => '+1 (555) 777-8899',
            'registration_notes' => 'New AI robotics startup launching corporate scheduling.',
        ]);

        $response->assertRedirect(route('login'));
        $response->assertSessionHas('status');

        // Verify Company is in pending status
        $company = Company::where('name', 'Nova Robotics Inc')->first();
        $this->assertNotNull($company);
        $this->assertEquals(Company::STATUS_PENDING, $company->status);

        // Verify User is created as Super Admin with pending status
        $user = User::withoutGlobalScopes()->where('email', 'liam@novarobotics.com')->first();
        $this->assertNotNull($user);
        $this->assertEquals(User::ROLE_SUPER_ADMIN, $user->role);
        $this->assertEquals(User::STATUS_PENDING, $user->approval_status);
        $this->assertEquals($company->id, $user->company_id);

        // 2. Pending CEO tries to log in -> blocked with error
        $loginAttempt = $this->post(route('login.post'), [
            'email' => 'liam@novarobotics.com',
            'password' => 'SecurePass123!',
        ]);
        $loginAttempt->assertSessionHasErrors('email');
        $this->assertGuest();

        // 3. Platform Developer approves the Company & CEO Super Admin
        $approveResponse = $this->actingAs($developer)->patch(route('admin.registration-requests.approve', $user), [
            'role' => User::ROLE_SUPER_ADMIN,
        ]);
        $approveResponse->assertSessionHas('success');

        $user->refresh();
        $company->refresh();

        $this->assertEquals(User::STATUS_APPROVED, $user->approval_status);
        $this->assertEquals(Company::STATUS_ACTIVE, $company->status);

        // 4. Approved CEO logs in successfully
        auth()->logout();
        $loginSuccess = $this->post(route('login.post'), [
            'email' => 'liam@novarobotics.com',
            'password' => 'SecurePass123!',
        ]);
        $loginSuccess->assertRedirect(route('dashboard'));
        $this->assertAuthenticatedAs($user);
    }

    public function test_cross_company_meeting_isolation_between_super_admins(): void
    {
        $schedioEmployee = User::where('email', 'marcus.v@schedio.com')->first();
        $apexCeo = User::where('email', 'ceo@apexlogistics.com')->first();

        // Apex CEO views meetings
        $apexResponse = $this->actingAs($apexCeo)->get(route('meetings.index'));
        $apexResponse->assertStatus(200);
        $apexResponse->assertSee('Apex Q4 Confidential Supply Chain Meeting');
        $apexResponse->assertDontSee('Q4 Sprint Planning & Architecture Review');

        // Schedio employee views meetings
        $schedioResponse = $this->actingAs($schedioEmployee)->get(route('meetings.index'));
        $schedioResponse->assertStatus(200);
        $schedioResponse->assertSee('Q4 Sprint Planning & Architecture Review');
        $schedioResponse->assertDontSee('Apex Q4 Confidential Supply Chain Meeting');
    }

    public function test_super_admin_cannot_view_another_companys_meeting_by_direct_id(): void
    {
        $apexCeo = User::where('email', 'ceo@apexlogistics.com')->first();
        $schedioMeeting = Meeting::withoutGlobalScopes()->where('title', 'like', '%Sprint Planning%')->first();

        // Apex CEO tries to directly access Schedio HQ's meeting details -> 404 (due to CompanyScope)
        $response = $this->actingAs($apexCeo)->get(route('meetings.show', $schedioMeeting));
        $this->assertTrue(in_array($response->status(), [403, 404], true));
    }

    public function test_cross_company_room_isolation(): void
    {
        $apexCeo = User::where('email', 'ceo@apexlogistics.com')->first();

        // Room listing for Apex CEO only lists Apex rooms
        $response = $this->actingAs($apexCeo)->get(route('rooms.index'));
        $response->assertStatus(200);
        $response->assertSee('Apex Executive Summit Suite');
        $response->assertDontSee('Apollo Executive Boardroom');
    }

    public function test_company_super_admin_cannot_approve_users_from_other_companies(): void
    {
        $apexCeo = User::where('email', 'ceo@apexlogistics.com')->first();
        $pendingSchedioUser = User::withoutGlobalScopes()->where('email', 'sophia.lin@schedio.com')->first();

        // Apex CEO attempts to approve Sophia Lin (who belongs to Schedio HQ) -> 403 Forbidden
        $response = $this->actingAs($apexCeo)->patch(route('admin.registration-requests.approve', $pendingSchedioUser), [
            'role' => User::ROLE_EMPLOYEE,
        ]);
        $response->assertStatus(403);
    }

    public function test_platform_developer_can_view_all_companies_and_meetings(): void
    {
        $developer = User::where('email', 'admin@schedio.com')->first();

        // Developer views meetings listing -> can view both
        $response = $this->actingAs($developer)->get(route('meetings.index'));
        $response->assertStatus(200);
        $response->assertSee('Q4 Sprint Planning & Architecture Review');
        $response->assertSee('Apex Q4 Confidential Supply Chain Meeting');
    }
}
