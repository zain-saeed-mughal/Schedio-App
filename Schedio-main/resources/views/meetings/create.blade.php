@extends('layouts.app')

@section('title', 'Schedule Meeting — Schedio')

@section('content')
<div class="max-w-4xl mx-auto space-y-6" x-data="meetingScheduler()">

    <!-- Header -->
    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-2xl font-bold text-white tracking-tight flex items-center gap-2.5">
                <span>Schedule Meeting</span>
                <span class="text-xs px-2.5 py-0.5 rounded-full bg-amber-400 text-slate-950 font-bold shadow-sm shadow-amber-500/20">Client & BD Ready</span>
            </h1>
            <p class="text-xs text-slate-400">Schedule meetings for existing BD pipeline clients in 1-click, or create a custom appointment manually with automated reminders.</p>
        </div>
        <a href="{{ request('return_to', old('return_to', route('meetings.index'))) }}" class="text-xs text-slate-400 hover:text-white flex items-center gap-1 transition-colors">
            &larr; Back to {{ (request('return_to') && str_contains(request('return_to'), 'clients')) || (old('return_to') && str_contains(old('return_to'), 'clients')) ? 'Client / Pipeline' : 'Meetings' }}
        </a>
    </div>

    @if ($errors->any())
        <div class="p-4 rounded-xl bg-rose-950/60 border border-rose-500/30 text-rose-300 text-xs space-y-1">
            @foreach ($errors->all() as $error)
                <div class="flex items-center gap-2">
                    <svg class="w-4 h-4 text-rose-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>
                    <span>{{ $error }}</span>
                </div>
            @endforeach
        </div>
    @endif

    <form action="{{ route('meetings.store') }}" method="POST" @submit="if(isSubmitting) { $event.preventDefault(); return; } isSubmitting = true" class="glass-panel rounded-3xl p-6 sm:p-8 shadow-2xl space-y-7 border border-white/[0.08]">
        @csrf
        <input type="hidden" name="return_to" value="{{ request('return_to', old('return_to', '')) }}">

        <!-- MODE SELECTION: TWO CLEAR WAYS TO SCHEDULE -->
        <div class="p-4 rounded-2xl bg-slate-950/70 border border-white/[0.08] space-y-3">
            <span class="text-[10px] font-bold uppercase tracking-wider text-slate-400 block">Select Scheduling Mode</span>
            
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <!-- Mode 1: Existing Client (Fast 1-Click) -->
                <label @click="schedulingMode = 'existing'"
                    class="p-3.5 rounded-2xl border flex items-center gap-3 cursor-pointer transition-all"
                    :class="schedulingMode === 'existing' ? 'bg-amber-400/15 border-amber-400 text-white shadow-md shadow-amber-500/10' : 'bg-slate-900/60 border-slate-800 text-slate-400 hover:border-slate-700'">
                    <input type="radio" name="_mode" value="existing" x-model="schedulingMode" class="sr-only">
                    <div class="w-8 h-8 rounded-xl flex items-center justify-center shrink-0 font-bold text-xs"
                        :class="schedulingMode === 'existing' ? 'bg-amber-400 text-slate-950' : 'bg-slate-800 text-slate-400'">
                        1
                    </div>
                    <div>
                        <div class="text-xs font-bold" :class="schedulingMode === 'existing' ? 'text-amber-300' : 'text-slate-200'">
                            Existing Client (1-Click Fast)
                        </div>
                        <div class="text-[11px] text-slate-400">Select pre-added client, auto-fill details</div>
                    </div>
                </label>

                <!-- Mode 2: Enter Details Manually -->
                <label @click="schedulingMode = 'manual'"
                    class="p-3.5 rounded-2xl border flex items-center gap-3 cursor-pointer transition-all"
                    :class="schedulingMode === 'manual' ? 'bg-amber-400/15 border-amber-400 text-white shadow-md shadow-amber-500/10' : 'bg-slate-900/60 border-slate-800 text-slate-400 hover:border-slate-700'">
                    <input type="radio" name="_mode" value="manual" x-model="schedulingMode" class="sr-only">
                    <div class="w-8 h-8 rounded-xl flex items-center justify-center shrink-0 font-bold text-xs"
                        :class="schedulingMode === 'manual' ? 'bg-amber-400 text-slate-950' : 'bg-slate-800 text-slate-400'">
                        2
                    </div>
                    <div>
                        <div class="text-xs font-bold" :class="schedulingMode === 'manual' ? 'text-amber-300' : 'text-slate-200'">
                            Enter Details Manually
                        </div>
                        <div class="text-[11px] text-slate-400">Type all client & meeting info from scratch</div>
                    </div>
                </label>
            </div>
        </div>

        <!-- MODE 1 CONTENT: SELECT EXISTING CLIENT -->
        <div x-show="schedulingMode === 'existing'" class="space-y-4" x-cloak>
            <div class="p-5 rounded-2xl bg-amber-950/20 border border-amber-500/30 space-y-4">
                <div class="flex items-center justify-between">
                    <div>
                        <h3 class="text-xs font-bold uppercase tracking-wider text-amber-300 flex items-center gap-2">
                            <span>Select Pre-added Client</span>
                        </h3>
                        <p class="text-xs text-slate-400 mt-0.5">Details and company information will be attached automatically.</p>
                    </div>

                    <a href="{{ route('clients.index') }}" target="_blank" class="text-xs text-amber-400 hover:text-amber-300 font-semibold flex items-center gap-1">
                        <span>+ Add New to Pipeline</span>
                        <span>↗</span>
                    </a>
                </div>

                @if(isset($clients) && $clients->isNotEmpty())
                    <div>
                        <select name="client_id" x-model="selectedClientId" @change="onClientSelected($event.target.value)"
                            class="w-full px-4 py-3 bg-slate-950 border border-amber-500/50 rounded-xl text-slate-100 text-xs font-semibold focus:ring-2 focus:ring-amber-400 focus:outline-none cursor-pointer">
                            <option value="">-- Choose a Client from Pipeline ({{ $clients->count() }} available) --</option>
                            @foreach ($clients as $cl)
                                <option value="{{ $cl->id }}" {{ old('client_id', request('client_id')) == $cl->id ? 'selected' : '' }}>
                                    {{ $cl->company_name }} &bull; {{ $cl->contact_name }} ({{ $cl->campaign ?? 'No Campaign' }} &mdash; {{ $cl->status_label }})
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <!-- Client Connected Card Preview -->
                    <template x-if="selectedClientData">
                        <div class="p-4 rounded-xl bg-slate-950/80 border border-emerald-500/30 space-y-2">
                            <div class="flex items-center justify-between">
                                <div class="flex items-center gap-2">
                                    <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
                                    <span class="text-xs font-bold text-white" x-text="selectedClientData.company_name"></span>
                                    <span class="text-[11px] text-slate-400" x-text="'(' + selectedClientData.contact_name + ')'"></span>
                                </div>
                                <span class="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase"
                                    :style="selectedClientData.status_meta?.badge_style || ''"
                                    x-text="selectedClientData.status_label"></span>
                            </div>
                            <div class="text-[11px] text-slate-400 flex items-center gap-3">
                                <span x-text="'Email: ' + (selectedClientData.contact_email || 'None')"></span>
                                <span>&bull;</span>
                                <span x-text="'Campaign: ' + (selectedClientData.campaign || 'Direct')"></span>
                            </div>
                        </div>
                    </template>
                @else
                    <div class="py-4 text-center text-xs text-slate-400 space-y-1">
                        <p>No clients exist in pipeline yet.</p>
                        <a href="{{ route('clients.index') }}" class="text-amber-400 underline font-semibold">Click here to add your first client</a> or switch to "Enter Details Manually" above.
                    </div>
                @endif
            </div>
        </div>

        <!-- MEETING TITLE & AGENDA -->
        <div class="space-y-4">
            <div>
                <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Meeting Title <span class="text-rose-400">*</span></label>
                <input type="text" name="title" x-model="meetingTitle" required placeholder="e.g. Discovery & Pitch Call with Acme Corp"
                    class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-sm focus:ring-2 focus:ring-amber-400 focus:outline-none">
            </div>

            <div>
                <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Agenda / Talking Points</label>
                <textarea name="description" x-model="meetingDescription" rows="2" placeholder="Key topics, architecture discussion, pricing tiers..."
                    class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-sm focus:ring-2 focus:ring-amber-400 focus:outline-none resize-none"></textarea>
            </div>
        </div>

        <!-- MODE 2 CONTENT: MANUAL CLIENT ENTRY -->
        <div x-show="schedulingMode === 'manual'" class="space-y-4 pt-4 border-t border-slate-800" x-cloak>
            <div class="flex items-center justify-between">
                <div>
                    <h3 class="text-xs font-bold uppercase tracking-wider text-purple-400">
                        Client & Contact Information
                    </h3>
                    <p class="text-xs text-slate-400 mt-0.5">Enter details for this client.</p>
                </div>
            </div>

            <input type="hidden" name="is_client_meeting" value="1">

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 p-4 rounded-2xl bg-purple-950/20 border border-purple-800/40">
                <div>
                    <label class="block text-xs font-semibold uppercase text-purple-300 mb-1">Company Name</label>
                    <input type="text" name="client_company" x-model="clientCompany" placeholder="e.g. Acme Corp"
                        class="w-full px-3.5 py-2.5 bg-slate-950/80 border border-purple-700/50 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-purple-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold uppercase text-purple-300 mb-1">Point of Contact Name</label>
                    <input type="text" name="client_name" x-model="clientName" placeholder="e.g. John Doe"
                        class="w-full px-3.5 py-2.5 bg-slate-950/80 border border-purple-700/50 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-purple-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold uppercase text-purple-300 mb-1">Client Email</label>
                    <input type="email" name="client_email" x-model="clientEmail" placeholder="e.g. contact@company.com"
                        class="w-full px-3.5 py-2.5 bg-slate-950/80 border border-purple-700/50 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-purple-500 focus:outline-none">
                </div>

                <div class="sm:col-span-2">
                    <label class="block text-xs font-semibold uppercase text-purple-300 mb-1">Campaign Source (Optional)</label>
                    <input type="text" name="campaign" placeholder="e.g. Cold Email, LinkedIn, Outbound Q4"
                        class="w-full px-3.5 py-2.5 bg-slate-950/80 border border-purple-700/50 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-purple-500 focus:outline-none">
                </div>

                <div class="sm:col-span-1 flex items-center pt-5">
                    <label class="flex items-center gap-2 cursor-pointer text-xs text-amber-300 font-semibold">
                        <input type="checkbox" name="save_as_client" value="1" checked
                            class="rounded bg-slate-950 border-slate-700 text-amber-500 focus:ring-amber-400">
                        <span>Save as Lead in BD Pipeline</span>
                    </label>
                </div>
            </div>
        </div>

        <!-- DATE & TIME & TIMEZONE -->
        <div class="space-y-4 pt-4 border-t border-slate-800">
            <div class="flex items-center justify-between">
                <h3 class="text-xs font-bold uppercase tracking-wider text-amber-400 flex items-center gap-2">
                    <span>Date, Time & Timezone</span>
                </h3>
                <button type="button" @click="fetchSmartSuggestions()"
                    class="text-xs text-amber-400 hover:text-amber-300 flex items-center gap-1 font-semibold cursor-pointer">
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path></svg>
                    <span>Suggest Free Slots</span>
                </button>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Start Time <span class="text-rose-400">*</span></label>
                    <input type="datetime-local" name="start_time" x-model="startTime" required
                        class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-400 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">End Time <span class="text-rose-400">*</span></label>
                    <input type="datetime-local" name="end_time" x-model="endTime" required
                        class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-400 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Timezone <span class="text-rose-400">*</span></label>
                    <select name="timezone" class="w-full px-3 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-400 focus:outline-none">
                        <option value="America/New_York" {{ old('timezone', $user->timezone) === 'America/New_York' ? 'selected' : '' }}>America/New York (EST/EDT)</option>
                        <option value="America/Chicago" {{ old('timezone', $user->timezone) === 'America/Chicago' ? 'selected' : '' }}>America/Chicago (CST/CDT)</option>
                        <option value="America/Los_Angeles" {{ old('timezone', $user->timezone) === 'America/Los_Angeles' ? 'selected' : '' }}>America/Los Angeles (PST/PDT)</option>
                        <option value="Europe/London" {{ old('timezone', $user->timezone) === 'Europe/London' ? 'selected' : '' }}>Europe/London (GMT/BST)</option>
                        <option value="Europe/Paris" {{ old('timezone', $user->timezone) === 'Europe/Paris' ? 'selected' : '' }}>Europe/Paris / Berlin (CET)</option>
                        <option value="Asia/Dubai" {{ old('timezone', $user->timezone) === 'Asia/Dubai' ? 'selected' : '' }}>Asia/Dubai (GST - UAE)</option>
                        <option value="Asia/Karachi" {{ old('timezone', $user->timezone) === 'Asia/Karachi' ? 'selected' : '' }}>Asia/Karachi (PKT)</option>
                        <option value="Asia/Kolkata" {{ old('timezone', $user->timezone) === 'Asia/Kolkata' ? 'selected' : '' }}>Asia/Kolkata (IST)</option>
                        <option value="UTC" {{ old('timezone', $user->timezone) === 'UTC' ? 'selected' : '' }}>UTC Universal</option>
                    </select>
                </div>
            </div>
        </div>

        <!-- VIDEO CALL & LOCATION -->
        <div class="space-y-4 pt-4 border-t border-slate-800">
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Meeting Format <span class="text-rose-400">*</span></label>
                    <select name="type" x-model="meetingType" class="w-full px-3 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-400 focus:outline-none cursor-pointer">
                        <option value="virtual">Virtual Conference (Google Meet / Zoom)</option>
                        <option value="in_person">In Person</option>
                        <option value="hybrid">Hybrid</option>
                    </select>
                </div>

                <div class="sm:col-span-2">
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Video Meeting Link (Google Meet / Zoom / Teams)</label>
                    <input type="url" name="meeting_link" value="{{ old('meeting_link') }}" placeholder="https://meet.google.com/abc-defg-hij"
                        class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-400 focus:outline-none">
                </div>
            </div>
        </div>

        <!-- AUTOMATED PRE-MEETING REMINDERS (THE KEY BD FEATURE) -->
        <div class="p-5 rounded-2xl bg-gradient-to-r from-amber-950/30 via-slate-950 to-slate-900 border border-amber-500/30 space-y-3">
            <div class="flex items-center gap-2">
                <span class="p-1.5 rounded-lg bg-amber-500/20 text-amber-400">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path></svg>
                </span>
                <div>
                    <h3 class="text-xs font-bold uppercase tracking-wider text-amber-300">Automated Pre-Meeting Reminders</h3>
                    <p class="text-[11px] text-slate-400">Timely alerts guarantee you never miss a client pitch session. Reminders are dispatched via In-App & Email.</p>
                </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-1">
                <div>
                    <label class="block text-xs font-semibold uppercase text-amber-400 mb-1">Arm Reminder Before Meeting</label>
                    <select name="reminder_minutes" class="w-full px-3 py-2.5 bg-slate-950/80 border border-amber-500/40 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-400 focus:outline-none cursor-pointer">
                        <option value="15" selected>15 Minutes Before (Recommended for BD)</option>
                        <option value="30">30 Minutes Before</option>
                        <option value="60">1 Hour Before</option>
                        <option value="1440">1 Day Before</option>
                        <option value="0">Do Not Remind</option>
                    </select>
                </div>
                <div class="flex items-center pt-5 text-[11px] text-slate-400">
                    <span>Schedio's Reminder Engine will automatically trigger alerts to your topnav and email.</span>
                </div>
            </div>
        </div>

        <!-- Submit Actions -->
        <div class="flex items-center justify-end gap-3 pt-4 border-t border-white/[0.08]">
            <a href="{{ request('return_to', old('return_to', route('meetings.index'))) }}" class="px-5 py-2.5 rounded-xl bg-white/[0.04] hover:bg-white/[0.08] text-slate-300 text-xs font-semibold border border-white/10 transition-all">
                Cancel
            </a>
            <button type="submit" :disabled="isSubmitting" class="btn-amber px-6 py-2.5 rounded-xl text-xs font-bold shadow-lg shadow-amber-500/20 cursor-pointer disabled:opacity-50">
                <span x-text="isSubmitting ? 'Scheduling...' : 'Confirm & Schedule Meeting'">Confirm & Schedule Meeting</span>
            </button>
        </div>
    </form>
