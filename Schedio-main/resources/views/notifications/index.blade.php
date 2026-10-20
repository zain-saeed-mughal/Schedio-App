@extends('layouts.app')

@section('title', 'Notification Center & Preferences')

@section('content')
<div class="space-y-8" x-data="{
    activeTab: 'inbox',
    filter: '{{ $filter }}',
    async markAsRead(id) {
        try {
            const res = await fetch(`/notifications/${id}/read`, {
                method: 'PATCH',
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name=csrf-token]').content,
                    'Accept': 'application/json'
                }
            });
            if (res.ok) {
                window.location.reload();
            }
        } catch (e) {}
    },
    async markAsUnread(id) {
        try {
            const res = await fetch(`/notifications/${id}/unread`, {
                method: 'PATCH',
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name=csrf-token]').content,
                    'Accept': 'application/json'
                }
            });
            if (res.ok) {
                window.location.reload();
            }
        } catch (e) {}
    },
    async deleteNotification(id) {
        if (!confirm('Remove this notification?')) return;
        try {
            const res = await fetch(`/notifications/${id}`, {
                method: 'DELETE',
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name=csrf-token]').content,
                    'Accept': 'application/json'
                }
            });
            if (res.ok) {
                window.location.reload();
            }
        } catch (e) {}
    },
    async markAllRead() {
        try {
            const res = await fetch('/notifications/mark-all-read', {
                method: 'POST',
                headers: {
                    'X-CSRF-TOKEN': document.querySelector('meta[name=csrf-token]').content,
                    'Accept': 'application/json'
                }
            });
            if (res.ok) {
                window.location.reload();
            }
        } catch (e) {}
    }
}">

    <!-- Top Hero Banner -->
    <div class="relative overflow-hidden rounded-3xl glass-panel p-6 sm:p-8 shadow-2xl">
        <div class="absolute -right-20 -top-20 w-80 h-80 bg-gradient-to-br from-amber-500/15 via-indigo-500/15 to-transparent rounded-full blur-3xl pointer-events-none"></div>
        <div class="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div class="space-y-2">
                <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-500/10 border border-indigo-500/20 text-indigo-300 text-xs font-medium">
                    <span class="w-2 h-2 rounded-full bg-amber-400 animate-pulse"></span>
                    <span>Real-time Notification & Reminder Engine</span>
                </div>
                <h1 class="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
                    Notification Center
                </h1>
                <p class="text-xs sm:text-sm text-slate-400 max-w-2xl leading-relaxed">
                    Review meeting invitations, urgent session reminders, schedule changes, RSVP responses, and action item task activity in one synchronized hub.
                </p>
            </div>

            <!-- Action Buttons -->
            <div class="flex flex-wrap items-center gap-3">
                <button @click="activeTab = 'inbox'"
                    :class="activeTab === 'inbox' ? 'bg-amber-400 text-slate-950 font-extrabold shadow-lg shadow-amber-500/25' : 'bg-slate-800 text-slate-300 hover:text-white hover:bg-slate-700'"
                    class="px-4 py-2.5 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path></svg>
                    <span>Activity Feed</span>
                    @if ($unreadCount > 0)
                        <span class="px-1.5 py-0.5 rounded-full bg-slate-950 text-amber-400 text-[10px] font-mono font-bold">{{ $unreadCount }}</span>
                    @endif
                </button>

                <button @click="activeTab = 'preferences'"
                    :class="activeTab === 'preferences' ? 'bg-amber-400 text-slate-950 font-extrabold shadow-lg shadow-amber-500/25' : 'bg-slate-800 text-slate-300 hover:text-white hover:bg-slate-700'"
                    class="px-4 py-2.5 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
                    <span>Delivery Preferences</span>
                </button>
            </div>
        </div>
    </div>

    <!-- TAB 1: INBOX & ACTIVITY FEED -->
    <div x-show="activeTab === 'inbox'" class="space-y-6">
        <!-- Filter Controls Bar -->
        <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4 bg-slate-900/60 border border-slate-800/80 p-4 rounded-2xl">
            <!-- Filter Pills -->
            <div class="flex flex-wrap items-center gap-2">
                <a href="{{ route('notifications.index', ['filter' => 'all', 'search' => $search]) }}"
                    class="px-3 py-1.5 rounded-xl text-xs font-bold transition-all {{ $filter === 'all' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                    All ({{ $counts['all'] }})
                </a>

                <a href="{{ route('notifications.index', ['filter' => 'unread', 'search' => $search]) }}"
                    class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all flex items-center gap-1.5 {{ $filter === 'unread' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                    <span>Unread</span>
                    <span class="px-1.5 py-0.2 rounded-full text-[10px] {{ $filter === 'unread' ? 'bg-slate-950/20 text-slate-950 font-bold' : 'bg-amber-500/20 text-amber-300' }}">{{ $counts['unread'] }}</span>
                </a>

                <a href="{{ route('notifications.index', ['filter' => 'meeting_invitations', 'search' => $search]) }}"
                    class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $filter === 'meeting_invitations' ? 'bg-indigo-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                    Invitations ({{ $counts['meeting_invitations'] }})
                </a>

                <a href="{{ route('notifications.index', ['filter' => 'meeting_reminders', 'search' => $search]) }}"
                    class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $filter === 'meeting_reminders' ? 'bg-indigo-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                    Reminders ({{ $counts['meeting_reminders'] }})
                </a>

                <a href="{{ route('notifications.index', ['filter' => 'meeting_updates', 'search' => $search]) }}"
                    class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $filter === 'meeting_updates' ? 'bg-indigo-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                    Updates ({{ $counts['meeting_updates'] }})
                </a>

                <a href="{{ route('notifications.index', ['filter' => 'participant_responses', 'search' => $search]) }}"
                    class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $filter === 'participant_responses' ? 'bg-indigo-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                    RSVPs ({{ $counts['participant_responses'] }})
                </a>

                <a href="{{ route('notifications.index', ['filter' => 'task_activity', 'search' => $search]) }}"
                    class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $filter === 'task_activity' ? 'bg-indigo-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                    Tasks ({{ $counts['task_activity'] }})
                </a>
            </div>

            <!-- Search & Global Mark Read -->
            <div class="flex items-center gap-3">
                <form action="{{ route('notifications.index') }}" method="GET" class="relative">
                    <input type="hidden" name="filter" value="{{ $filter }}">
                    <input type="text" name="search" value="{{ $search }}" placeholder="Search alerts..."
                        class="w-48 sm:w-64 pl-8 pr-3 py-1.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500">
                    <svg class="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
                </form>

                @if ($unreadCount > 0)
                    <button @click="markAllRead()"
                        class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-amber-400 hover:text-amber-300 text-xs font-bold transition-all shrink-0 cursor-pointer">
                        Mark All Read
                    </button>
                @endif
            </div>
        </div>

        <!-- Notification List Items -->
        <div class="space-y-3">
            @forelse ($notifications as $n)
                @php
                    $data = $n->data;
                    $isUnread = $n->read_at === null;
                    $category = $data['category'] ?? 'general';
                    $color = $data['color'] ?? 'indigo';
                @endphp
                <div class="relative group p-4 sm:p-5 rounded-2xl border transition-all duration-200 {{ $isUnread ? 'bg-slate-900/90 border-indigo-500/40 shadow-lg shadow-indigo-950/20' : 'bg-slate-950/40 border-slate-800/80 opacity-80 hover:opacity-100 hover:border-slate-700' }}">
                    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                        
                        <!-- Left: Status Indicator, Icon, Text Details -->
                        <div class="flex items-start gap-3.5 flex-1 min-w-0">
                            <!-- Unread glowing pip -->
                            <div class="mt-2 shrink-0">
                                @if ($isUnread)
                                    <span class="flex h-2.5 w-2.5 relative">
                                        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
                                        <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-amber-400"></span>
                                    </span>
                                @else
                                    <span class="inline-block h-2.5 w-2.5 rounded-full bg-slate-700"></span>
                                @endif
                            </div>

                            <!-- Category Icon Badge -->
                            <div class="w-10 h-10 rounded-xl bg-slate-800/80 border border-slate-700/60 flex items-center justify-center shrink-0 text-indigo-400">
                                @if ($category === 'meeting_invitations')
                                    <svg class="w-5 h-5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                                @elseif ($category === 'meeting_reminders')
                                    <svg class="w-5 h-5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path></svg>
                                @elseif ($category === 'meeting_updates')
                                    <svg class="w-5 h-5 text-sky-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg>
                                @elseif ($category === 'meeting_cancellations')
                                    <svg class="w-5 h-5 text-rose-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                                @elseif ($category === 'participant_responses')
                                    <svg class="w-5 h-5 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                                @elseif ($category === 'task_activity')
                                    <svg class="w-5 h-5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path></svg>
                                @else
                                    <svg class="w-5 h-5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                                @endif
                            </div>

                            <!-- Text Content -->
                            <div class="space-y-1 min-w-0">
                                <div class="flex flex-wrap items-center gap-2">
                                    <h4 class="text-sm font-bold text-white tracking-tight">{{ $data['title'] ?? 'Schedio Notification' }}</h4>
                                    <x-badge :variant="$color" size="sm">
                                        {{ ucwords(str_replace('_', ' ', $category)) }}
                                    </x-badge>
                                    <span class="text-[11px] text-slate-500 font-mono">{{ $n->created_at->diffForHumans() }}</span>
                                </div>
                                <p class="text-xs text-slate-300 leading-relaxed">{{ $data['message'] ?? '' }}</p>
                            </div>
                        </div>

                        <!-- Right: Action Buttons & Mark Read Controls -->
                        <div class="flex items-center justify-end gap-2 shrink-0 sm:self-center pl-10 sm:pl-0">
                            @if (!empty($data['action_url']))
                                <a href="{{ $data['action_url'] }}"
                                    @click="markAsRead('{{ $n->id }}')"
                                    class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-indigo-600/20 hover:bg-indigo-600/40 text-indigo-300 border border-indigo-500/30 text-xs font-semibold transition-all">
                                    <span>{{ $data['action_text'] ?? 'View' }}</span>
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
                                </a>
                            @endif

                            @if ($isUnread)
                                <button @click="markAsRead('{{ $n->id }}')" title="Mark as read"
                                    class="p-2 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-300 hover:text-white transition-all cursor-pointer">
                                    <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                                </button>
                            @else
                                <button @click="markAsUnread('{{ $n->id }}')" title="Mark as unread"
                                    class="p-2 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-400 hover:text-amber-400 transition-all cursor-pointer">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path></svg>
                                </button>
                            @endif

                            <button @click="deleteNotification('{{ $n->id }}')" title="Delete notification"
                                class="p-2 rounded-xl bg-slate-800/80 hover:bg-rose-950/40 text-slate-400 hover:text-rose-400 transition-all cursor-pointer">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                            </button>
                        </div>
                    </div>
                </div>
            @empty
                <div class="py-16 text-center space-y-3 bg-slate-900/30 rounded-2xl border border-slate-800/80">
                    <div class="inline-flex p-4 rounded-2xl bg-slate-800/60 text-slate-500">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path></svg>
                    </div>
                    <h3 class="text-sm font-bold text-slate-300">No notifications found</h3>
                    <p class="text-xs text-slate-500 max-w-sm mx-auto">
                        @if ($search)
                            No alerts matched "{{ $search }}". Try clearing the search keyword.
                        @else
                            You are completely caught up! New invitations, schedule changes, and reminders will appear here in real-time.
                        @endif
                    </p>
                </div>
            @endforelse
        </div>

        <!-- Pagination -->
        <div class="pt-4">
            {{ $notifications->links() }}
        </div>
    </div>

    <!-- TAB 2: USER NOTIFICATION PREFERENCES -->
    <div x-show="activeTab === 'preferences'" class="space-y-6" x-cloak>
        <form action="{{ route('notifications.preferences') }}" method="POST">
            @csrf
            <x-card
                title="Notification Delivery Channels & Category Rules"
                description="Tailor how and when Schedio dispatches in-app alerts and email notifications for your account">

                <div class="space-y-8">
                    <!-- Global Master Channels -->
                    <div class="space-y-4">
                        <h4 class="text-xs font-bold uppercase tracking-wider text-slate-400">Master Channel Toggles</h4>
                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <!-- In-App Master -->
                            <label class="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 flex items-center justify-between cursor-pointer hover:border-slate-700 transition-all">
                                <div class="space-y-0.5">
                                    <span class="text-xs font-bold text-white block">In-App Notification Bell & Center</span>
                                    <span class="text-[11px] text-slate-400">Show live alerts in your workspace topbar and notification feed</span>
                                </div>
                                <input type="checkbox" name="channel_in_app" value="1" {{ ($preferences['channels']['in_app'] ?? true) ? 'checked' : '' }}
                                    class="w-5 h-5 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                            </label>

                            <!-- Email Master -->
                            <label class="p-4 rounded-xl bg-slate-950/60 border border-slate-800/80 flex items-center justify-between cursor-pointer hover:border-slate-700 transition-all">
                                <div class="space-y-0.5">
                                    <span class="text-xs font-bold text-white block">Email Dispatch</span>
                                    <span class="text-[11px] text-slate-400">Send email digests and invitations to {{ $user->email }}</span>
                                </div>
                                <input type="checkbox" name="channel_email" value="1" {{ ($preferences['channels']['email'] ?? true) ? 'checked' : '' }}
                                    class="w-5 h-5 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                            </label>
                        </div>
                    </div>

                    <!-- Category-Specific Preference Matrix -->
                    <div class="space-y-4 pt-4 border-t border-slate-800/80">
                        <h4 class="text-xs font-bold uppercase tracking-wider text-slate-400">Category Delivery Rules</h4>
                        
                        <div class="overflow-x-auto">
                            <table class="w-full text-left text-xs border border-slate-800 rounded-2xl overflow-hidden">
                                <thead class="bg-slate-950/80 text-slate-400 font-semibold border-b border-slate-800">
                                    <tr>
                                        <th class="p-4">Notification Event</th>
                                        <th class="p-4 text-center w-36">In-App Alerts</th>
                                        <th class="p-4 text-center w-36">Email Dispatch</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y divide-slate-800/80 bg-slate-900/40">
                                    <!-- Meeting Invitations -->
                                    <tr>
                                        <td class="p-4">
                                            <div class="font-bold text-slate-200">Meeting Invitations</div>
                                            <div class="text-[11px] text-slate-400">When someone adds you to a scheduled session or sync</div>
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[meeting_invitations][in_app]" value="1"
                                                {{ ($preferences['categories']['meeting_invitations']['in_app'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[meeting_invitations][email]" value="1"
                                                {{ ($preferences['categories']['meeting_invitations']['email'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                    </tr>

                                    <!-- Meeting Reminders -->
                                    <tr>
                                        <td class="p-4">
                                            <div class="font-bold text-slate-200">Upcoming Session Reminders</div>
                                            <div class="text-[11px] text-slate-400">Automated alerts 15m, 30m or 1h before your scheduled meeting starts</div>
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[meeting_reminders][in_app]" value="1"
                                                {{ ($preferences['categories']['meeting_reminders']['in_app'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[meeting_reminders][email]" value="1"
                                                {{ ($preferences['categories']['meeting_reminders']['email'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                    </tr>

                                    <!-- Meeting Updates -->
                                    <tr>
                                        <td class="p-4">
                                            <div class="font-bold text-slate-200">Schedule & Location Updates</div>
                                            <div class="text-[11px] text-slate-400">When an organizer reschedules a meeting or changes meeting room links</div>
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[meeting_updates][in_app]" value="1"
                                                {{ ($preferences['categories']['meeting_updates']['in_app'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[meeting_updates][email]" value="1"
                                                {{ ($preferences['categories']['meeting_updates']['email'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                    </tr>

                                    <!-- Meeting Cancellations -->
                                    <tr>
                                        <td class="p-4">
                                            <div class="font-bold text-slate-200">Meeting Cancellations</div>
                                            <div class="text-[11px] text-slate-400">When a scheduled session is called off or deleted</div>
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[meeting_cancellations][in_app]" value="1"
                                                {{ ($preferences['categories']['meeting_cancellations']['in_app'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[meeting_cancellations][email]" value="1"
                                                {{ ($preferences['categories']['meeting_cancellations']['email'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                    </tr>

                                    <!-- Participant Responses (RSVP) -->
                                    <tr>
                                        <td class="p-4">
                                            <div class="font-bold text-slate-200">Participant RSVPs</div>
                                            <div class="text-[11px] text-slate-400">When attendees accept, decline, or mark tentative on your meetings</div>
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[participant_responses][in_app]" value="1"
                                                {{ ($preferences['categories']['participant_responses']['in_app'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[participant_responses][email]" value="1"
                                                {{ ($preferences['categories']['participant_responses']['email'] ?? false) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                    </tr>

                                    <!-- Task Activity -->
                                    <tr>
                                        <td class="p-4">
                                            <div class="font-bold text-slate-200">Task & Action Item Activity</div>
                                            <div class="text-[11px] text-slate-400">When you are assigned an action item or a task status is completed</div>
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[task_activity][in_app]" value="1"
                                                {{ ($preferences['categories']['task_activity']['in_app'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                        <td class="p-4 text-center">
                                            <input type="checkbox" name="categories[task_activity][email]" value="1"
                                                {{ ($preferences['categories']['task_activity']['email'] ?? true) ? 'checked' : '' }}
                                                class="w-4 h-4 rounded border-slate-700 bg-slate-900 text-indigo-600 focus:ring-indigo-500">
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Save Button -->
                    <div class="flex justify-end pt-4 border-t border-slate-800/80">
                        <button type="submit"
                            class="btn-amber px-6 py-2.5 rounded-xl text-xs font-bold shadow-lg shadow-amber-500/20 cursor-pointer">
                            Save Notification Preferences
                        </button>
                    </div>
                </div>
            </x-card>
        </form>
    </div>
</div>
@endsection
