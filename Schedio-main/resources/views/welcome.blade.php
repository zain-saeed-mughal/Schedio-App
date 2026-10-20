<!DOCTYPE html>
<html lang={{ str_replace('_', '-', app()->getLocale()) }} class=h-full>
<head>
    <meta charset=utf-8>
    <meta name=viewport content=width=device-width, initial-scale=1>
    <title>{{ config('app.name', 'Schedio') }} - Enterprise Scheduling & Operations</title>

    <link rel=preconnect href=https://fonts.googleapis.com>
    <link rel=preconnect href=https://fonts.gstatic.com crossorigin>
    <link href=https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap rel=stylesheet>

    @vite(['resources/css/app.css', 'resources/js/app.js'])
</head>
<body class=min-h-full bg-slate-950 text-slate-100 font-sans antialiased flex flex-col justify-between selection:bg-indigo-500 selection:text-white x-data={ loaded: true, time: new Date().toLocaleTimeString() } x-init=setInterval(() => time = new Date().toLocaleTimeString(), 1000)>
    
    {{-- Header --}}
    <header class=w-full border-b border-slate-800/80 bg-slate-900/50 backdrop-blur-md sticky top-0 z-50>
        <div class=max-w-7xl mx-auto px-6 h-16 flex items-center justify-between>
            <div class=flex items-center gap-3>
                <div class=w-9 h-9 rounded-xl bg-gradient-to-tr from-indigo-600 via-indigo-500 to-cyan-400 flex items-center justify-center shadow-lg shadow-indigo-500/20 ring-1 ring-white/20>
                    <svg class=w-5 h-5 text-white viewBox=0 0 24 24 fill=none stroke=currentColor stroke-width=2.2 stroke-linecap=round stroke-linejoin=round>
                        <rect x=3 y=4 width=18 height=18 rx=2 ry=2></rect>
                        <line x1=16 y1=2 x2=16 y2=6></line>
                        <line x1=8 y1=2 x2=8 y2=6></line>
                        <line x1=3 y1=10 x2=21 y2=10></line>
                    </svg>
                </div>
                <div>
                    <span class=text-lg font-bold tracking-tight bg-gradient-to-r from-white via-slate-200 to-slate-400 bg-clip-text text-transparent>Schedio</span>
                    <span class=ml-2 text-xs font-semibold px-2 py-0.5 rounded-full bg-indigo-500/10 text-indigo-400 border border-indigo-500/20>Foundation v1.0</span>
                </div>
            </div>

            <div class=flex items-center gap-4 text-xs font-medium text-slate-400>
                <div class=hidden sm:flex items-center gap-2 px-3 py-1 rounded-full bg-slate-900 border border-slate-800 text-slate-300>
                    <span class=w-2 h-2 rounded-full bg-emerald-400 animate-pulse></span>
                    <span>Herd Engine Active</span>
                </div>
                <div class=hidden md:block text-slate-500 x-text=time></div>
            </div>
        </div>
    </header>

    {{-- Main Hero / Foundation Status --}}
    <main class=max-w-7xl mx-auto px-6 py-12 flex-1 flex flex-col justify-center>
        <div class=text-center max-w-3xl mx-auto mb-12>
            <div class=inline-flex items-center gap-2 px-3.5 py-1 rounded-full bg-indigo-950/60 border border-indigo-500/30 text-indigo-300 text-xs font-semibold tracking-wide uppercase mb-6 shadow-inner>
                <svg class=w-3.5 h-3.5 text-indigo-400 fill=none viewBox=0 0 24 24 stroke=currentColor>
                    <path stroke-linecap=round stroke-linejoin=round stroke-width=2 d=M5 13l4 4L19 7/>
                </svg>
                Phase 1 Core Architecture Ready
            </div>
            <h1 class=text-4xl sm:text-5xl font-extrabold tracking-tight text-white mb-4>
                Enterprise Scheduling Platform <span class=bg-gradient-to-r from-indigo-400 via-sky-400 to-emerald-400 bg-clip-text text-transparent>Schedio</span>
            </h1>
            <p class=text-slate-400 text-base sm:text-lg leading-relaxed>
                Foundation environment configured with Laravel 12, PHP 8.4, PostgreSQL, Redis, Tailwind CSS v4, Alpine.js, and FullCalendar integration.
            </p>
        </div>

        {{-- Environment Grid --}}
        <div class=grid grid-cols-1 md:grid-cols-3 gap-6 max-w-5xl mx-auto w-full>
            {{-- Stack Card 1 --}}
            <div class=bg-slate-900/60 border border-slate-800/80 rounded-2xl p-6 shadow-xl relative overflow-hidden backdrop-blur-sm group hover:border-slate-700 transition>
                <div class=absolute -top-12 -right-12 w-28 h-28 bg-indigo-500/10 rounded-full blur-2xl group-hover:bg-indigo-500/20 transition></div>
                <div class=flex items-center justify-between mb-4>
                    <span class=text-xs font-semibold text-slate-400 uppercase tracking-wider>Backend Runtime</span>
                    <span class=px-2 py-0.5 rounded text-xs font-semibold bg-indigo-500/20 text-indigo-300>Laravel 12</span>
                </div>
                <div class=space-y-2 text-sm>
                    <div class=flex justify-between py-1 border-b border-slate-800>
                        <span class=text-slate-400>PHP Version</span>
                        <span class=font-mono text-slate-200 font-semibold>{{ PHP_VERSION }}</span>
                    </div>
                    <div class=flex justify-between py-1 border-b border-slate-800>
                        <span class=text-slate-400>Environment</span>
                        <span class=font-mono text-emerald-400 font-medium>{{ app()->environment() }}</span>
                    </div>
                    <div class=flex justify-between py-1>
                        <span class=text-slate-400>Local Domain</span>
                        <span class=font-mono text-indigo-400 font-medium>{{ config('app.url') }}</span>
                    </div>
                </div>
            </div>

            {{-- Stack Card 2 --}}
            <div class=bg-slate-900/60 border border-slate-800/80 rounded-2xl p-6 shadow-xl relative overflow-hidden backdrop-blur-sm group hover:border-slate-700 transition>
                <div class=absolute -top-12 -right-12 w-28 h-28 bg-sky-500/10 rounded-full blur-2xl group-hover:bg-sky-500/20 transition></div>
                <div class=flex items-center justify-between mb-4>
                    <span class=text-xs font-semibold text-slate-400 uppercase tracking-wider>Frontend Stack</span>
                    <span class=px-2 py-0.5 rounded text-xs font-semibold bg-sky-500/20 text-sky-300>Vite + Blade</span>
                </div>
                <div class=space-y-2 text-sm>
                    <div class=flex justify-between py-1 border-b border-slate-800>
                        <span class=text-slate-400>Styling Engine</span>
                        <span class=font-mono text-slate-200>Tailwind CSS v4</span>
                    </div>
                    <div class=flex justify-between py-1 border-b border-slate-800>
                        <span class=text-slate-400>Reactivity</span>
                        <span class=font-mono text-sky-400>Alpine.js Active</span>
                    </div>
                    <div class=flex justify-between py-1>
                        <span class=text-slate-400>Calendar Lib</span>
                        <span class=font-mono text-slate-200>FullCalendar 6</span>
                    </div>
                </div>
            </div>

            {{-- Stack Card 3 --}}
            <div class=bg-slate-900/60 border border-slate-800/80 rounded-2xl p-6 shadow-xl relative overflow-hidden backdrop-blur-sm group hover:border-slate-700 transition>
                <div class=absolute -top-12 -right-12 w-28 h-28 bg-emerald-500/10 rounded-full blur-2xl group-hover:bg-emerald-500/20 transition></div>
                <div class=flex items-center justify-between mb-4>
                    <span class=text-xs font-semibold text-slate-400 uppercase tracking-wider>Data & Cache Layer</span>
                    <span class=px-2 py-0.5 rounded text-xs font-semibold bg-emerald-500/20 text-emerald-300>Configured</span>
                </div>
                <div class=space-y-2 text-sm>
                    <div class=flex justify-between py-1 border-b border-slate-800>
                        <span class=text-slate-400>Driver</span>
                        <span class=font-mono text-slate-200>{{ config('database.default') }}</span>
                    </div>
                    <div class=flex justify-between py-1 border-b border-slate-800>
                        <span class=text-slate-400>Redis Driver</span>
                        <span class=font-mono text-emerald-400>{{ extension_loaded('redis') ? 'phpredis extension' : 'predis' }}</span>
                    </div>
                    <div class=flex justify-between py-1>
                        <span class=text-slate-400>Migration State</span>
                        <span class=font-mono text-emerald-400>Ready</span>
                    </div>
                </div>
            </div>
        </div>
    </main>

    {{-- Footer --}}
    <footer class=border-t border-slate-800/80 py-6 bg-slate-900/40>
        <div class=max-w-7xl mx-auto px-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500>
            <div>
                &copy; {{ date('Y') }} Schedio Enterprise Scheduling System. All rights reserved.
            </div>
            <div class=flex items-center gap-6>
                <span>Laravel Herd Windows Environment</span>
                <span>Node v24 / npm 11</span>
            </div>
        </div>
    </footer>
</body>
</html>
