<?php

namespace Tests\Feature;

use App\Models\Client;
use App\Models\Department;
use App\Models\Meeting;
use App\Models\User;
use Carbon\Carbon;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserDataIsolationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    public function test_regular_user_cannot_see_other_users_deals_in_pipeline(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $userA = User::where('email', 'marcus.v@schedio.com')->first();
        $userB = User::where('email', 'sarah.chen@schedio.com')->first();

        // Create deal for User A
        $dealA = Client::create([
            'company_name' => 'Company A Private Deal',
            'contact_name' => 'Alice A',
            'status' => 'discovery',
            'deal_value' => 50000,
            'assigned_to' => $userA->id,
            'created_by' => $userA->id,
        ]);

        // Create deal for User B
        $dealB = Client::create([
            'company_name' => 'Company B Private Deal',
            'contact_name' => 'Bob B',
            'status' => 'scheduled',
            'deal_value' => 75000,
            'assigned_to' => $userB->id,
            'created_by' => $userB->id,
        ]);

        // User A views pipeline
        $responseA = $this->actingAs($userA)->get(route('clients.index'));
        $responseA->assertStatus(200);
        $responseA->assertSee('Company A Private Deal');
        $responseA->assertDontSee('Company B Private Deal');

        // User B views pipeline
        $responseB = $this->actingAs($userB)->get(route('clients.index'));
        $responseB->assertStatus(200);
        $responseB->assertSee('Company B Private Deal');
        $responseB->assertDontSee('Company A Private Deal');

        // Developer (Super Admin) sees BOTH deals
        $responseAdmin = $this->actingAs($superAdmin)->get(route('clients.index'));
        $responseAdmin->assertStatus(200);
        $responseAdmin->assertSee('Company A Private Deal');
        $responseAdmin->assertSee('Company B Private Deal');
    }

    public function test_regular_user_cannot_view_or_edit_another_users_deal_directly(): void
    {
        $userA = User::where('email', 'marcus.v@schedio.com')->first();
        $userB = User::where('email', 'sarah.chen@schedio.com')->first();

        $dealB = Client::create([
            'company_name' => 'Top Secret Corp B',
            'contact_name' => 'Confidential Contact',
            'status' => 'discovery',
            'deal_value' => 100000,
            'assigned_to' => $userB->id,
            'created_by' => $userB->id,
        ]);

        // User A tries to view Deal B -> 403 Forbidden
        $response = $this->actingAs($userA)->get(route('clients.show', $dealB));
        $response->assertStatus(403);

        // User A tries to update status of Deal B -> 403 Forbidden
        $patchResponse = $this->actingAs($userA)->patchJson(route('clients.update-status', $dealB), [
            'status' => 'scheduled',
        ]);
        $patchResponse->assertStatus(403);
    }

    public function test_regular_user_cannot_access_user_approvals_screen(): void
    {
        $userA = User::where('email', 'marcus.v@schedio.com')->first();

        // Regular user cannot see developer's user approvals
        $response = $this->actingAs($userA)->get(route('admin.registration-requests.index'));
        $response->assertStatus(403);
    }

    public function test_new_user_registration_is_pending_until_developer_approves(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $dept = Department::first();

        // 1. New user submits signup
        $registerResponse = $this->post(route('register.post'), [
            'name' => 'Zubair Khan',
            'email' => 'zubair.khan@example.com',
            'password' => 'SecurePass123!',
            'password_confirmation' => 'SecurePass123!',
            'department_id' => $dept->id,
            'registration_notes' => 'New BD rep joining team.',
        ]);

        $newUser = User::where('email', 'zubair.khan@example.com')->first();
        $this->assertNotNull($newUser);
        $this->assertEquals(User::STATUS_PENDING, $newUser->approval_status);

        // 2. Pending user tries to log in -> blocked with error
        $loginResponse = $this->post(route('login.post'), [
            'email' => 'zubair.khan@example.com',
            'password' => 'SecurePass123!',
        ]);
        $loginResponse->assertSessionHasErrors('email');
        $this->assertGuest();

        // 3. Developer approves the user
        $approveResponse = $this->actingAs($superAdmin)->patch(route('admin.registration-requests.approve', $newUser), [
            'role' => User::ROLE_EMPLOYEE,
            'department_id' => $dept->id,
            'title' => 'BD Associate',
        ]);
        $approveResponse->assertSessionHas('success');

        $newUser->refresh();
        $this->assertEquals(User::STATUS_APPROVED, $newUser->approval_status);

        // 4. Log out admin and user logs in successfully
        auth()->logout();

        $loginSuccess = $this->post(route('login.post'), [
            'email' => 'zubair.khan@example.com',
            'password' => 'SecurePass123!',
        ]);
        $loginSuccess->assertRedirect(route('dashboard'));
        $this->assertAuthenticatedAs($newUser);
    }
}
