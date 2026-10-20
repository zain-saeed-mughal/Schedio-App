@extends('layouts.app')

@section('title', 'Sign In')

@section('content')
<div class="min-h-full flex flex-col justify-center py-12 px-4 sm:px-6 lg:px-8 relative z-10" x-data="{
    fillUser(email, pass) {
        document.getElementById('email').value = email;
        document.getElementById('password').value = pass;
        document.getElementById('loginForm').submit();
    }
}">
    <!-- Brand / Hero Title -->
    <div class="sm:mx-auto sm:w-full sm:max-w-md text-center space-y-3">
        <div class="flex justify-center">
            <x-brand-logo size="xl" :showText="false" class="scale-110" />
        </div>
        <div>
            <h1 class="text-3xl sm:text-4xl font-extrabold tracking-tight text-white flex items-center justify-center gap-2">
                Schedio
                <span class="text-xs font-mono font-bold px-2 py-0.5 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-300">ENTERPRISE</span>
            </h1>
            <p class="text-xs sm:text-sm text-slate-400 font-medium max-w-sm mx-auto leading-relaxed mt-1.5">
                Executive Scheduling & Intelligent Meeting Suite
            </p>
        </div>
    </div>

    <!-- Main Login Card -->
    <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div class="glass-panel py-8 px-6 sm:px-10 rounded-3xl relative overflow-hidden">
            <!-- Subtle Golden Top Flare -->
            <div class="absolute -top-12 left-1/2 -translate-x-1/2 w-48 h-20 bg-amber-500/20 rounded-full blur-2xl pointer-events-none"></div>

            @if (session('status'))
                <div class="mb-6 p-4 rounded-2xl bg-emerald-950/60 border border-emerald-500/40 text-emerald-300 text-xs font-semibold flex items-start gap-3">
                    <svg class="w-5 h-5 text-emerald-400 shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                    </svg>
                    <span>{{ session('status') }}</span>
                </div>
            @endif

            @if ($errors->any())
                <div class="mb-6 p-4 rounded-2xl bg-rose-950/60 border border-rose-500/40 text-rose-300 text-xs font-medium space-y-1.5">
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

            <!-- Fast One-Click Demo Access (Warm Amber Pills) -->
            <div class="mb-6 pb-6 border-b border-white/[0.08]">
                <div class="text-[10px] font-bold uppercase tracking-wider text-amber-400/90 mb-2.5 flex items-center gap-1.5">
                    <span class="w-1.5 h-1.5 rounded-full bg-amber-400 animate-pulse"></span>
                    <span>One-Click Demo Staff Login</span>
                </div>
                <div class="grid grid-cols-2 gap-2.5">
                    <button type="button" @click="fillUser('admin@schedio.com', 'password')"
                        class="p-2.5 rounded-xl bg-white/[0.04] hover:bg-amber-400/10 border border-white/10 hover:border-amber-400/50 text-left transition-all group cursor-pointer">
                        <div class="text-xs font-bold text-white group-hover:text-amber-300">Alex Rivera</div>
                        <div class="text-[10px] text-amber-400 font-semibold">Super Admin &rarr;</div>
                    </button>
                    <button type="button" @click="fillUser('sarah.chen@schedio.com', 'password')"
                        class="p-2.5 rounded-xl bg-white/[0.04] hover:bg-amber-400/10 border border-white/10 hover:border-amber-400/50 text-left transition-all group cursor-pointer">
                        <div class="text-xs font-bold text-white group-hover:text-amber-300">Sarah Chen</div>
                        <div class="text-[10px] text-amber-400 font-semibold">Head of Product &rarr;</div>
                    </button>
                </div>
            </div>

            <form id="loginForm" class="space-y-4" action="{{ route('login.post') }}" method="POST">
                @csrf

                <div>
                    <label for="email" class="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-1.5">
                        Work Email Address
                    </label>
                    <div class="relative">
                        <input id="email" name="email" type="email" autocomplete="email" required
                            value="{{ old('email', 'admin@schedio.com') }}"
                            placeholder="admin@schedio.com"
                            class="w-full px-4 py-3 bg-[#111317]/80 border border-white/[0.14] rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent transition-all text-sm">
                    </div>
                </div>

                <div>
                    <label for="password" class="block text-xs font-bold uppercase tracking-wider text-slate-300 mb-1.5">
                        Password
                    </label>
                    <div class="relative">
                        <input id="password" name="password" type="password" autocomplete="current-password" required
                            value="password"
                            placeholder="••••••••"
                            class="w-full px-4 py-3 bg-[#111317]/80 border border-white/[0.14] rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-400 focus:border-transparent transition-all text-sm">
                    </div>
                </div>

                <div class="flex items-center justify-between pt-1">
                    <label class="flex items-center gap-2 cursor-pointer">
                        <input id="remember" name="remember" type="checkbox" checked
                            class="h-4 w-4 bg-[#111317] border-white/20 rounded text-amber-500 focus:ring-amber-400">
                        <span class="text-xs text-slate-400 font-medium">Keep me signed in</span>
                    </label>
                </div>

                <div class="pt-2">
                    <button type="submit"
                        class="btn-amber w-full py-3.5 px-4 rounded-xl text-sm shadow-lg hover:scale-[1.01] active:scale-[0.99] flex items-center justify-center gap-2 cursor-pointer">
                        <span>Sign In to Workspace</span>
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M14 5l7 7m0 0l-7 7m7-7H3"></path></svg>
                    </button>
                </div>
            </form>

            <div class="mt-6 pt-5 border-t border-white/[0.08] text-center">
                <p class="text-xs text-slate-400">
                    Need an account?
                    <a href="{{ route('register') }}" class="font-bold text-amber-400 hover:text-amber-300 transition-colors ml-1">
                        Request Staff Access &rarr;
                    </a>
                </p>
            </div>
        </div>
    </div>
</div>
@endsection
