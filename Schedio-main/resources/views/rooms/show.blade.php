@extends('layouts.app')

@section('title', $room->name . ' - Suite Details & Schedule')

@section('content')
<div class="space-y-8">
    <!-- Back to Rooms / Top Nav -->
    <div class="flex items-center justify-between">
        <a href="{{ route('rooms.index') }}"
            class="inline-flex items-center gap-2 text-xs font-semibold text-slate-400 hover:text-white transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path>
            </svg>
            <span>Back to All Suites</span>
        </a>

        <div class="flex items-center gap-3">
            <a href="{{ route('calendar.index', ['room_id' => $room->id]) }}"
                class="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold transition-all flex items-center gap-2">
                <svg class="w-4 h-4 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                </svg>
                <span>Calendar View</span>
            </a>
            <a href="{{ route('meetings.create', ['room_id' => $room->id]) }}"
                class="px-4 py-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white text-xs font-bold shadow-lg shadow-emerald-600/30 transition-all flex items-center gap-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"></path>
                </svg>
                <span>Book This Room</span>
            </a>
        </div>
    </div>

    <!-- Hero Card -->
    <div class="relative overflow-hidden rounded-3xl bg-slate-900/90 border border-slate-800/80 p-6 sm:p-8 shadow-2xl">
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div class="space-y-3">
                <div class="flex items-center gap-3">
                    <span class="w-3.5 h-3.5 rounded-full ring-4 ring-white/10" style="background-color: {{ $room->color ?? '#6366f1' }}"></span>
                    <span class="text-xs font-mono font-bold uppercase tracking-wider text-indigo-400">{{ $room->code }}</span>
                    @if ($room->is_active)
                        <span class="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-300 border border-emerald-500/20">Active & Bookable</span>
                    @else
                        <span class="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-rose-500/10 text-rose-300 border border-rose-500/20">Inactive / Maintenance</span>
                    @endif
                </div>

                <h1 class="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
                    {{ $room->name }}
                </h1>

                <p class="text-xs sm:text-sm text-slate-400 flex items-center gap-2">
                    <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                    </svg>
                    <span>{{ $room->location }}</span>
                </p>
            </div>

            <!-- Fast Specs Grid -->
            <div class="flex items-center gap-4 bg-slate-950/80 p-4 rounded-2xl border border-slate-800">
                <div class="px-4 text-center">
                    <div class="text-[10px] uppercase font-bold text-slate-500 tracking-wider">Capacity</div>
                    <div class="text-xl font-extrabold text-white mt-1">{{ $room->capacity }}</div>
                    <div class="text-[10px] text-slate-400">Seats</div>
                </div>
                <div class="w-px h-10 bg-slate-800"></div>
                <div class="px-4 text-center">
                    <div class="text-[10px] uppercase font-bold text-slate-500 tracking-wider">Upcoming</div>
                    <div class="text-xl font-extrabold text-indigo-400 mt-1">{{ $room->meetings->count() }}</div>
                    <div class="text-[10px] text-slate-400">Sessions</div>
                </div>
            </div>
        </div>

        @if (!empty($room->amenities))
            <div class="mt-6 pt-6 border-t border-slate-800 flex flex-wrap items-center gap-2">
                <span class="text-xs font-bold text-slate-400 mr-2">Amenities:</span>
                @foreach ($room->amenities as $amenity)
                    <span class="px-3 py-1 rounded-xl bg-slate-800/80 text-slate-200 text-xs font-medium border border-slate-700/60">
                        {{ $amenity }}
                    </span>
                @endforeach
            </div>
        @endif
    </div>

    <!-- Scheduled Meetings Timeline -->
    <div class="space-y-4">
        <h2 class="text-lg font-bold text-white flex items-center gap-2">
            <svg class="w-5 h-5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            <span>Upcoming Scheduled Sessions</span>
        </h2>

        @if ($room->meetings->isEmpty())
            <div class="py-12 text-center bg-slate-900/40 rounded-2xl border border-slate-800">
                <div class="text-slate-400 text-sm font-semibold">No upcoming meetings scheduled in this room.</div>
                <p class="text-slate-500 text-xs mt-1">This room is completely free for reservations.</p>
                <a href="{{ route('meetings.create', ['room_id' => $room->id]) }}"
                    class="mt-4 inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition-all">
                    <span>Schedule First Meeting</span>
                </a>
            </div>
        @else
            <div class="space-y-3">
                @foreach ($room->meetings as $meeting)
                    <a href="{{ route('meetings.show', $meeting) }}"
                        class="block p-4 rounded-2xl bg-slate-900/80 hover:bg-slate-800/80 border border-slate-800 transition-all group">
                        <div class="flex items-center justify-between">
                            <div class="space-y-1">
                                <div class="text-sm font-bold text-white group-hover:text-indigo-300 transition-colors">
                                    {{ $meeting->title }}
                                </div>
                                <div class="text-xs text-slate-400 flex items-center gap-3">
                                    <span>{{ $meeting->start_time->format('l, M j, Y') }} &bull; {{ $meeting->start_time->format('h:i A') }} - {{ $meeting->end_time->format('h:i A') }}</span>
                                    <span>&bull;</span>
                                    <span>Organized by {{ $meeting->organizer->name ?? 'Team Member' }}</span>
                                </div>
                            </div>
                            <span class="px-2.5 py-1 rounded-lg text-xs font-bold uppercase tracking-wider
                                @if($meeting->status === 'completed') bg-emerald-500/10 text-emerald-400 border border-emerald-500/20
                                @elseif($meeting->status === 'cancelled') bg-rose-500/10 text-rose-400 border border-rose-500/20
                                @else bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 @endif">
                                {{ $meeting->status }}
                            </span>
                        </div>
                    </a>
                @endforeach
            </div>
        @endif
    </div>
</div>
@endsection
