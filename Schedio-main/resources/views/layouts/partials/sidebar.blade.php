<aside class="fixed inset-y-0 left-0 z-50 w-64 bg-[#16191E]/95 backdrop-blur-2xl border-r border-white/[0.08] flex flex-col justify-between transition-transform duration-300 ease-in-out lg:translate-x-0"
    :class="sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'">

    <!-- Sidebar Header / Brand -->
    <div class="p-4.5 border-b border-white/[0.08] flex items-center justify-between">
        <a href="{{ route('calendar.index') }}" class="flex items-center group">
            <x-brand-logo size="md" :subtitle="auth()->user()?->isDeveloper() ? 'Platform Developer' : (auth()->user()?->company?->name ?? 'Executive Workspace')" />
        </a>

        <!-- Mobile Close Button -->
        <button @click="sidebarOpen = false" class="lg:hidden p-1.5 rounded-xl text-slate-400 hover:text-white hover:bg-white/[0.06] transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
        </button>
    </div>

    <!-- Quick Action: Schedule Meeting (Warm Amber Accent) -->
    <div class="px-4 pt-4 pb-2">
        <a href="{{ route('meetings.create') }}"
            class="btn-amber w-full flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl text-xs shadow-md shadow-amber-500/20 cursor-pointer group">
            <svg class="w-4 h-4 transition-transform group-hover:rotate-90 duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"></path>
            </svg>
            <span>+ Schedule Meeting</span>
        </a>
    </div>

    <!-- Navigation Menu (Using Active Left Amber Bar from Reference UI) -->
    <div class="flex-1 overflow-y-auto px-4 py-3 space-y-4">
        <div class="space-y-1">
            <div class="px-3 text-[10px] font-bold uppercase tracking-wider text-slate-400 mb-2.5">
                Workspace
            </div>

            <!-- Calendar Workspace -->
            <a href="{{ route('calendar.index') }}"
                class="flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-semibold transition-all duration-200 {{ request()->routeIs('calendar.*') ? 'bg-white/[0.08] text-amber-300 border-l-[3px] border-amber-400 pl-2.5 shadow-sm' : 'text-slate-300 hover:text-white hover:bg-white/[0.05]' }}">
                <div class="flex items-center gap-3">
                    <svg class="w-4 h-4 {{ request()->routeIs('calendar.*') ? 'text-amber-400' : 'text-slate-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                    </svg>
                    <span>Calendar Hub</span>
                </div>
                <span class="px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider rounded-full {{ request()->routeIs('calendar.*') ? 'bg-amber-400 text-slate-950' : 'bg-white/10 text-slate-400' }}">Live</span>
            </a>

            <!-- Meetings List -->
            <a href="{{ route('meetings.index') }}"
                class="flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-semibold transition-all duration-200 {{ request()->routeIs('meetings.*') ? 'bg-white/[0.08] text-amber-300 border-l-[3px] border-amber-400 pl-2.5 shadow-sm' : 'text-slate-300 hover:text-white hover:bg-white/[0.05]' }}">
                <div class="flex items-center gap-3">
                    <svg class="w-4 h-4 {{ request()->routeIs('meetings.*') ? 'text-amber-400' : 'text-slate-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
                    </svg>
                    <span>My Meetings</span>
                </div>
            </a>

            <!-- BD Client & Deal Pipeline -->
            <a href="{{ route('clients.index') }}"
                class="flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-semibold transition-all duration-200 {{ request()->routeIs('clients.*') ? 'bg-white/[0.08] text-amber-300 border-l-[3px] border-amber-400 pl-2.5 shadow-sm' : 'text-slate-300 hover:text-white hover:bg-white/[0.05]' }}">
                <div class="flex items-center gap-3">
                    <svg class="w-4 h-4 {{ request()->routeIs('clients.*') ? 'text-amber-400' : 'text-slate-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path>
                    </svg>
                    <span>Clients & Pipeline</span>
                </div>
                <span class="px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider rounded-full {{ request()->routeIs('clients.*') ? 'bg-amber-400 text-slate-950' : 'bg-amber-500/15 text-amber-300 border border-amber-500/30' }}">BD CRM</span>
            </a>

            <!-- Public Booking Link (Cal.com / Calendly style) -->
            <a href="{{ route('booking.show', auth()->user()->username ?: auth()->user()->id) }}" target="_blank"
                class="flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-semibold text-slate-300 hover:text-white hover:bg-white/[0.05] transition-all duration-200 group">
                <div class="flex items-center gap-3">
                    <svg class="w-4 h-4 text-amber-400 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"></path>
                    </svg>
                    <span>My Booking Page</span>
                </div>
                <span class="text-[10px] text-amber-400/80 group-hover:text-amber-300 font-mono flex items-center gap-0.5">
                    <span>↗</span>
                </span>
            </a>

            <!-- Dashboard Overview -->
            <a href="{{ route('dashboard') }}"
                class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-xs font-semibold transition-all duration-200 {{ request()->routeIs('dashboard') ? 'bg-white/[0.08] text-amber-300 border-l-[3px] border-amber-400 pl-2.5 shadow-sm' : 'text-slate-300 hover:text-white hover:bg-white/[0.05]' }}">
                <svg class="w-4 h-4 {{ request()->routeIs('dashboard') ? 'text-amber-400' : 'text-slate-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
                </svg>
                <span>Today's Overview</span>
            </a>

            <!-- Notification & Reminders Center -->
            <a href="{{ route('notifications.index') }}"
                class="flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-semibold transition-all duration-200 {{ request()->routeIs('notifications.*') ? 'bg-white/[0.08] text-amber-300 border-l-[3px] border-amber-400 pl-2.5 shadow-sm' : 'text-slate-300 hover:text-white hover:bg-white/[0.05]' }}">
                <div class="flex items-center gap-3">
                    <svg class="w-4 h-4 {{ request()->routeIs('notifications.*') ? 'text-amber-400' : 'text-slate-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path>
                    </svg>
                    <span>Reminders & Alerts</span>
                </div>
                @php
                    $sidebarUnreadCount = auth()->user()->unreadNotifications()->count();
                @endphp
                @if ($sidebarUnreadCount > 0)
                    <span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-amber-400 text-slate-950 shadow-sm shadow-amber-400/50">
                        {{ $sidebarUnreadCount }}
                    </span>
                @endif
            </a>

            <!-- Meeting Suites & Rooms -->
            <a href="{{ route('rooms.index') }}"
                class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-xs font-semibold transition-all duration-200 {{ request()->routeIs('rooms.*') ? 'bg-white/[0.08] text-amber-300 border-l-[3px] border-amber-400 pl-2.5 shadow-sm' : 'text-slate-300 hover:text-white hover:bg-white/[0.05]' }}">
                <svg class="w-4 h-4 {{ request()->routeIs('rooms.*') ? 'text-amber-400' : 'text-slate-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path>
                </svg>
                <span>Meeting Suites</span>
            </a>

            <!-- Company Events & Holidays -->
            <a href="{{ route('events.index') }}"
                class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-xs font-semibold transition-all duration-200 {{ request()->routeIs('events.*') ? 'bg-white/[0.08] text-amber-300 border-l-[3px] border-amber-400 pl-2.5 shadow-sm' : 'text-slate-300 hover:text-white hover:bg-white/[0.05]' }}">
                <svg class="w-4 h-4 {{ request()->routeIs('events.*') ? 'text-amber-400' : 'text-slate-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                </svg>
                <span>Events & Holidays</span>
            </a>
        </div>

        <!-- Super Admin Section -->
        @if (auth()->user()->isSuperAdmin())
            <div class="space-y-1 pt-3 border-t border-white/[0.08]">
                <div class="px-3 text-[10px] font-bold uppercase tracking-wider text-slate-500 mb-1">
                    Administration
                </div>
                <a href="{{ route('admin.registration-requests.index') }}"
                    class="flex items-center justify-between px-3 py-2 rounded-xl text-xs font-medium transition-all {{ request()->routeIs('admin.registration-requests.*') ? 'bg-white/[0.08] text-amber-300 border-l-[3px] border-amber-400 pl-2.5' : 'text-slate-400 hover:text-white hover:bg-white/[0.04]' }}">
                    <div class="flex items-center gap-2.5">
                        <svg class="w-3.5 h-3.5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"></path>
                        </svg>
                        <span>User Approvals</span>
                    </div>
                    @php
                        $pendingQuery = \App\Models\User::withoutGlobalScopes()->where('approval_status', 'pending');
                        if (auth()->user()->isDeveloper()) {
                            $pendingCount = (clone $pendingQuery)->where('role', '!=', 'developer')->count();
                        } else {
                            $pendingCount = (clone $pendingQuery)->where('company_id', auth()->user()->company_id)->where('role', '!=', 'super_admin')->count();
                        }
                    @endphp
                    @if ($pendingCount > 0)
                        <span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-amber-400 text-slate-950 font-bold">
                            {{ $pendingCount }}
                        </span>
                    @endif
                </a>
            </div>
        @endif
    </div>

    <!-- User Profile & Quick Actions Footer -->
    <div class="p-4 border-t border-white/[0.08] bg-[#111317]/90">
        <div class="flex items-center justify-between">
            <div class="flex items-center gap-3 min-w-0">
                <div class="w-9 h-9 rounded-xl bg-amber-400/20 border border-amber-400/40 flex items-center justify-center font-bold text-amber-300 text-xs shrink-0">
                    {{ strtoupper(substr(auth()->user()->name, 0, 1)) }}
                </div>
                <div class="truncate">
                    <div class="text-xs font-bold text-white truncate flex items-center gap-1.5">
                        <span>{{ auth()->user()->name }}</span>
                    </div>
                    <div class="text-[10px] text-amber-400/90 font-medium truncate">
                        {{ auth()->user()->role_label }}
                    </div>
                </div>
            </div>

            <form action="{{ route('logout') }}" method="POST">
                @csrf
                <button type="submit" class="p-2 rounded-xl text-slate-400 hover:text-amber-400 hover:bg-white/[0.06] transition-colors cursor-pointer" title="Sign Out">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path>
                    </svg>
                </button>
            </form>
        </div>
    </div>
</aside>
