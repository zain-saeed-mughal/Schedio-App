@extends('layouts.app')

@section('title', 'Edit Meeting — ' . $meeting->title)

@section('content')
<div class="max-w-4xl mx-auto space-y-6" x-data="{ isClientMeeting: {{ (isset($meeting->metadata['is_client_meeting']) && $meeting->metadata['is_client_meeting']) ? 'true' : 'false' }}, meetingType: '{{ $meeting->type }}' }">

    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-2xl font-bold text-white tracking-tight">Edit Meeting</h1>
            <p class="text-xs text-slate-400">Update schedule, client parameters, or invited team members.</p>
        </div>
        <a href="{{ route('meetings.show', $meeting) }}" class="text-xs text-slate-400 hover:text-white flex items-center gap-1 transition-colors">
            &larr; Back to Meeting Details
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

    <form action="{{ route('meetings.update', $meeting) }}" method="POST" class="bg-slate-900/80 border border-slate-800/80 rounded-3xl p-6 sm:p-8 shadow-2xl space-y-6">
        @csrf
        @method('PUT')

        <!-- Core Meeting Info -->
        <div class="space-y-4">
            <h3 class="text-xs font-bold uppercase tracking-wider text-indigo-400">1. Basic Information</h3>

            <div>
                <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Meeting Title <span class="text-rose-400">*</span></label>
                <input type="text" name="title" required value="{{ old('title', $meeting->title) }}"
                    class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-sm focus:ring-2 focus:ring-indigo-500 focus:outline-none">
            </div>

            <div>
                <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Agenda / Description</label>
                <textarea name="description" rows="3"
                    class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-sm focus:ring-2 focus:ring-indigo-500 focus:outline-none resize-none">{{ old('description', $meeting->description) }}</textarea>
            </div>
        </div>

        <!-- Date, Time & Timezone -->
        <div class="space-y-4 pt-4 border-t border-slate-800">
            <h3 class="text-xs font-bold uppercase tracking-wider text-indigo-400">2. Time & Timezone</h3>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Start Time <span class="text-rose-400">*</span></label>
                    <input type="datetime-local" name="start_time" required value="{{ old('start_time', $meeting->start_time->format('Y-m-d\TH:i')) }}"
                        class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">End Time <span class="text-rose-400">*</span></label>
                    <input type="datetime-local" name="end_time" required value="{{ old('end_time', $meeting->end_time->format('Y-m-d\TH:i')) }}"
                        class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Timezone</label>
                    <select name="timezone" class="w-full px-3 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                        <option value="America/New_York" {{ old('timezone', $meeting->timezone) === 'America/New_York' ? 'selected' : '' }}>America/New_York (EST)</option>
                        <option value="America/Chicago" {{ old('timezone', $meeting->timezone) === 'America/Chicago' ? 'selected' : '' }}>America/Chicago (CST)</option>
                        <option value="America/Los_Angeles" {{ old('timezone', $meeting->timezone) === 'America/Los_Angeles' ? 'selected' : '' }}>America/Los_Angeles (PST)</option>
                        <option value="Europe/London" {{ old('timezone', $meeting->timezone) === 'Europe/London' ? 'selected' : '' }}>Europe/London (GMT)</option>
                        <option value="Asia/Dubai" {{ old('timezone', $meeting->timezone) === 'Asia/Dubai' ? 'selected' : '' }}>Asia/Dubai (GST - UAE)</option>
                        <option value="Asia/Karachi" {{ old('timezone', $meeting->timezone) === 'Asia/Karachi' ? 'selected' : '' }}>Asia/Karachi (PKT)</option>
                        <option value="Asia/Kolkata" {{ old('timezone', $meeting->timezone) === 'Asia/Kolkata' ? 'selected' : '' }}>Asia/Kolkata (IST)</option>
                        <option value="UTC" {{ old('timezone', $meeting->timezone) === 'UTC' ? 'selected' : '' }}>UTC</option>
                    </select>
                </div>
            </div>
        </div>

        <!-- Format & Video Link -->
        <div class="space-y-4 pt-4 border-t border-slate-800">
            <h3 class="text-xs font-bold uppercase tracking-wider text-indigo-400">3. Video Conference & Platform</h3>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Format</label>
                    <select name="type" x-model="meetingType" class="w-full px-3 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                        <option value="virtual">Virtual Online Call</option>
                        <option value="hybrid">Hybrid</option>
                        <option value="in_person">In Person</option>
                    </select>
                </div>

                <div class="sm:col-span-2">
                    <label class="block text-xs font-semibold uppercase text-slate-300 mb-1">Video Meeting URL (Google Meet / Zoom / Teams)</label>
                    <input type="url" name="meeting_link" value="{{ old('meeting_link', $meeting->meeting_link) }}" placeholder="https://meet.google.com/xyz-abc"
                        class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-indigo-500 focus:outline-none">
                </div>
            </div>
        </div>

        <!-- Client Details -->
        <div class="space-y-4 pt-4 border-t border-slate-800">
            <h3 class="text-xs font-bold uppercase tracking-wider text-purple-400">4. Client Information (Optional)</h3>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 p-4 rounded-2xl bg-purple-950/20 border border-purple-800/40">
                <div>
                    <label class="block text-xs font-semibold uppercase text-purple-300 mb-1">Client Name</label>
                    <input type="text" name="client_name" value="{{ old('client_name', $meeting->metadata['client_name'] ?? '') }}"
                        class="w-full px-3.5 py-2 bg-slate-950/80 border border-purple-700/50 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-purple-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold uppercase text-purple-300 mb-1">Client Email</label>
                    <input type="email" name="client_email" value="{{ old('client_email', $meeting->metadata['client_email'] ?? '') }}"
                        class="w-full px-3.5 py-2 bg-slate-950/80 border border-purple-700/50 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-purple-500 focus:outline-none">
                </div>
                <div>
                    <label class="block text-xs font-semibold uppercase text-purple-300 mb-1">Company / Country</label>
                    <input type="text" name="client_company" value="{{ old('client_company', $meeting->metadata['client_company'] ?? '') }}"
                        class="w-full px-3.5 py-2 bg-slate-950/80 border border-purple-700/50 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-purple-500 focus:outline-none">
                </div>
            </div>
        </div>

        <!-- Participants & Privacy -->
        <div class="space-y-4 pt-4 border-t border-slate-800">
            <h3 class="text-xs font-bold uppercase tracking-wider text-indigo-400">5. Participants</h3>

            <div class="max-h-48 overflow-y-auto p-3 bg-slate-950/80 border border-slate-700/80 rounded-2xl grid grid-cols-1 sm:grid-cols-2 gap-2">
                @foreach ($users as $u)
                    @if ($u->id != $meeting->organizer_id)
                        <label class="flex items-center gap-2.5 p-2 hover:bg-slate-800/60 rounded-xl text-xs text-slate-300 cursor-pointer">
                            <input type="checkbox" name="participant_ids[]" value="{{ $u->id }}"
                                {{ in_array($u->id, old('participant_ids', $selectedParticipants)) ? 'checked' : '' }}
                                class="rounded bg-slate-900 border-slate-700 text-indigo-600 focus:ring-indigo-500">
                            <div>
                                <div class="font-semibold text-slate-200">{{ $u->name }}</div>
                                <div class="text-[10px] text-slate-500 font-mono">{{ $u->email }}</div>
                            </div>
                        </label>
                    @endif
                @endforeach
            </div>

            <div class="flex items-center gap-2 pt-2">
                <input type="checkbox" id="is_private" name="is_private" value="1" {{ old('is_private', $meeting->is_private) ? 'checked' : '' }}
                    class="rounded bg-slate-900 border-slate-700 text-indigo-600 focus:ring-indigo-500">
                <label for="is_private" class="text-xs text-slate-300 font-medium cursor-pointer">
                    Private Meeting (Visible only to organizer and invited participants)
                </label>
            </div>
        </div>

        <!-- Actions -->
        <div class="flex items-center justify-end gap-3 pt-6 border-t border-slate-800">
            <a href="{{ route('meetings.show', $meeting) }}" class="px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition-all">
                Cancel
            </a>
            <button type="submit" class="px-6 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold shadow-lg shadow-indigo-600/30 transition-all cursor-pointer">
                Update Meeting Details
            </button>
        </div>
    </form>
</div>
@endsection
