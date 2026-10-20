@props([
    'title',
    'value',
    'subtitle' => null,
    'icon' => null,
    'color' => 'amber',
    'trend' => null,
])

@php
    $colorClasses = [
        'amber' => 'text-amber-300 bg-gradient-to-tr from-amber-500/20 to-orange-500/20 border-amber-500/30',
        'indigo' => 'text-indigo-300 bg-gradient-to-tr from-indigo-500/20 to-violet-500/20 border-indigo-500/30',
        'purple' => 'text-purple-300 bg-gradient-to-tr from-purple-500/20 to-fuchsia-500/20 border-purple-500/30',
        'emerald' => 'text-emerald-300 bg-gradient-to-tr from-emerald-500/20 to-teal-500/20 border-emerald-500/30',
        'rose' => 'text-rose-300 bg-gradient-to-tr from-rose-500/20 to-pink-500/20 border-rose-500/30',
        'cyan' => 'text-cyan-300 bg-gradient-to-tr from-cyan-500/20 to-sky-500/20 border-cyan-500/30',
    ][$color] ?? 'text-amber-300 bg-gradient-to-tr from-amber-500/20 to-orange-500/20 border-amber-500/30';
@endphp

<div class="glass-card p-5 sm:p-6 rounded-3xl relative overflow-hidden group">
    <div class="flex items-center justify-between">
        <span class="text-xs font-bold uppercase tracking-wider text-slate-400">{{ $title }}</span>
        @if ($icon)
            <div class="p-2.5 rounded-2xl border shadow-md group-hover:scale-110 transition-transform duration-300 {{ $colorClasses }}">
                {!! $icon !!}
            </div>
        @endif
    </div>

    <div class="mt-3 flex items-baseline gap-2">
        <span class="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">{{ $value }}</span>
        @if ($trend)
            <span class="text-xs font-bold px-2 py-0.5 rounded-full {{ str_starts_with($trend, '+') ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30' : 'bg-amber-500/15 text-amber-400 border border-amber-500/30' }}">
                {{ $trend }}
            </span>
        @endif
    </div>

    @if ($subtitle)
        <p class="mt-1.5 text-xs text-slate-400 leading-normal">{{ $subtitle }}</p>
    @endif
</div>
