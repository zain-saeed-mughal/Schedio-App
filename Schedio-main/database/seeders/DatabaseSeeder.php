<?php

namespace Database\Seeders;

use App\Models\AuditLog;
use App\Models\Company;
use App\Models\Department;
use App\Models\Event;
use App\Models\Meeting;
use App\Models\MeetingParticipant;
use App\Models\Reminder;
use App\Models\Room;
use App\Models\Task;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // 0. Seed Primary Tenant Company (Schedio HQ)
        $primaryCompany = Company::create([
            'name' => 'Schedio Technologies HQ',
            'slug' => 'schedio-hq',
            'status' => Company::STATUS_ACTIVE,
            'domain' => 'schedio.com',
        ]);

        // 1. Seed Core Departments
        $engineering = Department::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Engineering & Technology',
            'code' => 'ENG',
            'description' => 'Software engineering, DevOps, and cloud infrastructure architecture.',
            'is_active' => true,
        ]);

        $product = Department::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Product & Design',
            'code' => 'PROD',
            'description' => 'Product strategy, UX/UI design systems, and user research.',
            'is_active' => true,
        ]);

        $clientOps = Department::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Client Success & Operations',
            'code' => 'OPS',
            'description' => 'Account management, external client relationships, and business operations.',
            'is_active' => true,
        ]);

        // 2. Seed Developer (Platform Master Admin) & Core Users
        $superAdmin = User::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Alex Rivera',
            'title' => 'Chief Technology Officer & Platform Developer',
            'email' => 'admin@schedio.com',
            'phone' => '+1 (555) 019-2834',
            'password' => Hash::make('password'),
            'department_id' => $engineering->id,
            'role' => User::ROLE_DEVELOPER,
            'approval_status' => User::STATUS_APPROVED,
            'approved_at' => now(),
            'timezone' => 'America/New_York',
            'is_active' => true,
            'email_verified_at' => now(),
        ]);

        $manager = User::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Sarah Chen',
            'title' => 'Head of Product',
            'email' => 'sarah.chen@schedio.com',
            'phone' => '+1 (555) 014-9921',
            'password' => Hash::make('password'),
            'department_id' => $product->id,
            'role' => User::ROLE_MANAGER,
            'approval_status' => User::STATUS_APPROVED,
            'approved_at' => now(),
            'approved_by' => $superAdmin->id,
            'timezone' => 'America/New_York',
            'is_active' => true,
            'email_verified_at' => now(),
        ]);

        $employee1 = User::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Marcus Vance',
            'title' => 'Senior Systems Engineer',
            'email' => 'marcus.v@schedio.com',
            'phone' => '+1 (555) 018-3729',
            'password' => Hash::make('password'),
            'department_id' => $engineering->id,
            'role' => User::ROLE_EMPLOYEE,
            'approval_status' => User::STATUS_APPROVED,
            'approved_at' => now(),
            'approved_by' => $superAdmin->id,
            'timezone' => 'America/New_York',
            'is_active' => true,
            'email_verified_at' => now(),
        ]);

        $clientUser = User::create([
            'company_id' => $primaryCompany->id,
            'name' => 'David Sterling',
            'title' => 'Partner / Enterprise Lead (Acme Corp)',
            'email' => 'david.sterling@acme.com',
            'phone' => '+1 (555) 015-8833',
            'password' => Hash::make('password'),
            'department_id' => $clientOps->id,
            'role' => User::ROLE_CLIENT,
            'approval_status' => User::STATUS_APPROVED,
            'approved_at' => now(),
            'approved_by' => $superAdmin->id,
            'timezone' => 'America/New_York',
            'is_active' => true,
            'email_verified_at' => now(),
        ]);

        // Seed Pending Registration Requests
        $pendingUser1 = User::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Sophia Lin',
            'title' => 'Frontend UI Engineer',
            'email' => 'sophia.lin@schedio.com',
            'phone' => '+1 (555) 017-4920',
            'password' => Hash::make('password'),
            'department_id' => $engineering->id,
            'role' => User::ROLE_EMPLOYEE,
            'approval_status' => User::STATUS_PENDING,
            'registration_notes' => 'Joined frontend squad under Alex Rivera. Need calendar & room access.',
            'timezone' => 'America/New_York',
            'is_active' => true,
        ]);

        $pendingUser2 = User::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Jessica Taylor',
            'title' => 'Procurement Director (Initech Global)',
            'email' => 'jessica.t@initech.com',
            'phone' => '+1 (555) 016-7733',
            'password' => Hash::make('password'),
            'department_id' => $clientOps->id,
            'role' => User::ROLE_EMPLOYEE,
            'approval_status' => User::STATUS_PENDING,
            'registration_notes' => 'External vendor lead for Q4 joint infrastructure integration.',
            'timezone' => 'America/Chicago',
            'is_active' => true,
        ]);

        // Assign department managers
        $engineering->update(['manager_id' => $superAdmin->id]);
        $product->update(['manager_id' => $manager->id]);
        $clientOps->update(['manager_id' => $superAdmin->id]);

        // 3. Seed Meeting Rooms
        $boardroom = Room::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Apollo Executive Boardroom',
            'code' => 'ROOM-APOLLO',
            'location' => 'Floor 4, East Wing',
            'capacity' => 16,
            'amenities' => ['4K Dual Displays', 'Cisco Telepresence', 'Smart Whiteboard', 'Airplay & HDMI', 'Coffee Station'],
            'color' => '#6366f1',
            'is_active' => true,
        ]);

        $focusRoom = Room::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Orion Focus Pod',
            'code' => 'ROOM-ORION',
            'location' => 'Floor 3, West Wing',
            'capacity' => 4,
            'amenities' => ['Acoustic Insulation', 'Ultra-wide Monitor', 'Jabra Wireless Speakerphone'],
            'color' => '#06b6d4',
            'is_active' => true,
        ]);

        $clientLounge = Room::create([
            'company_id' => $primaryCompany->id,
            'name' => 'Nova Client Suite',
            'code' => 'ROOM-NOVA',
            'location' => 'Floor 2, VIP Reception',
            'capacity' => 8,
            'amenities' => ['Executive Lounge Seating', 'Presentation Screen', 'Private Video Booth'],
            'color' => '#10b981',
            'is_active' => true,
        ]);

        // 4. Seed Meetings (Internal and External/Client)
        $internalMeeting = Meeting::create([
            'company_id' => $primaryCompany->id,
            'title' => 'Q4 Sprint Planning & Architecture Review',
            'description' => 'Review technical roadmap, microservice decoupling milestones, and PostgreSQL index optimizations.',
            'organizer_id' => $superAdmin->id,
            'department_id' => $engineering->id,
            'room_id' => $boardroom->id,
            'start_time' => Carbon::now()->addDay()->setTime(10, 0, 0),
            'end_time' => Carbon::now()->addDay()->setTime(11, 30, 0),
            'timezone' => 'America/New_York',
            'status' => 'scheduled',
            'type' => 'hybrid',
            'meeting_link' => 'https://meet.schedio.com/eng-sprint-q4',
            'location' => 'Apollo Executive Boardroom & Google Meet',
            'is_private' => false,
            'metadata' => ['agenda_doc' => 'https://docs.schedio.com/eng/q4-plan'],
        ]);

        $clientMeeting = Meeting::create([
            'company_id' => $primaryCompany->id,
            'title' => 'Acme Corp — Q4 Enterprise Architecture & SLA Review',
            'description' => 'Joint quarterly business review with David Sterling regarding enterprise uptime and roadmap delivery.',
            'organizer_id' => $superAdmin->id,
            'department_id' => $clientOps->id,
            'room_id' => $clientLounge->id,
            'start_time' => Carbon::now()->addDays(2)->setTime(14, 0, 0),
            'end_time' => Carbon::now()->addDays(2)->setTime(15, 30, 0),
            'timezone' => 'America/New_York',
            'status' => 'scheduled',
            'type' => 'hybrid',
            'meeting_link' => 'https://meet.schedio.com/acme-q4-review',
            'location' => 'Nova Client Suite & Zoom Room',
            'is_private' => false,
            'metadata' => ['client_code' => 'ACME-2026', 'sla_tier' => 'Platinum'],
        ]);

        // 5. Seed Meeting Participants
        MeetingParticipant::create([
            'meeting_id' => $internalMeeting->id,
            'user_id' => $superAdmin->id,
            'status' => 'accepted',
            'role' => 'host',
            'response_notes' => 'Organizing agenda and architectural overview.',
            'responded_at' => now(),
        ]);

        MeetingParticipant::create([
            'meeting_id' => $internalMeeting->id,
            'user_id' => $employee1->id,
            'status' => 'accepted',
            'role' => 'presenter',
            'response_notes' => 'Will present database partition benchmarks.',
            'responded_at' => now(),
        ]);

        MeetingParticipant::create([
            'meeting_id' => $internalMeeting->id,
            'user_id' => $manager->id,
            'status' => 'tentative',
            'role' => 'attendee',
            'response_notes' => 'May join 10m into the session.',
            'responded_at' => now(),
        ]);

        MeetingParticipant::create([
            'meeting_id' => $clientMeeting->id,
            'user_id' => $superAdmin->id,
            'status' => 'accepted',
            'role' => 'host',
            'response_notes' => 'Leading enterprise SLA review.',
            'responded_at' => now(),
        ]);

        MeetingParticipant::create([
            'meeting_id' => $clientMeeting->id,
            'user_id' => $clientUser->id,
            'status' => 'accepted',
            'role' => 'attendee',
            'response_notes' => 'Attending from Acme Corp leadership team.',
            'responded_at' => now(),
        ]);

        // 6. Seed Events
        Event::create([
            'company_id' => $primaryCompany->id,
            'title' => 'Annual Schedio Engineering Summit',
            'description' => 'Company-wide tech conference and product showcase.',
            'user_id' => $superAdmin->id,
            'department_id' => null,
            'category' => 'milestone',
            'start_time' => Carbon::now()->addDays(7)->setTime(9, 0, 0),
            'end_time' => Carbon::now()->addDays(7)->setTime(18, 0, 0),
            'is_all_day' => true,
            'color' => '#6366f1',
            'location' => 'Main Innovation Center',
            'is_company_wide' => true,
        ]);

        // 7. Seed Tasks
        $task1 = Task::create([
            'company_id' => $primaryCompany->id,
            'title' => 'Verify PostgreSQL Multi-Tenant Partitioning Performance',
            'description' => 'Run stress tests and review query execution plans on indexed tables.',
            'assigned_to' => $employee1->id,
            'created_by' => $superAdmin->id,
            'department_id' => $engineering->id,
            'meeting_id' => $internalMeeting->id,
            'status' => 'in_progress',
            'priority' => 'high',
            'due_date' => Carbon::now()->addDays(3)->setTime(17, 0, 0),
        ]);

        // 8. Seed Reminders
        Reminder::create([
            'user_id' => $employee1->id,
            'title' => 'Upcoming Meeting: Q4 Sprint Planning',
            'message' => 'Your presentation starts in 15 minutes.',
            'remindable_type' => Meeting::class,
            'remindable_id' => $internalMeeting->id,
            'remind_at' => Carbon::now()->addDay()->setTime(9, 45, 0),
            'channel' => 'in_app',
            'status' => 'pending',
            'payload' => ['meeting_id' => $internalMeeting->id],
        ]);

        // 9. Seed Audit Logs
        AuditLog::create([
            'company_id' => $primaryCompany->id,
            'user_id' => $superAdmin->id,
            'action' => 'login',
            'auditable_type' => User::class,
            'auditable_id' => $superAdmin->id,
            'description' => 'Platform Developer Alex Rivera authenticated from primary workstation.',
            'ip_address' => '127.0.0.1',
            'user_agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Schedio/1.0',
            'metadata' => ['role' => 'developer'],
        ]);

        AuditLog::create([
            'company_id' => $primaryCompany->id,
            'user_id' => null,
            'action' => 'registration_requested',
            'auditable_type' => User::class,
            'auditable_id' => $pendingUser1->id,
            'description' => 'Registration request submitted by Sophia Lin (sophia.lin@schedio.com).',
            'ip_address' => '127.0.0.1',
            'user_agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            'new_values' => ['name' => $pendingUser1->name, 'email' => $pendingUser1->email],
        ]);

        // 10. Seed Second Company: Apex Global Logistics (For Tenant Isolation)
        $apexCompany = Company::create([
            'name' => 'Apex Global Logistics',
            'slug' => 'apex-global',
            'status' => Company::STATUS_ACTIVE,
            'domain' => 'apexlogistics.com',
        ]);

        $apexCeo = User::create([
            'company_id' => $apexCompany->id,
            'name' => 'Elena Rostova',
            'title' => 'Chief Executive Officer (Apex Global)',
            'email' => 'ceo@apexlogistics.com',
            'phone' => '+1 (555) 044-9988',
            'password' => Hash::make('password'),
            'role' => User::ROLE_SUPER_ADMIN,
            'approval_status' => User::STATUS_APPROVED,
            'approved_at' => now(),
            'approved_by' => $superAdmin->id,
            'timezone' => 'America/Chicago',
            'is_active' => true,
            'email_verified_at' => now(),
        ]);

        $apexRoom = Room::create([
            'company_id' => $apexCompany->id,
            'name' => 'Apex Executive Summit Suite',
            'code' => 'ROOM-APEX-1',
            'location' => 'Tower B, Floor 14',
            'capacity' => 20,
            'amenities' => ['Video Wall', 'Executive Board Table'],
            'color' => '#f59e0b',
            'is_active' => true,
        ]);

        Meeting::create([
            'company_id' => $apexCompany->id,
            'title' => 'Apex Q4 Confidential Supply Chain Meeting',
            'description' => 'Strictly confidential internal logistics planning for Apex Global.',
            'organizer_id' => $apexCeo->id,
            'room_id' => $apexRoom->id,
            'start_time' => Carbon::now()->addDays(2)->setTime(13, 0, 0),
            'end_time' => Carbon::now()->addDays(2)->setTime(14, 30, 0),
            'timezone' => 'America/Chicago',
            'status' => 'scheduled',
            'type' => 'in_person',
            'location' => 'Apex Executive Summit Suite',
            'is_private' => true,
        ]);
    }
}
