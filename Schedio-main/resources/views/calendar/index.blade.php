@extends('layouts.app')

@section('title', 'My Calendar & Meeting Schedule')

@section('content')
<div class="space-y-6" x-data="schedioCalendar()">

    <!-- Top Action Bar & Filter Controls -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 glass-panel p-5 rounded-3xl shadow-xl">
        <div class="space-y-1">
            <h1 class="text-xl sm:text-2xl font-extrabold text-white tracking-tight flex items-center gap-2.5">
                <span>Calendar Hub</span>
                <span class="text-xs px-2.5 py-0.5 rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/30 font-bold">Interactive</span>
            </h1>
            <p class="text-xs text-slate-400">
                Click any slot or drag-and-drop to reschedule. Conflict detection and reminders run automatically.
            </p>
        </div>

        <!-- Filter Controls & Action Button -->
        <div class="flex flex-wrap items-center gap-3">
            <!-- Search Filter -->
            <div class="relative">
                <input type="text" x-model="searchQuery" @input.debounce.300ms="refetchEvents()"
                    placeholder="Search meetings..."
                    class="px-3.5 py-2.5 pl-9 rounded-xl bg-slate-950/70 border border-white/[0.1] text-xs text-white placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 w-44 sm:w-56 shadow-inner">
                <svg class="w-4 h-4 text-slate-500 absolute left-3 top-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                </svg>
            </div>

            <!-- Quick Create Button -->
            <button @click="openCreateModal()"
                class="btn-amber px-4 py-2.5 rounded-xl font-bold text-xs flex items-center gap-2 cursor-pointer shadow-lg shadow-amber-500/20">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"></path></svg>
                <span>+ Schedule Meeting</span>
            </button>
        </div>
    </div>

    <!-- Calendar Container -->
    <div class="glass-panel rounded-3xl p-4 sm:p-6 shadow-2xl overflow-hidden relative min-h-[700px]">
        <div id="calendar" class="w-full"></div>
    </div>

    <!-- 1. Event Details Modal -->
    <div x-show="detailsModalOpen" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">
        
        <div @click.outside="detailsModalOpen = false"
            class="bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl max-w-lg w-full p-6 space-y-5 overflow-hidden">
            
            <div class="flex items-start justify-between gap-4">
                <div class="space-y-1">
                    <div class="flex items-center gap-2">
                        <span class="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30">
                            Scheduled Meeting
                        </span>
                        <template x-if="activeEvent.extendedProps?.reminder_minutes">
                            <span class="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/30 flex items-center gap-1">
                                <span>🔔</span>
                                <span x-text="activeEvent.extendedProps?.reminder_minutes + 'm Reminder Active'"></span>
                            </span>
                        </template>
                    </div>
                    <h3 class="text-xl font-bold text-white leading-snug" x-text="activeEvent.title"></h3>
                </div>

                <button @click="detailsModalOpen = false" class="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition-colors">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <!-- Time & Date Info -->
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs bg-slate-950/60 p-4 rounded-xl border border-slate-800">
                <div>
                    <span class="text-slate-500 block mb-0.5 font-medium">Starts At</span>
                    <span class="text-slate-200 font-semibold text-sm" x-text="formatDate(activeEvent.start)"></span>
                </div>
                <div>
                    <span class="text-slate-500 block mb-0.5 font-medium">Ends At</span>
                    <span class="text-slate-200 font-semibold text-sm" x-text="formatDate(activeEvent.end)"></span>
                </div>

                <!-- Client Info -->
                <template x-if="activeEvent.extendedProps?.client_name">
                    <div class="sm:col-span-2 pt-2.5 mt-1 border-t border-slate-800/80 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                        <div>
                            <span class="text-slate-500 block text-[11px]">Meeting With Client</span>
                            <span class="text-white font-bold" x-text="activeEvent.extendedProps?.client_name"></span>
                            <span class="text-slate-400" x-show="activeEvent.extendedProps?.client_company" x-text="' (' + activeEvent.extendedProps?.client_company + ')'"></span>
                        </div>
                        <template x-if="activeEvent.extendedProps?.client_email">
                            <a :href="'mailto:' + activeEvent.extendedProps?.client_email" class="text-indigo-400 hover:underline text-xs flex items-center gap-1 font-mono">
                                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path></svg>
                                <span x-text="activeEvent.extendedProps?.client_email"></span>
                            </a>
                        </template>
                    </div>
                </template>
            </div>

            <!-- Video Meeting Link (Large Action Button) -->
            <template x-if="activeEvent.extendedProps?.meeting_link">
                <div class="p-3.5 rounded-xl bg-gradient-to-r from-indigo-950/60 to-purple-950/60 border border-indigo-500/40 flex items-center justify-between gap-3">
                    <div class="min-w-0 flex items-center gap-2.5 text-indigo-300 text-xs">
                        <div class="p-2 rounded-lg bg-indigo-600/30 text-indigo-400">
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg>
                        </div>
                        <div class="truncate">
                            <div class="font-semibold text-white">Video Call Ready</div>
                            <div class="truncate text-[11px] text-slate-400 font-mono" x-text="activeEvent.extendedProps?.meeting_link"></div>
                        </div>
                    </div>
                    <a :href="activeEvent.extendedProps?.meeting_link" target="_blank"
                        class="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-xl text-xs shrink-0 shadow-lg shadow-emerald-600/30 transition-all flex items-center gap-1.5 cursor-pointer">
                        <span>Join Call</span>
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg>
                    </a>
                </div>
            </template>

            <!-- Description / Notes -->
            <template x-if="activeEvent.extendedProps?.description">
                <div class="text-xs text-slate-300 bg-slate-950/40 p-3.5 rounded-xl border border-slate-800/80 leading-relaxed space-y-1">
                    <span class="text-slate-500 font-semibold block text-[10px] uppercase tracking-wider">Agenda / Notes</span>
                    <p x-text="activeEvent.extendedProps?.description"></p>
                </div>
            </template>

            <!-- Actions (Delete / Edit / Close) -->
            <div class="flex items-center justify-between pt-4 border-t border-slate-800">
                <template x-if="activeEvent.extendedProps?.can_delete">
                    <button @click="deleteActiveEvent()"
                        class="px-3.5 py-2 rounded-xl bg-rose-950/60 hover:bg-rose-900/60 border border-rose-800/60 text-rose-300 text-xs font-semibold transition-all cursor-pointer flex items-center gap-1.5">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                        <span>Cancel Meeting</span>
                    </button>
                </template>
                <div class="flex items-center gap-2">
                    <template x-if="activeEvent.extendedProps?.entity_id">
                        <a :href="'/meetings/' + activeEvent.extendedProps?.entity_id"
                            class="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition-all">
                            Full Details
                        </a>
                    </template>
                    <button @click="detailsModalOpen = false"
                        class="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition-all cursor-pointer">
                        Close
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- 2. Create Meeting Modal -->
    <div x-show="createModalOpen" x-cloak
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0"
        x-transition:enter-end="opacity-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100"
        x-transition:leave-end="opacity-0">
        
        <div @click.outside="createModalOpen = false"
            class="bg-slate-900 border border-slate-800 rounded-3xl shadow-2xl max-w-lg w-full p-6 sm:p-7 space-y-5 max-h-[90vh] overflow-y-auto">
            
            <div class="flex items-center justify-between">
                <div>
                    <h3 class="text-xl font-bold text-white">Schedule Meeting</h3>
                    <p class="text-xs text-slate-400">Set up a call, add client details, and choose when to get reminded.</p>
                </div>
                <button @click="createModalOpen = false" class="text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
            </div>

            <!-- Error Banner -->
            <div x-show="createError" x-cloak class="p-3.5 rounded-xl bg-rose-950/60 border border-rose-500/30 text-rose-300 text-xs" x-text="createError"></div>

            <form @submit.prevent="submitCreateForm()" class="space-y-4">
                <!-- Title -->
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">
                        Meeting Title / Purpose <span class="text-rose-400">*</span>
                    </label>
                    <input type="text" x-model="formData.title" required placeholder="e.g. US Client Consultation & Demo"
                        class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                </div>

                <!-- Client Details Grid -->
                <div class="p-3.5 rounded-xl bg-slate-950/60 border border-slate-800/80 space-y-3">
                    <div class="text-[11px] font-bold uppercase tracking-wider text-purple-400 flex items-center gap-1.5">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path></svg>
                        <span>Client Information (Optional)</span>
                    </div>
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        <div>
                            <label class="block text-[11px] font-medium text-slate-400 mb-1">Client Full Name</label>
                            <input type="text" x-model="formData.client_name" placeholder="e.g. David Miller"
                                class="w-full px-3 py-2 bg-slate-900 border border-slate-700/80 rounded-lg text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                        </div>
                        <div>
                            <label class="block text-[11px] font-medium text-slate-400 mb-1">Client Email Address</label>
                            <input type="email" x-model="formData.client_email" placeholder="e.g. david@client.com"
                                class="w-full px-3 py-2 bg-slate-900 border border-slate-700/80 rounded-lg text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                        </div>
                    </div>
                </div>

                <!-- Date & Time Grid -->
                <div class="space-y-2">
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        <div>
                            <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Start Time <span class="text-rose-400">*</span></label>
                            <input type="datetime-local" x-model="formData.start_time" required @change="onStartTimeChange()"
                                class="w-full px-3.5 py-2 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                        </div>
                        <div>
                            <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">End Time <span class="text-rose-400">*</span></label>
                            <input type="datetime-local" x-model="formData.end_time" required
                                class="w-full px-3.5 py-2 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                        </div>
                    </div>
                    <!-- Quick Duration Buttons -->
                    <div class="flex items-center gap-1.5 text-[11px] text-slate-400">
                        <span>Duration:</span>
                        <button type="button" @click="setDuration(30)" class="px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-300">30 min</button>
                        <button type="button" @click="setDuration(45)" class="px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-300">45 min</button>
                        <button type="button" @click="setDuration(60)" class="px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-300">1 hour</button>
                    </div>
                </div>

                <!-- Video Meeting Link -->
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Video Call Link (Google Meet / Zoom / Teams)</label>
                    <div class="relative">
                        <input type="url" x-model="formData.meeting_link" placeholder="https://meet.google.com/xyz-abc or Zoom URL"
                            class="w-full pl-9 pr-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                        <svg class="w-4 h-4 text-indigo-400 absolute left-3 top-2.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg>
                    </div>
                </div>

                <!-- Reminder Selector (Prominent) -->
                <div class="p-3.5 rounded-xl bg-amber-950/30 border border-amber-500/30">
                    <label class="block text-xs font-semibold text-amber-300 mb-1 flex items-center gap-1.5">
                        <svg class="w-4 h-4 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path></svg>
                        <span>Meeting Reminder Alert</span>
                    </label>
                    <select x-model="formData.reminder_minutes"
                        class="w-full px-3 py-2 bg-slate-900 border border-amber-500/40 rounded-lg text-slate-100 text-xs focus:ring-2 focus:ring-amber-500 focus:outline-none">
                        <option value="5">5 Minutes Before</option>
                        <option value="10">10 Minutes Before</option>
                        <option value="15" selected>15 Minutes Before (Recommended)</option>
                        <option value="30">30 Minutes Before</option>
                        <option value="60">1 Hour Before</option>
                        <option value="1440">1 Day Before</option>
                        <option value="0">No Reminder</option>
                    </select>
                    <p class="text-[11px] text-slate-400 mt-1">
                        Schedio will automatically notify you so you never miss this meeting.
                    </p>
                </div>

                <!-- Notes / Agenda -->
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Notes / Agenda (Optional)</label>
                    <textarea x-model="formData.description" rows="2" placeholder="Key topics or things to prepare for the call..."
                        class="w-full px-4 py-2 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none resize-none"></textarea>
                </div>

                <!-- Submit Buttons -->
                <div class="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
                    <button type="button" @click="createModalOpen = false"
                        class="px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition-all">
                        Cancel
                    </button>
                    <button type="submit" :disabled="submitting"
                        class="btn-amber px-5 py-2.5 rounded-xl text-xs font-bold shadow-lg shadow-amber-500/20 cursor-pointer disabled:opacity-50">
                        <span x-text="submitting ? 'Scheduling...' : 'Save & Set Reminder'"></span>
                    </button>
                </div>
            </form>
        </div>
    </div>

