@extends('layouts.app')

@section('title', $meeting->title . ' — Meeting Workspace')

@section('content')
<div class="max-w-7xl mx-auto space-y-8" x-data="{
    activeTab: 'workspace', // workspace, notes, tasks, history
    openNewTaskModal: false,
    openNewNoteModal: false,
    editNoteModalOpen: false,
    editNoteData: {
        id: null,
        agenda: '',
        discussion: '',
        decisions: '',
        action_items: '',
        follow_up_date: '',
        attachments_text: ''
    },
    openEditNote(note) {
        this.editNoteData = {
            id: note.id,
            agenda: note.agenda || '',
            discussion: note.discussion || '',
            decisions: note.decisions || '',
            action_items: note.action_items || '',
            follow_up_date: note.follow_up_date ? note.follow_up_date.substring(0, 16) : '',
            attachments_text: (note.attachments || []).map(a => a.url || a.text || a.name).join('\n')
        };
        this.editNoteModalOpen = true;
    }
}">

    <!-- Top Action Bar -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <a href="{{ route('meetings.index') }}" class="text-xs text-slate-400 hover:text-white flex items-center gap-1.5 font-medium transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path></svg>
            <span>Back to Meetings Listing</span>
        </a>

        @if ($canManage)
            <div class="flex items-center gap-2">
                @if ($meeting->status === 'scheduled')
                    <form action="{{ route('meetings.cancel', $meeting) }}" method="POST" onsubmit="return confirm('Cancel this meeting and notify all attendees?');">
                        @csrf
                        @method('PATCH')
                        <button type="submit" class="px-3.5 py-2 rounded-xl bg-amber-950/60 hover:bg-amber-900/60 border border-amber-800/60 text-amber-300 text-xs font-semibold transition-all cursor-pointer">
                            Cancel Meeting
                        </button>
                    </form>
                @endif

                <a href="{{ route('meetings.edit', $meeting) }}"
                    class="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-semibold transition-all flex items-center gap-1.5">
                    <svg class="w-3.5 h-3.5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
                    <span>Edit Meeting</span>
                </a>

                <form action="{{ route('meetings.destroy', $meeting) }}" method="POST" onsubmit="return confirm('Delete this meeting session?');">
                    @csrf
                    @method('DELETE')
                    <button type="submit" class="p-2 rounded-xl bg-rose-950/60 hover:bg-rose-900/60 border border-rose-800/60 text-rose-300 transition-all cursor-pointer" title="Delete Meeting">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                    </button>
                </form>
            </div>
        @endif
    </div>

    <!-- Flash Alert -->
    @if (session('success'))
        <div class="p-4 rounded-xl bg-emerald-950/60 border border-emerald-500/30 text-emerald-300 text-sm flex items-center gap-3">
            <svg class="w-5 h-5 text-emerald-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <span>{{ session('success') }}</span>
        </div>
    @endif

    <!-- Meeting Workspace Hero / Header -->
    <div class="relative overflow-hidden rounded-3xl glass-panel border border-amber-500/20 p-6 sm:p-8 shadow-2xl shadow-black/50 space-y-6">
        <div class="absolute -right-20 -top-20 w-80 h-80 bg-amber-500/10 rounded-full blur-3xl pointer-events-none"></div>

        <div class="relative z-10 space-y-3">
            <div class="flex flex-wrap items-center gap-2">
                <x-badge :variant="$meeting->status === 'scheduled' ? 'success' : ($meeting->status === 'cancelled' ? 'danger' : 'default')" size="sm">
                    {{ strtoupper($meeting->status) }}
                </x-badge>
                <span class="px-2.5 py-0.5 rounded-full text-xs font-bold uppercase tracking-wider bg-slate-800 text-slate-300 border border-slate-700">
                    {{ str_replace('_', ' ', $meeting->type) }}
                </span>
                @if ($meeting->metadata && isset($meeting->metadata['is_client_meeting']) && $meeting->metadata['is_client_meeting'])
                    <x-badge variant="purple" size="sm">
                        External Client Review &bull; {{ $meeting->metadata['client_company'] ?? 'Partner' }}
                    </x-badge>
                @endif
                @if ($meeting->department)
                    <span class="text-xs text-indigo-400 font-medium">{{ $meeting->department->name }}</span>
                @endif
            </div>

            <h1 class="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
                {{ $meeting->title }}
            </h1>

            @if ($meeting->description)
                <p class="text-xs sm:text-sm text-slate-300 leading-relaxed max-w-3xl">
                    {{ $meeting->description }}
                </p>
            @endif
        </div>

        <!-- Schedule & Location Spec Grid -->
        <div class="relative z-10 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 p-4 sm:p-5 rounded-2xl bg-slate-950/60 border border-slate-800">
            <div>
                <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">Date & Time</span>
                <span class="text-xs font-semibold text-slate-200 mt-0.5 block">
                    {{ $meeting->start_time->format('l, M d, Y') }}
                </span>
                <span class="text-[11px] text-indigo-400 font-mono">
                    {{ $meeting->start_time->format('h:i A') }} &ndash; {{ $meeting->end_time->format('h:i A') }} ({{ $meeting->timezone }})
                </span>
            </div>

            <div>
                <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">Meeting Channel</span>
                <span class="text-xs font-semibold text-white mt-0.5 block flex items-center gap-1.5">
                    <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
                    {{ $meeting->type === 'virtual' ? 'Virtual Call' : ucfirst($meeting->type) }}
                </span>
                <span class="text-[11px] text-indigo-400 font-mono">
                    {{ $meeting->meeting_link ? 'Direct Link Ready' : 'Online Session' }}
                </span>
            </div>

            <div>
                <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">Host / Organizer</span>
                <span class="text-xs font-semibold text-white mt-0.5 block">{{ $meeting->organizer->name }}</span>
                <span class="text-[11px] text-slate-400 font-mono">{{ $meeting->organizer->email }}</span>
            </div>

            <div>
                <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block">Workspace Scope</span>
                <span class="text-xs font-semibold text-slate-300 mt-0.5 block">
                    {{ $meeting->is_private ? 'Confidential / Private' : 'Open Workspace' }}
                </span>
                <span class="text-[11px] text-slate-500">
                    {{ $meeting->recurrence ? ucfirst($meeting->recurrence['frequency']) : 'Single Session' }}
                </span>
            </div>
        </div>

        <!-- Video Call Banner -->
        @if ($meeting->meeting_link)
            <div class="relative z-10 flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 rounded-2xl bg-gradient-to-r from-indigo-950/60 to-purple-950/40 border border-indigo-500/30">
                <div class="flex items-center gap-3">
                    <div class="p-2 rounded-xl bg-indigo-600/30 text-indigo-300 shrink-0">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg>
                    </div>
                    <div class="min-w-0">
                        <div class="text-xs font-bold text-white">Video Conference Room Active</div>
                        <div class="text-xs text-indigo-300 font-mono truncate max-w-md">{{ $meeting->meeting_link }}</div>
                    </div>
                </div>
                <a href="{{ $meeting->meeting_link }}" target="_blank"
                    class="btn-amber px-5 py-2.5 rounded-xl font-bold text-xs text-center shrink-0">
                    Join Video Conference &rarr;
                </a>
            </div>
        @endif
    </div>

    <!-- Workspace Tab Navigation -->
    <div class="flex items-center gap-2 border-b border-amber-500/20 pb-2">
        <button @click="activeTab = 'workspace'"
            class="px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer"
            :class="activeTab === 'workspace' ? 'bg-amber-400 text-slate-950 font-extrabold shadow-md shadow-amber-500/20' : 'text-slate-400 hover:text-white hover:bg-slate-800/60'">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path></svg>
            <span>Overview & Participants</span>
        </button>

        <button @click="activeTab = 'notes'"
            class="px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer"
            :class="activeTab === 'notes' ? 'bg-amber-400 text-slate-950 font-extrabold shadow-md shadow-amber-500/20' : 'text-slate-400 hover:text-white hover:bg-slate-800/60'">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
            <span>Meeting Notes & Agendas ({{ $meeting->notes->count() }})</span>
        </button>

        <button @click="activeTab = 'tasks'"
            class="px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer"
            :class="activeTab === 'tasks' ? 'bg-amber-400 text-slate-950 font-extrabold shadow-md shadow-amber-500/20' : 'text-slate-400 hover:text-white hover:bg-slate-800/60'">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path></svg>
            <span>Action Items & Tasks ({{ $meeting->tasks->count() }})</span>
        </button>

        <button @click="activeTab = 'history'"
            class="px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer"
            :class="activeTab === 'history' ? 'bg-amber-400 text-slate-950 font-extrabold shadow-md shadow-amber-500/20' : 'text-slate-400 hover:text-white hover:bg-slate-800/60'">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <span>Activity History</span>
        </button>
    </div>

    <!-- TAB 1: OVERVIEW & PARTICIPANTS -->
    <div x-show="activeTab === 'workspace'" class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Left: RSVP & Participant Roster (2 Cols) -->
        <div class="lg:col-span-2 space-y-6">
            <!-- RSVP Box -->
            <x-card title="Your RSVP Response" description="Confirm your attendance with the meeting organizer">
                @php
                    $myParticipantRecord = $meeting->participants->where('id', auth()->id())->first();
                    $currentStatus = $myParticipantRecord ? $myParticipantRecord->pivot->status : 'none';
                @endphp

                <form action="{{ route('meetings.rsvp', $meeting) }}" method="POST" class="space-y-4">
                    @csrf
                    <div class="grid grid-cols-3 gap-3">
                        <label class="p-3 rounded-xl border flex items-center justify-center gap-2 cursor-pointer transition-all {{ $currentStatus === 'accepted' ? 'bg-emerald-950/40 border-emerald-500 text-emerald-300 ring-1 ring-emerald-500' : 'bg-slate-950/40 border-slate-800 text-slate-400 hover:border-slate-700' }}">
                            <input type="radio" name="status" value="accepted" {{ $currentStatus === 'accepted' ? 'checked' : '' }} class="sr-only">
                            <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                            <span class="text-xs font-bold">Accept</span>
                        </label>

                        <label class="p-3 rounded-xl border flex items-center justify-center gap-2 cursor-pointer transition-all {{ $currentStatus === 'tentative' ? 'bg-amber-950/40 border-amber-500 text-amber-300 ring-1 ring-amber-500' : 'bg-slate-950/40 border-slate-800 text-slate-400 hover:border-slate-700' }}">
                            <input type="radio" name="status" value="tentative" {{ $currentStatus === 'tentative' ? 'checked' : '' }} class="sr-only">
                            <svg class="w-4 h-4 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                            <span class="text-xs font-bold">Tentative</span>
                        </label>

                        <label class="p-3 rounded-xl border flex items-center justify-center gap-2 cursor-pointer transition-all {{ $currentStatus === 'declined' ? 'bg-rose-950/40 border-rose-500 text-rose-300 ring-1 ring-rose-500' : 'bg-slate-950/40 border-slate-800 text-slate-400 hover:border-slate-700' }}">
                            <input type="radio" name="status" value="declined" {{ $currentStatus === 'declined' ? 'checked' : '' }} class="sr-only">
                            <svg class="w-4 h-4 text-rose-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                            <span class="text-xs font-bold">Decline</span>
                        </label>
                    </div>

                    <div>
                        <input type="text" name="response_notes" placeholder="Optional RSVP note to the organizer..." value="{{ $myParticipantRecord?->pivot?->response_notes }}"
                            class="w-full px-4 py-2 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                    </div>

                    <div class="flex justify-end">
                        <button type="submit" class="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold shadow-md shadow-indigo-600/20 cursor-pointer">
                            Update RSVP Status
                        </button>
                    </div>
                </form>
            </x-card>

            <!-- Participant Roster -->
            <x-card title="Invited Participants ({{ $meeting->participants->count() }})" description="Live attendance and response status">
                <div class="divide-y divide-slate-800/80">
                    @foreach ($meeting->participants as $p)
                        <div class="py-3.5 first:pt-0 last:pb-0 flex items-center justify-between">
                            <div class="flex items-center gap-3">
                                <div class="w-9 h-9 rounded-xl bg-gradient-to-tr from-indigo-500 to-purple-600 flex items-center justify-center font-bold text-white text-xs">
                                    {{ strtoupper(substr($p->name, 0, 1)) }}
                                </div>
                                <div>
                                    <div class="text-xs font-bold text-slate-200">{{ $p->name }}</div>
                                    <div class="text-[11px] text-slate-500 font-mono">{{ $p->email }} &bull; <span class="capitalize">{{ $p->pivot->role }}</span></div>
                                    @if ($p->pivot->response_notes)
                                        <div class="text-[11px] text-slate-400 italic mt-0.5">"{{ $p->pivot->response_notes }}"</div>
                                    @endif
                                </div>
                            </div>

                            <div>
                                <x-badge :variant="$p->pivot->status === 'accepted' ? 'success' : ($p->pivot->status === 'declined' ? 'danger' : 'warning')" size="sm">
                                    {{ ucfirst($p->pivot->status) }}
                                </x-badge>
                            </div>
                        </div>
                    @endforeach
                </div>
            </x-card>
        </div>

        <!-- Right: Recent Notes & Tasks Summary (1 Col) -->
        <div class="space-y-6">
            <!-- Latest Meeting Notes Card -->
            <x-card title="Meeting Notes Summary" description="Key takeaways and decisions">
                <x-slot:action>
                    <button @click="activeTab = 'notes'" class="text-xs text-indigo-400 hover:text-indigo-300 font-semibold">View All &rarr;</button>
                </x-slot:action>

                @if ($meeting->notes->isEmpty())
                    <div class="py-6 text-center space-y-2">
                        <p class="text-xs text-slate-500">No meeting notes recorded yet.</p>
                        <button @click="openNewNoteModal = true" class="px-3 py-1.5 rounded-lg bg-indigo-600/20 text-indigo-300 hover:bg-indigo-600/30 text-xs font-semibold">
                            + Add First Note
                        </button>
                    </div>
                @else
                    <div class="space-y-3">
                        @foreach ($meeting->notes->take(2) as $note)
                            <div class="p-3.5 rounded-xl bg-slate-950/60 border border-slate-800 space-y-2">
                                <div class="flex items-center justify-between text-[11px]">
                                    <span class="font-bold text-slate-300">{{ $note->author->name }}</span>
                                    <span class="text-slate-500 font-mono">{{ $note->created_at->diffForHumans() }}</span>
                                </div>
                                @if ($note->agenda)
                                    <div>
                                        <span class="text-[10px] font-bold uppercase text-slate-500 block">Agenda</span>
                                        <p class="text-xs text-slate-300 line-clamp-2">{{ $note->agenda }}</p>
                                    </div>
                                @endif
                                @if ($note->decisions)
                                    <div>
                                        <span class="text-[10px] font-bold uppercase text-emerald-400 block">Decisions</span>
                                        <p class="text-xs text-slate-300 line-clamp-2">{{ $note->decisions }}</p>
                                    </div>
                                @endif
                            </div>
                        @endforeach
                    </div>
                @endif
            </x-card>

            <!-- Tasks Summary Card -->
            <x-card title="Assigned Action Items" description="Deliverables from this session">
                <x-slot:action>
                    <button @click="activeTab = 'tasks'" class="text-xs text-indigo-400 hover:text-indigo-300 font-semibold">Manage &rarr;</button>
                </x-slot:action>

                @if ($meeting->tasks->isEmpty())
                    <div class="py-6 text-center space-y-2">
                        <p class="text-xs text-slate-500">No action items assigned.</p>
                        <button @click="openNewTaskModal = true" class="px-3 py-1.5 rounded-lg bg-indigo-600/20 text-indigo-300 hover:bg-indigo-600/30 text-xs font-semibold">
                            + Add Action Item
                        </button>
                    </div>
                @else
                    <div class="space-y-2.5">
                        @foreach ($meeting->tasks->take(3) as $task)
                            <div class="p-3 rounded-xl bg-slate-950/60 border border-slate-800 space-y-1.5">
                                <div class="flex items-center justify-between text-[10px]">
                                    <x-badge :variant="$task->priority === 'high' || $task->priority === 'urgent' ? 'danger' : 'warning'" size="sm">
                                        {{ strtoupper($task->priority) }}
                                    </x-badge>
                                    <span class="text-slate-400 font-mono">{{ $task->due_date ? $task->due_date->format('M d') : 'No due date' }}</span>
                                </div>
                                <h5 class="text-xs font-bold text-slate-200">{{ $task->title }}</h5>
                                <div class="text-[11px] text-slate-400 flex items-center justify-between pt-1 border-t border-slate-800/80">
                                    <span>Assignee: <span class="text-slate-300">{{ $task->assignee?->name ?? 'Unassigned' }}</span></span>
                                    <span class="capitalize text-slate-400">{{ str_replace('_', ' ', $task->status) }}</span>
                                </div>
                            </div>
                        @endforeach
                    </div>
                @endif
            </x-card>
        </div>
    </div>

    <!-- TAB 2: MEETING NOTES & STRUCTURED AGENDAS -->
    <div x-show="activeTab === 'notes'" class="space-y-6" x-cloak>
        <div class="flex items-center justify-between bg-slate-900/60 border border-slate-800/80 p-4 rounded-2xl">
            <div class="space-y-0.5">
                <h3 class="text-sm font-bold text-white">Meeting Minutes & Notes Hub</h3>
                <p class="text-xs text-slate-400">Structured documentation of meeting agenda, discussion topics, agreed decisions and follow-up milestones.</p>
            </div>
            <button @click="openNewNoteModal = true"
                class="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-lg shadow-indigo-600/30 flex items-center gap-1.5 cursor-pointer">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
                <span>Record New Note</span>
            </button>
        </div>

        <!-- Notes Feed -->
        <div class="space-y-6">
            @forelse ($meeting->notes as $note)
                <div class="bg-slate-900/80 border border-slate-800/90 rounded-2xl p-6 shadow-xl space-y-5">
                    <!-- Note Header -->
                    <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                        <div class="flex items-center gap-3">
                            <div class="w-8 h-8 rounded-full bg-gradient-to-tr from-indigo-500 to-purple-600 flex items-center justify-center font-bold text-white text-xs">
                                {{ strtoupper(substr($note->author->name, 0, 1)) }}
                            </div>
                            <div>
                                <h4 class="text-xs font-bold text-white">{{ $note->author->name }}</h4>
                                <span class="text-[10px] text-slate-500 font-mono">{{ $note->created_at->format('M d, Y • h:i A') }} ({{ $note->created_at->diffForHumans() }})</span>
                            </div>
                        </div>

                        <div class="flex items-center gap-2">
                            @if ($note->follow_up_date)
                                <span class="px-2.5 py-1 rounded-lg bg-amber-500/15 border border-amber-500/30 text-amber-300 text-xs font-medium flex items-center gap-1.5">
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                                    <span>Follow-up: {{ $note->follow_up_date->format('M d, Y') }}</span>
                                </span>
                            @endif

                            @if ($canManage || $note->user_id === auth()->id())
                                <button @click="openEditNote({{ Js::from($note) }})"
                                    class="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer" title="Edit Note">
                                    <svg class="w-3.5 h-3.5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
                                </button>

                                <form action="{{ route('meetings.notes.destroy', $note) }}" method="POST" onsubmit="return confirm('Delete this meeting note?');">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="p-1.5 rounded-lg bg-slate-800 hover:bg-rose-950/40 text-slate-400 hover:text-rose-400 transition-colors cursor-pointer" title="Delete Note">
                                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                                    </button>
                                </form>
                            @endif
                        </div>
                    </div>

                    <!-- Note Grid: Agenda, Discussion, Decisions, Actions -->
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        @if ($note->agenda)
                            <div class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 space-y-1.5">
                                <span class="text-[10px] font-bold uppercase tracking-wider text-indigo-400 flex items-center gap-1.5">
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path></svg>
                                    <span>Meeting Agenda</span>
                                </span>
                                <p class="text-xs text-slate-300 whitespace-pre-line leading-relaxed">{{ $note->agenda }}</p>
                            </div>
                        @endif

                        @if ($note->discussion)
                            <div class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 space-y-1.5">
                                <span class="text-[10px] font-bold uppercase tracking-wider text-sky-400 flex items-center gap-1.5">
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path></svg>
                                    <span>Key Discussion Points</span>
                                </span>
                                <p class="text-xs text-slate-300 whitespace-pre-line leading-relaxed">{{ $note->discussion }}</p>
                            </div>
                        @endif

                        @if ($note->decisions)
                            <div class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 space-y-1.5">
                                <span class="text-[10px] font-bold uppercase tracking-wider text-emerald-400 flex items-center gap-1.5">
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                                    <span>Decisions Made</span>
                                </span>
                                <p class="text-xs text-slate-300 whitespace-pre-line leading-relaxed">{{ $note->decisions }}</p>
                            </div>
                        @endif

                        @if ($note->action_items)
                            <div class="p-4 rounded-xl bg-slate-950/60 border border-slate-800 space-y-1.5">
                                <span class="text-[10px] font-bold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path></svg>
                                    <span>Agreed Action Items Summary</span>
                                </span>
                                <p class="text-xs text-slate-300 whitespace-pre-line leading-relaxed">{{ $note->action_items }}</p>
                            </div>
                        @endif
                    </div>

                    <!-- Linked Attachments & Documents -->
                    @if (!empty($note->attachments))
                        <div class="pt-3 border-t border-slate-800/80 space-y-2">
                            <span class="text-[10px] font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"></path></svg>
                                <span>Attached Resources & Document Links</span>
                            </span>
                            <div class="flex flex-wrap gap-2">
                                @foreach ($note->attachments as $att)
                                    @if (!empty($att['url']))
                                        <a href="{{ $att['url'] }}" target="_blank"
                                            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-indigo-950/40 hover:bg-indigo-900/50 border border-indigo-500/30 text-indigo-300 text-xs font-medium transition-all">
                                            <span>{{ $att['name'] ?? $att['url'] }}</span>
                                            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
                                        </a>
                                    @else
                                        <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-800 text-slate-300 text-xs font-medium border border-slate-700">
                                            {{ $att['text'] ?? $att['name'] }}
                                        </span>
                                    @endif
                                @endforeach
                            </div>
                        </div>
                    @endif
                </div>
            @empty
                <div class="py-16 text-center space-y-3 bg-slate-900/30 rounded-2xl border border-slate-800/80">
                    <div class="inline-flex p-4 rounded-2xl bg-slate-800/60 text-slate-500">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
                    </div>
                    <h4 class="text-sm font-bold text-slate-300">No meeting notes recorded</h4>
                    <p class="text-xs text-slate-500 max-w-sm mx-auto">
                        Document session decisions, review items, agendas, and linked documentation for the entire team.
                    </p>
                    <button @click="openNewNoteModal = true" class="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold shadow-md">
                        + Record Minutes
                    </button>
                </div>
            @endforelse
        </div>
    </div>

    <!-- TAB 3: ACTION ITEMS & TASKS -->
    <div x-show="activeTab === 'tasks'" class="space-y-6" x-cloak>
        <div class="flex items-center justify-between bg-slate-900/60 border border-slate-800/80 p-4 rounded-2xl">
            <div class="space-y-0.5">
                <h3 class="text-sm font-bold text-white">Meeting Action Items & Deliverables</h3>
                <p class="text-xs text-slate-400">Track assigned items derived from this meeting with real-time status transitions and priority levels.</p>
            </div>
            <button @click="openNewTaskModal = true"
                class="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-lg shadow-indigo-600/30 flex items-center gap-1.5 cursor-pointer">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
                <span>Add Action Item</span>
            </button>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            @forelse ($meeting->tasks as $t)
                @php
                    $isDone = $t->status === 'completed';
                    $statusVariant = match ($t->status) {
                        'completed' => 'success',
                        'in_progress' => 'info',
                        default => 'warning',
                    };
                @endphp
                <div class="bg-slate-900/80 border border-slate-800/90 rounded-2xl p-4 sm:p-5 shadow-xl space-y-3 flex flex-col justify-between {{ $isDone ? 'opacity-70 bg-slate-950/40' : '' }}">
                    <div class="space-y-2">
                        <div class="flex items-center justify-between">
                            <x-badge :variant="$t->priority === 'high' || $t->priority === 'urgent' ? 'danger' : ($t->priority === 'medium' ? 'warning' : 'default')" size="sm">
                                {{ strtoupper($t->priority) }}
                            </x-badge>
                            <x-badge :variant="$statusVariant" size="sm">
                                {{ ucfirst(str_replace('_', ' ', $t->status)) }}
                            </x-badge>
                        </div>

                        <h4 class="text-sm font-bold text-white leading-snug {{ $isDone ? 'line-through text-slate-400' : '' }}">
                            {{ $t->title }}
                        </h4>

                        @if ($t->description)
                            <p class="text-xs text-slate-400 line-clamp-2 leading-relaxed">{{ $t->description }}</p>
                        @endif

                        <div class="text-[11px] text-slate-400 space-y-1 pt-1">
                            <div class="flex items-center justify-between">
                                <span>Assignee:</span>
                                <span class="text-slate-200 font-semibold">{{ $t->assignee?->name ?? 'Unassigned' }}</span>
                            </div>
                            <div class="flex items-center justify-between">
                                <span>Due Date:</span>
                                <span class="font-mono {{ $t->due_date && $t->due_date->isPast() && !$isDone ? 'text-rose-400 font-bold' : 'text-slate-300' }}">
                                    {{ $t->due_date ? $t->due_date->format('M d, Y') : 'None set' }}
                                </span>
                            </div>
                        </div>
                    </div>

                    <!-- Task Status Action Dropdown/Buttons -->
                    <div class="pt-3 border-t border-slate-800/80 flex items-center justify-between gap-2">
                        <form action="{{ route('tasks.update-status', $t) }}" method="POST" class="flex items-center gap-1.5 w-full">
                            @csrf
                            @method('PATCH')
                            <select name="status" onchange="this.form.submit()"
                                class="w-full px-2 py-1.5 rounded-lg bg-slate-950 border border-slate-700 text-xs text-slate-200 focus:ring-2 focus:ring-indigo-500 cursor-pointer">
                                <option value="todo" {{ $t->status === 'todo' ? 'selected' : '' }}>Pending / To Do</option>
                                <option value="in_progress" {{ $t->status === 'in_progress' ? 'selected' : '' }}>In Progress</option>
                                <option value="completed" {{ $t->status === 'completed' ? 'selected' : '' }}>Completed</option>
                            </select>
                        </form>
                    </div>
                </div>
            @empty
                <div class="col-span-full py-16 text-center space-y-3 bg-slate-900/30 rounded-2xl border border-slate-800/80">
                    <div class="inline-flex p-4 rounded-2xl bg-slate-800/60 text-slate-500">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path></svg>
                    </div>
                    <h4 class="text-sm font-bold text-slate-300">No action items assigned</h4>
                    <p class="text-xs text-slate-500 max-w-sm mx-auto">
                        Delegate follow-up tasks to meeting attendees with assigned priorities and due dates.
                    </p>
                    <button @click="openNewTaskModal = true" class="px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold shadow-md">
                        + Add Action Item
                    </button>
                </div>
            @endforelse
        </div>
    </div>

    <!-- TAB 4: AUDIT ACTIVITY HISTORY -->
    <div x-show="activeTab === 'history'" class="space-y-6" x-cloak>
        <x-card title="Meeting Audit Trail & Event Timeline" description="Complete chronological history of edits, RSVPs, note updates and task creation">
            <div class="space-y-4">
                @forelse ($meeting->auditLogs->sortByDesc('created_at') as $audit)
                    <div class="flex items-start gap-3 text-xs p-3 rounded-xl bg-slate-950/40 border border-slate-800/80">
                        <div class="w-2 h-2 rounded-full bg-indigo-400 mt-1.5 shrink-0"></div>
                        <div class="flex-1 min-w-0">
                            <p class="text-slate-200 font-medium leading-relaxed">{{ $audit->description }}</p>
                            <div class="text-[10px] text-slate-500 font-mono mt-0.5 flex items-center gap-2">
                                <span>{{ $audit->created_at->diffForHumans() }}</span>
                                <span>&bull;</span>
                                <span>Actor: {{ $audit->user?->name ?? 'System' }}</span>
                            </div>
                        </div>
                    </div>
                @empty
                    <div class="py-8 text-center text-xs text-slate-500">
                        No activity records logged for this session yet.
                    </div>
                @endforelse
            </div>
        </x-card>
    </div>

    <!-- MODAL 1: ADD MEETING NOTE -->
    <div x-show="openNewNoteModal" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">
        
        <div @click.outside="openNewNoteModal = false"
            class="bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl max-w-2xl w-full p-6 space-y-5 overflow-hidden max-h-[90vh] overflow-y-auto">
            
            <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                <h3 class="text-base font-bold text-white">Record Meeting Minutes & Agendas</h3>
                <button @click="openNewNoteModal = false" class="text-slate-400 hover:text-white">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <form action="{{ route('meetings.notes.store', $meeting) }}" method="POST" class="space-y-4">
                @csrf
                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Session Agenda Topics</label>
                    <textarea name="agenda" rows="2" placeholder="Topics scheduled to be covered during this meeting..."
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Discussion Notes</label>
                    <textarea name="discussion" rows="3" placeholder="Key arguments, architecture questions, updates from squads..."
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Key Decisions Made</label>
                        <textarea name="decisions" rows="2" placeholder="Agreed architectural or business decisions..."
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Action Items Summary</label>
                        <textarea name="action_items" rows="2" placeholder="High-level team takeaways..."
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                    </div>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Follow-up Review Date</label>
                        <input type="datetime-local" name="follow_up_date"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Attachments / Resource URLs (one per line)</label>
                        <textarea name="attachments_text" rows="2" placeholder="https://docs.schedio.com/arch-q4&#10;https://figma.com/file/xyz"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                    </div>
                </div>

                <div class="flex justify-end gap-3 pt-3 border-t border-slate-800">
                    <button type="button" @click="openNewNoteModal = false"
                        class="px-4 py-2 rounded-xl text-xs text-slate-400 hover:text-white">Cancel</button>
                    <button type="submit"
                        class="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-lg shadow-indigo-600/30">
                        Save Meeting Notes
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 2: EDIT MEETING NOTE -->
    <div x-show="editNoteModalOpen" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">
        
        <div @click.outside="editNoteModalOpen = false"
            class="bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl max-w-2xl w-full p-6 space-y-5 overflow-hidden max-h-[90vh] overflow-y-auto">
            
            <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                <h3 class="text-base font-bold text-white">Edit Meeting Notes</h3>
                <button @click="editNoteModalOpen = false" class="text-slate-400 hover:text-white">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <form :action="`/meeting-notes/${editNoteData.id}`" method="POST" class="space-y-4">
                @csrf
                @method('PUT')

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Session Agenda Topics</label>
                    <textarea name="agenda" rows="2" x-model="editNoteData.agenda"
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Discussion Notes</label>
                    <textarea name="discussion" rows="3" x-model="editNoteData.discussion"
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Key Decisions Made</label>
                        <textarea name="decisions" rows="2" x-model="editNoteData.decisions"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Action Items Summary</label>
                        <textarea name="action_items" rows="2" x-model="editNoteData.action_items"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                    </div>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Follow-up Review Date</label>
                        <input type="datetime-local" name="follow_up_date" x-model="editNoteData.follow_up_date"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Attachments / URLs</label>
                        <textarea name="attachments_text" rows="2" x-model="editNoteData.attachments_text"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                    </div>
                </div>

                <div class="flex justify-end gap-3 pt-3 border-t border-slate-800">
                    <button type="button" @click="editNoteModalOpen = false"
                        class="px-4 py-2 rounded-xl text-xs text-slate-400 hover:text-white">Cancel</button>
                    <button type="submit"
                        class="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-lg shadow-indigo-600/30">
                        Update Notes
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 3: ADD ACTION ITEM / TASK -->
    <div x-show="openNewTaskModal" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">
        
        <div @click.outside="openNewTaskModal = false"
            class="bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl max-w-lg w-full p-6 space-y-5 overflow-hidden">
            
            <div class="flex items-center justify-between border-b border-slate-800 pb-3">
                <h3 class="text-base font-bold text-white">Add Follow-up Action Item</h3>
                <button @click="openNewTaskModal = false" class="text-slate-400 hover:text-white">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <form action="{{ route('tasks.store') }}" method="POST" class="space-y-4">
                @csrf
                <input type="hidden" name="meeting_id" value="{{ $meeting->id }}">
                <input type="hidden" name="department_id" value="{{ $meeting->department_id }}">

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Task Title *</label>
                    <input type="text" name="title" required placeholder="e.g. Conduct benchmark stress testing on partitioned queries"
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                </div>

                <div class="grid grid-cols-2 gap-3">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Assignee</label>
                        <select name="assigned_to"
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                            <option value="">Unassigned</option>
                            @foreach ($meeting->participants as $p)
                                <option value="{{ $p->id }}">{{ $p->name }} ({{ $p->email }})</option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Priority *</label>
                        <select name="priority" required
                            class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                            <option value="medium" selected>Medium</option>
                            <option value="high">High</option>
                            <option value="urgent">Urgent</option>
                            <option value="low">Low</option>
                        </select>
                    </div>
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Target Due Date</label>
                    <input type="datetime-local" name="due_date"
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Description / Deliverable Criteria</label>
                    <textarea name="description" rows="3" placeholder="Context, criteria for completion, links..."
                        class="w-full px-3 py-2 bg-slate-950 border border-slate-700 rounded-xl text-xs text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"></textarea>
                </div>

                <div class="flex justify-end gap-3 pt-3 border-t border-slate-800">
                    <button type="button" @click="openNewTaskModal = false"
                        class="px-4 py-2 rounded-xl text-xs text-slate-400 hover:text-white">Cancel</button>
                    <button type="submit"
                        class="px-5 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-lg shadow-indigo-600/30">
                        Create Action Item
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection
