<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" class="h-full">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">

    <title>Schedule with {{ $host->name }} &bull; Schedio</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">

    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-full bg-[#15181D] text-slate-100 font-sans antialiased selection:bg-amber-400 selection:text-slate-950 flex flex-col justify-between relative overflow-x-hidden"
    x-data="publicBooking({
        username: '{{ $host->username ?: $host->id }}',
        defaultDuration: {{ $defaultDuration }},
        initialDate: '{{ $dates[0]['date_string'] }}'
    })">

    <!-- Organic Clay & Terracotta Contour Background Vector (Matching Reference Image) -->
    <div class="fixed inset-0 pointer-events-none z-0 overflow-hidden" aria-hidden="true">
        <svg class="absolute w-full h-full object-cover opacity-60" viewBox="0 0 1440 900" fill="none" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">
            <ellipse cx="120" cy="80" rx="360" ry="260" fill="#362923" />
            <ellipse cx="1320" cy="480" rx="420" ry="340" fill="#2B2F38" />
            <ellipse cx="780" cy="220" rx="300" ry="240" fill="#23262E" />
            <ellipse cx="480" cy="780" rx="380" ry="320" fill="#3D3028" />
            <ellipse cx="1280" cy="860" rx="200" ry="200" fill="#322620" />
            <ellipse cx="80" cy="820" rx="140" ry="140" fill="#24282F" />

            <!-- Fluid Contour Line Art -->
            <path d="M-80 340 C 260 200, 380 580, 720 380 C 1060 180, 1220 540, 1520 380" stroke="#C8A168" stroke-width="1.8" stroke-opacity="0.35" fill="none" />
            <path d="M-40 460 C 320 340, 440 680, 820 480 C 1140 280, 1340 640, 1560 480" stroke="#7A808C" stroke-width="1.5" stroke-opacity="0.25" fill="none" />
            <path d="M200 -60 C 260 280, 480 320, 620 580 C 760 840, 940 760, 1120 980" stroke="#C8A168" stroke-width="1.2" stroke-opacity="0.2" fill="none" />
        </svg>
        <div class="absolute inset-0 bg-[#15181D]/60 backdrop-blur-[2px]"></div>
    </div>

    <!-- Top Navigation Header -->
    <header class="relative z-10 w-full border-b border-white/[0.08] bg-[#16191E]/70 backdrop-blur-md">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
            <div class="flex items-center">
                <x-brand-logo size="md" subtitle="Client Appointment Portal" />
            </div>

            <div class="flex items-center gap-3 text-xs">
                @auth
                    <a href="{{ route('dashboard') }}" class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 font-bold border border-slate-700 transition-all flex items-center gap-1.5">
                        <svg class="w-3.5 h-3.5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path></svg>
                        <span>Back to Dashboard</span>
                    </a>
                @else
                    <a href="{{ route('login') }}" class="text-amber-400 hover:text-amber-300 font-bold transition-colors">
                        Sign In &rarr;
                    </a>
                @endauth
            </div>
        </div>
    </header>

    <!-- Main Booking Hub Content -->
    <main class="relative z-10 max-w-6xl w-full mx-auto px-4 sm:px-6 py-8 sm:py-12 flex-1 flex flex-col justify-center">

        <!-- Warm Welcome Headline (Matching Reference Image) -->
        <div class="text-center space-y-2 mb-8">
            <h1 class="text-3xl sm:text-4xl font-extrabold tracking-tight text-amber-400 drop-shadow-sm">
                Warm welcome:)
            </h1>
            <p class="text-xs sm:text-sm text-slate-300 max-w-xl mx-auto leading-relaxed">
                Please book an appointment with our team. Select an available date and time slot below to schedule your consultation.
            </p>
        </div>

        <!-- Outer Glass Container -->
        <div class="glass-panel rounded-3xl border border-white/[0.1] shadow-2xl shadow-black/70 overflow-hidden grid grid-cols-1 lg:grid-cols-12 min-h-[580px]">

            <!-- LEFT COLUMN: Host Profile & Meeting Spec (5 Cols) -->
            <div class="lg:col-span-5 p-6 sm:p-8 bg-[#181B22]/80 border-b lg:border-b-0 lg:border-r border-white/[0.08] flex flex-col justify-between space-y-6">
                <div class="space-y-6">
                    <!-- Host Avatar & Details -->
                    <div class="flex items-center gap-4">
                        <div class="w-16 h-16 rounded-2xl bg-gradient-to-tr from-amber-500 via-amber-400 to-amber-200 text-slate-950 font-black text-2xl flex items-center justify-center shadow-lg shadow-amber-500/25 ring-2 ring-white/20 shrink-0">
                            {{ strtoupper(substr($host->name, 0, 1)) }}
                        </div>
                        <div>
                            <div class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-amber-500/15 text-amber-300 border border-amber-500/30 text-[10px] font-bold uppercase tracking-wider mb-1">
                                <span class="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse"></span>
                                <span>Verified Host</span>
                            </div>
                            <h2 class="text-xl font-extrabold text-white leading-tight">{{ $host->name }}</h2>
                            <p class="text-xs text-slate-400">{{ $host->title ?? 'Executive Consultation' }} &bull; {{ $host->department ? $host->department->name : 'Schedio' }}</p>
                        </div>
                    </div>

                    <!-- Headline / Bio -->
                    <div class="p-4 rounded-2xl bg-black/30 border border-white/[0.06] space-y-2">
                        <div class="text-xs font-bold text-amber-400">
                            {{ $host->booking_headline ?? 'Consultation & Strategy Session' }}
                        </div>
                        <p class="text-xs text-slate-300 leading-relaxed">
                            {{ $host->booking_bio ?? 'Select a time that suits your schedule. We look forward to connecting and discussing your goals in detail.' }}
                        </p>
                    </div>

                    <!-- Duration Selector Pills -->
                    <div class="space-y-2">
                        <label class="text-[11px] font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                            <svg class="w-3.5 h-3.5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                            <span>Select Meeting Duration</span>
                        </label>
                        <div class="grid grid-cols-4 gap-2">
                            @foreach ($durations as $dur)
                                <button type="button" @click="setDuration({{ $dur }})"
                                    :class="selectedDuration === {{ $dur }} ? 'bg-amber-400 text-slate-950 font-black shadow-lg shadow-amber-500/25 border-amber-300' : 'bg-slate-900/60 text-slate-300 hover:text-white border-white/[0.08] hover:border-slate-700'"
                                    class="py-2 px-2 rounded-xl text-xs font-semibold border transition-all text-center cursor-pointer">
                                    {{ $dur }}m
                                </button>
                            @endforeach
                        </div>
                    </div>

                    <!-- Meeting Format Specs -->
                    <div class="space-y-2.5 pt-2 text-xs text-slate-300">
                        <div class="flex items-center gap-2.5">
                            <div class="p-1.5 rounded-lg bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg>
                            </div>
                            <span>Video conference via Google Meet / Schedio link</span>
                        </div>
                        <div class="flex items-center gap-2.5">
                            <div class="p-1.5 rounded-lg bg-amber-500/10 text-amber-400 border border-amber-500/20">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064"></path></svg>
                            </div>
                            <span>Timezone: <strong class="text-white font-mono">{{ $host->timezone ?: 'UTC' }}</strong></span>
                        </div>
                        <div class="flex items-center gap-2.5">
                            <div class="p-1.5 rounded-lg bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                            </div>
                            <span>Automated calendar invites & reminders sent instantly</span>
                        </div>
                    </div>
                </div>

                <!-- Footer Host Status -->
                <div class="pt-4 border-t border-white/[0.08] flex items-center justify-between text-[11px] text-slate-400">
                    <span class="flex items-center gap-1.5">
                        <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
                        <span>Double-Booking Guard Active</span>
                    </span>
                    <span>Powered by Schedio</span>
                </div>
            </div>

            <!-- RIGHT COLUMN: Interactive Date Carousel & Slot Grid (7 Cols) -->
            <div class="lg:col-span-7 p-6 sm:p-8 flex flex-col justify-between space-y-6">

                <!-- 1. Horizontal Date Picker Carousel -->
                <div class="space-y-3">
                    <div class="flex items-center justify-between">
                        <div class="text-xs font-bold uppercase tracking-wider text-slate-400 flex items-center gap-1.5">
                            <svg class="w-4 h-4 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                            <span>Select Date</span>
                        </div>
                        <div class="text-xs font-mono text-slate-400" x-text="dateLabel"></div>
                    </div>

                    <!-- Scrollable Horizontal Date Pills -->
                    <div class="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-thin">
                        @foreach ($dates as $d)
                            <button type="button" @click="selectDate('{{ $d['date_string'] }}')"
                                :class="selectedDate === '{{ $d['date_string'] }}' ? 'bg-amber-400 text-slate-950 font-black shadow-lg shadow-amber-500/25 border-amber-300 scale-[1.03]' : 'bg-slate-900/70 text-slate-300 hover:text-white border-white/[0.08] hover:border-slate-700'"
                                class="date-selector-card min-w-[70px] sm:min-w-[76px] py-3 px-2 rounded-2xl flex flex-col items-center justify-center transition-all cursor-pointer border shrink-0">
                                <span class="text-base sm:text-lg font-bold leading-none">{{ $d['day_number'] }}</span>
                                <span class="text-[10px] font-bold mt-1 tracking-wider uppercase opacity-80">{{ $d['day_name'] }}</span>
                            </button>
                        @endforeach
                    </div>
                </div>

                <!-- 2. Time Slots Section (Reference Image Morning & Afternoon Pills) -->
                <div x-show="!selectedSlot" class="space-y-6">

                    <!-- Loading Indicator -->
                    <div x-show="loadingSlots" class="py-12 text-center space-y-2">
                        <div class="inline-block w-6 h-6 border-2 border-amber-400 border-t-transparent rounded-full animate-spin"></div>
                        <p class="text-xs text-slate-400">Finding conflict-free available slots...</p>
                    </div>

                    <!-- Slots Grid -->
                    <div x-show="!loadingSlots" class="space-y-5">

                        <!-- MORNING SLOTS -->
                        <div class="space-y-2.5">
                            <span class="text-[11px] font-bold uppercase tracking-wider text-slate-400 block">Morning</span>
                            <template x-if="morningSlots.length > 0">
                                <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-2">
                                    <template x-for="slot in morningSlots" :key="slot.start_time">
                                        <button type="button" @click="selectSlot(slot)"
                                            class="time-slot-pill py-2.5 px-2 rounded-xl text-xs font-semibold text-center border transition-all cursor-pointer hover:border-amber-400/80 hover:text-white hover:scale-[1.02]"
                                            :class="selectedSlot && selectedSlot.start_time === slot.start_time ? 'bg-amber-400 text-slate-950 font-black shadow-lg shadow-amber-500/25 border-amber-400' : 'bg-slate-950/60 border-white/[0.1] text-slate-200'">
                                            <span x-text="slot.formatted_time"></span>
                                        </button>
                                    </template>
                                </div>
                            </template>
                            <template x-if="morningSlots.length === 0">
                                <p class="text-xs text-slate-500 italic py-1">No morning slots remaining for this date.</p>
                            </template>
                        </div>

                        <!-- AFTERNOON SLOTS -->
                        <div class="space-y-2.5">
                            <span class="text-[11px] font-bold uppercase tracking-wider text-slate-400 block">Afternoon</span>
                            <template x-if="afternoonSlots.length > 0">
                                <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-2">
                                    <template x-for="slot in afternoonSlots" :key="slot.start_time">
                                        <button type="button" @click="selectSlot(slot)"
                                            class="time-slot-pill py-2.5 px-2 rounded-xl text-xs font-semibold text-center border transition-all cursor-pointer hover:border-amber-400/80 hover:text-white hover:scale-[1.02]"
                                            :class="selectedSlot && selectedSlot.start_time === slot.start_time ? 'bg-amber-400 text-slate-950 font-black shadow-lg shadow-amber-500/25 border-amber-400' : 'bg-slate-950/60 border-white/[0.1] text-slate-200'">
                                            <span x-text="slot.formatted_time"></span>
                                        </button>
                                    </template>
                                </div>
                            </template>
                            <template x-if="afternoonSlots.length === 0">
                                <p class="text-xs text-slate-500 italic py-1">No afternoon slots remaining for this date.</p>
                            </template>
                        </div>

                        <!-- Empty State if No Slots -->
                        <template x-if="morningSlots.length === 0 && afternoonSlots.length === 0">
                            <div class="py-8 text-center bg-slate-950/40 rounded-2xl border border-white/[0.08] p-4 space-y-2">
                                <p class="text-xs text-slate-400 font-medium">No open time slots available on this day.</p>
                                <p class="text-[11px] text-slate-500">Please select another date on the horizontal date picker above.</p>
                            </div>
                        </template>
                    </div>
                </div>

                <!-- 3. Booking Details Form (Smooth Slide-In when Slot Selected) -->
                <div x-show="selectedSlot" x-cloak class="space-y-5">
                    <!-- Selected Slot Summary Pill -->
                    <div class="p-4 rounded-2xl bg-amber-400/10 border border-amber-400/30 flex items-center justify-between gap-3">
                        <div class="space-y-0.5">
                            <div class="text-[10px] font-bold uppercase tracking-wider text-amber-400">Selected Appointment Time</div>
                            <div class="text-sm font-extrabold text-white flex items-center gap-2">
                                <span x-text="dateLabel"></span>
                                <span>&bull;</span>
                                <span class="text-amber-300 font-mono" x-text="selectedSlot?.formatted_time"></span>
                                <span class="text-xs font-semibold text-slate-400" x-text="'(' + selectedDuration + ' mins)'"></span>
                            </div>
                        </div>
                        <button type="button" @click="selectedSlot = null"
                            class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-xs font-bold transition-all cursor-pointer shrink-0">
                            Change Time
                        </button>
                    </div>

                    <!-- Client Input Form -->
                    <form action="{{ route('booking.store', $host->username ?: $host->id) }}" method="POST" class="space-y-4">
                        @csrf
                        <input type="hidden" name="start_time" :value="selectedSlot?.start_time">
                        <input type="hidden" name="duration_minutes" :value="selectedDuration">

                        @if ($errors->any())
                            <div class="p-3.5 rounded-xl bg-rose-950/60 border border-rose-500/30 text-rose-300 text-xs">
                                {{ $errors->first() }}
                            </div>
                        @endif

                        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                            <div>
                                <label class="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1">
                                    Your Full Name <span class="text-rose-400">*</span>
                                </label>
                                <input type="text" name="client_name" required value="{{ old('client_name') }}"
                                    placeholder="e.g. David Miller"
                                    class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-500 focus:outline-none">
                            </div>

                            <div>
                                <label class="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1">
                                    Your Email Address <span class="text-rose-400">*</span>
                                </label>
                                <input type="email" name="client_email" required value="{{ old('client_email') }}"
                                    placeholder="e.g. david@partner.com"
                                    class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-500 focus:outline-none">
                            </div>
                        </div>

                        <div>
                            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1">
                                Company / Organization (Optional)
                            </label>
                            <input type="text" name="client_company" value="{{ old('client_company') }}"
                                placeholder="e.g. Acme Corporation"
                                class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-500 focus:outline-none">
                        </div>

                        <div>
                            <label class="block text-xs font-semibold uppercase tracking-wider text-slate-300 mb-1">
                                What would you like to discuss? (Optional)
                            </label>
                            <textarea name="notes" rows="2" placeholder="Briefly share the topics or agenda for our call..."
                                class="w-full px-4 py-2.5 bg-slate-950/80 border border-slate-700/80 rounded-xl text-slate-100 text-xs focus:ring-2 focus:ring-amber-500 focus:outline-none resize-none">{{ old('notes') }}</textarea>
                        </div>

                        <div class="pt-2 flex items-center justify-between gap-4">
                            <button type="button" @click="selectedSlot = null"
                                class="px-4 py-3 rounded-xl text-xs font-bold text-slate-400 hover:text-white transition-colors">
                                &larr; Back to Slots
                            </button>
                            <button type="submit"
                                class="btn-amber px-6 py-3 rounded-xl text-xs font-extrabold shadow-xl shadow-amber-500/25 cursor-pointer">
                                Confirm Appointment with {{ $host->name }} &rarr;
                            </button>
                        </div>
                    </form>
                </div>

                <!-- Bottom Helper Text -->
                <div class="pt-4 border-t border-white/[0.08] text-[11px] text-slate-500 text-center">
                    Appointments automatically sync to Google Calendar, Microsoft Outlook, and Apple Calendar.
                </div>
            </div>
        </div>
    </main>

    <!-- Footer -->
    <footer class="relative z-10 w-full py-4 border-t border-white/[0.08] bg-[#121418]/60 text-center text-xs text-slate-500">
        &copy; {{ date('Y') }} Schedio Enterprise Scheduling System &bull; Secure Client Booking Link
    </footer>

    <!-- Alpine.js Reactive Controller Script -->
    <script>
    function publicBooking(config) {
        return {
            username: config.username,
            selectedDuration: config.defaultDuration,
            selectedDate: config.initialDate,
            dateLabel: '',
            morningSlots: [],
            afternoonSlots: [],
            selectedSlot: null,
            loadingSlots: false,

            init() {
                this.fetchSlots();
            },

            setDuration(mins) {
                this.selectedDuration = mins;
                this.selectedSlot = null;
                this.fetchSlots();
            },

            selectDate(dateStr) {
                this.selectedDate = dateStr;
                this.selectedSlot = null;
                this.fetchSlots();
            },

            selectSlot(slot) {
                this.selectedSlot = slot;
            },

            async fetchSlots() {
                this.loadingSlots = true;
                try {
                    const url = `/book/${this.username}/slots?date=${encodeURIComponent(this.selectedDate)}&duration=${this.selectedDuration}`;
                    const res = await fetch(url);
                    if (res.ok) {
                        const data = await res.json();
                        this.dateLabel = data.date;
                        this.morningSlots = data.morning || [];
                        this.afternoonSlots = data.afternoon || [];
                    }
                } catch (e) {
                    console.error('Failed to load slots', e);
                } finally {
                    this.loadingSlots = false;
                }
            }
        };
    }
    </script>
</body>
</html>
