@props([
    'variant' => 'default', // default, success, warning, danger, info, purple
    'size' => 'md',        // sm, md, lg
])

@php
    $variants = [
        'default' => 'bg-slate-800/80 text-slate-300 border-slate-700/60',
        'success' => 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30',
        'warning' => 'bg-amber-500/15 text-amber-300 border-amber-500/30',
        'danger'  => 'bg-rose-500/15 text-rose-300 border-rose-500/30',
        'info'    => 'bg-sky-500/15 text-sky-300 border-sky-500/30',
        'purple'  => 'bg-purple-500/15 text-purple-300 border-purple-500/30',
        'indigo'  => 'bg-indigo-500/15 text-indigo-300 border-indigo-500/30',
    ];

    $sizes = [
        'sm' => 'px-2 py-0.5 text-[10px]',
        'md' => 'px-2.5 py-1 text-xs',
        'lg' => 'px-3 py-1.5 text-sm',
    ];

    $classes = 'inline-flex items-center gap-1.5 font-medium rounded-full border ' . ($variants[$variant] ?? $variants['default']) . ' ' . ($sizes[$size] ?? $sizes['md']);
@endphp

<span {{ $attributes->merge(['class' => $classes]) }}>
    {{ $slot }}
</span>
