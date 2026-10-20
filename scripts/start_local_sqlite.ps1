$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$php = Join-Path $taskRoot '.tools/php/php.exe'
& $php (Join-Path $PSScriptRoot 'verify_local_sqlite.php')
if ($LASTEXITCODE -ne 0) { throw 'SQLite compatibility isolation verification failed.' }
foreach ($port in @(8090, 8091)) {
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        $existing = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener[0].OwningProcess)"
        if (-not $existing.CommandLine.Contains($taskRoot)) { throw "Port $port is occupied." }
        continue
    }
    Start-Process $php -ArgumentList @('artisan', 'serve', '--env=staging-sqlite-local',
        '--host=127.0.0.1', "--port=$port", '--no-reload') `
        -WorkingDirectory (Join-Path $taskRoot 'Schedio-main') -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $taskRoot ".tools/staging/sqlite-compat/server-$port.log") `
        -RedirectStandardError (Join-Path $taskRoot ".tools/staging/sqlite-compat/server-$port-error.log") | Out-Null
}
$workers = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'php.exe' -and $_.CommandLine -like '*queue:work*' `
        -and $_.CommandLine -like '*--env=staging-sqlite-local*'
}
if (-not $workers) {
    Start-Process $php -ArgumentList @('artisan', 'queue:work', '--env=staging-sqlite-local',
        '--sleep=1', '--tries=3', '--backoff=2') -WorkingDirectory (Join-Path $taskRoot 'Schedio-main') `
        -WindowStyle Hidden -RedirectStandardOutput (Join-Path $taskRoot '.tools/staging/sqlite-compat/queue.log') `
        -RedirectStandardError (Join-Path $taskRoot '.tools/staging/sqlite-compat/queue-error.log') | Out-Null
}
Write-Output 'SQLite compatibility API: http://10.0.2.2:8090/api/v1/'
