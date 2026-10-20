@extends('layouts.app')

@section('title', 'Warm welcome:) — Executive Dashboard')

@section('content')
<div class="space-y-7" x-data="{
    selectedDate: '{{ now()->format('Y-m-d') }}',
    selectedSlot: '10:00 am',
    quickDates: [
        { day: '{{ now()->format('D') }}', num: '{{ now()->format('j') }}', date: '{{ now()->format('Y-m-d') }}' },
        { day: '{{ now()->addDays(1)->format('D') }}', num: '{{ now()->addDays(1)->format('j') }}', date: '{{ now()->addDays(1)->format('Y-m-d') }}' },
        { day: '{{ now()->addDays(2)->format('D') }}', num: '{{ now()->addDays(2)->format('j') }}', date: '{{ now()->addDays(2)->format('Y-m-d') }}' },
        { day: '{{ now()->addDays(3)->format('D') }}', num: '{{ now()->addDays(3)->format('j') }}', date: '{{ now()->addDays(3)->format('Y-m-d') }}' },
        { day: '{{ now()->addDays(4)->format('D') }}', num: '{{ now()->addDays(4)->format('j') }}', date: '{{ now()->addDays(4)->format('Y-m-d') }}' },
        { day: '{{ now()->addDays(5)->format('D') }}', num: '{{ now()->addDays(5)->format('j') }}', date: '{{ now()->addDays(5)->format('Y-m-d') }}' },
        { day: '{{ now()->addDays(6)->format('D') }}', num: '{{ now()->addDays(6)->format('j') }}', date: '{{ now()->addDays(6)->format('Y-m-d') }}' }
    ]
}">

    <!-- Top Hero Banner: Warm Welcome Headline (Inspired by Reference) -->
    <div class="glass-panel rounded-3xl p-6 sm:p-8 relative overflow-hidden">
        <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-6 relative z-10">
            <div class="space-y-2 max-w-2xl">
                <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-400/10 border border-amber-400/25 text-amber-300 text-xs font-semibold">
                    <span class="w-2 h-2 rounded-full bg-amber-400 animate-pulse"></span>
                    <span>Executive Calendar Workspace</span>
                </div>
                <h1 class="text-3xl sm:text-4xl font-extrabold tracking-tight text-amber-400">
                    Warm welcome:)
                </h1>
                <p class="text-xs sm:text-sm text-slate-300 leading-relaxed">
                    Hello {{ $user->name }}, review your schedule, book client appointments, and inspect availability across suites and team members.
                </p>
            </div>

            <!-- Quick Action Buttons -->
            <div class="flex flex-wrap items-center gap-3">
                <a href="{{ route('clients.index') }}"
                    class="px-4 py-2.5 rounded-xl bg-amber-400/10 hover:bg-amber-400/20 text-amber-300 text-xs font-bold border border-amber-400/30 transition-all flex items-center gap-2">
                    <svg class="w-4 h-4 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path></svg>
                    <span>BD Pipeline</span>
                </a>
                <a href="{{ route('calendar.index') }}"
                    class="px-4 py-2.5 rounded-xl bg-white/[0.04] hover:bg-white/[0.08] text-slate-200 text-xs font-bold border border-white/10 transition-all flex items-center gap-2">
                    <svg class="w-4 h-4 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                    <span>Full Calendar</span>
                </a>
                <a href="{{ route('meetings.create') }}"
                    class="btn-amber px-5 py-2.5 rounded-xl text-xs flex items-center gap-2 cursor-pointer">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"></path></svg>
                    <span>+ Book Appointment</span>
                </a>
            </div>
        </div>

        <!-- Public Booking Link Share Bar -->
        <div class="mt-6 pt-5 border-t border-white/[0.08] flex flex-col md:flex-row md:items-center justify-between gap-4 bg-gradient-to-r from-amber-500/10 via-slate-900/40 to-transparent p-4 rounded-2xl border border-amber-500/20"
            x-data="{ copied: false }">
            <div class="flex items-center gap-3">
                <div class="p-2.5 rounded-xl bg-amber-400 text-slate-950 font-black shadow-md shadow-amber-500/20 shrink-0">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"></path></svg>
                </div>
                <div>
                    <div class="text-xs font-bold text-white flex items-center gap-2">
                        <span>Your Public Booking Link</span>
                        <span class="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 font-bold border border-emerald-500/30 uppercase">Live & Shareable</span>
                    </div>
                    <div class="text-xs text-amber-300/90 font-mono mt-0.5 select-all">
                        {{ url('/book/' . ($user->username ?: $user->id)) }}
                    </div>
                </div>
            </div>

            <div class="flex items-center gap-2">
                <button type="button" @click="navigator.clipboard.writeText('{{ url('/book/' . ($user->username ?: $user->id)) }}'); copied = true; setTimeout(() => copied = false, 2500)"
                    class="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold border border-white/[0.1] transition-all flex items-center gap-1.5 cursor-pointer">
                    <svg class="w-3.5 h-3.5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"></path></svg>
                    <span x-text="copied ? 'Copied to Clipboard! ✨' : 'Copy Booking Link'"></span>
                </button>
                <a href="{{ route('booking.show', $user->username ?: $user->id) }}" target="_blank"
                    class="btn-amber px-3.5 py-2 rounded-xl text-xs font-bold shadow-md shadow-amber-500/20 flex items-center gap-1.5">
                    <span>View Public Page</span>
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
                </a>
            </div>
        </div>

        <!-- Next Immediate Meeting Banner -->
        @if ($nextMeeting)
            <div class="mt-6 pt-5 border-t border-white/[0.08] flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white/[0.02] p-4 rounded-2xl border border-white/10">
                <div class="flex items-start sm:items-center gap-3.5">
                    <div class="p-2.5 rounded-xl bg-amber-400/20 text-amber-300 border border-amber-400/30 shrink-0">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                    </div>
                    <div>
                        <div class="flex items-center gap-2 text-xs">
                            <span class="text-amber-400 font-bold uppercase tracking-wider text-[10px] px-2 py-0.5 rounded-full bg-amber-400/10 border border-amber-400/20">Next Up</span>
                            <span class="text-slate-500">&bull;</span>
                            <span class="text-slate-200 font-semibold">{{ $nextMeeting->start_time->diffForHumans() }} ({{ $nextMeeting->start_time->format('g:i A') }})</span>
                        </div>
                        <h4 class="text-sm font-bold text-white mt-1">{{ $nextMeeting->title }}</h4>
                        @if (!empty($nextMeeting->metadata['client_name']))
                            <div class="text-[11px] text-amber-300/80 flex items-center gap-1 mt-0.5">
                                <span>Client: {{ $nextMeeting->metadata['client_name'] }}</span>
                                @if (!empty($nextMeeting->metadata['client_company']))
                                    <span class="text-slate-400">({{ $nextMeeting->metadata['client_company'] }})</span>
                                @endif
                            </div>
                        @endif
                    </div>
                </div>

                <div class="flex items-center gap-2.5 shrink-0">
                    @if ($nextMeeting->meeting_link)
                        <a href="{{ $nextMeeting->meeting_link }}" target="_blank"
                            class="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl text-xs shadow-md transition-all flex items-center gap-1.5 cursor-pointer">
                            <span>Join Video Call</span>
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
                        </a>
                    @endif
                    <a href="{{ route('meetings.show', $nextMeeting) }}"
                        class="px-3.5 py-2 bg-white/[0.04] hover:bg-white/[0.08] text-slate-200 text-xs font-bold rounded-xl border border-white/10 transition-all">
                        View Details
                    </a>
                </div>
            </div>
        @endif
    </div>

    <!-- Quick Interactive Appointment & Slot Picker Card (Matching Screenshot) -->
    <div class="glass-card rounded-3xl p-6 sm:p-8 space-y-6">
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-white/[0.08] pb-5">
            <div>
                <span class="text-xs text-slate-400">
                    Your appointment will be booked with any available staff.
                    <a href="{{ route('meetings.create') }}" class="text-amber-400 font-bold hover:underline ml-1">Change</a>
                </span>
                <h3 class="text-lg font-bold text-white mt-1 flex items-center gap-2">
                    <span>{{ now()->format('F, Y') }}</span>
                    <span class="text-xs text-slate-500 font-mono">({{ config('app.timezone') }})</span>
                </h3>
            </div>

            <!-- Horizontal Date Strip (Carousel like screenshot) -->
            <div class="flex items-center gap-2 overflow-x-auto pb-1 max-w-full">
                <template x-for="item in quickDates" :key="item.date">
                    <button type="button" @click="selectedDate = item.date"
                        class="date-selector-card min-w-[3.5rem] flex flex-col items-center justify-center py-2 px-3 transition-all"
                        :class="selectedDate === item.date ? 'active' : ''">
                        <span class="text-base font-extrabold leading-tight" x-text="item.num"></span>
                        <span class="text-[9px] font-bold uppercase tracking-wider mt-0.5 opacity-80" x-text="item.day"></span>
                    </button>
                </template>
            </div>
        </div>

        <!-- Time Slot Selection Grid (Morning & Afternoon like screenshot) -->
        <div class="space-y-5">
            <!-- Morning Slots -->
            <div class="space-y-2">
                <div class="text-[11px] font-bold uppercase tracking-wider text-slate-400 flex items-center gap-2">
                    <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
                    <span>Morning Slots</span>
                </div>
                <div class="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-5 gap-2.5">
                    @foreach (['09:00 am', '09:30 am', '10:00 am', '10:30 am', '11:00 am', '11:30 am'] as $slot)
                        <button type="button" @click="selectedSlot = '{{ $slot }}'"
                            class="time-slot-pill"
                            :class="selectedSlot === '{{ $slot }}' ? 'active' : ''">
                            {{ $slot }}
                        </button>
                    @endforeach
                </div>
            </div>

            <!-- Afternoon Slots -->
            <div class="space-y-2 pt-2">
                <div class="text-[11px] font-bold uppercase tracking-wider text-slate-400 flex items-center gap-2">
                    <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
                    <span>Afternoon Slots</span>
                </div>
                <div class="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-5 gap-2.5">
                    @foreach (['02:00 pm', '02:30 pm', '03:00 pm', '03:30 pm', '04:00 pm', '04:30 pm'] as $slot)
                        <button type="button" @click="selectedSlot = '{{ $slot }}'"
                            class="time-slot-pill"
                            :class="selectedSlot === '{{ $slot }}' ? 'active' : ''">
                            {{ $slot }}
                        </button>
                    @endforeach
                </div>
            </div>

            <div class="pt-3 border-t border-white/[0.08] flex items-center justify-between">
                <div class="text-xs text-slate-400">
                    Selected: <span class="font-bold text-amber-400" x-text="`${selectedDate} at ${selectedSlot}`"></span>
                </div>
                <a :href="`{{ route('meetings.create') }}?date=${selectedDate}&time=${selectedSlot}`"
                    class="btn-amber px-5 py-2 rounded-xl text-xs shadow-md">
                    Continue with Selected Slot &rarr;
                </a>
            </div>
        </div>
    </div>

    <!-- 3 Metric Cards Grid (Golden Amber & Earthy Charcoal) -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6">
        <!-- Metric 1 -->
        <div class="glass-card p-5 rounded-3xl flex items-center justify-between group">
            <div class="space-y-1">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-400">Today's Schedule</span>
                <div class="text-3xl font-extrabold text-white tracking-tight">{{ $metrics['today_meetings_count'] }}</div>
                <span class="text-[11px] text-amber-400 font-semibold flex items-center gap-1">
                    <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
                    <span>Session(s) on docket today</span>
                </span>
            </div>
            <div class="p-3.5 rounded-2xl bg-amber-400/10 text-amber-300 border border-amber-400/30 shadow-md group-hover:scale-110 transition-transform">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            </div>
        </div>

        <!-- Metric 2 -->
        <div class="glass-card p-5 rounded-3xl flex items-center justify-between group">
            <div class="space-y-1">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-400">Client Reviews</span>
                <div class="text-3xl font-extrabold text-white tracking-tight">{{ $metrics['client_meetings'] }}</div>
                <span class="text-[11px] text-slate-300 font-semibold flex items-center gap-1">
                    <span class="w-1.5 h-1.5 rounded-full bg-amber-400/60"></span>
                    <span>External client partners</span>
                </span>
            </div>
            <div class="p-3.5 rounded-2xl bg-white/[0.04] text-amber-300 border border-white/10 shadow-md group-hover:scale-110 transition-transform">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path></svg>
            </div>
        </div>

        <!-- Metric 3 -->
        <div class="glass-card p-5 rounded-3xl flex items-center justify-between group">
            <div class="space-y-1">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-400">Armed Reminders</span>
                <div class="text-3xl font-extrabold text-white tracking-tight">{{ $metrics['active_reminders'] }}</div>
                <span class="text-[11px] text-amber-400 font-semibold flex items-center gap-1">
                    <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
                    <span>Automated alerts active</span>
                </span>
            </div>
            <div class="p-3.5 rounded-2xl bg-amber-400/10 text-amber-300 border border-amber-400/30 shadow-md group-hover:scale-110 transition-transform">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path></svg>
            </div>
        </div>
    </div>

    <!-- Main Content 2-Column Split -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 sm:gap-8">
        
        <!-- Left Section: Schedule Timeline (2 Cols) -->
        <div class="lg:col-span-2 space-y-6">
            
            <!-- Today's Schedule Timeline -->
            <div class="glass-card rounded-3xl p-6 shadow-xl space-y-4">
                <div class="flex items-center justify-between">
                    <div>
                        <h3 class="text-base font-bold text-white flex items-center gap-2">
                            <span>Today's Agenda</span>
                            <span class="text-xs px-2.5 py-0.5 rounded-full bg-amber-400/15 text-amber-300 font-bold border border-amber-400/25">{{ now()->format('M d') }}</span>
                        </h3>
                        <p class="text-xs text-slate-400 mt-0.5">Chronological timeline of all calls and reviews for today</p>
                    </div>
                    <a href="{{ route('calendar.index') }}" class="text-xs text-amber-400 hover:text-amber-300 font-bold flex items-center gap-1 transition-colors">
                        <span>View on Calendar</span>
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
                    </a>
                </div>

                @if ($todayMeetings->isEmpty())
                    <div class="py-12 text-center space-y-3 border border-dashed border-white/[0.1] rounded-2xl bg-white/[0.02]">
                        <div class="inline-flex p-3.5 rounded-2xl bg-white/[0.05] text-slate-400">
                            <svg class="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                        </div>
                        <h4 class="text-sm font-bold text-slate-200">No Meetings Scheduled For Today</h4>
                        <p class="text-xs text-slate-400 max-w-sm mx-auto">Your schedule is wide open today. Take the opportunity to focus or schedule a new call.</p>
                        <div class="pt-2">
                            <a href="{{ route('meetings.create') }}" class="btn-amber inline-flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs">
                                + Schedule Meeting
                            </a>
                        </div>
                    </div>
                @else
                    <div class="space-y-3">
                        @foreach ($todayMeetings as $tm)
                            <div class="p-4 rounded-2xl bg-white/[0.03] border border-white/[0.06] hover:border-amber-400/30 hover:bg-white/[0.05] flex flex-col sm:flex-row sm:items-center justify-between gap-3 transition-all duration-200">
                                <div class="space-y-1 min-w-0">
                                    <div class="flex items-center gap-2">
                                        <span class="text-xs font-bold text-amber-400 font-mono">
                                            {{ $tm->start_time->format('g:i A') }} – {{ $tm->end_time->format('g:i A') }}
                                        </span>
                                        @if (!empty($tm->metadata['reminder_minutes']))
                                            <span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-amber-500/15 text-amber-300 border border-amber-500/30 flex items-center gap-1">
                                                <span>🔔</span>
                                                <span>{{ $tm->metadata['reminder_minutes'] }}m Alert</span>
                                            </span>
                                        @endif
                                    </div>
                                    <h4 class="text-sm font-bold text-white truncate">{{ $tm->title }}</h4>
                                    @if (!empty($tm->metadata['client_name']))
                                        <div class="text-xs text-slate-300">
                                            Client: <span class="font-bold text-white">{{ $tm->metadata['client_name'] }}</span>
                                            @if (!empty($tm->metadata['client_company']))
                                                <span class="text-slate-400">({{ $tm->metadata['client_company'] }})</span>
                                            @endif
                                        </div>
                                    @endif
                                </div>

                                <div class="flex items-center gap-2 shrink-0">
                                    @if ($tm->meeting_link)
                                        <a href="{{ $tm->meeting_link }}" target="_blank"
                                            class="px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-md transition-all flex items-center gap-1.5 cursor-pointer">
                                            <span>Join Call</span>
                                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
                                        </a>
                                    @endif
                                    <a href="{{ route('meetings.show', $tm) }}"
                                        class="px-3.5 py-1.5 rounded-xl bg-white/[0.04] hover:bg-white/[0.08] text-slate-200 text-xs font-bold border border-white/10 transition-all">
                                        Details
                                    </a>
                                </div>
                            </div>
                        @endforeach
                    </div>
                @endif
            </div>

            <!-- Upcoming Meetings (Next 7 Days) -->
            <div class="glass-card rounded-3xl p-6 shadow-xl space-y-4">
                <div class="flex items-center justify-between">
                    <div>
                        <h3 class="text-base font-bold text-white">Upcoming Meetings</h3>
                        <p class="text-xs text-slate-400">Scheduled client reviews & consultations</p>
                    </div>
                    <a href="{{ route('meetings.index') }}" class="text-xs text-amber-400 hover:text-amber-300 font-bold flex items-center gap-1 transition-colors">
                        <span>View All ({{ $metrics['upcoming_meetings'] }})</span>
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
                    </a>
                </div>

                @if ($upcomingMeetings->isEmpty())
                    <div class="py-8 text-center text-xs text-slate-400">
                        No upcoming meetings on the calendar.
                    </div>
                @else
                    <div class="divide-y divide-white/[0.06]">
                        @foreach ($upcomingMeetings as $um)
                            <div class="py-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 first:pt-0 last:pb-0">
                                <div class="space-y-0.5 min-w-0">
                                    <div class="flex items-center gap-2">
                                        <span class="text-[11px] font-semibold text-slate-400">
                                            {{ $um->start_time->format('l, M d • g:i A') }}
                                        </span>
                                        @if (!empty($um->metadata['reminder_minutes']))
                                            <span class="text-[10px] text-amber-400 font-bold flex items-center gap-0.5">
                                                <span>🔔</span>
                                                <span>{{ $um->metadata['reminder_minutes'] }}m</span>
                                            </span>
                                        @endif
                                    </div>
                                    <h4 class="text-xs font-bold text-white truncate">{{ $um->title }}</h4>
                                    @if (!empty($um->metadata['client_name']))
                                        <div class="text-[11px] text-amber-300/80">
                                            Client: {{ $um->metadata['client_name'] }}
                                        </div>
                                    @endif
                                </div>

                                <div class="flex items-center gap-2 shrink-0">
                                    @if ($um->meeting_link)
                                        <a href="{{ $um->meeting_link }}" target="_blank"
                                            class="px-3 py-1 bg-amber-400/20 hover:bg-amber-400/30 text-amber-300 rounded-xl text-xs font-bold border border-amber-400/30 transition-all">
                                            Join Call
                                        </a>
                                    @endif
                                    <a href="{{ route('meetings.show', $um) }}"
                                        class="px-2.5 py-1 bg-white/[0.04] hover:bg-white/[0.08] text-slate-300 hover:text-white rounded-xl text-xs font-bold border border-white/10 transition-all">
                                        View
                                    </a>
                                </div>
                            </div>
                        @endforeach
                    </div>
                @endif
            </div>

        </div>

        <!-- Right Section: Active Reminders & Quick Calendar Launcher -->
        <div class="space-y-6">
            
            <!-- Active Reminders Box -->
            <div class="glass-card rounded-3xl p-6 shadow-xl space-y-4">
                <div class="flex items-center justify-between">
                    <div>
                        <h3 class="text-base font-bold text-white flex items-center gap-2">
                            <span class="p-1.5 rounded-lg bg-amber-400/10 text-amber-400 text-xs">🔔</span>
                            <span>Active Reminders</span>
                        </h3>
                        <p class="text-xs text-slate-400 mt-0.5">Pre-meeting alerts configured</p>
                    </div>
                    <a href="{{ route('notifications.index') }}" class="text-xs text-amber-400 hover:text-amber-300 font-bold transition-colors">
                        History &rarr;
                    </a>
                </div>

                @if ($upcomingReminders->isEmpty())
                    <div class="p-5 rounded-2xl bg-white/[0.02] border border-white/[0.06] text-center text-xs text-slate-400 space-y-1">
                        <div class="font-bold text-slate-300">No pending alerts queued.</div>
                        <p class="text-[11px] text-slate-500">When you schedule a meeting with a reminder, it will be armed here.</p>
                    </div>
                @else
                    <div class="space-y-2.5">
                        @foreach ($upcomingReminders as $rem)
                            <div class="p-3.5 rounded-2xl bg-amber-500/[0.08] border border-amber-500/25 flex items-start gap-3 text-xs">
                                <span class="text-amber-400 text-sm mt-0.5">🔔</span>
                                <div class="min-w-0 flex-1">
                                    <div class="text-[11px] font-bold text-amber-300">
                                        Alert at {{ $rem->remind_at->format('g:i A, M d') }}
                                    </div>
                                    <div class="text-white font-semibold truncate mt-0.5">
                                        {{ $rem->remindable?->title ?? 'Scheduled Call' }}
                                    </div>
                                    <div class="text-[10px] text-slate-400 mt-0.5">
                                        Will alert {{ $rem->remind_at->diffForHumans() }}
                                    </div>
                                </div>
                            </div>
                        @endforeach
                    </div>
                @endif
            </div>

            <!-- Quick Calendar Card Launcher -->
            <div class="glass-panel rounded-3xl p-6 shadow-2xl relative overflow-hidden space-y-4 border border-amber-400/20">
                <div class="flex items-center gap-3">
                    <div class="w-9 h-9 rounded-xl bg-amber-400 text-slate-950 font-black flex items-center justify-center text-sm shadow-md">
                        📅
                    </div>
                    <div>
                        <h4 class="text-sm font-bold text-white">Interactive Calendar</h4>
                        <p class="text-xs text-slate-400">Day, Week, and Month views</p>
                    </div>
                </div>
                <p class="text-xs text-slate-300 leading-relaxed">
                    Prefer dragging, dropping, and visually viewing your team's scrums? Launch the full calendar grid.
                </p>
                <a href="{{ route('calendar.index') }}"
                    class="btn-amber w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl text-xs">
                    <span>Open Calendar Workspace</span>
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3"></path></svg>
                </a>
            </div>

        </div>

    </div>

</div>
@endsection
