<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" class="h-full">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>Appointment Confirmed &bull; Schedio</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">

    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class="min-h-full bg-[#15181D] text-slate-100 font-sans antialiased selection:bg-amber-400 selection:text-slate-950 flex flex-col justify-between relative overflow-x-hidden">

    <!-- Organic Clay Background Vector -->
    <div class="fixed inset-0 pointer-events-none z-0 overflow-hidden" aria-hidden="true">
        <svg class="absolute w-full h-full object-cover opacity-60" viewBox="0 0 1440 900" fill="none" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">
            <ellipse cx="200" cy="180" rx="400" ry="300" fill="#362923" />
            <ellipse cx="1200" cy="680" rx="420" ry="340" fill="#2B2F38" />
            <ellipse cx="780" cy="320" rx="320" ry="240" fill="#23262E" />
            <path d="M-80 340 C 260 200, 380 580, 720 380 C 1060 180, 1220 540, 1520 380" stroke="#C8A168" stroke-width="1.8" stroke-opacity="0.35" fill="none" />
        </svg>
        <div class="absolute inset-0 bg-[#15181D]/60 backdrop-blur-[2px]"></div>
    </div>

    <!-- Top Navigation Header -->
    <header class="relative z-10 w-full border-b border-white/[0.08] bg-[#16191E]/70 backdrop-blur-md">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
            <div class="flex items-center">
                <x-brand-logo size="md" subtitle="Booking Confirmed" />
            </div>

            <div>
                <a href="{{ route('booking.show', $host->username ?: $host->id) }}" class="text-xs text-amber-400 hover:text-amber-300 font-bold transition-colors">
                    &larr; Book Another
                </a>
            </div>
        </div>
    </header>

    <!-- Main Confirmation Card -->
    <main class="relative z-10 max-w-2xl w-full mx-auto px-4 sm:px-6 py-10 sm:py-16 flex-1 flex flex-col justify-center">

        <div class="glass-panel rounded-3xl border border-white/[0.1] shadow-2xl shadow-black/80 p-6 sm:p-10 space-y-8 text-center relative overflow-hidden">
            <div class="absolute -right-20 -top-20 w-80 h-80 bg-amber-500/10 rounded-full blur-3xl pointer-events-none"></div>

            <!-- Success Checkmark Badge -->
            <div class="relative z-10 flex flex-col items-center space-y-3">
                <div class="w-16 h-16 rounded-2xl bg-amber-400 text-slate-950 flex items-center justify-center shadow-xl shadow-amber-500/30 ring-4 ring-amber-400/20 animate-bounce">
                    <svg class="w-8 h-8 stroke-[3]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"></path></svg>
                </div>
                <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/15 text-emerald-300 border border-emerald-500/30 text-xs font-bold uppercase tracking-wider">
                    <span>Confirmed & Scheduled</span>
                </div>
                <h1 class="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
                    You're all set!
                </h1>
                <p class="text-xs sm:text-sm text-slate-300 max-w-md mx-auto">
                    A confirmation email and calendar invitation have been sent to <strong class="text-white font-mono">{{ $meeting->metadata['client_email'] ?? 'your email' }}</strong>.
                </p>
            </div>

            <!-- Meeting Spec Details Grid -->
            <div class="relative z-10 rounded-2xl bg-black/40 border border-white/[0.08] p-5 text-left space-y-4">
                <div class="border-b border-white/[0.08] pb-3">
                    <div class="text-[10px] font-bold uppercase tracking-wider text-slate-500">Meeting Title</div>
                    <div class="text-base font-extrabold text-white mt-0.5">{{ $meeting->title }}</div>
                </div>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
                    <div>
                        <span class="text-slate-500 font-bold uppercase text-[10px] block">Date & Time</span>
                        <span class="text-white font-bold block mt-0.5">{{ $meeting->start_time->format('l, F j, Y') }}</span>
                        <span class="text-amber-400 font-mono text-[11px] block">{{ $meeting->start_time->format('h:i A') }} &ndash; {{ $meeting->end_time->format('h:i A') }} ({{ $meeting->timezone }})</span>
                    </div>

                    <div>
                        <span class="text-slate-500 font-bold uppercase text-[10px] block">With Host</span>
                        <span class="text-white font-bold block mt-0.5">{{ $host->name }}</span>
                        <span class="text-slate-400 text-[11px] block">{{ $host->title ?? 'Executive Consultation' }}</span>
                    </div>
                </div>

                @if ($meeting->meeting_link)
                    <div class="pt-3 border-t border-white/[0.08] flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                        <div class="text-xs space-y-0.5">
                            <span class="text-slate-500 font-bold uppercase text-[10px] block">Web Conference Link</span>
                            <span class="text-indigo-300 font-mono text-[11px] truncate max-w-xs block">{{ $meeting->meeting_link }}</span>
                        </div>
                        <a href="{{ $meeting->meeting_link }}" target="_blank"
                            class="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs shadow-lg shadow-emerald-600/30 transition-all text-center shrink-0">
                            Open Video Call &rarr;
                        </a>
                    </div>
                @endif
            </div>

            <!-- Calendar Export Action Buttons -->
            <div class="relative z-10 space-y-3">
                <span class="text-xs font-bold uppercase tracking-wider text-slate-400 block">Add to Your Calendar</span>
                <div class="flex flex-col sm:flex-row items-center justify-center gap-3">
                    <!-- Google Calendar -->
                    <a href="{{ $googleCalUrl }}" target="_blank"
                        class="btn-amber w-full sm:w-auto px-5 py-2.5 rounded-xl text-xs font-extrabold shadow-lg shadow-amber-500/20 flex items-center justify-center gap-2">
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M19 4h-1V2h-2v2H8V2H6v2H5c-1.11 0-1.99.9-1.99 2L3 20c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V9h14v11z"/></svg>
                        <span>Add to Google Calendar</span>
                    </a>

                    <!-- Outlook / Apple iCal (.ics) -->
                    <a href="{{ route('booking.export-ical', ['username' => $host->username ?: $host->id, 'meeting' => $meeting->id]) }}"
                        class="w-full sm:w-auto px-5 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs border border-white/[0.1] shadow-md transition-all flex items-center justify-center gap-2">
                        <svg class="w-4 h-4 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>
                        <span>Download Outlook / iCal (.ics)</span>
                    </a>
                </div>
            </div>

            <!-- Back Link -->
            <div class="relative z-10 pt-4 border-t border-white/[0.08] flex items-center justify-between text-xs text-slate-400">
                <span>Need to reschedule? Email {{ $host->email }}</span>
                <a href="{{ route('booking.show', $host->username ?: $host->id) }}" class="text-amber-400 hover:text-amber-300 font-bold">
                    Schedule Another &rarr;
                </a>
            </div>
        </div>
    </main>

    <!-- Footer -->
    <footer class="relative z-10 w-full py-4 border-t border-white/[0.08] bg-[#121418]/60 text-center text-xs text-slate-500">
        &copy; {{ date('Y') }} Schedio Enterprise Scheduling System
    </footer>
</body>
</html>
