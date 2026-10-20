<header class="h-16 bg-[#16191E]/85 backdrop-blur-2xl border-b border-white/[0.08] sticky top-0 z-30 flex items-center justify-between px-4 sm:px-6 lg:px-8">
    <!-- Left: Mobile Menu Trigger & Page Indicator -->
    <div class="flex items-center gap-4">
        <button @click="sidebarOpen = true" class="lg:hidden p-2 rounded-xl bg-white/[0.06] text-slate-300 hover:text-white hover:bg-white/[0.1] transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
            </svg>
        </button>

        <div class="hidden sm:flex items-center gap-2.5 text-xs">
            <span class="font-extrabold text-white text-sm tracking-tight">
                @if (request()->routeIs('calendar.*'))
                    Calendar Hub
                @elseif (request()->routeIs('meetings.*'))
                    My Meetings
                @elseif (request()->routeIs('dashboard'))
                    Today's Overview
                @elseif (request()->routeIs('notifications.*'))
                    Reminders & Alerts
                @elseif (request()->routeIs('rooms.*'))
                    Meeting Suites
                @elseif (request()->routeIs('events.*'))
                    Events & Holidays
                @else
                    Workspace
                @endif
            </span>
            <span class="text-slate-600">&bull;</span>
            <span class="text-slate-400 font-medium flex items-center gap-1.5">
                <span class="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse"></span>
                <span>{{ now()->format('l, M j') }}</span>
            </span>
        </div>
    </div>

    <!-- Right: Quick Actions & Notification Bell -->
    <div class="flex items-center gap-3">
        <!-- Quick New Meeting Button (Golden Amber Accent) -->
        <a href="{{ route('meetings.create') }}"
            class="btn-amber hidden sm:inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs shadow-md shadow-amber-500/20 cursor-pointer">
            <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"></path>
            </svg>
            <span>+ New Meeting</span>
        </a>

        <!-- Notification Area Dropdown with Real-Time Alpine State -->
        @php
            $headerUnreadCount = auth()->user()->unreadNotifications()->count();
            $recentHeaderNotifications = auth()->user()->notifications()->latest()->take(5)->get();
        @endphp
        <div class="relative" x-data="{
            open: false,
            unreadCount: {{ $headerUnreadCount }},
            notifications: {{ Js::from($recentHeaderNotifications->map(function($n) {
                return [
                    'id' => $n->id,
                    'read' => $n->read_at !== null,
                    'title' => $n->data['title'] ?? 'Notification',
                    'message' => $n->data['message'] ?? '',
                    'action_url' => $n->data['action_url'] ?? route('notifications.index'),
                    'time' => $n->created_at->diffForHumans(),
                    'color' => $n->data['color'] ?? 'amber',
                ];
            })) }},
            async markRead(id, url) {
                try {
                    await fetch(`/notifications/${id}/read`, {
                        method: 'PATCH',
                        headers: {
                            'X-CSRF-TOKEN': document.querySelector('meta[name=csrf-token]').content,
                            'Accept': 'application/json'
                        }
                    });
                    const item = this.notifications.find(n => n.id === id);
                    if (item && !item.read) {
                        item.read = true;
                        this.unreadCount = Math.max(0, this.unreadCount - 1);
                    }
                    if (url) window.location.href = url;
                } catch (e) {
                    if (url) window.location.href = url;
                }
            },
            async markAllRead() {
                try {
                    await fetch('/notifications/mark-all-read', {
                        method: 'POST',
                        headers: {
                            'X-CSRF-TOKEN': document.querySelector('meta[name=csrf-token]').content,
                            'Accept': 'application/json'
                        }
                    });
                    this.notifications.forEach(n => n.read = true);
                    this.unreadCount = 0;
                } catch (e) {}
            },
            async pollFeed() {
                try {
                    const res = await fetch('/notifications/feed');
                    if (res.ok) {
                        const data = await res.json();
                        this.unreadCount = data.unread_count;
                    }
                } catch (e) {}
            }
        }" x-init="setInterval(() => pollFeed(), 30000)">
            <button @click="open = !open" @click.outside="open = false"
                class="p-2.5 rounded-xl bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 text-slate-300 hover:text-white relative transition-all cursor-pointer">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path>
                </svg>
                <template x-if="unreadCount > 0">
                    <span class="absolute top-1 right-1 px-1.5 py-0.2 min-w-4 text-[10px] font-bold text-slate-950 bg-amber-400 rounded-full text-center leading-tight ring-2 ring-slate-900 shadow-sm animate-pulse"
                        x-text="unreadCount"></span>
                </template>
            </button>

            <!-- Dropdown Panel -->
            <div x-show="open" x-cloak
                x-transition:enter="transition ease-out duration-150"
                x-transition:enter-start="opacity-0 scale-95"
                x-transition:enter-end="opacity-100 scale-100"
                x-transition:leave="transition ease-in duration-100"
                x-transition:leave-start="opacity-100 scale-100"
                x-transition:leave-end="opacity-0 scale-95"
                class="absolute right-0 mt-2 w-80 sm:w-96 bg-[#16191E]/95 backdrop-blur-2xl border border-white/10 rounded-2xl shadow-2xl py-3 z-50 overflow-hidden">
                <div class="px-4 pb-2 border-b border-white/[0.08] flex items-center justify-between">
                    <div class="flex items-center gap-2">
                        <span class="text-xs font-bold uppercase tracking-wider text-slate-200">Activity Center</span>
                        <span class="text-[10px] px-2 py-0.5 rounded-full bg-amber-400/20 text-amber-300 font-mono font-bold border border-amber-400/30" x-text="`${unreadCount} Unread`"></span>
                    </div>
                    <template x-if="unreadCount > 0">
                        <button @click="markAllRead()" class="text-[11px] text-amber-400 hover:text-amber-300 font-medium cursor-pointer transition-colors">
                            Mark all read
                        </button>
                    </template>
                </div>

                <div class="max-h-80 overflow-y-auto divide-y divide-white/[0.06]">
                    <template x-for="item in notifications" :key="item.id">
                        <div class="p-3.5 hover:bg-white/[0.04] transition-colors cursor-pointer"
                            :class="item.read ? 'opacity-70' : 'bg-amber-400/[0.05]'"
                            @click="markRead(item.id, item.action_url)">
                            <div class="flex items-start gap-2.5">
                                <div class="w-2 h-2 rounded-full mt-1.5 shrink-0"
                                    :class="item.read ? 'bg-slate-600' : 'bg-amber-400 ring-2 ring-amber-400/30'"></div>
                                <div class="flex-1 min-w-0">
                                    <div class="text-xs font-bold text-slate-200" x-text="item.title"></div>
                                    <div class="text-xs text-slate-400 mt-0.5 leading-snug line-clamp-2" x-text="item.message"></div>
                                    <div class="text-[10px] text-slate-500 font-mono mt-1" x-text="item.time"></div>
                                </div>
                            </div>
                        </div>
                    </template>
                    <template x-if="notifications.length === 0">
                        <div class="py-8 text-center text-xs text-slate-500">
                            No notifications at this time.
                        </div>
                    </template>
                </div>

                <div class="pt-2 px-4 border-t border-white/[0.08] flex items-center justify-between text-xs">
                    <a href="{{ route('notifications.index') }}" class="text-amber-400 hover:text-amber-300 font-semibold flex items-center gap-1">
                        <span>Open Notification Center</span>
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
                    </a>
                </div>
            </div>
        </div>

        <!-- Profile Menu Dropdown -->
        <div class="relative" x-data="{ userMenuOpen: false }">
            <button @click="userMenuOpen = !userMenuOpen" @click.outside="userMenuOpen = false"
                class="flex items-center gap-2 p-1.5 pl-2.5 pr-3 rounded-xl bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 transition-all cursor-pointer">
                <div class="w-6 h-6 rounded-lg bg-amber-400 text-slate-950 flex items-center justify-center font-bold text-[10px]">
                    {{ strtoupper(substr(auth()->user()->name, 0, 1)) }}
                </div>
                <span class="text-xs font-semibold text-slate-200 hidden sm:inline">{{ auth()->user()->name }}</span>
                <svg class="w-3.5 h-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
                </svg>
            </button>

            <!-- User Menu Panel -->
            <div x-show="userMenuOpen" x-cloak
                x-transition:enter="transition ease-out duration-150"
                x-transition:enter-start="opacity-0 scale-95"
                x-transition:enter-end="opacity-100 scale-100"
                x-transition:leave="transition ease-in duration-100"
                x-transition:leave-start="opacity-100 scale-100"
                x-transition:leave-end="opacity-0 scale-95"
                class="absolute right-0 mt-2 w-56 bg-[#16191E] border border-white/10 rounded-2xl shadow-2xl py-2 z-50">
                
                <div class="px-4 py-2 border-b border-white/[0.08]">
                    <div class="text-xs font-bold text-white">{{ auth()->user()->name }}</div>
                    <div class="text-[11px] text-slate-400 font-mono truncate">{{ auth()->user()->email }}</div>
                    <div class="mt-1">
                        @if (auth()->user()->isSuperAdmin())
                            <span class="text-[10px] font-bold px-2 py-0.5 rounded bg-amber-400/20 text-amber-300 border border-amber-400/30">Super Admin</span>
                        @elseif (auth()->user()->role === 'client')
                            <span class="text-[10px] font-bold px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">Client Partner</span>
                        @else
                            <span class="text-[10px] font-medium text-slate-400 capitalize">{{ auth()->user()->role }} &bull; {{ auth()->user()->department?->name ?? 'Staff' }}</span>
                        @endif
                    </div>
                </div>

                @if (auth()->user()->isSuperAdmin())
                    <a href="{{ route('admin.registration-requests.index') }}" class="flex items-center gap-2.5 px-4 py-2 text-xs text-slate-300 hover:text-amber-300 hover:bg-white/[0.04] transition-colors">
                        <svg class="w-3.5 h-3.5 text-amber-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"></path></svg>
                        <span>Manage Registrations</span>
                    </a>
                @endif

                <form action="{{ route('logout') }}" method="POST" class="pt-1 border-t border-white/[0.08]">
                    @csrf
                    <button type="submit" class="w-full flex items-center gap-2.5 px-4 py-2 text-xs text-rose-400 hover:text-rose-300 hover:bg-rose-950/30 transition-colors text-left cursor-pointer">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path></svg>
                        <span>Sign Out</span>
                    </button>
                </form>
            </div>
        </div>
    </div>
</header>
