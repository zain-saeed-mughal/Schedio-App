@extends('layouts.app')

@section('title', $admin->isDeveloper() ? 'Developer Console — Registrations & Companies' : 'Super Admin — Team Registrations')

@section('content')
<div class="min-h-full flex flex-col">
    <!-- Top Navigation Header -->
    <header class="bg-slate-900/80 backdrop-blur-md border-b border-slate-800/80 sticky top-0 z-30">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
            <div class="flex items-center gap-6">
                <a href="{{ route('dashboard') }}" class="flex items-center gap-3 group">
                    <x-brand-logo size="sm" :subtitle="$admin->isDeveloper() ? 'Platform Developer' : ($admin->company?->name ?? 'Executive Workspace')" />
                </a>

                <nav class="hidden md:flex items-center gap-1.5 ml-4">
                    <a href="{{ route('dashboard') }}" class="px-3 py-1.5 rounded-lg text-xs font-semibold text-slate-400 hover:text-white hover:bg-slate-800/60 transition-all">
                        &larr; Return to Workspace
                    </a>
                    <span class="text-slate-700">&bull;</span>
                    <a href="{{ route('admin.registration-requests.index') }}" class="px-3 py-1.5 rounded-lg text-xs font-bold text-slate-950 bg-amber-400 border border-amber-300 shadow-sm shadow-amber-500/20">
                        Registration Queue
                        @if ($counts['pending'] > 0)
                            <span class="ml-1.5 px-1.5 py-0.5 text-[10px] font-bold rounded-full bg-slate-950 text-amber-400">
                                {{ $counts['pending'] }}
                            </span>
                        @endif
                    </a>
                </nav>
            </div>

            <div class="flex items-center gap-4">
                <div class="text-right hidden sm:block">
                    <div class="text-xs font-semibold text-slate-200">{{ auth()->user()->name }}</div>
                    <div class="text-[11px] text-amber-400 font-mono font-bold">{{ $admin->role_label }}</div>
                </div>
                <form action="{{ route('logout') }}" method="POST">
                    @csrf
                    <button type="submit" class="p-2 rounded-lg bg-slate-800/80 hover:bg-slate-700/80 text-slate-400 hover:text-slate-200 transition-all text-xs font-medium cursor-pointer" title="Sign Out">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path>
                        </svg>
                    </button>
                </form>
            </div>
        </div>
    </header>

    <!-- Main Content Area -->
    <main class="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">

        @if (session('success'))
            <div class="p-4 rounded-xl bg-emerald-950/60 border border-emerald-500/30 text-emerald-300 text-sm flex items-center gap-3">
                <svg class="w-5 h-5 text-emerald-400 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <span>{{ session('success') }}</span>
            </div>
        @endif

        <!-- Developer Mode Notice -->
        @if ($admin->isDeveloper())
            <div class="p-4 rounded-2xl bg-gradient-to-r from-amber-500/15 via-amber-500/5 to-transparent border border-amber-500/30 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                <div class="flex items-center gap-3">
                    <div class="p-2 rounded-xl bg-amber-400 text-slate-950 font-black">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path></svg>
                    </div>
                    <div>
                        <h2 class="text-sm font-bold text-white flex items-center gap-2">
                            <span>Platform Master Developer Console</span>
                            <span class="text-[10px] px-2 py-0.5 rounded-full bg-amber-400 text-slate-950 font-mono font-bold">ALL ACCESS</span>
                        </h2>
                        <p class="text-xs text-slate-300">
                            You have authority over all company tenant workspaces. You approve newly requested organizations and their Super Admins (CEOs).
                        </p>
                    </div>
                </div>

                <!-- Developer Category Tabs (Companies vs Staff) -->
                <div class="flex items-center gap-1.5 p-1 bg-slate-950/80 rounded-xl border border-white/10 shrink-0">
                    <a href="{{ route('admin.registration-requests.index', ['status' => $status, 'type' => 'companies']) }}"
                        class="px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 {{ $type === 'companies' ? 'bg-amber-400 text-slate-950 shadow-md' : 'text-slate-400 hover:text-white' }}">
                        <span>🏢 Company & Super Admin</span>
                        @if ($pendingCompanyCount > 0)
                            <span class="px-1.5 py-0.2 rounded-full text-[10px] bg-rose-500 text-white font-bold animate-pulse">{{ $pendingCompanyCount }}</span>
                        @endif
                    </a>
                    <a href="{{ route('admin.registration-requests.index', ['status' => $status, 'type' => 'staff']) }}"
                        class="px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 {{ $type === 'staff' ? 'bg-amber-400 text-slate-950 shadow-md' : 'text-slate-400 hover:text-white' }}">
                        <span>👥 Team Staff</span>
                    </a>
                    <a href="{{ route('admin.registration-requests.index', ['status' => $status, 'type' => 'all']) }}"
                        class="px-3 py-1.5 rounded-lg text-xs font-bold transition-all {{ $type === 'all' ? 'bg-amber-400 text-slate-950 shadow-md' : 'text-slate-400 hover:text-white' }}">
                        All
                    </a>
                </div>
            </div>
        @else
            <!-- Company Super Admin Scope Banner -->
            <div class="p-4 rounded-2xl bg-slate-900 border border-slate-800 flex items-center justify-between">
                <div>
                    <h2 class="text-sm font-bold text-white flex items-center gap-2">
                        <span>{{ $admin->company?->name ?? 'Organization' }} Workspace Admin</span>
                        <span class="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 font-mono font-bold">COMPANY SCOPED</span>
                    </h2>
                    <p class="text-xs text-slate-400">
                        Authorizing staff members for your organization. You have full visibility into your company's schedules, tasks, and users.
                    </p>
                </div>
            </div>
        @endif

        <!-- Status Filter Tabs -->
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-slate-800 pb-4">
            <div>
                <h1 class="text-2xl font-bold text-white tracking-tight">
                    {{ $type === 'companies' ? 'Company & CEO Registrations' : 'Registration Queue' }}
                </h1>
                <p class="text-sm text-slate-400">
                    {{ $admin->isDeveloper() ? 'Review company creation and staff requests across tenant organizations.' : 'Review and authorize team members for your organization.' }}
                </p>
            </div>

            <div class="flex items-center gap-2 p-1 bg-slate-900 rounded-xl border border-slate-800">
                <a href="{{ route('admin.registration-requests.index', ['status' => 'pending', 'type' => $type]) }}"
                    class="px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 {{ $status === 'pending' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'text-slate-400 hover:text-white' }}">
                    <span>Pending</span>
                    <span class="px-1.5 py-0.2 rounded-full text-[10px] {{ $status === 'pending' ? 'bg-slate-950/20 text-slate-950 font-bold' : 'bg-slate-800 text-slate-400' }}">{{ $counts['pending'] }}</span>
                </a>
                <a href="{{ route('admin.registration-requests.index', ['status' => 'approved', 'type' => $type]) }}"
                    class="px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 {{ $status === 'approved' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'text-slate-400 hover:text-white' }}">
                    <span>Approved</span>
                    <span class="px-1.5 py-0.2 rounded-full text-[10px] {{ $status === 'approved' ? 'bg-slate-950/20 text-slate-950 font-bold' : 'bg-slate-800 text-slate-400' }}">{{ $counts['approved'] }}</span>
                </a>
                <a href="{{ route('admin.registration-requests.index', ['status' => 'rejected', 'type' => $type]) }}"
                    class="px-3 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 {{ $status === 'rejected' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'text-slate-400 hover:text-white' }}">
                    <span>Rejected</span>
                    <span class="px-1.5 py-0.2 rounded-full text-[10px] {{ $status === 'rejected' ? 'bg-slate-950/20 text-slate-950 font-bold' : 'bg-slate-800 text-slate-400' }}">{{ $counts['rejected'] }}</span>
                </a>
            </div>
        </div>

        <!-- Requests Listing -->
        <div class="bg-slate-900/70 border border-slate-800/80 rounded-2xl shadow-xl overflow-hidden">
            @if ($requests->isEmpty())
                <div class="text-center py-16 px-4">
                    <div class="inline-flex p-4 rounded-2xl bg-slate-800/50 text-slate-500 mb-3">
                        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                        </svg>
                    </div>
                    <h3 class="text-base font-semibold text-slate-300">No {{ ucfirst($status) }} Requests</h3>
                    <p class="text-xs text-slate-500 mt-1">There are no registration requests currently matching this view.</p>
                </div>
            @else
                <div class="divide-y divide-slate-800/80">
                    @foreach ($requests as $req)
                        <div class="p-6 hover:bg-slate-850/40 transition-colors flex flex-col lg:flex-row lg:items-center justify-between gap-6" x-data="{ showRejectModal: false }">
                            <!-- Left: User & Company Details -->
                            <div class="space-y-2 max-w-xl">
                                <div class="flex items-center gap-3">
                                    <div class="w-11 h-11 rounded-2xl {{ $req->isCompanySuperAdmin() ? 'bg-gradient-to-br from-amber-400 to-amber-600 text-slate-950' : 'bg-gradient-to-br from-indigo-500 to-purple-600 text-white' }} flex items-center justify-center font-black shadow-md shrink-0 text-base">
                                        {{ $req->isCompanySuperAdmin() ? '🏢' : strtoupper(substr($req->name, 0, 1)) }}
                                    </div>
                                    <div>
                                        <h3 class="text-base font-bold text-white flex flex-wrap items-center gap-2">
                                            <span>{{ $req->name }}</span>

                                            @if ($req->isCompanySuperAdmin())
                                                <span class="text-[10px] px-2 py-0.5 rounded-full font-bold bg-amber-400 text-slate-950 uppercase tracking-wider font-mono">
                                                    COMPANY SUPER ADMIN (CEO)
                                                </span>
                                            @endif

                                            @if ($req->approval_status === 'pending')
                                                <span class="text-[11px] px-2 py-0.5 rounded-full font-medium bg-amber-500/20 text-amber-300 border border-amber-500/30">Pending Review</span>
                                            @elseif ($req->approval_status === 'approved')
                                                <span class="text-[11px] px-2 py-0.5 rounded-full font-medium bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">Approved ({{ ucfirst($req->role) }})</span>
                                            @elseif ($req->approval_status === 'rejected')
                                                <span class="text-[11px] px-2 py-0.5 rounded-full font-medium bg-rose-500/20 text-rose-300 border border-rose-500/30">Rejected</span>
                                            @endif
                                        </h3>
                                        <div class="text-xs text-slate-400 font-mono">
                                            {{ $req->email }}
                                            @if ($req->phone)
                                                <span class="text-slate-600 mx-1">&bull;</span> {{ $req->phone }}
                                            @endif
                                        </div>
                                    </div>
                                </div>

                                <!-- Organization & Department Badges -->
                                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs pt-1">
                                    <div class="p-2.5 rounded-xl bg-slate-950/70 border border-white/5">
                                        <span class="text-slate-500 block text-[10px] uppercase font-bold tracking-wider">Company Workspace:</span>
                                        <span class="text-amber-300 font-bold flex items-center gap-1.5 mt-0.5">
                                            <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
                                            {{ $req->company?->name ?? 'Unassigned / Global' }}
                                        </span>
                                    </div>
                                    <div class="p-2.5 rounded-xl bg-slate-950/70 border border-white/5">
                                        <span class="text-slate-500 block text-[10px] uppercase font-bold tracking-wider">Title & Department:</span>
                                        <span class="text-slate-300 font-medium block mt-0.5">
                                            {{ $req->title ?? 'Executive' }} &bull; {{ $req->department ? $req->department->name : 'General' }}
                                        </span>
                                    </div>
                                </div>

                                @if ($req->registration_notes)
                                    <div class="p-2.5 rounded-xl bg-slate-950/60 border border-slate-800 text-xs text-slate-300">
                                        <span class="text-slate-500 font-semibold">User Note:</span> "{{ $req->registration_notes }}"
                                    </div>
                                @endif

                                @if ($req->rejection_reason)
                                    <div class="p-2.5 rounded-xl bg-rose-950/40 border border-rose-900/50 text-xs text-rose-300">
                                        <span class="text-rose-400 font-semibold">Rejection Reason:</span> {{ $req->rejection_reason }}
                                    </div>
                                @endif

                                <div class="text-[11px] text-slate-500">
                                    Submitted: {{ $req->created_at->format('M d, Y • h:i A') }} ({{ $req->created_at->diffForHumans() }})
                                </div>
                            </div>

                            <!-- Right: Approval Form or Actions -->
                            @if ($req->approval_status === 'pending')
                                <div class="bg-slate-950/80 p-4 rounded-xl border border-slate-800/80 min-w-[320px] space-y-3">
                                    <form action="{{ route('admin.registration-requests.approve', $req) }}" method="POST" class="space-y-3">
                                        @csrf
                                        @method('PATCH')

                                        @if ($req->isCompanySuperAdmin())
                                            <input type="hidden" name="role" value="super_admin">
                                            <div class="p-2.5 rounded-lg bg-amber-500/10 border border-amber-500/20 text-xs text-amber-300">
                                                <strong>Authorize Organization:</strong> Approving will activate the company workspace <strong>{{ $req->company?->name }}</strong> and grant full tenant administration to this user.
                                            </div>
                                        @else
                                            <div class="grid grid-cols-2 gap-2">
                                                <div>
                                                    <label class="block text-[10px] font-bold uppercase text-slate-400 mb-1">Assign Role</label>
                                                    <select name="role" required class="w-full text-xs px-2.5 py-1.5 bg-slate-900 border border-slate-700 rounded-lg text-slate-200">
                                                        <option value="employee" {{ $req->role === 'employee' ? 'selected' : '' }}>Employee</option>
                                                        <option value="manager" {{ $req->role === 'manager' ? 'selected' : '' }}>Manager</option>
                                                        <option value="client" {{ $req->role === 'client' ? 'selected' : '' }}>Client / External</option>
                                                    </select>
                                                </div>

                                                <div>
                                                    <label class="block text-[10px] font-bold uppercase text-slate-400 mb-1">Department</label>
                                                    <select name="department_id" class="w-full text-xs px-2.5 py-1.5 bg-slate-900 border border-slate-700 rounded-lg text-slate-200">
                                                        <option value="">-- None / General --</option>
                                                        @foreach ($departments as $dept)
                                                            <option value="{{ $dept->id }}" {{ $req->department_id == $dept->id ? 'selected' : '' }}>{{ $dept->name }}</option>
                                                        @endforeach
                                                    </select>
                                                </div>
                                            </div>
                                        @endif

                                        <div class="flex items-center gap-2 pt-1">
                                            <button type="submit" class="flex-1 py-2 px-3 rounded-lg {{ $req->isCompanySuperAdmin() ? 'bg-amber-400 text-slate-950 font-bold hover:bg-amber-300 shadow-md shadow-amber-500/20' : 'bg-emerald-600 hover:bg-emerald-500 text-white font-semibold shadow-md shadow-emerald-600/20' }} text-xs transition-all cursor-pointer">
                                                {{ $req->isCompanySuperAdmin() ? 'Activate Company & Approve CEO' : 'Approve & Grant Access' }}
                                            </button>
                                            <button type="button" @click="showRejectModal = !showRejectModal" class="py-2 px-3 rounded-lg bg-rose-950/60 hover:bg-rose-900/60 border border-rose-700/50 text-rose-300 text-xs font-semibold transition-all cursor-pointer">
                                                Reject
                                            </button>
                                        </div>
                                    </form>

                                    <!-- Inline Reject Prompt -->
                                    <div x-show="showRejectModal" x-cloak class="pt-3 border-t border-slate-800">
                                        <form action="{{ route('admin.registration-requests.reject', $req) }}" method="POST" class="space-y-2">
                                            @csrf
                                            @method('PATCH')
                                            <label class="block text-[10px] font-bold uppercase text-rose-400">Rejection Reason</label>
                                            <input type="text" name="rejection_reason" placeholder="e.g. Identity or company verification incomplete" class="w-full text-xs px-2.5 py-1.5 bg-slate-900 border border-rose-800/60 rounded-lg text-rose-200 placeholder-rose-500/50">
                                            <div class="flex justify-end gap-2">
                                                <button type="button" @click="showRejectModal = false" class="text-[11px] text-slate-400 hover:text-white px-2 py-1">Cancel</button>
                                                <button type="submit" class="text-[11px] bg-rose-600 hover:bg-rose-500 text-white font-semibold px-2.5 py-1 rounded-lg">Confirm Rejection</button>
                                            </div>
                                        </form>
                                    </div>
                                </div>
                            @else
                                <div class="text-right text-xs text-slate-500 space-y-1">
                                    <div>Processed by: <span class="text-slate-300">{{ $req->approver ? $req->approver->name : 'System Admin' }}</span></div>
                                    @if ($req->approved_at)
                                        <div>Date: <span class="text-slate-400">{{ $req->approved_at->format('M d, Y') }}</span></div>
                                    @endif
                                </div>
                            @endif
                        </div>
                    @endforeach
                </div>

                @if ($requests->hasPages())
                    <div class="p-4 border-t border-slate-800">
                        {{ $requests->links() }}
                    </div>
                @endif
            @endif
        </div>
    </main>
</div>
@endsection