</div>

@push('scripts')
<script>
document.addEventListener('alpine:init', () => {
    Alpine.data('schedioCalendar', () => ({
        calendar: null,
        detailsModalOpen: false,
        createModalOpen: false,
        submitting: false,
        createError: null,
        searchQuery: '',
        activeEvent: {},
        formData: {
            entity_type: 'meeting',
            title: '',
            description: '',
            client_name: '',
            client_email: '',
            client_company: '',
            start_time: '',
            end_time: '',
            type: 'virtual',
            meeting_link: '',
            reminder_minutes: 15,
        },

        init() {
            const calendarEl = document.getElementById('calendar');
            const { Calendar, dayGridPlugin, timeGridPlugin, listPlugin, interactionPlugin } = window.FullCalendar;

            this.calendar = new Calendar(calendarEl, {
                plugins: [dayGridPlugin, timeGridPlugin, listPlugin, interactionPlugin],
                initialView: 'timeGridWeek',
                headerToolbar: {
                    left: 'prev,next today',
                    center: 'title',
                    right: 'timeGridWeek,dayGridMonth,timeGridDay,listWeek',
                },
                buttonText: {
                    today: 'Today',
                    timeGridWeek: 'Week',
                    dayGridMonth: 'Month',
                    timeGridDay: 'Day',
                    listWeek: 'Agenda List',
                },
                editable: true,
                selectable: true,
                selectMirror: true,
                dayMaxEvents: true,
                weekends: true,
                nowIndicator: true,
                slotMinTime: '06:00:00',
                slotMaxTime: '23:00:00',
                events: (info, successCallback, failureCallback) => {
                    const params = new URLSearchParams({
                        start: info.startStr,
                        end: info.endStr,
                        type: 'meetings',
                        search: this.searchQuery || '',
                    });

                    axios.get(`/calendar/feed?${params.toString()}`)
                        .then(res => successCallback(res.data))
                        .catch(err => {
                            console.error('Failed to load events:', err);
                            failureCallback(err);
                        });
                },
                eventContent: (arg) => {
                    const title = arg.event.title;
                    const props = arg.event.extendedProps || {};
                    const isClient = !!props.client_name;
                    const hasLink = !!props.meeting_link;
                    const hasReminder = !!props.reminder_minutes;

                    let html = `<div class="p-1 leading-tight overflow-hidden w-full">`;
                    html += `<div class="flex items-center gap-1 font-bold truncate text-[11px] text-white">`;
                    if (hasLink) html += `<span class="shrink-0">📹</span>`;
                    html += `<span class="truncate">${title}</span>`;
                    html += `</div>`;
                    
                    if (isClient) {
                        html += `<div class="text-[10px] text-purple-200 truncate font-medium opacity-90">👤 ${props.client_name}</div>`;
                    }
                    if (hasReminder) {
                        html += `<div class="text-[9px] text-amber-200 truncate flex items-center gap-0.5 opacity-90"><span>🔔</span><span>${props.reminder_minutes}m alert</span></div>`;
                    }
                    html += `</div>`;

                    return { html: html };
                },
                select: (info) => {
                    this.openCreateModalWithRange(info.startStr, info.endStr);
                },
                eventClick: (info) => {
                    this.activeEvent = {
                        id: info.event.id,
                        title: info.event.title,
                        start: info.event.start,
                        end: info.event.end || info.event.start,
                        allDay: info.event.allDay,
                        extendedProps: info.event.extendedProps,
                    };
                    this.detailsModalOpen = true;
                },
                eventDrop: (info) => {
                    this.handleEventTimeChange(info);
                },
                eventResize: (info) => {
                    this.handleEventTimeChange(info);
                },
            });

            this.calendar.render();
        },

        refetchEvents() {
            if (this.calendar) {
                this.calendar.refetchEvents();
            }
        },

        openCreateModal() {
            const now = new Date();
            // Round up to nearest 15 mins
            const coeff = 1000 * 60 * 15;
            const roundedNow = new Date(Math.ceil(now.getTime() / coeff) * coeff);
            const roundedLater = new Date(roundedNow.getTime() + 45 * 60 * 1000);

            this.formData.start_time = this.toLocalISO(roundedNow);
            this.formData.end_time = this.toLocalISO(roundedLater);
            this.formData.title = '';
            this.formData.description = '';
            this.formData.client_name = '';
            this.formData.client_email = '';
            this.formData.client_company = '';
            this.formData.meeting_link = '';
            this.formData.reminder_minutes = 15;
            this.createError = null;
            this.createModalOpen = true;
        },

        openCreateModalWithRange(startStr, endStr) {
            this.openCreateModal();
            const start = new Date(startStr);
            let end = new Date(endStr);
            if (startStr.length <= 10) {
                // Day clicked on month view
                start.setHours(10, 0, 0);
                end = new Date(start.getTime() + 45 * 60 * 1000);
            }
            this.formData.start_time = this.toLocalISO(start);
            this.formData.end_time = this.toLocalISO(end);
        },

        setDuration(minutes) {
            if (!this.formData.start_time) return;
            const start = new Date(this.formData.start_time);
            const end = new Date(start.getTime() + minutes * 60 * 1000);
            this.formData.end_time = this.toLocalISO(end);
        },

        onStartTimeChange() {
            if (this.formData.start_time) {
                const start = new Date(this.formData.start_time);
                const currentEnd = this.formData.end_time ? new Date(this.formData.end_time) : null;
                if (!currentEnd || currentEnd <= start) {
                    const end = new Date(start.getTime() + 45 * 60 * 1000);
                    this.formData.end_time = this.toLocalISO(end);
                }
            }
        },

        toLocalISO(date) {
            const pad = (n) => String(n).padStart(2, '0');
            return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
        },

        formatDate(date) {
            if (!date) return 'N/A';
            const d = new Date(date);
            return d.toLocaleString('en-US', {
                weekday: 'short',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
            });
        },

        handleEventTimeChange(info) {
            const id = info.event.extendedProps?.entity_id;
            const start = info.event.start.toISOString();
            const end = (info.event.end || new Date(info.event.start.getTime() + 2700000)).toISOString();

            axios.patch(`/calendar/meeting/${id}/time`, {
                start_time: start,
                end_time: end,
            })
            .then(res => {
                // Success
            })
            .catch(err => {
                info.revert();
                alert(err.response?.data?.message || 'Failed to update meeting time.');
            });
        },

        submitCreateForm() {
            this.submitting = true;
            this.createError = null;

            axios.post('/calendar', this.formData)
                .then(res => {
                    this.createModalOpen = false;
                    this.submitting = false;
                    this.refetchEvents();
                })
                .catch(err => {
                    this.submitting = false;
                    this.createError = err.response?.data?.message || 'Failed to schedule meeting. Please check inputs.';
                });
        },

        deleteActiveEvent() {
            if (!confirm('Are you sure you want to cancel this meeting?')) return;

            const id = this.activeEvent.extendedProps?.entity_id;

            axios.delete(`/calendar/meeting/${id}`)
                .then(res => {
                    this.detailsModalOpen = false;
                    this.refetchEvents();
                })
                .catch(err => {
                    alert(err.response?.data?.message || 'Failed to cancel meeting.');
                });
        },
    }));
});
</script>
@endpush
@endsection
