<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use App\Models\Department;
use App\Models\Event;
use App\Models\Meeting;
use App\Models\Reminder;
use App\Models\Room;
use App\Models\Task;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

class DashboardController extends Controller
{
    /**
     * Display unified premium Schedio executive dashboard.
     */
    public function index(Request $request): View
    {
        $user = Auth::user();
        $today = Carbon::today();

        // System & personal overview metrics (Strictly scoped for regular users)
        $meetingBaseQuery = Meeting::query()
            ->when(!$user->isSuperAdmin(), function ($q) use ($user) {
                $q->where(function ($sub) use ($user) {
                    $sub->where('organizer_id', $user->id)
                        ->orWhereHas('participants', fn($p) => $p->where('users.id', $user->id));
                });
            });

        $metrics = [
            'pending_requests' => $user->isSuperAdmin()
                ? User::where('approval_status', User::STATUS_PENDING)->where('role', '!=', User::ROLE_SUPER_ADMIN)->count()
                : 0,
            'today_meetings_count' => (clone $meetingBaseQuery)
                ->whereDate('start_time', $today)
                ->where('status', '!=', 'cancelled')
                ->count(),
            'total_users' => User::where('approval_status', User::STATUS_APPROVED)->count(),
            'upcoming_meetings' => (clone $meetingBaseQuery)
                ->where('start_time', '>=', now())
                ->where('status', '!=', 'cancelled')
                ->count(),
            'client_meetings' => (clone $meetingBaseQuery)
                ->where('metadata->is_client_meeting', true)
                ->where('status', '!=', 'cancelled')
                ->count(),
            'active_reminders' => Reminder::where('user_id', $user->id)
                ->where('status', 'pending')
                ->count(),
            'pending_tasks' => Task::when(!$user->isSuperAdmin(), fn($q) => $q->where(fn($sub) => $sub->where('assigned_to', $user->id)->orWhere('created_by', $user->id)))
                ->where('status', '!=', 'completed')
                ->count(),
            'unread_notifications' => Reminder::where('user_id', $user->id)
                ->where('status', 'pending')
                ->count(),
        ];

        // Today's specific schedule (Meetings + Events)
        $todayMeetings = (clone $meetingBaseQuery)
            ->with(['organizer', 'department', 'participants'])
            ->whereDate('start_time', $today)
            ->where('status', '!=', 'cancelled')
            ->orderBy('start_time')
            ->get();

        $todayEvents = Event::where(function ($q) use ($today, $user) {
            $q->whereDate('start_time', '<=', $today)
              ->whereDate('end_time', '>=', $today);
        })
        ->where(function ($q) use ($user) {
            $q->where('is_company_wide', true)
              ->orWhere('user_id', $user->id)
              ->orWhere('department_id', $user->department_id);
        })
        ->get();

        // Upcoming meetings across the next 7 days
        $upcomingMeetings = (clone $meetingBaseQuery)
            ->with(['organizer', 'department', 'participants'])
            ->where('start_time', '>=', now())
            ->where('status', '!=', 'cancelled')
            ->orderBy('start_time')
            ->take(6)
            ->get();

        // Pending Tasks
        $pendingTasks = Task::with(['department', 'creator', 'assignee', 'meeting'])
            ->when(!$user->isSuperAdmin(), function ($q) use ($user) {
                $q->where(function ($sub) use ($user) {
                    $sub->where('assigned_to', $user->id)
                        ->orWhere('created_by', $user->id);
                });
            })
            ->where('status', '!=', 'completed')
            ->orderBy('priority', 'desc')
            ->orderBy('due_date')
            ->take(6)
            ->get();

        // User Reminders / Notifications
        $userNotifications = Reminder::where('user_id', $user->id)
            ->latest('remind_at')
            ->take(5)
            ->get();

        // Recent system audit trail
        $recentActivities = AuditLog::with('user')
            ->when(!$user->isSuperAdmin(), fn($q) => $q->where('user_id', $user->id))
            ->latest()
            ->take(6)
            ->get();

        // Active upcoming reminders for the user
        $upcomingReminders = Reminder::where('user_id', $user->id)
            ->where('status', 'pending')
            ->orderBy('remind_at')
            ->take(5)
            ->get();

        // Next immediate upcoming meeting
        $nextMeeting = (clone $meetingBaseQuery)
            ->where('start_time', '>=', now())
            ->where('status', '!=', 'cancelled')
            ->orderBy('start_time')
            ->first();

        return view('dashboard', compact(
            'user',
            'metrics',
            'todayMeetings',
            'todayEvents',
            'upcomingMeetings',
            'nextMeeting',
            'pendingTasks',
            'userNotifications',
            'recentActivities',
            'upcomingReminders'
        ));
    }
}
