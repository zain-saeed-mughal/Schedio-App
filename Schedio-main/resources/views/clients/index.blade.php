@extends('layouts.app')

@section('title', 'Business Development Pipeline — Schedio Enterprise CRM')

@section('content')
<style>
    /* Custom sleek scrollbar for horizontal Kanban board */
    .kanban-scrollbar::-webkit-scrollbar {
        height: 7px;
        width: 7px;
    }
    .kanban-scrollbar::-webkit-scrollbar-track {
        background: rgba(15, 23, 42, 0.6);
        border-radius: 9999px;
    }
    .kanban-scrollbar::-webkit-scrollbar-thumb {
        background: rgba(148, 163, 184, 0.25);
        border-radius: 9999px;
    }
    .kanban-scrollbar::-webkit-scrollbar-thumb:hover {
        background: rgba(245, 158, 11, 0.7);
    }
    .kanban-column-scroll::-webkit-scrollbar {
        width: 4px;
    }
    .kanban-column-scroll::-webkit-scrollbar-track {
        background: transparent;
    }
    .kanban-column-scroll::-webkit-scrollbar-thumb {
        background: rgba(255, 255, 255, 0.1);
        border-radius: 9999px;
    }
    .kanban-column-scroll::-webkit-scrollbar-thumb:hover {
        background: rgba(245, 158, 11, 0.5);
    }
</style>

