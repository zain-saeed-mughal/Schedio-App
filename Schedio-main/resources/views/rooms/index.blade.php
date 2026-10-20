@extends('layouts.app')

@section('title', 'Meeting Rooms & Suites Hub')

@section('content')
<div class="space-y-8" x-data="{
    createModalOpen: false,
    editModalOpen: false,
    editRoom: {
        id: null,
        name: '',
        code: '',
        location: '',
        capacity: 10,
        color: '#6366f1',
        amenities: [],
        amenities_text: '',
        is_active: true
    },
    openEdit(room) {
        this.editRoom = {
            id: room.id,
            name: room.name,
            code: room.code,
            location: room.location,
            capacity: room.capacity,
            color: room.color || '#6366f1',
            amenities: room.amenities || [],
            amenities_text: (room.amenities || []).join(', '),
            is_active: Boolean(room.is_active)
        };
        this.editModalOpen = true;
    }
}">

    <!-- Top Banner -->
    <div class="relative overflow-hidden rounded-3xl glass-panel p-6 sm:p-8 shadow-2xl">
        <div class="absolute -right-20 -top-20 w-80 h-80 bg-gradient-to-br from-emerald-500/20 to-teal-500/10 rounded-full blur-3xl pointer-events-none"></div>
        <div class="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div class="space-y-2">
                <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 text-xs font-medium">
                    <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
                    <span>Automated Double-Booking Prevention Active</span>
                </div>
                <h1 class="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
                    Meeting Suites & Focus Pods
                </h1>
                <p class="text-xs sm:text-sm text-slate-400 max-w-2xl leading-relaxed">
                    Manage corporate boardrooms, acoustic focus pods, and hybrid client suites. Real-time availability checks guarantee conflict-free reservations.
                </p>
            </div>

            @if ($user->isSuperAdmin())
                <button @click="createModalOpen = true"
                    class="btn-amber px-5 py-2.5 rounded-xl font-bold text-xs shadow-lg shadow-amber-500/20 flex items-center gap-2 shrink-0 cursor-pointer">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
                    <span>Add New Suite / Pod</span>
                </button>
            @endif
        </div>
    </div>

    <!-- Quick Stats Grid -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        <x-metric-card
            title="Total Suites & Pods"
            :value="$stats['total']"
            subtitle="Configured conference facilities"
            color="emerald">
            <x-slot:icon>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path></svg>
            </x-slot:icon>
        </x-metric-card>

        <x-metric-card
            title="Active & Available"
            :value="$stats['active']"
            subtitle="Bookable for internal & client scrums"
            color="indigo">
            <x-slot:icon>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            </x-slot:icon>
        </x-metric-card>

        <x-metric-card
            title="Total Combined Capacity"
            :value="$stats['total_capacity'] . ' seats'"
            subtitle="Seating across all active suites"
            color="purple">
            <x-slot:icon>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path></svg>
            </x-slot:icon>
        </x-metric-card>

        <x-metric-card
            title="Today's Reservations"
            :value="$stats['today_bookings']"
            subtitle="Sessions scheduled for today"
            color="amber">
            <x-slot:icon>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
            </x-slot:icon>
        </x-metric-card>
    </div>

    <!-- Filter & Search Controls -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-slate-900/60 border border-slate-800/80 p-4 rounded-2xl">
        <div class="flex items-center gap-2">
            <a href="{{ route('rooms.index', ['status' => 'all', 'search' => $search]) }}"
                class="px-3 py-1.5 rounded-xl text-xs font-bold transition-all {{ $status === 'all' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                All ({{ $stats['total'] }})
            </a>
            <a href="{{ route('rooms.index', ['status' => 'active', 'search' => $search]) }}"
                class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $status === 'active' ? 'bg-emerald-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                Active ({{ $stats['active'] }})
            </a>
            <a href="{{ route('rooms.index', ['status' => 'inactive', 'search' => $search]) }}"
                class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all {{ $status === 'inactive' ? 'bg-rose-600 text-white' : 'bg-slate-800/80 text-slate-300 hover:text-white' }}">
                Inactive ({{ $stats['total'] - $stats['active'] }})
            </a>
        </div>

        <form action="{{ route('rooms.index') }}" method="GET" class="relative">
            <input type="hidden" name="status" value="{{ $status }}">
            <input type="text" name="search" value="{{ $search }}" placeholder="Search suites by name, code, location..."
                class="w-64 sm:w-80 pl-8 pr-3 py-1.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500">
            <svg class="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
        </form>
    </div>

    <!-- Rooms Cards Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        @forelse ($rooms as $room)
            <div class="glass-card rounded-3xl p-5 sm:p-6 shadow-xl space-y-4 flex flex-col justify-between group">
                <div class="space-y-3">
                    <!-- Top header with color pill and status badge -->
                    <div class="flex items-center justify-between">
                        <div class="flex items-center gap-2">
                            <span class="w-3 h-3 rounded-full shadow-sm" style="background-color: {{ $room->color }}"></span>
                            <span class="text-[11px] font-mono font-bold text-slate-400 uppercase tracking-wider">{{ $room->code }}</span>
                        </div>
                        <x-badge :variant="$room->is_active ? 'success' : 'danger'" size="sm">
                            {{ $room->is_active ? 'Available' : 'Maintenance' }}
                        </x-badge>
                    </div>

                    <!-- Room Title & Location -->
                    <div>
                        <h3 class="text-lg font-bold text-white group-hover:text-amber-400 transition-colors">
                            {{ $room->name }}
                        </h3>
                        <p class="text-xs text-slate-400 flex items-center gap-1 mt-0.5">
                            <svg class="w-3.5 h-3.5 text-slate-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
                            <span>{{ $room->location }}</span>
                        </p>
                    </div>

                    <!-- Metrics / Amenities -->
                    <div class="grid grid-cols-2 gap-2 text-xs bg-slate-950/60 p-3 rounded-xl border border-slate-800/80">
                        <div>
                            <span class="text-slate-500 block text-[10px] uppercase font-bold">Max Capacity</span>
                            <span class="text-slate-200 font-bold">{{ $room->capacity }} Persons</span>
                        </div>
                        <div>
                            <span class="text-slate-500 block text-[10px] uppercase font-bold">Upcoming</span>
                            <span class="text-amber-400 font-bold">{{ $room->upcoming_meetings_count }} Scheduled</span>
                        </div>
                    </div>

                    <!-- Equipment & Amenities Pills -->
                    @if (!empty($room->amenities))
                        <div class="space-y-1.5 pt-1">
                            <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">Equipment & Amenities</span>
                            <div class="flex flex-wrap gap-1.5">
                                @foreach ($room->amenities as $amenity)
                                    <span class="px-2 py-0.5 rounded-lg bg-slate-800/80 text-slate-300 text-[10px] font-medium border border-slate-700/60">
                                        {{ $amenity }}
                                    </span>
                                @endforeach
                            </div>
                        </div>
                    @endif
                </div>

                <!-- Footer Actions -->
                <div class="pt-4 border-t border-slate-800/80 flex items-center justify-between gap-2">
                    <a href="{{ route('calendar.index', ['room_id' => $room->id]) }}"
                        class="text-xs text-amber-400 hover:text-amber-300 font-semibold flex items-center gap-1">
                        <span>View Schedule</span>
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
                    </a>

                    @if ($user->isSuperAdmin())
                        <div class="flex items-center gap-2">
                            <button @click="openEdit({{ Js::from($room) }})" title="Edit Suite"
                                class="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer">
                                <svg class="w-3.5 h-3.5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
                            </button>

                            <form action="{{ route('rooms.destroy', $room) }}" method="POST" onsubmit="return confirm('Remove suite {{ $room->name }}?');">
                                @csrf
                                @method('DELETE')
                                <button type="submit" title="Delete Suite"
                                    class="p-1.5 rounded-lg bg-slate-800 hover:bg-rose-950/40 text-slate-400 hover:text-rose-400 transition-colors cursor-pointer">
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                                </button>
                            </form>
                        </div>
                    @endif
                </div>
            </div>
        @empty
            <div class="col-span-full py-16 text-center space-y-3 bg-slate-900/30 rounded-2xl border border-slate-800/80">
                <div class="inline-flex p-4 rounded-2xl bg-slate-800/60 text-slate-500">
                    <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path></svg>
                </div>
                <h3 class="text-sm font-bold text-slate-300">No suites found</h3>
                <p class="text-xs text-slate-500 max-w-sm mx-auto">
                    No conference rooms match your query. Super Admins can add new rooms above.
                </p>
            </div>
        @endforelse
    </div>

    <!-- Pagination -->
    <div class="pt-4">
        {{ $rooms->links() }}
    </div>

    <!-- MODAL 1: CREATE ROOM (Super Admin) -->
    @if ($user->isSuperAdmin())
        <div x-show="createModalOpen" x-cloak
            class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
            x-transition:enter="transition ease-out duration-200"
            x-transition:enter-start="opacity-0"
            x-transition:enter-end="opacity-100"
            x-transition:leave="transition ease-in duration-150"
            x-transition:leave-start="opacity-100"
            x-transition:leave-end="opacity-0">
            
            <div @click.outside="createModalOpen = false"
                class="bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl max-w-lg w-full p-6 space-y-5 overflow-hidden">
                
                <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                    <h3 class="text-base font-bold text-white">Add New Meeting Suite / Focus Pod</h3>
                    <button @click="createModalOpen = false" class="text-slate-400 hover:text-white">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                    </button>
                </div>

                <form action="{{ route('rooms.store') }}" method="POST" class="space-y-4">
                    @csrf
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Room / Suite Name *</label>
                        <input type="text" name="name" required placeholder="e.g. Zenith Executive Boardroom"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-emerald-500 focus:outline-none">
                    </div>

                    <div class="grid grid-cols-2 gap-3">
                        <div>
                            <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Room Code</label>
                            <input type="text" name="code" placeholder="e.g. ROOM-ZENITH"
                                class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-emerald-500 focus:outline-none">
                        </div>

                        <div>
                            <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Max Capacity (Seats) *</label>
                            <input type="number" name="capacity" min="1" max="500" value="8" required
                                class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-emerald-500 focus:outline-none">
                        </div>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Building Location / Floor *</label>
                        <input type="text" name="location" required placeholder="e.g. Floor 5, East Innovation Wing"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-emerald-500 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Equipment & Amenities (comma-separated)</label>
                        <input type="text" name="amenities_text" placeholder="e.g. 4K Dual Displays, Cisco Telepresence, Smart Whiteboard, Jabra Mic"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-emerald-500 focus:outline-none">
                    </div>

                    <div class="grid grid-cols-2 gap-3 items-center">
                        <div>
                            <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Calendar Color Tag</label>
                            <div class="flex items-center gap-2">
                                <input type="color" name="color" value="#10b981"
                                    class="w-8 h-8 rounded-lg border-0 bg-transparent cursor-pointer">
                                <span class="text-xs text-slate-400">Identifies suite on calendar</span>
                            </div>
                        </div>

                        <div>
                            <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Status</label>
                            <label class="flex items-center gap-2 cursor-pointer mt-2">
                                <input type="checkbox" name="is_active" value="1" checked
                                    class="w-4 h-4 rounded border-slate-700 bg-slate-950 text-emerald-600 focus:ring-emerald-500">
                                <span class="text-xs text-slate-300 font-medium">Active & Bookable</span>
                            </label>
                        </div>
                    </div>

                    <div class="flex justify-end gap-3 pt-3 border-t border-slate-800">
                        <button type="button" @click="createModalOpen = false"
                            class="px-4 py-2 rounded-xl text-xs text-slate-400 hover:text-white">Cancel</button>
                        <button type="submit"
                            class="btn-amber px-5 py-2 rounded-xl text-xs font-bold shadow-lg shadow-amber-500/20">
                            Create Suite
                        </button>
                    </div>
                </form>
            </div>
        </div>

        <!-- MODAL 2: EDIT ROOM (Super Admin) -->
        <div x-show="editModalOpen" x-cloak
            class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
            x-transition:enter="transition ease-out duration-200"
            x-transition:enter-start="opacity-0"
            x-transition:enter-end="opacity-100"
            x-transition:leave="transition ease-in duration-150"
            x-transition:leave-start="opacity-100"
            x-transition:leave-end="opacity-0">
            
            <div @click.outside="editModalOpen = false"
                class="bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl max-w-lg w-full p-6 space-y-5 overflow-hidden">
                
                <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                    <h3 class="text-base font-bold text-white">Edit Meeting Suite / Pod</h3>
                    <button @click="editModalOpen = false" class="text-slate-400 hover:text-white">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                    </button>
                </div>

                <form :action="`/rooms/${editRoom.id}`" method="POST" class="space-y-4">
                    @csrf
                    @method('PUT')

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Room / Suite Name *</label>
                        <input type="text" name="name" x-model="editRoom.name" required
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                    </div>

                    <div class="grid grid-cols-2 gap-3">
                        <div>
                            <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Room Code *</label>
                            <input type="text" name="code" x-model="editRoom.code" required
                                class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                        </div>

                        <div>
                            <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Max Capacity (Seats) *</label>
                            <input type="number" name="capacity" x-model="editRoom.capacity" min="1" max="500" required
                                class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                        </div>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Building Location / Floor *</label>
                        <input type="text" name="location" x-model="editRoom.location" required
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Equipment & Amenities (comma-separated)</label>
                        <input type="text" name="amenities_text" x-model="editRoom.amenities_text"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                    </div>

                    <div class="grid grid-cols-2 gap-3 items-center">
                        <div>
                            <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Calendar Color Tag</label>
                            <div class="flex items-center gap-2">
                                <input type="color" name="color" x-model="editRoom.color"
                                    class="w-8 h-8 rounded-lg border-0 bg-transparent cursor-pointer">
                                <span class="text-xs text-slate-400 font-mono" x-text="editRoom.color"></span>
                            </div>
                        </div>

                        <div>
                            <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Status</label>
                            <label class="flex items-center gap-2 cursor-pointer mt-2">
                                <input type="checkbox" name="is_active" value="1" x-model="editRoom.is_active"
                                    class="w-4 h-4 rounded border-slate-700 bg-slate-950 text-indigo-600 focus:ring-indigo-500">
                                <span class="text-xs text-slate-300 font-medium">Active & Bookable</span>
                            </label>
                        </div>
                    </div>

                    <div class="flex justify-end gap-3 pt-3 border-t border-slate-800">
                        <button type="button" @click="editModalOpen = false"
                            class="px-4 py-2 rounded-xl text-xs text-slate-400 hover:text-white">Cancel</button>
                        <button type="submit"
                            class="btn-amber px-5 py-2 rounded-xl text-xs font-bold shadow-lg shadow-amber-500/20">
                            Save Changes
                        </button>
                    </div>
                </form>
            </div>
        </div>
    @endif
</div>
@endsection
