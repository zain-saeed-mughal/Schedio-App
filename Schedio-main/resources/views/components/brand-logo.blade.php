@props([
    'size' => 'md', // sm (28px), md (38px), lg (48px), xl (64px)
    'showText' => true,
    'showSubtitle' => true,
    'subtitle' => 'Executive Workspace',
    'badge' => null,
    'animate' => true,
])

@php
    $sizeClasses = match($size) {
        'sm' => 'w-7 h-7',
        'md' => 'w-10 h-10',
        'lg' => 'w-12 h-12',
        'xl' => 'w-16 h-16',
        default => 'w-10 h-10',
    };

    $textClasses = match($size) {
        'sm' => 'text-base',
        'md' => 'text-[19px]',
        'lg' => 'text-2xl',
        'xl' => 'text-3xl',
        default => 'text-[19px]',
    };

    $svgId = 'schedio-logo-' . uniqid();
@endphp

<div {{ $attributes->merge(['class' => 'inline-flex items-center gap-3 select-none group']) }}>
    <!-- Luxury Obsidian & Golden Monogram Emblem -->
    <div class="relative shrink-0 {{ $sizeClasses }} rounded-xl transition-all duration-300 group-hover:scale-105 group-hover:shadow-[0_0_24px_rgba(245,158,11,0.35)] shadow-[0_4px_16px_rgba(0,0,0,0.5)]">
        <svg class="w-full h-full drop-shadow-md" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <!-- Obsidian Armor Gradient -->
                <linearGradient id="{{ $svgId }}-bg" x1="0" y1="0" x2="48" y2="48" gradientUnits="userSpaceOnUse">
                    <stop offset="0%" stop-color="#262A34"/>
                    <stop offset="50%" stop-color="#14171E"/>
                    <stop offset="100%" stop-color="#0B0D11"/>
                </linearGradient>

                <!-- Specular Beveled Gold Perimeter -->
                <linearGradient id="{{ $svgId }}-border" x1="0" y1="0" x2="48" y2="48" gradientUnits="userSpaceOnUse">
                    <stop offset="0%" stop-color="#FDE68A" stop-opacity="0.9"/>
                    <stop offset="30%" stop-color="#F59E0B" stop-opacity="0.6"/>
                    <stop offset="70%" stop-color="#FFFFFF" stop-opacity="0.1"/>
                    <stop offset="100%" stop-color="#B45309" stop-opacity="0.4"/>
                </linearGradient>

                <!-- Radiant Golden Ribbon Gradients -->
                <linearGradient id="{{ $svgId }}-ribbon-upper" x1="12" y1="10" x2="36" y2="28" gradientUnits="userSpaceOnUse">
                    <stop offset="0%" stop-color="#FFFDF5"/>
                    <stop offset="25%" stop-color="#FDE68A"/>
                    <stop offset="65%" stop-color="#F59E0B"/>
                    <stop offset="100%" stop-color="#D97706"/>
                </linearGradient>

                <linearGradient id="{{ $svgId }}-ribbon-lower" x1="12" y1="20" x2="36" y2="38" gradientUnits="userSpaceOnUse">
                    <stop offset="0%" stop-color="#F59E0B"/>
                    <stop offset="60%" stop-color="#D97706"/>
                    <stop offset="100%" stop-color="#78350F"/>
                </linearGradient>

                <!-- Ambient Golden Aura Blur -->
                <filter id="{{ $svgId }}-glow" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#F59E0B" flood-opacity="0.45"/>
                </filter>
            </defs>

            <!-- Outer Metallic Obsidian Squircle -->
            <rect x="1.5" y="1.5" width="45" height="45" rx="13" fill="url(#{{ $svgId }}-bg)"/>
            <rect x="1.5" y="1.5" width="45" height="45" rx="13" stroke="url(#{{ $svgId }}-border)" stroke-width="1.3"/>
            
            <!-- Glass Reflection Bevel Sheen -->
            <path d="M4 14C4 8.47715 8.47715 4 14 4H34C39.5228 4 44 8.47715 44 14V17C44 17 32 15 24 15C16 15 4 17 4 17V14Z" fill="white" fill-opacity="0.04"/>

            <!-- Ambient Warm Core Light -->
            <circle cx="20" cy="18" r="13" fill="#F59E0B" fill-opacity="0.16"/>

            <!-- Sculpted Precision 'S' Ribbon Monogram -->
            <g filter="url(#{{ $svgId }}-glow)">
                <!-- Upper Dynamic Arc -->
                <path d="M34 15.2C34 12.3 31.2 11 26.5 11H19C14.8 11 12.5 13.5 12.5 17.2C12.5 20.8 15.2 22.5 20 23.8L24.8 25.1C28.5 26.1 30.5 27.6 30.5 30.6C30.5 34 27.8 35.8 23.5 35.8H15.5C12.8 35.8 11.2 34.2 10.8 32.2"
                      stroke="url(#{{ $svgId }}-ribbon-upper)"
                      stroke-width="4.4"
                      stroke-linecap="round"
                      stroke-linejoin="round"/>

                <!-- Clock & Calendar Synchronization Precision Nodes -->
                <circle cx="34" cy="15.2" r="2.2" fill="#FFFDF5"/>
                <circle cx="10.8" cy="32.2" r="2.2" fill="#FBBF24"/>
                
                <!-- Center Intersection Light Nexus -->
                <circle cx="22.4" cy="24.4" r="1.6" fill="#FFFBEB"/>
            </g>
        </svg>
    </div>

    @if ($showText)
        <div class="flex flex-col">
            <!-- Brand Name + Optional HQ/Enterprise Badge -->
            <div class="flex items-center gap-2">
                <span class="{{ $textClasses }} font-black tracking-tight text-white transition-colors duration-200 group-hover:text-amber-100 flex items-center">
                    Schedio
                </span>

                @if ($badge)
                    <span class="text-[9.5px] font-mono font-bold px-1.5 py-0.5 rounded bg-amber-500/15 border border-amber-500/30 text-amber-300 uppercase tracking-wider">
                        {{ $badge }}
                    </span>
                @endif
            </div>

            <!-- Sleek Executive Workspace Status Pill -->
            @if ($showSubtitle)
                <div class="inline-flex items-center gap-1.5 mt-0.5">
                    <span class="relative flex h-1.5 w-1.5">
                        @if ($animate)
                            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75"></span>
                        @endif
                        <span class="relative inline-flex rounded-full h-1.5 w-1.5 bg-amber-400 shadow-[0_0_6px_#f59e0b]"></span>
                    </span>
                    <span class="text-[10px] font-semibold tracking-wider uppercase text-amber-300/90 font-mono">
                        {{ $subtitle }}
                    </span>
                </div>
            @endif
        </div>
    @endif
</div>