<div class="w-full max-w-[1700px] mx-auto space-y-6" x-data="{
    currentView: 'board', // 'board' or 'sheet'
    openNewClientModal: false,
    openScheduleModal: false,
    openShiftModal: false,
    selectedClient: null,
    targetStatus: 'scheduled',
    shiftProgress: '',
    shiftDealValue: '',
    shiftNotes: '',
    draggingClientId: null,
    dragOverStatus: null,
    toastMessage: null,
    toastType: 'success',

    showToast(msg, type = 'success') {
        this.toastMessage = msg;
        this.toastType = type;
        setTimeout(() => { this.toastMessage = null; }, 3500);
    },

    openScheduleFor(client) {
        this.selectedClient = client;
        this.openScheduleModal = true;
    },

    openShiftModalFor(client, targetStage) {
        this.selectedClient = client;
        this.targetStatus = targetStage || client.next_status || 'scheduled';
        this.shiftProgress = client.progress || '';
        this.shiftDealValue = client.deal_value || '';
        this.shiftNotes = '';
        this.openShiftModal = true;
    },

    onDragStart(event, clientId, currentStatus) {
        this.draggingClientId = clientId;
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', clientId.toString());
    },

    onDragOver(event, statusKey) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        this.dragOverStatus = statusKey;
    },

    onDragLeave(event, statusKey) {
        if (this.dragOverStatus === statusKey) {
            this.dragOverStatus = null;
        }
    },

    onDrop(event, newStatus) {
        event.preventDefault();
        this.dragOverStatus = null;
        const clientId = event.dataTransfer.getData('text/plain') || this.draggingClientId;
        if (!clientId) return;
        this.quickUpdateStatus(clientId, newStatus);
        this.draggingClientId = null;
    },

    onDragEnd() {
        this.draggingClientId = null;
        this.dragOverStatus = null;
    },

    quickUpdateStatus(clientId, newStatus, progress = null, dealValue = null, notes = null) {
        const payload = { status: newStatus };
        if (progress !== null) payload.progress = progress;
        if (dealValue !== null) payload.deal_value = dealValue;
        if (notes !== null) payload.notes = notes;

        fetch(`/clients/${clientId}/status`, {
            method: 'PATCH',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-TOKEN': '{{ csrf_token() }}',
                'Accept': 'application/json'
            },
            body: JSON.stringify(payload)
        })
        .then(res => res.json())
        .then(data => {
            if (data.success) {
                this.showToast(data.message || 'Deal moved successfully!');
                if (this.openShiftModal) {
                    this.openShiftModal = false;
                }
                setTimeout(() => {
                    window.location.reload();
                }, 300);
            } else {
                this.showToast('Could not update status. Please try again.', 'error');
            }
        })
        .catch(err => {
            console.error(err);
            this.showToast('Network error while updating deal stage.', 'error');
        });
    },

    submitShiftModal() {
        if (!this.selectedClient) return;
        this.quickUpdateStatus(
            this.selectedClient.id,
            this.targetStatus,
            this.shiftProgress,
            this.shiftDealValue ? parseFloat(this.shiftDealValue) : null,
            this.shiftNotes
        );
    }
}">

    <!-- Modern Floating Toast Notification -->
    <div x-show="toastMessage" x-cloak
        x-transition:enter="transition ease-out duration-300"
        x-transition:enter-start="opacity-0 translate-y-4 scale-95"
        x-transition:enter-end="opacity-100 translate-y-0 scale-100"
        x-transition:leave="transition ease-in duration-200"
        x-transition:leave-start="opacity-100 translate-y-0 scale-100"
        x-transition:leave-end="opacity-0 translate-y-4 scale-95"
        class="fixed bottom-6 right-6 z-50 flex items-center gap-3 px-5 py-3.5 rounded-2xl shadow-2xl backdrop-blur-xl border text-sm font-semibold max-w-md"
        :class="toastType === 'success' ? 'bg-[#181B20]/95 border-amber-500/40 text-amber-300 shadow-amber-500/20' : 'bg-rose-950/95 border-rose-500/40 text-rose-200'">
        <div class="p-1.5 rounded-xl bg-amber-400/20 text-amber-400 shrink-0">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"></path></svg>
        </div>
        <span x-text="toastMessage" class="flex-1 text-xs sm:text-sm"></span>
        <button @click="toastMessage = null" class="text-slate-400 hover:text-white text-base leading-none">&times;</button>
    </div>

    <!-- Top Flash Notification -->
    @if (session('success'))
        <div class="p-4 rounded-2xl bg-emerald-950/70 border border-emerald-500/30 text-emerald-300 text-sm flex items-center justify-between shadow-xl">
            <div class="flex items-center gap-3">
                <div class="p-1.5 rounded-xl bg-emerald-500/20 text-emerald-400">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                </div>
                <span class="font-medium">{{ session('success') }}</span>
            </div>
            <button @click="$el.parentElement.remove()" class="text-emerald-400/60 hover:text-emerald-300 text-xs">Dismiss</button>
        </div>
    @endif

    <!-- EXECUTIVE HEADER WITH AMBER GLOW & ENTERPRISE KPI CARDS -->
    <div class="relative overflow-hidden rounded-3xl glass-panel border border-amber-500/20 p-6 sm:p-7 shadow-2xl shadow-black/50 space-y-6">
        <div class="absolute -right-20 -top-20 w-96 h-96 bg-amber-500/10 rounded-full blur-3xl pointer-events-none"></div>
        <div class="absolute -left-20 -bottom-20 w-80 h-80 bg-sky-500/10 rounded-full blur-3xl pointer-events-none"></div>

        <div class="relative z-10 flex flex-col lg:flex-row lg:items-center justify-between gap-6">
            <div class="space-y-2">
                <div class="flex items-center gap-2">
                    <span class="px-3 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider bg-gradient-to-r from-amber-400 to-amber-500 text-slate-950 shadow-sm shadow-amber-500/30">
                        BD CRM PIPELINE
                    </span>
                    <span class="text-xs text-amber-300 font-semibold flex items-center gap-1.5">
                        <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                        Active Deal Pipeline & Automated Outreach
                    </span>
                </div>
                <h1 class="text-2xl sm:text-3xl font-black text-white tracking-tight flex items-center gap-3">
                    <span>Business Development Pipeline</span>
                    <span class="text-xs px-2.5 py-1 rounded-xl bg-slate-900/80 border border-slate-700/80 text-amber-300 font-mono font-bold">
                        ${{ number_format($metrics['total_pipeline_value'] ?? 0) }} Total Pipeline
                    </span>
                </h1>
                <p class="text-xs sm:text-sm text-slate-300 max-w-3xl leading-relaxed">
                    Interactive Kanban workflow: Drag deals across columns or click <strong>1-Click Stage Shift</strong> to advance leads through <strong>Discovery ➔ Scheduled ➔ Paperwork/Onboarding ➔ Won</strong>.
                </p>
            </div>

            <!-- View Switcher & Actions -->
            <div class="flex flex-wrap items-center gap-3 shrink-0">
                <div class="bg-slate-900/90 border border-slate-700/80 rounded-2xl p-1 flex items-center gap-1 shadow-inner">
                    <button @click="currentView = 'board'"
                        class="px-3.5 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer"
                        :class="currentView === 'board' ? 'bg-amber-400 text-slate-950 shadow-md shadow-amber-500/25 font-black' : 'text-slate-400 hover:text-white'">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1H5a1 1 0 01-1-1V5zm10 0a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1V5zM4 15a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1H5a1 1 0 01-1-1v-4zm10 0a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1v-4z"></path></svg>
                        <span>Kanban Board</span>
                    </button>

                    <button @click="currentView = 'sheet'"
                        class="px-3.5 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer"
                        :class="currentView === 'sheet' ? 'bg-amber-400 text-slate-950 shadow-md shadow-amber-500/25 font-black' : 'text-slate-400 hover:text-white'">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M3 14h18m-9-4v8m-7 0h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path></svg>
                        <span>Spreadsheet View</span>
                    </button>
                </div>

                <button @click="openNewClientModal = true"
                    class="btn-amber px-4 py-2.5 rounded-xl font-black text-xs flex items-center gap-2 shadow-lg shadow-amber-500/25 cursor-pointer">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"></path></svg>
                    <span>+ Add New Deal</span>
                </button>
            </div>
        </div>

        <!-- Metric Cards Strip -->
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 pt-4 border-t border-white/[0.08]">
            @foreach (\App\Models\Client::STATUSES as $statusKey => $meta)
                @php
                    $colClients = $clientsByStatus[$statusKey] ?? collect();
                    $count = $metrics[$statusKey . '_count'] ?? $colClients->count();
                    $colValue = $colClients->sum('deal_value');
                @endphp
                <div class="p-3.5 rounded-2xl bg-slate-950/60 border border-slate-800/80 hover:border-slate-700 transition-all space-y-1">
                    <div class="flex items-center justify-between">
                        <span class="text-[10px] font-black uppercase tracking-wider text-slate-400 truncate">{{ $meta['label'] }}</span>
                        <span class="w-2.5 h-2.5 rounded-full {{ $meta['dot'] }}"></span>
                    </div>
                    <div class="flex items-baseline justify-between">
                        <span class="text-xl font-black text-white">{{ $count }}</span>
                        @if ($colValue > 0)
                            <span class="text-[10px] font-mono font-bold text-amber-400/90">${{ number_format($colValue) }}</span>
                        @else
                            <span class="text-[10px] text-slate-500">deals</span>
                        @endif
                    </div>
                </div>
            @endforeach
        </div>
    </div>

    <!-- Filter & Search Toolbar -->
    <div class="bg-[#16191E]/95 border border-white/[0.08] p-4 rounded-2xl flex flex-col md:flex-row items-center justify-between gap-4 shadow-xl">
        <form method="GET" action="{{ route('clients.index') }}" class="w-full md:w-96 relative">
            <input type="text" name="search" value="{{ request('search') }}" placeholder="Search company, contact, campaign, or deal value..."
                class="w-full pl-9 pr-4 py-2.5 bg-slate-950/90 border border-slate-700/80 rounded-xl text-xs text-white placeholder-slate-500 focus:ring-2 focus:ring-amber-400 focus:outline-none">
            <svg class="w-4 h-4 text-slate-400 absolute left-3 top-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
        </form>

        <div class="flex flex-wrap items-center gap-3 w-full md:w-auto">
            <form method="GET" action="{{ route('clients.index') }}" class="flex items-center gap-2">
                @if (request('search'))
                    <input type="hidden" name="search" value="{{ request('search') }}">
                @endif

                <select name="campaign" onchange="this.form.submit()"
                    class="px-3 py-2 bg-slate-950/90 border border-slate-700/80 rounded-xl text-xs text-slate-300 focus:ring-2 focus:ring-amber-400 cursor-pointer">
                    <option value="all">All Campaigns ({{ $campaigns->count() }})</option>
                    @foreach ($campaigns as $camp)
                        <option value="{{ $camp }}" {{ request('campaign') === $camp ? 'selected' : '' }}>{{ $camp }}</option>
                    @endforeach
                </select>

                @if (auth()->user()->isSuperAdmin())
                    <select name="assigned_to" onchange="this.form.submit()"
                        class="px-3 py-2 bg-slate-950/90 border border-slate-700/80 rounded-xl text-xs text-slate-300 focus:ring-2 focus:ring-amber-400 cursor-pointer">
                        <option value="all">All BD Reps (Developer View)</option>
                        @foreach ($bdUsers as $u)
                            <option value="{{ $u->id }}" {{ request('assigned_to') == $u->id ? 'selected' : '' }}>{{ $u->name }}</option>
                        @endforeach
                    </select>
                @endif

                @if (request('search') || (request('campaign') && request('campaign') !== 'all') || (request('assigned_to') && request('assigned_to') !== 'all'))
                    <a href="{{ route('clients.index') }}" class="text-xs text-amber-400 hover:text-amber-300 font-semibold px-2">Clear</a>
                @endif
            </form>
        </div>
    </div>

    <!-- VIEW 1: ADVANCED HORIZONTAL-SCROLL KANBAN BOARD -->
    <div x-show="currentView === 'board'" class="space-y-4">
        <!-- Scroll instruction hint -->
        <div class="flex items-center justify-between text-[11px] text-slate-400 px-1">
            <span class="flex items-center gap-1.5">
                <svg class="w-3.5 h-3.5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4"></path></svg>
                <span>Drag deals between columns or use <strong>Shift Stage</strong> buttons to advance leads</span>
            </span>
            <span class="hidden md:inline-block text-slate-500 font-medium">Scroll horizontally &rarr;</span>
        </div>

        <!-- Kanban Board Horizontal Container -->
        <div class="flex gap-4 overflow-x-auto pb-6 pt-1 px-1 kanban-scrollbar min-h-[640px] items-start">
            @foreach (\App\Models\Client::STATUSES as $statusKey => $meta)
                @php
                    $columnClients = $clientsByStatus[$statusKey] ?? collect();
                    $colSum = $columnClients->sum('deal_value');
                @endphp
                <!-- Column Container (Generous 320px width for beautiful spacing) -->
                <div class="w-[310px] min-w-[310px] max-w-[325px] shrink-0 rounded-3xl border flex flex-col max-h-[82vh] shadow-2xl transition-all duration-200"
                    @dragover="onDragOver($event, '{{ $statusKey }}')"
                    @dragleave="onDragLeave($event, '{{ $statusKey }}')"
                    @drop="onDrop($event, '{{ $statusKey }}')"
                    :class="dragOverStatus === '{{ $statusKey }}' ? 'border-amber-400 bg-amber-500/[0.08] ring-4 ring-amber-400/30 shadow-amber-500/20' : 'border-white/[0.08] bg-[#121418]'">

                    <!-- Column Header Bar -->
                    <div class="p-4 border-b border-white/[0.08] flex items-center justify-between shrink-0">
                        <div class="flex items-center gap-2.5">
                            <span class="w-3 h-3 rounded-full {{ $meta['dot'] }} ring-4 ring-white/[0.05]"></span>
                            <div>
                                <h3 class="text-xs font-black text-white uppercase tracking-wider">{{ $meta['label'] }}</h3>
                                <span class="text-[10px] text-slate-400 font-mono">
                                    {{ $columnClients->count() }} {{ Str::plural('deal', $columnClients->count()) }}
                                    @if ($colSum > 0)
                                        &bull; <strong class="text-amber-400">${{ number_format($colSum) }}</strong>
                                    @endif
                                </span>
                            </div>
                        </div>

                        <button @click="openNewClientModal = true" class="p-1 rounded-lg hover:bg-white/[0.08] text-slate-400 hover:text-white transition-colors" title="Add lead to this stage">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"></path></svg>
                        </button>
                    </div>

                    <!-- Column Cards Feed (Vertical scrollable per column) -->
                    <div class="flex-1 overflow-y-auto p-3 space-y-3 kanban-column-scroll">
                        @forelse ($columnClients as $client)
                            <div draggable="true"
                                @dragstart="onDragStart($event, {{ $client->id }}, '{{ $client->status }}')"
                                @dragend="onDragEnd()"
                                :class="draggingClientId == {{ $client->id }} ? 'opacity-40 scale-95 border-amber-400 cursor-grabbing' : 'cursor-grab active:cursor-grabbing'"
                                class="bg-[#181B20] border border-white/[0.08] hover:border-amber-500/40 rounded-2xl p-4 shadow-lg hover:shadow-black/70 transition-all duration-200 space-y-3 group relative">

                                <!-- Top Row: Monogram Avatar + Company + Deal Value -->
                                <div class="flex items-start justify-between gap-2">
                                    <div class="flex items-center gap-2.5 min-w-0">
                                        <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-amber-400/20 to-amber-600/30 border border-amber-500/30 text-amber-300 font-black text-xs flex items-center justify-center shrink-0 shadow-sm">
                                            {{ strtoupper(substr($client->company_name, 0, 2)) }}
                                        </div>
                                        <div class="min-w-0">
                                            <a href="{{ route('clients.show', $client) }}" class="text-xs font-black text-white group-hover:text-amber-300 transition-colors truncate block">
                                                {{ $client->company_name }}
                                            </a>
                                            <div class="text-[11px] text-slate-400 truncate flex items-center gap-1">
                                                <span class="text-slate-300 font-medium">{{ $client->contact_name }}</span>
                                                @if ($client->contact_role)
                                                    <span class="text-slate-600">&bull;</span>
                                                    <span class="text-slate-400 truncate">{{ $client->contact_role }}</span>
                                                @endif
                                            </div>
                                        </div>
                                    </div>

                                    @if ($client->deal_value)
                                        <span class="px-2 py-0.5 rounded-lg text-[10px] font-mono font-bold bg-amber-400/10 text-amber-300 border border-amber-400/30 shrink-0">
                                            ${{ number_format($client->deal_value) }}
                                        </span>
                                    @endif
                                </div>

                                <!-- ADVANCED 4-STEP SEGMENTED PROGRESS TRACKER (CLEAN & SLEEK) -->
                                <div class="space-y-1">
                                    <div class="flex items-center justify-between text-[9px] font-bold text-slate-400">
                                        <span class="text-slate-500">Pipeline Flow</span>
                                        <span class="text-amber-400 font-semibold">
                                            @if ($client->pipeline_step_index == 1) 1. Discovery
                                            @elseif ($client->pipeline_step_index == 2) 2. Scheduled
                                            @elseif ($client->pipeline_step_index == 3) 3. Paperwork
                                            @elseif ($client->pipeline_step_index == 4) 4. Won & Onboarded
                                            @else Off-track ({{ ucfirst($client->status) }})
                                            @endif
                                        </span>
                                    </div>
                                    <div class="grid grid-cols-4 gap-1 p-1 rounded-lg bg-slate-950/80 border border-slate-800">
                                        <!-- Step 1 -->
                                        <div class="h-1.5 rounded-full transition-all {{ $client->pipeline_step_index >= 1 ? 'bg-amber-400 shadow-sm shadow-amber-400/50' : 'bg-slate-800' }}" title="Discovery"></div>
                                        <!-- Step 2 -->
                                        <div class="h-1.5 rounded-full transition-all {{ $client->pipeline_step_index >= 2 ? 'bg-sky-400 shadow-sm shadow-sky-400/50' : 'bg-slate-800' }}" title="Scheduled"></div>
                                        <!-- Step 3 -->
                                        <div class="h-1.5 rounded-full transition-all {{ $client->pipeline_step_index >= 3 ? 'bg-indigo-400 shadow-sm shadow-indigo-400/50' : 'bg-slate-800' }}" title="Paperwork/Onboarding"></div>
                                        <!-- Step 4 -->
                                        <div class="h-1.5 rounded-full transition-all {{ $client->pipeline_step_index >= 4 ? 'bg-emerald-400 shadow-sm shadow-emerald-400/50' : 'bg-slate-800' }}" title="Onboarded"></div>
                                    </div>
                                </div>

                                <!-- Campaign & BD Tag -->
                                <div class="flex flex-wrap items-center gap-1.5">
                                    @if ($client->campaign)
                                        <span class="px-2 py-0.5 rounded-lg text-[9px] font-semibold bg-slate-900 border border-slate-800 text-indigo-300 truncate max-w-[190px]">
                                            🎯 {{ $client->campaign }}
                                        </span>
                                    @endif
                                    @if ($client->assignedTo)
                                        <span class="px-2 py-0.5 rounded-lg text-[9px] font-medium bg-slate-900 border border-slate-800 text-slate-400 truncate max-w-[100px]">
                                            👤 {{ Str::words($client->assignedTo->name, 1, '') }}
                                        </span>
                                    @endif
                                </div>

                                <!-- Progress Snippet -->
                                @if ($client->progress)
                                    <div class="p-2.5 rounded-xl bg-slate-950/70 border-l-2 border-l-amber-500/80 border border-slate-800/80 text-[11px] text-slate-300 leading-relaxed line-clamp-2">
                                        {{ $client->progress }}
                                    </div>
                                @endif

                                <!-- Scheduled Pitch Meeting Box with Live Alert -->
                                @if ($client->upcomingMeeting)
                                    <div class="p-2.5 rounded-xl bg-sky-950/40 border border-sky-500/30 space-y-1.5">
                                        <div class="flex items-center justify-between text-[10px]">
                                            <span class="font-bold text-sky-400 flex items-center gap-1">
                                                <span class="w-1.5 h-1.5 rounded-full bg-sky-400 animate-pulse"></span>
                                                Pitch Scheduled
                                            </span>
                                            <span class="text-slate-400 font-mono">{{ $client->upcomingMeeting->start_time->format('M d') }}</span>
                                        </div>
                                        <div class="text-[11px] font-semibold text-slate-100 truncate">
                                            {{ $client->upcomingMeeting->start_time->format('h:i A') }} ({{ $client->upcomingMeeting->start_time->diffForHumans() }})
                                        </div>
                                        <div class="flex items-center justify-between pt-1 border-t border-sky-800/40 text-[10px]">
                                            <span class="text-amber-400 flex items-center gap-1">
                                                🔔 Reminders Armed
                                            </span>
                                            @if ($client->upcomingMeeting->meeting_link)
                                                <a href="{{ $client->upcomingMeeting->meeting_link }}" target="_blank" class="text-indigo-300 hover:text-white font-bold">Join Call &rarr;</a>
                                            @endif
                                        </div>
                                    </div>
                                @endif

                                <!-- ACTION TOOLBAR: 1-CLICK STAGE SHIFTER & DROPDOWN -->
                                <div class="pt-2.5 border-t border-white/[0.08] space-y-2">
                                    <!-- Primary Next Stage Button -->
                                    @if ($client->next_status)
                                        <div class="flex items-center gap-1.5">
                                            <button @click="quickUpdateStatus({{ $client->id }}, '{{ $client->next_status }}')"
                                                class="flex-1 py-2 px-3 rounded-xl text-xs font-black transition-all flex items-center justify-center gap-1.5 shadow-md cursor-pointer
                                                    @if ($client->status === \App\Models\Client::STATUS_DISCOVERY)
                                                        bg-gradient-to-r from-sky-400 to-sky-500 hover:from-sky-300 hover:to-sky-400 text-slate-950 shadow-sky-500/20
                                                    @elseif ($client->status === \App\Models\Client::STATUS_SCHEDULED)
                                                        bg-gradient-to-r from-indigo-500 to-blue-600 hover:from-indigo-400 hover:to-blue-500 text-white shadow-indigo-500/20
                                                    @elseif ($client->status === \App\Models\Client::STATUS_PAPERWORK_ONBOARDING)
                                                        bg-gradient-to-r from-emerald-400 to-teal-500 hover:from-emerald-300 hover:to-teal-400 text-slate-950 shadow-emerald-500/20
                                                    @else
                                                        bg-slate-800 hover:bg-slate-700 text-slate-200
                                                    @endif
                                                ">
                                                <span>{{ $client->next_action_label }}</span>
                                                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M13 7l5 5m0 0l-5 5m5-5H6"></path></svg>
                                            </button>

                                            <!-- Edit & Notes modal button -->
                                            <button @click="openShiftModalFor({{ Js::from($client) }}, '{{ $client->next_status }}')"
                                                class="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition-all cursor-pointer shrink-0"
                                                title="Advance stage with notes & deal value">
                                                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
                                            </button>
                                        </div>
                                    @elseif ($client->status === \App\Models\Client::STATUS_ONBOARDED)
                                        <div class="py-1.5 px-3 rounded-xl bg-emerald-950/60 border border-emerald-500/40 text-emerald-300 text-xs font-black flex items-center justify-center gap-1.5 shadow-inner">
                                            <svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"></path></svg>
                                            <span>Deal Won & Active</span>
                                        </div>
                                    @endif

                                    <!-- Jump to Any Stage Dropdown + Quick Schedule Button -->
                                    <div class="flex items-center justify-between gap-1.5">
                                        <div class="relative flex-1">
                                            <select @change="quickUpdateStatus({{ $client->id }}, $event.target.value)"
                                                class="w-full px-2.5 py-1.5 rounded-xl text-[11px] font-bold transition-all cursor-pointer border focus:ring-1 focus:ring-amber-400 truncate"
                                                style="{{ $client->status_meta['badge_style'] }}">
                                                @foreach (\App\Models\Client::STATUSES as $optKey => $optMeta)
                                                    <option value="{{ $optKey }}" {{ $client->status === $optKey ? 'selected' : '' }}>
                                                        Move to: {{ $optMeta['label'] }}
                                                    </option>
                                                @endforeach
                                            </select>
                                        </div>

                                        <button @click="openScheduleFor({{ Js::from($client) }})"
                                            class="p-1.5 rounded-xl bg-slate-800 hover:bg-amber-400 hover:text-slate-950 text-slate-300 transition-all cursor-pointer shrink-0"
                                            title="Schedule Pitch Meeting with Client">
                                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                                        </button>
                                    </div>
                                </div>
                            </div>
                        @empty
                            <div class="py-16 text-center space-y-2 bg-slate-950/20 rounded-2xl border border-dashed border-slate-800/80">
                                <svg class="w-8 h-8 text-slate-700 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>
                                <p class="text-[11px] text-slate-500 font-medium">Drop deals here</p>
                            </div>
                        @endforelse
                    </div>

                    <!-- Column Footer Button -->
                    <div class="p-3 border-t border-white/[0.08] shrink-0">
                        <button @click="openNewClientModal = true"
                            class="w-full py-1.5 rounded-xl text-[11px] font-semibold text-slate-400 hover:text-amber-300 hover:bg-white/[0.04] transition-all flex items-center justify-center gap-1.5 cursor-pointer">
                            <span>+ Add Deal</span>
                        </button>
                    </div>
                </div>
            @endforeach
        </div>
    </div>

    <!-- VIEW 2: SPREADSHEET VIEW -->
    <div x-show="currentView === 'sheet'" class="bg-[#16191E]/95 border border-white/[0.08] rounded-3xl overflow-hidden shadow-2xl space-y-0" x-cloak>
        <div class="overflow-x-auto">
            <table class="w-full text-left border-collapse">
                <thead>
                    <tr class="bg-[#2e7d32]/90 border-b border-emerald-600 text-white font-black text-xs uppercase tracking-wider">
                        <th class="py-3.5 px-4">Company Name</th>
                        <th class="py-3.5 px-4">Point of Contact</th>
                        <th class="py-3.5 px-4">Campaign</th>
                        <th class="py-3.5 px-4">Deal Value</th>
                        <th class="py-3.5 px-4">Progress</th>
                        <th class="py-3.5 px-4">Current Stage</th>
                        <th class="py-3.5 px-4">Quick Advance</th>
                        <th class="py-3.5 px-4">Scheduled Pitch</th>
                        <th class="py-3.5 px-4 text-right">Actions</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-white/[0.06] text-xs text-slate-200">
                    @forelse ($allClients as $client)
                        <tr class="hover:bg-white/[0.03] transition-colors">
                            <td class="py-4 px-4 font-bold text-white whitespace-nowrap">
                                <a href="{{ route('clients.show', $client) }}" class="hover:text-amber-300 flex items-center gap-2.5">
                                    <div class="w-7 h-7 rounded-lg bg-amber-400/20 text-amber-300 flex items-center justify-center font-black text-xs">
                                        {{ strtoupper(substr($client->company_name, 0, 1)) }}
                                    </div>
                                    <span>{{ $client->company_name }}</span>
                                </a>
                            </td>

                            <td class="py-4 px-4 whitespace-nowrap">
                                <div class="font-medium text-slate-200">{{ $client->contact_name }}</div>
                                <div class="text-[11px] text-slate-500 font-mono">{{ $client->contact_email ?? $client->contact_phone ?? 'No contact info' }}</div>
                            </td>

                            <td class="py-4 px-4 whitespace-nowrap">
                                @if ($client->campaign)
                                    <span class="px-2.5 py-1 rounded-lg text-[10px] font-bold bg-slate-900 border border-slate-700 text-indigo-300">
                                        {{ $client->campaign }}
                                    </span>
                                @else
                                    <span class="text-slate-500">&mdash;</span>
                                @endif
                            </td>

                            <td class="py-4 px-4 whitespace-nowrap font-mono font-bold text-amber-400">
                                {{ $client->deal_value ? '$' . number_format($client->deal_value) : '—' }}
                            </td>

                            <td class="py-4 px-4 max-w-xs">
                                <p class="text-slate-300 line-clamp-2 leading-relaxed text-[11px]">
                                    {{ $client->progress ?? 'No progress logged yet' }}
                                </p>
                            </td>

                            <td class="py-4 px-4 whitespace-nowrap">
                                <select @change="quickUpdateStatus({{ $client->id }}, $event.target.value)"
                                    class="px-2.5 py-1 rounded-xl text-xs font-bold transition-all cursor-pointer border focus:ring-2 focus:ring-amber-400"
                                    style="{{ $client->status_meta['badge_style'] }}">
                                    @foreach (\App\Models\Client::STATUSES as $optKey => $optMeta)
                                        <option value="{{ $optKey }}" {{ $client->status === $optKey ? 'selected' : '' }}>
                                            {{ $optMeta['label'] }}
                                        </option>
                                    @endforeach
                                </select>
                            </td>

                            <td class="py-4 px-4 whitespace-nowrap">
                                @if ($client->next_status)
                                    <button @click="quickUpdateStatus({{ $client->id }}, '{{ $client->next_status }}')"
                                        class="px-3 py-1.5 rounded-xl text-[11px] font-bold bg-amber-400 text-slate-950 hover:bg-amber-300 transition-all shadow-sm shadow-amber-500/20 flex items-center gap-1.5 cursor-pointer">
                                        <span>{{ $client->next_action_label }}</span>
                                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M13 7l5 5m0 0l-5 5m5-5H6"></path></svg>
                                    </button>
                                @else
                                    <span class="text-emerald-400 text-[11px] font-bold">✓ Won</span>
                                @endif
                            </td>

                            <td class="py-4 px-4 whitespace-nowrap">
                                @if ($client->upcomingMeeting)
                                    <div class="flex items-center gap-2">
                                        <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
                                        <div>
                                            <div class="text-xs font-bold text-slate-200">{{ $client->upcomingMeeting->start_time->format('M d, h:i A') }}</div>
                                            <div class="text-[10px] text-amber-400 font-medium">Auto-reminders active</div>
                                        </div>
                                    </div>
                                @else
                                    <button @click="openScheduleFor({{ Js::from($client) }})"
                                        class="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium transition-all">
                                        + Schedule Pitch
                                    </button>
                                @endif
                            </td>

                            <td class="py-4 px-4 text-right whitespace-nowrap">
                                <div class="flex items-center justify-end gap-2">
                                    <button @click="openScheduleFor({{ Js::from($client) }})"
                                        class="p-1.5 rounded-lg bg-amber-400/10 hover:bg-amber-400 hover:text-slate-950 text-amber-300 transition-colors cursor-pointer"
                                        title="Schedule Pitch Meeting">
                                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                                    </button>

                                    <a href="{{ route('clients.show', $client) }}"
                                        class="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors"
                                        title="View Full Profile">
                                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path></svg>
                                    </a>
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="9" class="py-12 text-center text-slate-500">
                                No deals found. Click "+ Add New Deal" to begin tracking your pipeline.
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    <!-- MODAL 1: ADD NEW CLIENT -->
    <div x-show="openNewClientModal" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">

        <div @click.outside="openNewClientModal = false"
            class="bg-[#16191E] border border-amber-500/30 rounded-3xl shadow-2xl max-w-2xl w-full p-6 sm:p-8 space-y-6 max-h-[90vh] overflow-y-auto">

            <div class="flex items-center justify-between border-b border-white/[0.08] pb-4">
                <div>
                    <h3 class="text-lg font-black text-white">Add New Deal to Pipeline</h3>
                    <p class="text-xs text-slate-400">Record company point of contact, campaign, and deal value.</p>
                </div>
                <button @click="openNewClientModal = false" class="text-slate-400 hover:text-white p-1">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <form action="{{ route('clients.store') }}" method="POST" class="space-y-4">
                @csrf

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Company Name *</label>
                        <input type="text" name="company_name" required placeholder="e.g. Acme Corp / Apex Cloud"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Point of Contact Name *</label>
                        <input type="text" name="contact_name" required placeholder="e.g. John Doe / Elena Rostova"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Contact Email</label>
                        <input type="email" name="contact_email" placeholder="contact@company.com"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Contact Phone</label>
                        <input type="text" name="contact_phone" placeholder="+1 (555) 000-0000"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Contact Role / Title</label>
                        <input type="text" name="contact_role" placeholder="e.g. VP Operations / CTO"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Outreach Campaign</label>
                        <input type="text" name="campaign" placeholder="e.g. Cold Email #1, LinkedIn"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Estimated Deal Value ($)</label>
                        <input type="number" step="100" name="deal_value" placeholder="e.g. 50000"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Initial Status *</label>
                        <select name="status" required
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none cursor-pointer">
                            @foreach (\App\Models\Client::STATUSES as $statusKey => $meta)
                                <option value="{{ $statusKey }}">{{ $meta['label'] }}</option>
                            @endforeach
                        </select>
                    </div>
                </div>

                @if (auth()->user()->isSuperAdmin())
                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Assigned BD Representative</label>
                        <select name="assigned_to"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none cursor-pointer">
                            <option value="">Assign to Me ({{ Auth::user()->name }})</option>
                            @foreach ($bdUsers as $u)
                                <option value="{{ $u->id }}">{{ $u->name }} ({{ $u->title ?? 'BD Team' }})</option>
                            @endforeach
                        </select>
                    </div>
                @endif

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Progress Notes / Pitch History</label>
                    <textarea name="progress" rows="2" placeholder="e.g. Initial outreach email sent. Follow up next Tuesday."
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none"></textarea>
                </div>

                <div class="flex items-center justify-end gap-3 pt-3 border-t border-white/[0.08]">
                    <button type="button" @click="openNewClientModal = false" class="px-4 py-2 text-xs text-slate-400 hover:text-white">Cancel</button>
                    <button type="submit" class="btn-amber px-6 py-2.5 rounded-xl font-bold text-xs shadow-lg shadow-amber-500/20">
                        Create Deal & Place on Board
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- MODAL 2: STAGE TRANSITION DETAILS MODAL -->
    <div x-show="openShiftModal" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">

        <div @click.outside="openShiftModal = false"
            class="bg-[#16191E] border border-amber-500/30 rounded-3xl shadow-2xl max-w-lg w-full p-6 sm:p-8 space-y-6 max-h-[90vh] overflow-y-auto">

            <div class="flex items-center justify-between border-b border-white/[0.08] pb-4">
                <div>
                    <h3 class="text-base font-black text-white flex items-center gap-2">
                        <span>Advance Deal Stage</span>
                    </h3>
                    <p class="text-xs text-amber-300 font-medium mt-0.5" x-text="selectedClient ? selectedClient.company_name : ''"></p>
                </div>
                <button @click="openShiftModal = false" class="text-slate-400 hover:text-white p-1">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <div class="space-y-4">
                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Target Stage *</label>
                    <select x-model="targetStatus"
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none cursor-pointer">
                        @foreach (\App\Models\Client::STATUSES as $statusKey => $meta)
                            <option value="{{ $statusKey }}">{{ $meta['label'] }}</option>
                        @endforeach
                    </select>
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Updated Deal Value ($)</label>
                    <input type="number" step="100" x-model="shiftDealValue" placeholder="e.g. 75000"
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Progress Update Note</label>
                    <textarea x-model="shiftProgress" rows="3" placeholder="e.g. Pitch conducted. Client requested enterprise SLA terms and custom pricing."
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none"></textarea>
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Internal Notes</label>
                    <textarea x-model="shiftNotes" rows="2" placeholder="Private notes for BD team..."
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none"></textarea>
                </div>

                <div class="flex items-center justify-end gap-3 pt-3 border-t border-white/[0.08]">
                    <button type="button" @click="openShiftModal = false" class="px-4 py-2 text-xs text-slate-400 hover:text-white">Cancel</button>
                    <button type="button" @click="submitShiftModal()" class="btn-amber px-6 py-2.5 rounded-xl font-bold text-xs shadow-lg shadow-amber-500/20">
                        Confirm & Shift Stage
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- MODAL 3: SCHEDULE PITCH MEETING & ARMED REMINDERS -->
    <div x-show="openScheduleModal" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">

        <div @click.outside="openScheduleModal = false"
            class="bg-[#16191E] border border-amber-500/30 rounded-3xl shadow-2xl max-w-lg w-full p-6 sm:p-8 space-y-6 max-h-[90vh] overflow-y-auto">

            <div class="flex items-center justify-between border-b border-white/[0.08] pb-4">
                <div>
                    <h3 class="text-base font-black text-white flex items-center gap-2">
                        <span>Schedule Pitch Meeting</span>
                    </h3>
                    <p class="text-xs text-amber-300 font-medium mt-0.5" x-text="selectedClient ? 'With ' + selectedClient.company_name + ' (' + selectedClient.contact_name + ')' : ''"></p>
                </div>
                <button @click="openScheduleModal = false" class="text-slate-400 hover:text-white p-1">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <form :action="selectedClient ? `/clients/${selectedClient.id}/schedule-meeting` : '#'" method="POST" class="space-y-4">
                @csrf

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Meeting Title *</label>
                    <input type="text" name="title" required :value="selectedClient ? 'Pitch & Demo: ' + selectedClient.company_name : 'Executive Demo Call'"
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
                        <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Meeting Channel</label>
                        <select name="type"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none cursor-pointer">
                            <option value="virtual" selected>Virtual Conference (Google Meet / Zoom)</option>
                            <option value="in_person">In-Person Office Meeting</option>
                            <option value="hybrid">Hybrid</option>
                        </select>
                    </div>

                    <div>
                        <label class="text-[10px] font-bold uppercase tracking-wider text-amber-400 block mb-1">
                            🔔 Automated Reminders *
                        </label>
                        <select name="reminder_minutes"
                            class="w-full px-3.5 py-2.5 bg-slate-950 border border-amber-500/40 rounded-xl text-xs text-amber-300 focus:ring-2 focus:ring-amber-400 focus:outline-none cursor-pointer">
                            <option value="15" selected>15 minutes before call</option>
                            <option value="30">30 minutes before call</option>
                            <option value="60">1 hour before call</option>
                            <option value="1440">1 day before call</option>
                        </select>
                    </div>
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Video Meeting URL (Google Meet / Zoom)</label>
                    <input type="url" name="meeting_link" placeholder="https://meet.google.com/abc-defg-hij"
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none">
                </div>

                <div>
                    <label class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block mb-1">Agenda / Pitch Notes</label>
                    <textarea name="description" rows="2" placeholder="Topics: SLA review, microservice architecture, pricing tiers..."
                        class="w-full px-3.5 py-2.5 bg-slate-950 border border-slate-700/80 rounded-xl text-xs text-white focus:ring-2 focus:ring-amber-400 focus:outline-none"></textarea>
                </div>

                <div class="p-3 rounded-2xl bg-amber-950/40 border border-amber-500/30 text-[11px] text-amber-300 flex items-center gap-2">
                    <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                    <span>Scheduling advances stage to <strong>Scheduled</strong> and arms Schedio's Reminder Engine.</span>
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
</div>
@endsection
