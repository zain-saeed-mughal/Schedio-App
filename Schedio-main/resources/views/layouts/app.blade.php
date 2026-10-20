<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" class="h-full bg-[#15181D]">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Schedio') — Intelligent Calendar & Meeting Suite</title>
    <link rel="icon" type="image/svg+xml" href="{{ asset('favicon.svg') }}">

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">

    <!-- Styles & Scripts via Vite -->
    @vite(['resources/css/app.css', 'resources/js/app.js'])
    @stack('styles')
</head>
<body class="h-full font-sans antialiased text-slate-100 bg-[#15181D] selection:bg-amber-400 selection:text-slate-950 overflow-x-hidden relative" x-data="{ sidebarOpen: false }">

    <!-- Atmospheric Organic Earthy Waves & Contour Art (Inspired by Reference) -->
    <div class="fixed inset-0 pointer-events-none -z-10 overflow-hidden">
        <svg class="absolute w-full h-full min-w-[1200px] min-h-[900px] opacity-90" viewBox="0 0 1440 900" fill="none" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">
            <!-- Clay / Terracotta Top-Left Blob -->
            <path d="M-80 -60C120 -10 260 90 280 250C300 420 180 520 40 560C-100 600 -240 500 -260 320C-280 140 -220 -10 -80 -60Z" fill="#3D3028" fill-opacity="0.85"/>
            
            <!-- Charcoal Slate Top-Right Wave -->
            <path d="M680 -120C920 -140 1200 -40 1340 120C1480 280 1520 540 1380 680C1240 820 1020 800 860 720C700 640 680 440 660 280C640 120 560 -100 680 -120Z" fill="#24282F" fill-opacity="0.9"/>
            
            <!-- Mid-layer Deep Espresso / Terracotta Swirl -->
            <path d="M380 180C540 160 680 280 690 420C700 560 580 690 440 710C300 730 180 620 170 480C160 340 260 190 380 180Z" fill="#2E2520" fill-opacity="0.75"/>
            
            <!-- Floating Pebble Accents -->
            <circle cx="140" cy="740" r="48" fill="#47382E" fill-opacity="0.85"/>
            <circle cx="1320" cy="720" r="75" fill="#3A2C32" fill-opacity="0.8"/>
            <circle cx="80" cy="780" r="28" fill="#362C25" fill-opacity="0.6"/>

            <!-- Sweeping Fluid Contour Paths -->
            <path d="M-50 180C180 120 420 340 450 560C480 780 780 820 1020 740C1260 660 1480 720 1520 840" stroke="#C8A168" stroke-opacity="0.22" stroke-width="2"/>
            <path d="M-20 280C220 220 450 420 520 620C590 820 900 860 1140 760C1360 680 1490 760 1540 880" stroke="#E2E8F0" stroke-opacity="0.12" stroke-width="1.5"/>
            <path d="M500 -50C520 180 460 320 340 440C220 560 180 720 240 880" stroke="#C8A168" stroke-opacity="0.18" stroke-width="1.8"/>
            <path d="M720 -80C780 140 880 320 980 440C1080 560 1240 640 1460 600" stroke="#E2E8F0" stroke-opacity="0.1" stroke-width="1.5"/>
        </svg>
    </div>

    @auth
        <div class="min-h-full flex flex-col lg:flex-row">
            <!-- Mobile Sidebar Backdrop -->
            <div x-show="sidebarOpen" x-cloak
                @click="sidebarOpen = false"
                x-transition:enter="transition-opacity ease-linear duration-300"
                x-transition:enter-start="opacity-0"
                x-transition:enter-end="opacity-100"
                x-transition:leave="transition-opacity ease-linear duration-300"
                x-transition:leave-start="opacity-100"
                x-transition:leave-end="opacity-0"
                class="fixed inset-0 bg-black/80 backdrop-blur-md z-40 lg:hidden">
            </div>

            <!-- Sidebar Navigation -->
            @include('layouts.partials.sidebar')

            <!-- Main Application Content Area -->
            <div class="flex-1 flex flex-col min-w-0 lg:pl-64">
                <!-- Top Navigation Bar -->
                @include('layouts.partials.topnav')

                <!-- Main Content Body -->
                <main class="flex-1 p-4 sm:p-6 lg:p-8 space-y-6">
                    @yield('content')
                </main>
            </div>
        </div>
    @else
        @yield('content')
    @endauth

    @stack('scripts')
</body>
</html>
