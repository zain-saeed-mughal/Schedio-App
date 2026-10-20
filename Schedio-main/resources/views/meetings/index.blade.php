@extends('layouts.app')

@section('title', 'My Scheduled Meetings')

@section('content')
<div class="space-y-6">

    <!-- Header & Action Row -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 glass-panel p-5 rounded-3xl shadow-xl">
        <div class="space-y-1">
            <h1 class="text-xl sm:text-2xl font-extrabold text-white tracking-tight flex items-center gap-2.5">
                <span>My Scheduled Meetings</span>
                <span class="text-xs px-2.5 py-0.5 rounded-full bg-amber-500/20 text-amber-300 font-bold border border-amber-500/30">Meeting Management Hub</span>
            </h1>
            <p class="text-xs text-slate-400">
                Track all upcoming and past client calls, consults, and reviews with automatic reminders.
            </p>
        </div>

        <div class="flex items-center gap-3">
            <a href="{{ route('calendar.index') }}"
                class="px-4 py-2.5 rounded-xl bg-white/[0.06] hover:bg-white/[0.12] text-slate-200 text-xs font-bold border border-white/[0.08] transition-all flex items-center gap-1.5 shadow-md">
                <svg class="w-4 h-4 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                <span>Calendar View</span>
            </a>
            <a href="{{ route('meetings.create') }}"
                class="btn-amber px-4 py-2.5 rounded-xl text-xs font-bold shadow-lg shadow-amber-500/20 flex items-center gap-1.5">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
                <span>+ Schedule Meeting</span>
            </a>
        </div>
    </div>

    @if (session('success'))
        <div class="p-4 rounded-2xl bg-emerald-950/60 border border-emerald-500/35 text-emerald-300 text-sm flex items-center gap-3 shadow-lg shadow-emerald-950/30">
            <svg class="w-5 h-5 text-emerald-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            <span class="font-medium">{{ session('success') }}</span>
        </div>
    @endif

    <!-- Simple Search & Filter Bar -->
    <div class="glass-card rounded-3xl p-4 sm:p-5 shadow-lg space-y-4">
        <form action="{{ route('meetings.index') }}" method="GET" class="flex flex-col sm:flex-row items-center gap-3">
            <!-- Search Input -->
            <div class="relative flex-1 w-full">
                <input type="text" name="search" value="{{ $search }}" placeholder="Search by meeting title, client name, or notes..."
                    class="w-full pl-10 pr-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-500 focus:outline-none">
                <svg class="w-4 h-4 text-slate-500 absolute left-3.5 top-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                </svg>
            </div>

            <!-- Submit Filter -->
            <div class="flex items-center gap-2 w-full sm:w-auto">
                <button type="submit" class="btn-amber px-5 py-2.5 rounded-xl text-xs font-bold transition-all cursor-pointer">
                    Search
                </button>
                @if ($search || request('status'))
                    <a href="{{ route('meetings.index') }}" class="px-3.5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition-all text-center">
                        Clear
                    </a>
                @endif
            </div>
        </form>

        <!-- Status Filter Tabs -->
        <div class="flex items-center gap-2 pt-2 border-t border-slate-800/80 overflow-x-auto text-xs">
            <a href="{{ route('meetings.index', array_merge(request()->query(), ['status' => 'all'])) }}"
                class="px-3.5 py-1.5 rounded-lg font-bold transition-all {{ $status === 'all' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'bg-slate-800/80 text-slate-400 hover:text-slate-200' }}">
                All Meetings ({{ $counts['all'] }})
            </a>
            <a href="{{ route('meetings.index', array_merge(request()->query(), ['status' => 'scheduled'])) }}"
                class="px-3.5 py-1.5 rounded-lg font-bold transition-all {{ $status === 'scheduled' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'bg-slate-800/80 text-slate-400 hover:text-slate-200' }}">
                Scheduled ({{ $counts['upcoming'] }})
            </a>
            <a href="{{ route('meetings.index', array_merge(request()->query(), ['status' => 'completed'])) }}"
                class="px-3.5 py-1.5 rounded-lg font-bold transition-all {{ $status === 'completed' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'bg-slate-800/80 text-slate-400 hover:text-slate-200' }}">
                Completed ({{ $counts['completed'] }})
            </a>
            <a href="{{ route('meetings.index', array_merge(request()->query(), ['status' => 'cancelled'])) }}"
                class="px-3.5 py-1.5 rounded-lg font-bold transition-all {{ $status === 'cancelled' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'bg-slate-800/80 text-slate-400 hover:text-slate-200' }}">
                Cancelled ({{ $counts['cancelled'] }})
            </a>
        </div>
    </div>

    <!-- Meetings Listing -->
    <div class="bg-slate-900/70 border border-slate-800/80 rounded-2xl shadow-xl overflow-hidden">
        @if ($meetings->isEmpty())
            <div class="text-center py-16 px-4 space-y-3">
                <div class="inline-flex p-4 rounded-2xl bg-slate-800/50 text-slate-500">
                    <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                    </svg>
                </div>
                <h3 class="text-base font-semibold text-slate-300">No Meetings Found</h3>
                <p class="text-xs text-slate-500 max-w-sm mx-auto">No meetings match your search. Schedule your next meeting in seconds.</p>
                <div class="pt-2">
                    <a href="{{ route('meetings.create') }}" class="btn-amber inline-flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold shadow-lg shadow-amber-500/20">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
                        Schedule Meeting
                    </a>
                </div>
            </div>
        @else
            <div class="divide-y divide-slate-800/80">
                @foreach ($meetings as $m)
                    <div class="p-5 sm:p-6 hover:bg-slate-850/40 transition-colors flex flex-col lg:flex-row lg:items-center justify-between gap-6">
                        <!-- Meeting Info -->
                        <div class="space-y-2 max-w-2xl">
                            <div class="flex flex-wrap items-center gap-2">
                                <span class="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider {{ $m->status === 'scheduled' ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30' : ($m->status === 'cancelled' ? 'bg-rose-500/20 text-rose-300 border border-rose-500/30' : 'bg-slate-800 text-slate-300') }}">
                                    {{ strtoupper($m->status) }}
                                </span>

                                @if (!empty($m->metadata['client_name']))
                                    <span class="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/20 text-amber-300 border border-amber-500/30">
                                        Client: {{ $m->metadata['client_name'] }}
                                        @if (!empty($m->metadata['client_company']))
                                             ({{ $m->metadata['client_company'] }})
                                        @endif
                                    </span>
                                @endif

                                @if (!empty($m->metadata['reminder_minutes']))
                                    <span class="px-2 py-0.5 text-[10px] font-semibold rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/30 flex items-center gap-1">
                                        <span>🔔</span>
                                        <span>{{ $m->metadata['reminder_minutes'] }}m Alert</span>
                                    </span>
                                @endif
                            </div>

                            <a href="{{ route('meetings.show', $m) }}" class="text-base sm:text-lg font-bold text-white hover:text-amber-400 transition-colors block">
                                {{ $m->title }}
                            </a>

                            @if ($m->description)
                                <p class="text-xs text-slate-400 line-clamp-2">{{ $m->description }}</p>
                            @endif

                            <div class="flex flex-wrap items-center gap-4 text-xs text-slate-400 pt-1">
                                <div class="flex items-center gap-1.5 text-slate-200">
                                    <svg class="w-4 h-4 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                                    <span class="font-medium">{{ $m->start_time->format('D, M d, Y • h:i A') }}</span> - {{ $m->end_time->format('h:i A') }}
                                </div>

                                @if ($m->meeting_link)
                                    <div class="flex items-center gap-1.5 text-amber-400 font-mono">
                                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg>
                                        <span>Video Ready</span>
                                    </div>
                                @endif
                            </div>
                        </div>

                        <!-- Actions -->
                        <div class="flex items-center gap-2.5 shrink-0">
                            @if ($m->meeting_link)
                                <a href="{{ $m->meeting_link }}" target="_blank"
                                    class="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-600/30 transition-all flex items-center gap-1.5 cursor-pointer">
                                    <span>Join Call</span>
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
                                </a>
                            @endif

                            <a href="{{ route('meetings.show', $m) }}"
                                class="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold border border-slate-700 transition-all">
                                Details
                            </a>

                            @if (auth()->user()->isSuperAdmin() || $m->organizer_id === auth()->id())
                                <a href="{{ route('meetings.edit', $m) }}"
                                    class="p-2 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors" title="Edit Meeting">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
                                </a>
                            @endif
                        </div>
                    </div>
                @endforeach
            </div>

            @if ($meetings->hasPages())
                <div class="p-4 border-t border-slate-800">
                    {{ $meetings->links() }}
                </div>
            @endif
        @endif
    </div>
</div>
@endsection
