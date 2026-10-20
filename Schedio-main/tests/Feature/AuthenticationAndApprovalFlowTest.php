<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthenticationAndApprovalFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed(DatabaseSeeder::class);
    }

    public function test_login_page_renders_successfully(): void
    {
        $response = $this->get(route('login'));
        $response->assertStatus(200);
        $response->assertSee('Sign In to Workspace');
    }

    public function test_super_admin_can_login_successfully(): void
    {
        $response = $this->post(route('login.post'), [
            'email' => 'admin@schedio.com',
            'password' => 'password',
        ]);

        $response->assertRedirect(route('dashboard'));
        $this->assertAuthenticated();
        $this->assertTrue(auth()->user()->isSuperAdmin());
    }

    public function test_pending_user_cannot_login_and_sees_pending_message(): void
    {
        $response = $this->from(route('login'))->post(route('login.post'), [
            'email' => 'sophia.lin@schedio.com',
            'password' => 'password',
        ]);

        $response->assertRedirect(route('login'));
        $this->assertGuest();
        $response->assertSessionHasErrors(['email']);
    }

    public function test_registration_request_creates_pending_user(): void
    {
        $department = Department::first();

        $response = $this->post(route('register.post'), [
            'name' => 'John Wick',
            'email' => 'john.wick@continental.com',
            'password' => 'SecurePass123!',
            'password_confirmation' => 'SecurePass123!',
            'title' => 'Security Director',
            'department_id' => $department->id,
            'phone' => '+1 555-099-1122',
            'registration_notes' => 'Need scheduling for continental operations.',
        ]);

        $response->assertRedirect(route('login'));
        $response->assertSessionHas('status');

        $user = User::where('email', 'john.wick@continental.com')->first();
        $this->assertNotNull($user);
        $this->assertEquals(User::STATUS_PENDING, $user->approval_status);
        $this->assertTrue(Hash::check('SecurePass123!', $user->password));
    }

    public function test_super_admin_can_approve_pending_registration(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $pendingUser = User::where('email', 'sophia.lin@schedio.com')->first();
        $this->assertEquals(User::STATUS_PENDING, $pendingUser->approval_status);

        $response = $this->actingAs($superAdmin)
            ->patch(route('admin.registration-requests.approve', $pendingUser), [
                'role' => 'employee',
                'department_id' => $pendingUser->department_id,
            ]);

        $response->assertRedirect();
        $pendingUser->refresh();
        $this->assertEquals(User::STATUS_APPROVED, $pendingUser->approval_status);
        $this->assertEquals($superAdmin->id, $pendingUser->approved_by);
        $this->assertNotNull($pendingUser->approved_at);

        // Sophia can now log in
        $this->post(route('logout'));
        $loginRes = $this->post(route('login.post'), [
            'email' => 'sophia.lin@schedio.com',
            'password' => 'password',
        ]);
        $loginRes->assertRedirect(route('dashboard'));
    }

    public function test_super_admin_can_reject_registration(): void
    {
        $superAdmin = User::where('email', 'admin@schedio.com')->first();
        $pendingUser = User::where('email', 'jessica.t@initech.com')->first();

        $response = $this->actingAs($superAdmin)
            ->patch(route('admin.registration-requests.reject', $pendingUser), [
                'rejection_reason' => 'Vendor contract not active.',
            ]);

        $response->assertRedirect();
        $pendingUser->refresh();
        $this->assertEquals(User::STATUS_REJECTED, $pendingUser->approval_status);
        $this->assertEquals('Vendor contract not active.', $pendingUser->rejection_reason);
    }

    public function test_non_super_admin_cannot_access_admin_registration_management(): void
    {
        $employee = User::where('email', 'marcus.v@schedio.com')->first();

        $response = $this->actingAs($employee)
            ->get(route('admin.registration-requests.index'));

        $response->assertStatus(403);
    }
}
