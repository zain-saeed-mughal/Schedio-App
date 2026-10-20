@extends('layouts.app')

@section('title', $client->company_name . ' — Client Profile & Deal Room')

@section('content')
<div class="max-w-7xl mx-auto space-y-8" x-data="{
    openEditModal: false,
    openScheduleModal: false
}">

    <!-- Flash Notification -->
    @if (session('success'))
        <div class="p-4 rounded-2xl bg-emerald-950/60 border border-emerald-500/30 text-emerald-300 text-sm flex items-center justify-between shadow-lg shadow-black/40">
            <div class="flex items-center gap-3">
                <div class="p-1.5 rounded-xl bg-emerald-500/20 text-emerald-400">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                </div>
                <span class="font-medium">{{ session('success') }}</span>
            </div>
            <button @click="$el.parentElement.remove()" class="text-emerald-400/60 hover:text-emerald-300 text-xs">Dismiss</button>
        </div>
    @endif

    <!-- Top Action Bar -->
    <div class="flex items-center justify-between">
        <a href="{{ route('clients.index') }}" class="text-xs text-slate-400 hover:text-white flex items-center gap-1.5 font-medium transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path></svg>
            <span>Back to Clients & Pipeline</span>
        </a>

        <div class="flex items-center gap-2">
            <button @click="openScheduleModal = true"
                class="btn-amber px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-1.5 shadow-md shadow-amber-500/20 cursor-pointer">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                <span>Schedule Meeting</span>
            </button>

            <button @click="openEditModal = true"
                class="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-semibold transition-all">
                Edit Client
            </button>

            <form action="{{ route('clients.destroy', $client) }}" method="POST" onsubmit="return confirm('Remove this client from the pipeline?');">
                @csrf
                @method('DELETE')
                <button type="submit" class="p-2 rounded-xl bg-rose-950/60 hover:bg-rose-900/60 border border-rose-800/60 text-rose-300 transition-all cursor-pointer" title="Delete Client">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                </button>
            </form>
        </div>
    </div>

    <!-- Client Header Card (Matching Schedio Amber Glassmorphism) -->
    <div class="relative overflow-hidden rounded-3xl glass-panel border border-amber-500/20 p-6 sm:p-8 shadow-2xl shadow-black/50 space-y-6">
        <div class="absolute -right-20 -top-20 w-80 h-80 bg-amber-500/10 rounded-full blur-3xl pointer-events-none"></div>

        <div class="relative z-10 flex flex-col md:flex-row md:items-start justify-between gap-6">
            <div class="space-y-3">
                <div class="flex flex-wrap items-center gap-3">
                    <!-- Status Badge (Matching Screenshot 2 styling) -->
                    <span class="px-3.5 py-1.5 rounded-full text-xs font-black uppercase tracking-wider shadow-sm"
                        style="{{ $client->status_meta['badge_style'] }}">
                        {{ $client->status_label }}
                    </span>

                    @if ($client->campaign)
                        <span class="px-3 py-1 rounded-xl text-xs font-bold bg-slate-900 border border-slate-700 text-indigo-300">
                            🎯 {{ $client->campaign }}
                        </span>
                    @endif

                    @if ($client->deal_value)
                        <span class="px-3 py-1 rounded-xl text-xs font-mono font-bold bg-amber-400/10 text-amber-300 border border-amber-400/30">
                            Est. Value: ${{ number_format($client->deal_value) }}
                        </span>
                    @endif
                </div>

                <h1 class="text-2xl sm:text-4xl font-black text-white tracking-tight">
                    {{ $client->company_name }}
                </h1>

                <div class="flex flex-wrap items-center gap-4 text-xs text-slate-300">
                    <div class="flex items-center gap-2">
                        <span class="text-slate-500">Contact:</span>
                        <strong class="text-white">{{ $client->contact_name }}</strong>
                        @if ($client->contact_role)
                            <span class="text-slate-400">({{ $client->contact_role }})</span>
                        @endif
                    </div>

                    @if ($client->contact_email)
                        <div class="flex items-center gap-1.5 text-indigo-400 font-mono">
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path></svg>
                            <a href="mailto:{{ $client->contact_email }}" class="hover:underline">{{ $client->contact_email }}</a>
                        </div>
                    @endif

                    @if ($client->contact_phone)
                        <div class="flex items-center gap-1.5 text-slate-300 font-mono">
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"></path></svg>
                            <span>{{ $client->contact_phone }}</span>
                        </div>
                    @endif
                </div>
            </div>

            <!-- Quick Status Change Box -->
            <div class="bg-slate-950/70 border border-white/[0.08] p-4 rounded-2xl space-y-2 shrink-0 min-w-[220px]">
                <span class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block">Move Deal Stage</span>
                @if ($client->next_status)
                    <form action="{{ route('clients.update-status', $client) }}" method="POST">
                        @csrf
                        @method('PATCH')
                        <input type="hidden" name="status" value="{{ $client->next_status }}">
                        <button type="submit" class="w-full py-2 px-3 rounded-xl text-xs font-black bg-amber-400 text-slate-950 hover:bg-amber-300 transition-all shadow-md shadow-amber-500/20 flex items-center justify-center gap-1.5 cursor-pointer">
                            <span>{{ $client->next_action_label }}</span>
                            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M13 7l5 5m0 0l-5 5m5-5H6"></path></svg>
                        </button>
                    </form>
                @endif
                <form action="{{ route('clients.update-status', $client) }}" method="POST">
                    @csrf
                    @method('PATCH')
                    <select name="status" onchange="this.form.submit()"
                        class="w-full px-3 py-1.5 rounded-xl text-xs font-bold cursor-pointer border focus:ring-2 focus:ring-amber-400"
                        style="{{ $client->status_meta['badge_style'] }}">
                        @foreach (\App\Models\Client::STATUSES as $optKey => $optMeta)
                            <option value="{{ $optKey }}" {{ $client->status === $optKey ? 'selected' : '' }}>
                                {{ $optMeta['label'] }}
                            </option>
                        @endforeach
                    </select>
                </form>
                <span class="text-[10px] text-slate-500 block">Updated {{ $client->updated_at->diffForHumans() }}</span>
            </div>
        </div>

        <!-- Spec Grid -->
        <div class="relative z-10 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 p-4 sm:p-5 rounded-2xl bg-slate-950/60 border border-slate-800">
            <div>
                <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">Campaign Source</span>
                <span class="text-xs font-semibold text-slate-200 mt-0.5 block">{{ $client->campaign ?? 'Direct / Organic' }}</span>
                <span class="text-[11px] text-indigo-400 font-mono">Lead Generation</span>
            </div>

            <div>
                <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">Assigned BD Owner</span>
                <span class="text-xs font-semibold text-white mt-0.5 block">{{ $client->assignedTo?->name ?? 'Unassigned' }}</span>
                <span class="text-[11px] text-slate-400 font-mono">{{ $client->assignedTo?->email ?? 'Team Pool' }}</span>
            </div>

            <div>
                <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">Scheduled Meetings</span>
                <span class="text-xs font-semibold text-amber-300 mt-0.5 block">{{ $client->meetings->count() }} Sessions</span>
                <span class="text-[11px] text-slate-400">
                    {{ $client->upcomingMeeting ? 'Next: ' . $client->upcomingMeeting->start_time->format('M d') : 'No active calls' }}
                </span>
            </div>

            <div>
                <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">Reminder Alerts</span>
                <span class="text-xs font-semibold text-emerald-400 mt-0.5 block flex items-center gap-1.5">
                    <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
                    Reminder Engine Active
                </span>
                <span class="text-[11px] text-slate-500">15m / 1h In-App & Email</span>
            </div>
        </div>
    </div>

    <!-- Main Content Grid -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Left 2 Cols: Meetings & Progress Notes -->
        <div class="lg:col-span-2 space-y-6">

            <!-- SCHEDULED MEETINGS & REMINDERS SECTION -->
            <div class="bg-[#16191E]/95 border border-white/[0.08] rounded-3xl p-6 shadow-2xl space-y-4">
                <div class="flex items-center justify-between pb-3 border-b border-white/[0.08]">
                    <div class="flex items-center gap-2">
                        <div class="p-2 rounded-xl bg-amber-400/20 text-amber-300">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                        </div>
                        <div>
                            <h3 class="text-sm font-black text-white">Scheduled Meetings & Pitch Calls</h3>
                            <p class="text-xs text-slate-400">All sessions booked with {{ $client->company_name }} with automated reminders.</p>
                        </div>
                    </div>

                    <button @click="openScheduleModal = true"
                        class="btn-amber px-3 py-1.5 rounded-xl font-bold text-xs flex items-center gap-1 shadow-md shadow-amber-500/20 cursor-pointer">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"></path></svg>
                        <span>+ Schedule Call</span>
                    </button>
                </div>

                @if ($client->meetings->isEmpty())
                    <div class="py-12 text-center space-y-3 bg-slate-950/40 rounded-2xl border border-dashed border-slate-800">
                        <div class="w-10 h-10 rounded-2xl bg-amber-400/10 text-amber-300 flex items-center justify-center mx-auto">
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                        </div>
                        <h4 class="text-xs font-bold text-slate-300">No meetings scheduled with this client yet</h4>
                        <p class="text-[11px] text-slate-500 max-w-sm mx-auto">
                            Schedule a discovery call or product demo. Reminders will be armed automatically.
                        </p>
                        <button @click="openScheduleModal = true" class="btn-amber px-4 py-2 rounded-xl text-xs font-bold shadow-md">
                            Schedule First Call
                        </button>
                    </div>
                @else
                    <div class="space-y-3">
                        @foreach ($client->meetings as $meeting)
                            <div class="p-4 rounded-2xl bg-slate-950/70 border border-slate-800 hover:border-amber-500/30 transition-all space-y-3">
                                <div class="flex items-start justify-between gap-3">
                                    <div>
                                        <div class="flex items-center gap-2">
                                            <x-badge :variant="$meeting->status === 'scheduled' ? 'success' : 'default'" size="sm">
                                                {{ strtoupper($meeting->status) }}
                                            </x-badge>
                                            <span class="text-xs font-bold text-white">{{ $meeting->title }}</span>
                                        </div>
                                        <div class="text-[11px] text-indigo-400 font-mono mt-1">
                                            {{ $meeting->start_time->format('l, M d, Y • h:i A') }} &ndash; {{ $meeting->end_time->format('h:i A') }}
                                        </div>
                                    </div>

                                    <a href="{{ route('meetings.show', $meeting) }}"
                                        class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition-all">
                                        Open Workspace &rarr;
                                    </a>
                                </div>

                                <!-- Reminder & Join Strip -->
                                <div class="pt-2 border-t border-slate-800/80 flex flex-wrap items-center justify-between gap-2 text-xs">
                                    <div class="flex items-center gap-2 text-amber-400 font-semibold text-[11px]">
                                        <svg class="w-3.5 h-3.5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path></svg>
                                        <span>Automated Reminders Active (15m before)</span>
                                    </div>

                                    @if ($meeting->meeting_link)
                                        <a href="{{ $meeting->meeting_link }}" target="_blank"
                                            class="btn-amber px-3 py-1 rounded-lg text-xs font-bold flex items-center gap-1">
                                            <span>Join Call</span>
                                            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
                                        </a>
                                    @endif
                                </div>
                            </div>
                        @endforeach
                    </div>
                @endif
            </div>

            <!-- PROGRESS & SPREADSHEET NOTES SECTION -->
            <div class="bg-[#16191E]/95 border border-white/[0.08] rounded-3xl p-6 shadow-2xl space-y-4">
                <div class="flex items-center justify-between pb-3 border-b border-white/[0.08]">
                    <div class="flex items-center gap-2">
                        <div class="p-2 rounded-xl bg-emerald-500/20 text-emerald-300">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
                        </div>
                        <div>
                            <h3 class="text-sm font-black text-white">Progress Log & Next Steps</h3>
                            <p class="text-xs text-slate-400">Corresponds to the "Progress" column from your BD spreadsheet.</p>
                        </div>
                    </div>
                </div>

                <!-- Update Progress Form -->
                <form action="{{ route('clients.update', $client) }}" method="POST" class="space-y-3">
                    @csrf
                    @method('PUT')
                    <input type="hidden" name="company_name" value="{{ $client->company_name }}">
                    <input type="hidden" name="contact_name" value="{{ $client->contact_name }}">
                    <input type="hidden" name="contact_email" value="{{ $client->contact_email }}">
                    <input type="hidden" name="contact_phone" value="{{ $client->contact_phone }}">
                    <input type="hidden" name="contact_role" value="{{ $client->contact_role }}">
                    <input type="hidden" name="campaign" value="{{ $client->campaign }}">
                    <input type="hidden" name="status" value="{{ $client->status }}">
                    <input type="hidden" name="assigned_to" value="{{ $client->assigned_to }}">
                    <input type="hidden" name="deal_value" value="{{ $client->deal_value }}">

                    <textarea name="progress" rows="3" placeholder="Enter latest updates, feedback from pitch call, or next steps..."
                        class="w-full px-4 py-3 bg-slate-950 border border-slate-700/80 rounded-2xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">{{ $client->progress }}</textarea>

                    <div class="flex justify-end">
                        <button type="submit" class="btn-amber px-4 py-2 rounded-xl font-bold text-xs shadow-md shadow-amber-500/20">
                            Save Progress Update
                        </button>
                    </div>
                </form>
            </div>
        </div>

        <!-- Right 1 Col: Quick Info & Activity -->
        <div class="space-y-6">
            <!-- Point of Contact Card -->
            <div class="bg-[#16191E]/95 border border-white/[0.08] rounded-3xl p-6 shadow-2xl space-y-4">
                <h3 class="text-xs font-black uppercase tracking-wider text-slate-400">Point of Contact</h3>

                <div class="flex items-center gap-3">
                    <div class="w-12 h-12 rounded-2xl bg-gradient-to-tr from-amber-500 to-amber-700 flex items-center justify-center font-black text-slate-950 text-base shadow-lg shadow-amber-500/20">
                        {{ strtoupper(substr($client->contact_name, 0, 1)) }}
                    </div>
                    <div>
                        <div class="text-sm font-bold text-white">{{ $client->contact_name }}</div>
                        <div class="text-xs text-amber-400">{{ $client->contact_role ?? 'Representative' }}</div>
                        <div class="text-[11px] text-slate-400">{{ $client->company_name }}</div>
                    </div>
                </div>

                <div class="divide-y divide-white/[0.06] text-xs pt-2">
                    <div class="py-2.5 flex items-center justify-between">
                        <span class="text-slate-500">Email</span>
                        <span class="text-slate-200 font-mono">{{ $client->contact_email ?? 'Not set' }}</span>
                    </div>
                    <div class="py-2.5 flex items-center justify-between">
                        <span class="text-slate-500">Phone</span>
                        <span class="text-slate-200 font-mono">{{ $client->contact_phone ?? 'Not set' }}</span>
                    </div>
                    <div class="py-2.5 flex items-center justify-between">
                        <span class="text-slate-500">Campaign</span>
                        <span class="text-indigo-300 font-semibold">{{ $client->campaign ?? 'Direct' }}</span>
                    </div>
                    <div class="py-2.5 flex items-center justify-between">
                        <span class="text-slate-500">Added On</span>
                        <span class="text-slate-400 font-mono">{{ $client->created_at->format('M d, Y') }}</span>
                    </div>
                </div>
            </div>

            <!-- BD Owner Card -->
            <div class="bg-[#16191E]/95 border border-white/[0.08] rounded-3xl p-6 shadow-2xl space-y-3">
                <h3 class="text-xs font-black uppercase tracking-wider text-slate-400">Assigned BD Representative</h3>
                <div class="flex items-center gap-3">
                    <div class="w-9 h-9 rounded-xl bg-slate-800 text-slate-200 flex items-center justify-center font-bold text-xs border border-slate-700">
                        {{ strtoupper(substr($client->assignedTo?->name ?? 'U', 0, 1)) }}
                    </div>
                    <div>
                        <div class="text-xs font-bold text-white">{{ $client->assignedTo?->name ?? 'Unassigned' }}</div>
                        <div class="text-[11px] text-slate-400 font-mono">{{ $client->assignedTo?->email ?? 'Team Account' }}</div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- SCHEDULE MEETING MODAL -->
    <div x-show="openScheduleModal" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm">
        <div @click.outside="openScheduleModal = false"
            class="bg-[#16191E] border border-amber-500/30 rounded-3xl shadow-2xl max-w-lg w-full p-6 sm:p-8 space-y-6 max-h-[90vh] overflow-y-auto">

            <div class="flex items-center justify-between border-b border-white/[0.08] pb-4">
                <div>
                    <h3 class="text-base font-black text-white">Schedule Meeting with {{ $client->company_name }}</h3>
                    <p class="text-xs text-amber-300 font-medium mt-0.5">Contact: {{ $client->contact_name }} ({{ $client->contact_email }})</p>
                </div>
                <button @click="openScheduleModal = false" class="text-slate-400 hover:text-white p-1">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <form action="{{ route('clients.schedule-meeting', $client) }}" method="POST" class="space-y-4">
                @csrf

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Meeting Title *</label>
                    <input type="text" name="title" required value="Pitch & Demo Call: {{ $client->company_name }}"
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Start Date & Time *</label>
                        <input type="datetime-local" name="start_time" required
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">End Date & Time *</label>
                        <input type="datetime-local" name="end_time" required
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Meeting Type</label>
                        <select name="type"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 cursor-pointer">
                            <option value="virtual" selected>Virtual Conference</option>
                            <option value="in_person">In-Person</option>
                            <option value="hybrid">Hybrid</option>
                        </select>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-amber-400 block mb-1">🔔 Automated Reminders *</label>
                        <select name="reminder_minutes"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-amber-500/40 rounded-xl text-xs text-amber-300 focus:ring-2 focus:ring-amber-400 cursor-pointer">
                            <option value="15" selected>15 minutes before call</option>
                            <option value="30">30 minutes before call</option>
                            <option value="60">1 hour before call</option>
                            <option value="1440">1 day before call</option>
                        </select>
                    </div>
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Video Meeting Link (Google Meet / Zoom)</label>
                    <input type="url" name="meeting_link" placeholder="https://meet.google.com/xyz-abcd-efg"
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Session Agenda / Pitch Notes</label>
                    <textarea name="description" rows="2" placeholder="Topics to cover..."
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none"></textarea>
                </div>

                <div class="flex items-center justify-end gap-3 pt-3 border-t border-white/[0.08]">
                    <button type="button" @click="openScheduleModal = false" class="px-4 py-2 text-xs text-slate-400 hover:text-white">Cancel</button>
                    <button type="submit" class="btn-amber px-6 py-2.5 rounded-xl font-bold text-xs shadow-lg shadow-amber-500/20">
                        Confirm & Arm Reminders
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- EDIT CLIENT MODAL -->
    <div x-show="openEditModal" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm">
        <div @click.outside="openEditModal = false"
            class="bg-[#16191E] border border-amber-500/30 rounded-3xl shadow-2xl max-w-2xl w-full p-6 sm:p-8 space-y-6 max-h-[90vh] overflow-y-auto">

            <div class="flex items-center justify-between border-b border-white/[0.08] pb-4">
                <h3 class="text-lg font-black text-white">Edit Client Details</h3>
                <button @click="openEditModal = false" class="text-slate-400 hover:text-white p-1">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <form action="{{ route('clients.update', $client) }}" method="POST" class="space-y-4">
                @csrf
                @method('PUT')

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Company Name *</label>
                        <input type="text" name="company_name" required value="{{ $client->company_name }}"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Point of Contact Name *</label>
                        <input type="text" name="contact_name" required value="{{ $client->contact_name }}"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Contact Email</label>
                        <input type="email" name="contact_email" value="{{ $client->contact_email }}"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Contact Phone</label>
                        <input type="text" name="contact_phone" value="{{ $client->contact_phone }}"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Role / Position</label>
                        <input type="text" name="contact_role" value="{{ $client->contact_role }}"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Campaign</label>
                        <input type="text" name="campaign" value="{{ $client->campaign }}"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Status (Stage) *</label>
                        <select name="status" required
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 cursor-pointer">
                            @foreach (\App\Models\Client::STATUSES as $statusKey => $meta)
                                <option value="{{ $statusKey }}" {{ $client->status === $statusKey ? 'selected' : '' }}>{{ $meta['label'] }}</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Assigned BD Rep</label>
                        <select name="assigned_to"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 cursor-pointer">
                            @foreach ($bdUsers as $u)
                                <option value="{{ $u->id }}" {{ $client->assigned_to == $u->id ? 'selected' : '' }}>{{ $u->name }}</option>
                            @endforeach
                        </select>
                    </div>
                </div>

                <div class="flex items-center justify-end gap-3 pt-4 border-t border-white/[0.08]">
                    <button type="button" @click="openEditModal = false" class="px-4 py-2 text-xs text-slate-400 hover:text-white">Cancel</button>
                    <button type="submit" class="btn-amber px-6 py-2.5 rounded-xl font-bold text-xs shadow-lg shadow-amber-500/20">
                        Update Client
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection
