@extends('layouts.app')

@section('title', 'Company Events, Holidays & Important Dates')

@section('content')
<div class="space-y-8" x-data="{
    createEventModalOpen: false,
    editEventModalOpen: false,
    editEvent: {
        id: null,
        title: '',
        description: '',
        category: 'general',
        department_id: '',
        start_time: '',
        end_time: '',
        is_all_day: false,
        location: '',
        color: '#3b82f6',
        is_company_wide: false
    },
    openEdit(evt) {
        this.editEvent = {
            id: evt.id,
            title: evt.title,
            description: evt.description || '',
            category: evt.category || 'general',
            department_id: evt.department_id || '',
            start_time: evt.start_time ? evt.start_time.substring(0, 16) : '',
            end_time: evt.end_time ? evt.end_time.substring(0, 16) : '',
            is_all_day: Boolean(evt.is_all_day),
            location: evt.location || '',
            color: evt.color || '#3b82f6',
            is_company_wide: Boolean(evt.is_company_wide)
        };
        this.editEventModalOpen = true;
    }
}">

    <!-- Top Hero Banner -->
    <div class="relative overflow-hidden rounded-3xl glass-panel p-6 sm:p-8 shadow-2xl">
        <div class="absolute -right-20 -top-20 w-80 h-80 bg-gradient-to-br from-pink-500/20 to-purple-500/10 rounded-full blur-3xl pointer-events-none"></div>
        <div class="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div class="space-y-2">
                <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-pink-500/10 border border-pink-500/20 text-pink-300 text-xs font-medium">
                    <span class="w-2 h-2 rounded-full bg-pink-400 animate-pulse"></span>
                    <span>Calendar-Integrated Events & Milestones</span>
                </div>
                <h1 class="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
                    Company Events, Holidays & Key Dates
                </h1>
                <p class="text-xs sm:text-sm text-slate-400 max-w-2xl leading-relaxed">
                    Track organization-wide holidays, department workshops, certification trainings, product releases, and corporate milestone dates seamlessly synced to all employee calendars.
                </p>
            </div>

            <button @click="createEventModalOpen = true"
                class="btn-amber px-5 py-2.5 rounded-xl font-bold text-xs shadow-lg shadow-amber-500/20 flex items-center gap-2 shrink-0 cursor-pointer">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
                <span>Add Event / Holiday</span>
            </button>
        </div>
    </div>

    <!-- Category Stats Grid -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
        <x-metric-card
            title="Total Events"
            :value="$counts['all']"
            subtitle="Scheduled in workspace"
            color="indigo">
            <x-slot:icon>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
            </x-slot:icon>
        </x-metric-card>

        <x-metric-card
            title="Company Holidays"
            :value="$counts['holidays']"
            subtitle="Official office closures"
            color="danger">
            <x-slot:icon>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            </x-slot:icon>
        </x-metric-card>

        <x-metric-card
            title="Trainings & Sprints"
            :value="$counts['trainings']"
            subtitle="Workshops & bootcamps"
            color="purple">
            <x-slot:icon>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"></path></svg>
            </x-slot:icon>
        </x-metric-card>

        <x-metric-card
            title="Milestones"
            :value="$counts['milestones']"
            subtitle="Key corporate deliverables"
            color="amber">
            <x-slot:icon>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M19 3v4M5 11h14M5 19h14M6 7h12a2 2 0 012 2v10a2 2 0 01-2 2H6a2 2 0 01-2-2V9a2 2 0 012-2z"></path></svg>
            </x-slot:icon>
        </x-metric-card>

        <x-metric-card
            title="Major Deadlines"
            :value="$counts['deadlines']"
            subtitle="Release dates & reviews"
            color="emerald">
            <x-slot:icon>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            </x-slot:icon>
        </x-metric-card>
    </div>

    <!-- Category Filter Bar & Search -->
    <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-4 bg-slate-900/60 border border-slate-800/80 p-4 rounded-2xl">
        <div class="flex flex-wrap items-center gap-2">
            <a href="{{ route('events.index', ['category' => 'all', 'search' => $search]) }}"
                class="px-3 py-1.5 rounded-xl text-xs font-bold transition-all {{ $category === 'all' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                All ({{ $counts['all'] }})
            </a>
            <a href="{{ route('events.index', ['category' => 'company_holiday', 'search' => $search]) }}"
                class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $category === 'company_holiday' ? 'bg-pink-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                Holidays ({{ $counts['holidays'] }})
            </a>
            <a href="{{ route('events.index', ['category' => 'training', 'search' => $search]) }}"
                class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $category === 'training' ? 'bg-purple-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                Trainings ({{ $counts['trainings'] }})
            </a>
            <a href="{{ route('events.index', ['category' => 'milestone', 'search' => $search]) }}"
                class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $category === 'milestone' ? 'bg-amber-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                Milestones ({{ $counts['milestones'] }})
            </a>
            <a href="{{ route('events.index', ['category' => 'deadline', 'search' => $search]) }}"
                class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $category === 'deadline' ? 'bg-rose-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                Deadlines ({{ $counts['deadlines'] }})
            </a>
        </div>

        <div class="flex items-center gap-3">
            <form action="{{ route('events.index') }}" method="GET" class="relative">
                <input type="hidden" name="category" value="{{ $category }}">
                <input type="text" name="search" value="{{ $search }}" placeholder="Search events..."
                    class="w-64 sm:w-72 pl-8 pr-3 py-1.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500">
                <svg class="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
            </form>

            <a href="{{ route('calendar.index', ['type' => 'events']) }}"
                class="px-3.5 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-amber-400 hover:text-amber-300 text-xs font-semibold transition-all shrink-0 flex items-center gap-1.5">
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                <span>Calendar View</span>
            </a>
        </div>
    </div>

    <!-- Events List Table / Card Grid -->
    <div class="bg-slate-900/80 border border-slate-800/90 rounded-2xl overflow-hidden shadow-xl">
        <div class="divide-y divide-slate-800/80">
            @forelse ($events as $event)
                @php
                    $canEdit = $user->isSuperAdmin() || $event->user_id === $user->id;
                    $badgeVariant = match ($event->category) {
                        'company_holiday' => 'danger',
                        'training' => 'purple',
                        'milestone' => 'warning',
                        'deadline' => 'danger',
                        default => 'info',
                    };
                @endphp
                <div class="p-4 sm:p-5 hover:bg-slate-850/40 transition-colors flex flex-col md:flex-row md:items-center justify-between gap-4 group">
                    <div class="space-y-1.5 flex-1 min-w-0">
                        <div class="flex flex-wrap items-center gap-2">
                            <span class="w-2.5 h-2.5 rounded-full" style="background-color: {{ $event->color }}"></span>
                            <x-badge :variant="$badgeVariant" size="sm">
                                {{ ucwords(str_replace('_', ' ', $event->category)) }}
                            </x-badge>
                            @if ($event->is_company_wide)
                                <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-indigo-500/15 text-indigo-300 border border-indigo-500/30">Company-Wide</span>
                            @elseif ($event->department)
                                <span class="text-xs text-slate-400 font-medium">{{ $event->department->name }}</span>
                            @endif
                        </div>

                        <h3 class="text-base font-bold text-white group-hover:text-indigo-300 transition-colors">
                            {{ $event->title }}
                        </h3>

                        @if ($event->description)
                            <p class="text-xs text-slate-400 line-clamp-2 max-w-3xl leading-relaxed">{{ $event->description }}</p>
                        @endif

                        <div class="flex flex-wrap items-center gap-4 text-xs text-slate-400 pt-1">
                            <span class="text-slate-300 font-mono">
                                @if ($event->is_all_day)
                                    {{ $event->start_time->format('D, M d, Y') }} (All Day)
                                @else
                                    {{ $event->start_time->format('D, M d, Y • h:i A') }} - {{ $event->end_time->format('h:i A') }}
                                @endif
                            </span>

                            @if ($event->location)
                                <span class="flex items-center gap-1 text-slate-400">
                                    <svg class="w-3.5 h-3.5 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
                                    {{ $event->location }}
                                </span>
                            @endif

                            <span>Organizer: <span class="text-slate-300">{{ $event->user?->name ?? 'System' }}</span></span>
                        </div>
                    </div>

                    <!-- Right Actions -->
                    <div class="flex items-center gap-2 shrink-0 self-end md:self-center">
                        <a href="{{ route('calendar.index', ['type' => 'events']) }}"
                            class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-xs font-semibold transition-all">
                            View on Calendar
                        </a>

                        @if ($canEdit)
                            <button @click="openEdit({{ Js::from($event) }})" title="Edit Event"
                                class="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer">
                                <svg class="w-4 h-4 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
                            </button>

                            <form action="{{ route('events.destroy', $event) }}" method="POST" onsubmit="return confirm('Delete event {{ $event->title }}?');">
                                @csrf
                                @method('DELETE')
                                <button type="submit" title="Delete Event"
                                    class="p-1.5 rounded-lg bg-slate-800 hover:bg-rose-950/40 text-slate-400 hover:text-rose-400 transition-colors cursor-pointer">
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                                </button>
                            </form>
                        @endif
                    </div>
                </div>
            @empty
                <div class="py-16 text-center space-y-3">
                    <div class="inline-flex p-4 rounded-2xl bg-slate-800/60 text-slate-500">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                    </div>
                    <h3 class="text-sm font-bold text-slate-300">No events found</h3>
                    <p class="text-xs text-slate-500 max-w-sm mx-auto">
                        There are no events matching your category filter. Add a new company event, holiday or training above.
                    </p>
                </div>
            @endforelse
        </div>
    </div>

    <!-- Pagination -->
    <div class="pt-4">
        {{ $events->links() }}
    </div>

    <!-- MODAL 1: CREATE EVENT -->
    <div x-show="createEventModalOpen" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">
        
        <div @click.outside="createEventModalOpen = false"
            class="bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl max-w-lg w-full p-6 space-y-5 overflow-hidden">
            
            <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                <h3 class="text-base font-bold text-white">Create Company Event or Holiday</h3>
                <button @click="createEventModalOpen = false" class="text-slate-400 hover:text-white">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <form action="{{ route('events.store') }}" method="POST" class="space-y-4">
                @csrf
                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Event Title *</label>
                    <input type="text" name="title" required placeholder="e.g. Annual Tech Symposium & Hackathon"
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-pink-500 focus:outline-none">
                </div>

                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Category *</label>
                        <select name="category" required
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-pink-500 focus:outline-none">
                            <option value="company_holiday">Company Holiday</option>
                            <option value="training">Training / Workshop</option>
                            <option value="milestone">Company Milestone</option>
                            <option value="deadline">Product Deadline</option>
                            <option value="out_of_office">Out of Office</option>
                            <option value="general" selected>General Event</option>
                        </select>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Department</label>
                        <select name="department_id"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-pink-500 focus:outline-none">
                            <option value="">Company-Wide / All Teams</option>
                            @foreach ($departments as $dept)
                                <option value="{{ $dept->id }}">{{ $dept->name }}</option>
                            @endforeach
                        </select>
                    </div>
                </div>

                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Start Date & Time *</label>
                        <input type="datetime-local" name="start_time" required
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-pink-500 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">End Date & Time *</label>
                        <input type="datetime-local" name="end_time" required
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-pink-500 focus:outline-none">
                    </div>
                </div>

                <div class="grid grid-cols-2 gap-3 items-center">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Location / Venue</label>
                        <input type="text" name="location" placeholder="e.g. Main Auditorium or Virtual"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-pink-500 focus:outline-none">
                    </div>

                    <div class="flex items-center gap-4 pt-3">
                        <label class="flex items-center gap-2 cursor-pointer">
                            <input type="checkbox" name="is_all_day" value="1"
                                class="w-4 h-4 rounded border-slate-700 bg-slate-950 text-pink-600 focus:ring-pink-500">
                            <span class="text-xs text-slate-300 font-medium">All-Day</span>
                        </label>

                        @if ($user->isSuperAdmin())
                            <label class="flex items-center gap-2 cursor-pointer">
                                <input type="checkbox" name="is_company_wide" value="1" checked
                                    class="w-4 h-4 rounded border-slate-700 bg-slate-950 text-pink-600 focus:ring-pink-500">
                                <span class="text-xs text-slate-300 font-medium">Company-Wide</span>
                            </label>
                        @endif
                    </div>
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Description / Agenda</label>
                    <textarea name="description" rows="3" placeholder="Additional event details, links or instructions..."
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-pink-500 focus:outline-none"></textarea>
                </div>

                <div class="flex justify-end gap-3 pt-3 border-t border-slate-800">
                    <button type="button" @click="createEventModalOpen = false"
                        class="px-4 py-2 rounded-xl text-xs text-slate-400 hover:text-white">Cancel</button>
                    <button type="submit"
                        class="btn-amber px-5 py-2 rounded-xl text-xs font-bold shadow-lg shadow-amber-500/20">
                        Create & Publish Event
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 2: EDIT EVENT -->
    <div x-show="editEventModalOpen" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">
        
        <div @click.outside="editEventModalOpen = false"
            class="bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl max-w-lg w-full p-6 space-y-5 overflow-hidden">
            
            <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                <h3 class="text-base font-bold text-white">Edit Event Details</h3>
                <button @click="editEventModalOpen = false" class="text-slate-400 hover:text-white">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <form :action="`/events/${editEvent.id}`" method="POST" class="space-y-4">
                @csrf
                @method('PUT')

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Event Title *</label>
                    <input type="text" name="title" x-model="editEvent.title" required
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                </div>

                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Category *</label>
                        <select name="category" x-model="editEvent.category" required
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                            <option value="company_holiday">Company Holiday</option>
                            <option value="training">Training / Workshop</option>
                            <option value="milestone">Company Milestone</option>
                            <option value="deadline">Product Deadline</option>
                            <option value="out_of_office">Out of Office</option>
                            <option value="general">General Event</option>
                        </select>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Department</label>
                        <select name="department_id" x-model="editEvent.department_id"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                            <option value="">Company-Wide / All Teams</option>
                            @foreach ($departments as $dept)
                                <option value="{{ $dept->id }}">{{ $dept->name }}</option>
                            @endforeach
                        </select>
                    </div>
                </div>

                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Start Date & Time *</label>
                        <input type="datetime-local" name="start_time" x-model="editEvent.start_time" required
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">End Date & Time *</label>
                        <input type="datetime-local" name="end_time" x-model="editEvent.end_time" required
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                    </div>
                </div>

                <div class="grid grid-cols-2 gap-3 items-center">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Location / Venue</label>
                        <input type="text" name="location" x-model="editEvent.location"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                    </div>

                    <div class="flex items-center gap-4 pt-3">
                        <label class="flex items-center gap-2 cursor-pointer">
                            <input type="checkbox" name="is_all_day" value="1" x-model="editEvent.is_all_day"
                                class="w-4 h-4 rounded border-slate-700 bg-slate-950 text-indigo-600 focus:ring-indigo-500">
                            <span class="text-xs text-slate-300 font-medium">All-Day</span>
                        </label>

                        @if ($user->isSuperAdmin())
                            <label class="flex items-center gap-2 cursor-pointer">
                                <input type="checkbox" name="is_company_wide" value="1" x-model="editEvent.is_company_wide"
                                    class="w-4 h-4 rounded border-slate-700 bg-slate-950 text-indigo-600 focus:ring-indigo-500">
                                <span class="text-xs text-slate-300 font-medium">Company-Wide</span>
                            </label>
                        @endif
                    </div>
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Description / Agenda</label>
                    <textarea name="description" rows="3" x-model="editEvent.description"
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                </div>

                <div class="flex justify-end gap-3 pt-3 border-t border-slate-800">
                    <button type="button" @click="editEventModalOpen = false"
                        class="px-4 py-2 rounded-xl text-xs text-slate-400 hover:text-white">Cancel</button>
                    <button type="submit"
                        class="btn-amber px-5 py-2 rounded-xl text-xs font-bold shadow-lg shadow-amber-500/20">
                        Save Event
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection
