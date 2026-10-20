@props([
    'title' => null,
    'description' => null,
    'action' => null,
])

<div {{ $attributes->merge(['class' => 'bg-slate-900/70 border border-slate-800/80 rounded-2xl shadow-xl overflow-hidden']) }}>
    @if ($title || $description || $action)
        <div class="px-6 py-5 border-b border-slate-800/80 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
                @if ($title)
                    <h3 class="text-base font-bold text-white tracking-tight">{{ $title }}</h3>
                @endif
                @if ($description)
                    <p class="text-xs text-slate-400 mt-0.5">{{ $description }}</p>
                @endif
            </div>
            @if ($action)
                <div class="shrink-0">
                    {{ $action }}
                </div>
            @endif
        </div>
    @endif

    <div class="p-6">
        {{ $slot }}
    </div>
</div>
