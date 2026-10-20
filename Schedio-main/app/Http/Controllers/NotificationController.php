<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Notifications\DatabaseNotification;
use Illuminate\Support\Facades\Auth;
use Illuminate\View\View;

class NotificationController extends Controller
{
    /**
     * Display the full Notification Center dashboard.
     */
    public function index(Request $request): View
    {
        /** @var User $user */
        $user = Auth::user();
        $filter = $request->query('filter', 'all'); // all, unread, read, invitations, reminders, updates, tasks
        $search = $request->query('search');

        $query = $user->notifications();

        // Status filters
        if ($filter === 'unread') {
            $query->whereNull('read_at');
        } elseif ($filter === 'read') {
            $query->whereNotNull('read_at');
        } elseif (in_array($filter, ['meeting_invitations', 'meeting_reminders', 'meeting_updates', 'meeting_cancellations', 'participant_responses', 'task_activity'])) {
            $query->where('data->category', $filter);
        }

        // Search query
        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('data->title', 'like', "%{$search}%")
                  ->orWhere('data->message', 'like', "%{$search}%");
            });
        }

        $notifications = $query->paginate(15)->withQueryString();

        // Unread count
        $unreadCount = $user->unreadNotifications()->count();

        // Category breakdown counts
        $counts = [
            'all' => $user->notifications()->count(),
            'unread' => $unreadCount,
            'meeting_invitations' => $user->notifications()->where('data->category', 'meeting_invitations')->count(),
            'meeting_reminders' => $user->notifications()->where('data->category', 'meeting_reminders')->count(),
            'meeting_updates' => $user->notifications()->where('data->category', 'meeting_updates')->count(),
            'meeting_cancellations' => $user->notifications()->where('data->category', 'meeting_cancellations')->count(),
            'participant_responses' => $user->notifications()->where('data->category', 'participant_responses')->count(),
            'task_activity' => $user->notifications()->where('data->category', 'task_activity')->count(),
        ];

        $preferences = $user->getPreferences();

        return view('notifications.index', compact('notifications', 'unreadCount', 'counts', 'filter', 'search', 'preferences', 'user'));
    }

    /**
     * Fetch unread notifications and count via JSON API (polling / real-time widget).
     */
    public function feed(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        $unreadCount = $user->unreadNotifications()->count();
        $recentNotifications = $user->notifications()->latest()->take(6)->get()->map(function (DatabaseNotification $n) {
            $data = $n->data;
            return [
                'id' => $n->id,
                'read' => $n->read_at !== null,
                'read_at' => $n->read_at ? $n->read_at->toIso8601String() : null,
                'created_at' => $n->created_at->diffForHumans(),
                'created_at_raw' => $n->created_at->toIso8601String(),
                'category' => $data['category'] ?? 'general',
                'title' => $data['title'] ?? 'Notification',
                'message' => $data['message'] ?? '',
                'action_url' => $data['action_url'] ?? null,
                'action_text' => $data['action_text'] ?? 'View Details',
                'icon' => $data['icon'] ?? 'bell',
                'color' => $data['color'] ?? 'indigo',
            ];
        });

        return response()->json([
            'unread_count' => $unreadCount,
            'notifications' => $recentNotifications,
        ]);
    }

    /**
     * Mark a single notification as read.
     */
    public function markAsRead(Request $request, string $id): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = Auth::user();

        $notification = $user->notifications()->where('id', $id)->firstOrFail();
        $notification->markAsRead();

        if ($request->wantsJson() || $request->ajax()) {
            return response()->json([
                'success' => true,
                'unread_count' => $user->unreadNotifications()->count(),
            ]);
        }

        return back()->with('success', 'Notification marked as read.');
    }

    /**
     * Mark a single notification as unread.
     */
    public function markAsUnread(Request $request, string $id): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = Auth::user();

        $notification = $user->notifications()->where('id', $id)->firstOrFail();
        $notification->update(['read_at' => null]);

        if ($request->wantsJson() || $request->ajax()) {
            return response()->json([
                'success' => true,
                'unread_count' => $user->unreadNotifications()->count(),
            ]);
        }

        return back()->with('success', 'Notification marked as unread.');
    }

    /**
     * Mark all user notifications as read.
     */
    public function markAllAsRead(Request $request): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = Auth::user();
        $user->unreadNotifications->markAsRead();

        if ($request->wantsJson() || $request->ajax()) {
            return response()->json([
                'success' => true,
                'unread_count' => 0,
            ]);
        }

        return back()->with('success', 'All notifications marked as read.');
    }

    /**
     * Delete a notification.
     */
    public function destroy(Request $request, string $id): JsonResponse|RedirectResponse
    {
        /** @var User $user */
        $user = Auth::user();
        $notification = $user->notifications()->where('id', $id)->firstOrFail();
        $notification->delete();

        if ($request->wantsJson() || $request->ajax()) {
            return response()->json([
                'success' => true,
                'unread_count' => $user->unreadNotifications()->count(),
            ]);
        }

        return back()->with('success', 'Notification removed.');
    }

    /**
     * Update user notification preferences.
     */
    public function updatePreferences(Request $request): RedirectResponse
    {
        /** @var User $user */
        $user = Auth::user();

        $validated = $request->validate([
            'channel_in_app' => ['nullable', 'boolean'],
            'channel_email' => ['nullable', 'boolean'],
            'categories' => ['nullable', 'array'],
        ]);

        $newPreferences = [
            'channels' => [
                'in_app' => $request->boolean('channel_in_app'),
                'email' => $request->boolean('channel_email'),
            ],
            'categories' => [
                'meeting_invitations' => [
                    'in_app' => $request->boolean('categories.meeting_invitations.in_app'),
                    'email' => $request->boolean('categories.meeting_invitations.email'),
                ],
                'meeting_reminders' => [
                    'in_app' => $request->boolean('categories.meeting_reminders.in_app'),
                    'email' => $request->boolean('categories.meeting_reminders.email'),
                ],
                'meeting_updates' => [
                    'in_app' => $request->boolean('categories.meeting_updates.in_app'),
                    'email' => $request->boolean('categories.meeting_updates.email'),
                ],
                'meeting_cancellations' => [
                    'in_app' => $request->boolean('categories.meeting_cancellations.in_app'),
                    'email' => $request->boolean('categories.meeting_cancellations.email'),
                ],
                'participant_responses' => [
                    'in_app' => $request->boolean('categories.participant_responses.in_app'),
                    'email' => $request->boolean('categories.participant_responses.email'),
                ],
                'task_activity' => [
                    'in_app' => $request->boolean('categories.task_activity.in_app'),
                    'email' => $request->boolean('categories.task_activity.email'),
                ],
            ],
        ];

        $user->update([
            'notification_preferences' => $newPreferences,
        ]);

        return back()->with('success', 'Notification preferences saved successfully.');
    }
}