</div>

@push('scripts')
<script>
document.addEventListener('alpine:init', () => {
    const clientsList = @json($clients ?? []);

    Alpine.data('meetingScheduler', () => ({
        isSubmitting: false,
        schedulingMode: '{{ request('client_id') ? "existing" : "manual" }}',
        meetingType: 'virtual',
        meetingTitle: '{{ old('title', '') }}',
        meetingDescription: '{{ old('description', '') }}',
        clientCompany: '{{ old('client_company', '') }}',
        clientName: '{{ old('client_name', '') }}',
        clientEmail: '{{ old('client_email', '') }}',
        selectedClientId: '{{ old('client_id', request('client_id', '')) }}',
        selectedClientData: null,
        startTime: '{{ old('start_time', now()->addHour()->format('Y-m-d\TH:00')) }}',
        endTime: '{{ old('end_time', now()->addHours(2)->format('Y-m-d\TH:00')) }}',
        suggestions: [],

        init() {
            if (this.selectedClientId) {
                this.onClientSelected(this.selectedClientId);
            }
        },

        onClientSelected(id) {
            if (!id) {
                this.selectedClientData = null;
                return;
            }
            const found = clientsList.find(c => c.id == id);
            if (found) {
                this.selectedClientData = found;
                if (!this.meetingTitle || this.meetingTitle.startsWith('Pitch & Demo Call:')) {
                    this.meetingTitle = 'Pitch & Demo Call: ' + found.company_name;
                }
                this.clientCompany = found.company_name;
                this.clientName = found.contact_name;
                this.clientEmail = found.contact_email || '';
                if (!this.meetingDescription) {
                    this.meetingDescription = 'Campaign: ' + (found.campaign || 'Direct') + '. Point of Contact: ' + found.contact_name + '.';
                }
            }
        },

        fetchSmartSuggestions() {
            if (!this.startTime) return;
            const date = this.startTime.split('T')[0];
            axios.get('{{ route('availability.suggestions') }}', {
                params: { date: date, duration_minutes: 60 }
            })
            .then(res => {
                const slots = res.data.slots || [];
                if (slots.length > 0) {
                    this.startTime = slots[0].start_time.substring(0, 16);
                    this.endTime = slots[0].end_time.substring(0, 16);
                } else {
                    alert('No conflict-free slots found for standard working hours on this date.');
                }
            })
            .catch(err => console.error(err));
        }
    }));
});
</script>
@endpush
@endsection
