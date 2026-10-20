@extends('layouts.app')

@section('title', 'Request Workspace Access')

@section('content')
<div class="min-h-full flex flex-col justify-center py-10 sm:px-6 lg:px-8" x-data="{ regType: '{{ old('registration_type', 'company_super_admin') }}' }">
    <div class="sm:mx-auto sm:w-full sm:max-w-xl text-center">
        <!-- Logo Badge -->
        <div class="flex justify-center mb-4">
            <x-brand-logo size="lg" :showText="false" />
        </div>
        <h1 class="text-3xl font-extrabold tracking-tight text-white">
            Schedio Enterprise Registration
        </h1>
        <p class="mt-1.5 text-xs sm:text-sm text-slate-400 max-w-md mx-auto">
            Establish a new multi-tenant company workspace or request access to join your team.
        </p>
    </div>

    <div class="mt-6 sm:mx-auto sm:w-full sm:max-w-xl">
        <div class="glass-panel py-7 px-6 shadow-2xl shadow-black/60 rounded-3xl border border-amber-500/20 sm:px-10">

            @if ($errors->any())
                <div class="mb-5 p-4 rounded-xl bg-rose-950/60 border border-rose-500/30 text-rose-300 text-sm space-y-1">
                    @foreach ($errors->all() as $error)
                        <div class="flex items-start gap-2">
                            <svg class="w-4 h-4 text-rose-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
                            </svg>
                            <span>{{ $error }}</span>
                        </div>
                    @endforeach
                </div>
            @endif

            <!-- Registration Mode Toggle (Pill Switcher) -->
            <div class="mb-6 p-1 rounded-2xl bg-slate-900/80 border border-white/10 flex items-center gap-1">
                <button type="button" @click="regType = 'company_super_admin'"
                    :class="regType === 'company_super_admin' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'text-slate-400 hover:text-white'"
                    class="flex-1 py-2.5 px-3 rounded-xl text-xs sm:text-sm font-semibold transition-all duration-200 flex items-center justify-center gap-2 cursor-pointer">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path></svg>
                    <span>Register New Company (CEO)</span>
                </button>
                <button type="button" @click="regType = 'employee'"
                    :class="regType === 'employee' ? 'bg-amber-400 text-slate-950 font-bold shadow-md shadow-amber-500/20' : 'text-slate-400 hover:text-white'"
                    class="flex-1 py-2.5 px-3 rounded-xl text-xs sm:text-sm font-semibold transition-all duration-200 flex items-center justify-center gap-2 cursor-pointer">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path></svg>
                    <span>Join Existing Team</span>
                </button>
            </div>

            <form class="space-y-4" action="{{ route('register.post') }}" method="POST">
                @csrf
                <input type="hidden" name="registration_type" :value="regType">

                <!-- Mode A: Company Super Admin Details -->
                <div x-show="regType === 'company_super_admin'" x-cloak class="space-y-4">
                    <div class="p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/25 flex items-start gap-2.5 text-xs text-amber-200">
                        <svg class="w-4 h-4 text-amber-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                        <span>You are creating an independent company workspace as **Super Admin / CEO**. Your request will be routed directly to the **Platform Developer** for approval.</span>
                    </div>

                    <div>
                        <label for="company_name" class="block text-xs font-semibold uppercase tracking-wider text-amber-300">
                            Organization / Company Name <span class="text-rose-400">*</span>
                        </label>
                        <input id="company_name" name="company_name" type="text"
                            :required="regType === 'company_super_admin'"
                            value="{{ old('company_name') }}"
                            placeholder="e.g. Apex Global Logistics, Initech Solutions"
                            class="mt-1 w-full px-4 py-2.5 bg-slate-950/80 border border-amber-500/40 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm font-medium">
                    </div>
                </div>

                <!-- Mode B: Employee Company Selection -->
                <div x-show="regType === 'employee'" x-cloak class="space-y-4">
                    <div class="p-3.5 rounded-2xl bg-sky-500/10 border border-sky-500/25 flex items-start gap-2.5 text-xs text-sky-200">
                        <svg class="w-4 h-4 text-sky-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                        <span>Select your organization. Your staff request will be reviewed and authorized by your **Company Super Admin (CEO)**.</span>
                    </div>

                    <div>
                        <label for="company_id" class="block text-xs font-semibold uppercase tracking-wider text-slate-300">
                            Select Organization <span class="text-rose-400">*</span>
                        </label>
                        <select id="company_id" name="company_id"
                            class="mt-1 w-full px-4 py-2.5 bg-slate-950/60 border border-slate-700/80 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm">
                            <option value="">-- Choose Active Company Workspace --</option>
                            @foreach ($companies as $comp)
                                <option value="{{ $comp->id }}" {{ old('company_id') == $comp->id ? 'selected' : '' }}>
                                    {{ $comp->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>

                    <div>
                        <label for="department_id" class="block text-xs font-semibold uppercase tracking-wider text-slate-300">
                            Department / Team (Optional)
                        </label>
                        <select id="department_id" name="department_id"
                            class="mt-1 w-full px-4 py-2.5 bg-slate-950/60 border border-slate-700/80 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm">
                            <option value="">-- Select Team --</option>
                            @foreach ($departments as $dept)
                                <option value="{{ $dept->id }}" {{ old('department_id') == $dept->id ? 'selected' : '' }}>
                                    {{ $dept->name }}
                                </option>
                            @endforeach
                        </select>
                    </div>
                </div>

                <!-- Common Profile Fields -->
                <!-- Name -->
                <div>
                    <label for="name" class="block text-xs font-semibold uppercase tracking-wider text-slate-300">
                        Full Name <span class="text-rose-400">*</span>
                    </label>
                    <input id="name" name="name" type="text" required value="{{ old('name') }}"
                        placeholder="e.g. Elena Rostova"
                        class="mt-1 w-full px-4 py-2.5 bg-slate-950/60 border border-slate-700/80 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm">
                </div>

                <!-- Email -->
                <div>
                    <label for="email" class="block text-xs font-semibold uppercase tracking-wider text-slate-300">
                        Work Email Address <span class="text-rose-400">*</span>
                    </label>
                    <input id="email" name="email" type="email" required value="{{ old('email') }}"
                        placeholder="elena@company.com"
                        class="mt-1 w-full px-4 py-2.5 bg-slate-950/60 border border-slate-700/80 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm">
                </div>

                <!-- Designation / Title & Phone Grid -->
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                        <label for="title" class="block text-xs font-semibold uppercase tracking-wider text-slate-300">
                            Designation / Job Title
                        </label>
                        <input id="title" name="title" type="text" value="{{ old('title') }}"
                            placeholder="e.g. CEO / Lead Engineer"
                            class="mt-1 w-full px-4 py-2.5 bg-slate-950/60 border border-slate-700/80 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm">
                    </div>

                    <div>
                        <label for="phone" class="block text-xs font-semibold uppercase tracking-wider text-slate-300">
                            Phone Number
                        </label>
                        <input id="phone" name="phone" type="text" value="{{ old('phone') }}"
                            placeholder="+1 (555) 000-0000"
                            class="mt-1 w-full px-4 py-2.5 bg-slate-950/60 border border-slate-700/80 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm">
                    </div>
                </div>

                <!-- Password & Confirm Grid -->
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                        <label for="password" class="block text-xs font-semibold uppercase tracking-wider text-slate-300">
                            Password <span class="text-rose-400">*</span>
                        </label>
                        <input id="password" name="password" type="password" required
                            placeholder="Min 8 characters"
                            class="mt-1 w-full px-4 py-2.5 bg-slate-950/60 border border-slate-700/80 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm">
                    </div>

                    <div>
                        <label for="password_confirmation" class="block text-xs font-semibold uppercase tracking-wider text-slate-300">
                            Confirm Password <span class="text-rose-400">*</span>
                        </label>
                        <input id="password_confirmation" name="password_confirmation" type="password" required
                            placeholder="Re-type password"
                            class="mt-1 w-full px-4 py-2.5 bg-slate-950/60 border border-slate-700/80 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm">
                    </div>
                </div>

                <!-- Registration Notes / Purpose -->
                <div>
                    <label for="registration_notes" class="block text-xs font-semibold uppercase tracking-wider text-slate-300">
                        Registration Notes (Optional)
                    </label>
                    <textarea id="registration_notes" name="registration_notes" rows="2"
                        placeholder="Add any notes or context regarding your organization or team assignment..."
                        class="mt-1 w-full px-4 py-2.5 bg-slate-950/60 border border-slate-700/80 rounded-xl text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 focus:border-transparent text-sm resize-none">{{ old('registration_notes') }}</textarea>
                </div>

                <div class="pt-2">
                    <button type="submit"
                        class="btn-amber w-full py-3.5 px-4 rounded-xl text-sm font-bold shadow-xl shadow-amber-500/20 cursor-pointer">
                        <span x-text="regType === 'company_super_admin' ? 'Submit Company Request for Developer Approval' : 'Submit Staff Request for Super Admin Approval'"></span>
                    </button>
                </div>
            </form>

            <div class="mt-5 pt-5 border-t border-slate-800 text-center">
                <p class="text-xs text-slate-400">
                    Already have an approved account?
                    <a href="{{ route('login') }}" class="font-bold text-amber-400 hover:text-amber-300 transition-colors ml-1">
                        Sign In &rarr;
                    </a>
                </p>
            </div>
        </div>
    </div>
</div>
@endsection
