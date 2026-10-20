<?php

namespace Database\Seeders;

use App\Models\Client;
use App\Models\Meeting;
use App\Models\MeetingParticipant;
use App\Models\User;
use App\Services\ReminderEngineService;
use Carbon\Carbon;
use Illuminate\Database\Seeder;

class ClientPipelineSeeder extends Seeder
{
    /**
     * Run the database seeds for Business Developers CRM.
     */
    public function run(): void
    {
        $admin = User::where('email', 'admin@schedio.com')->first() ?? User::first();
        $sarah = User::where('email', 'sarah.chen@schedio.com')->first() ?? $admin;
        $marcus = User::where('email', 'marcus.v@schedio.com')->first() ?? $admin;

        $clientsData = [
            [
                'company_name' => 'Nexus Financial Technologies',
                'contact_name' => 'Elena Rostova',
                'contact_email' => 'elena.r@nexusfin.io',
                'contact_phone' => '+1 (555) 234-8901',
                'contact_role' => 'VP of Strategic Partnerships',
                'campaign' => 'Fintech Outbound Q4',
                'progress' => 'Cold outreach email responded positively. Initial discovery call requested for platform architecture review.',
                'status' => Client::STATUS_DISCOVERY,
                'deal_value' => 35000,
                'assigned_to' => $admin->id,
            ],
            [
                'company_name' => 'Apex Cloud Solutions',
                'contact_name' => 'Michael Chang',
                'contact_email' => 'mchang@apexcloud.co',
                'contact_phone' => '+1 (555) 789-1234',
                'contact_role' => 'Chief Technology Officer',
                'campaign' => 'LinkedIn BD Outreach',
                'progress' => 'Discovery call completed. Demo meeting scheduled for executive team with Google Meet link.',
                'status' => Client::STATUS_SCHEDULED,
                'deal_value' => 60000,
                'assigned_to' => $admin->id,
            ],
            [
                'company_name' => 'Horizon Health Systems',
                'contact_name' => 'Dr. Robert Miller',
                'contact_email' => 'rmiller@horizonhealth.org',
                'contact_phone' => '+1 (555) 456-7890',
                'contact_role' => 'Director of IT & Compliance',
                'campaign' => 'Healthcare Enterprise Inbound',
                'progress' => 'Commercial proposal accepted. MSA and HIPAA BAA paperwork sent for legal review and signature.',
                'status' => Client::STATUS_PAPERWORK_ONBOARDING,
                'deal_value' => 95000,
                'assigned_to' => $sarah->id,
            ],
            [
                'company_name' => 'Lumina Logistics Global',
                'contact_name' => 'Aisha Al-Mansoor',
                'contact_email' => 'aisha@luminalogistics.ae',
                'contact_phone' => '+971 4 312 9000',
                'contact_role' => 'Chief Operating Officer',
                'campaign' => 'Global Supply Chain Summit',
                'progress' => 'Contract executed! First onboarding kickoff session held. Integration team assigned.',
                'status' => Client::STATUS_ONBOARDED,
                'deal_value' => 120000,
                'assigned_to' => $admin->id,
            ],
            [
                'company_name' => 'Vanguard Retail Analytics',
                'contact_name' => 'Jason Vance',
                'contact_email' => 'jvance@vanguardanalytics.net',
                'contact_phone' => '+1 (555) 678-9012',
                'contact_role' => 'Procurement Lead',
                'campaign' => 'Cold Email Campaign #2',
                'progress' => 'Budget frozen until next fiscal year. Competitor contract locked in for 18 months.',
                'status' => Client::STATUS_DEADEND,
                'deal_value' => 20000,
                'assigned_to' => $marcus->id,
            ],
            [
                'company_name' => 'Starlight Media Group',
                'contact_name' => 'Chloe Bennett',
                'contact_email' => 'cbennett@starlightmedia.tv',
                'contact_phone' => '+1 (555) 890-1234',
                'contact_role' => 'Head of Brand Operations',
                'campaign' => 'Agency Partnership Wave',
                'progress' => 'Requested 30-day hold due to internal company restructuring. Follow up in November.',
                'status' => Client::STATUS_PAUSE,
                'deal_value' => 45000,
                'assigned_to' => $sarah->id,
            ],
        ];

        foreach ($clientsData as $data) {
            $client = Client::updateOrCreate(
                ['company_name' => $data['company_name']],
                array_merge($data, [
                    'created_by' => $admin->id,
                    'last_activity_at' => now()->subHours(rand(1, 48)),
                ])
            );

            // If scheduled or discovery, let's create a real meeting with reminders for Apex Cloud Solutions!
            if ($client->status === Client::STATUS_SCHEDULED) {
                $meeting = Meeting::updateOrCreate(
                    ['client_id' => $client->id],
                    [
                        'title' => "Executive Demo: {$client->company_name}",
                        'description' => "Deep dive demo and technical Q&A session with {$client->contact_name} ({$client->contact_role}). Campaign: {$client->campaign}.",
                        'organizer_id' => $admin->id,
                        'department_id' => $admin->department_id,
                        'client_id' => $client->id,
                        'start_time' => now()->addDays(1)->setHour(15)->setMinute(0),
                        'end_time' => now()->addDays(1)->setHour(15)->setMinute(45),
                        'timezone' => 'America/New_York',
                        'status' => 'scheduled',
                        'type' => 'virtual',
                        'meeting_link' => 'https://meet.google.com/xyz-schedio-apex',
                        'location' => 'Google Meet Virtual Conference',
                        'is_private' => false,
                        'metadata' => [
                            'is_client_meeting' => true,
                            'client_name' => $client->contact_name,
                            'client_email' => $client->contact_email,
                            'client_company' => $client->company_name,
                            'campaign' => $client->campaign,
                        ],
                    ]
                );

                MeetingParticipant::updateOrCreate(
                    ['meeting_id' => $meeting->id, 'user_id' => $admin->id],
                    ['role' => 'host', 'status' => 'accepted', 'responded_at' => now()]
                );

                // Schedule automated reminders
                app(ReminderEngineService::class)->scheduleMeetingReminders($meeting, 15, 'both');
            }
        }
    }
}
