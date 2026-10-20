$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$php = Join-Path $taskRoot '.tools/php/php.exe'
$pgctl = Join-Path $taskRoot '.tools/pgsql/bin/pg_ctl.exe'
$data = Join-Path $taskRoot '.tools/staging/pgdata'
if (-not (Test-Path -LiteralPath (Join-Path $data 'PG_VERSION'))) {
    throw 'The isolated local PostgreSQL cluster must be initialized first.'
}
& $pgctl status -D $data *> $null
if ($LASTEXITCODE -ne 0) {
    $process = Start-Process $pgctl -ArgumentList @(
        'start', '-D', "`"$data`"", '-l',
        "`"$(Join-Path $taskRoot '.tools/staging/postgres.log')`"",
        '-o', '"-h 127.0.0.1 -p 55432"'
    ) -WindowStyle Hidden -PassThru
    # Wait for pg_ctl itself, not its intentionally persistent descendants.
    if (-not $process.WaitForExit(30000) -or $process.ExitCode -ne 0) {
        throw 'Local PostgreSQL did not start; inspect the local postgres.log.'
    }
}
& $php (Join-Path $PSScriptRoot 'verify_local_postgres.php')
if ($LASTEXITCODE -ne 0) { throw 'Local staging isolation verification failed.' }
foreach ($port in @(8088, 8089)) {
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        $existing = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener[0].OwningProcess)"
        if (-not $existing.CommandLine.Contains($taskRoot)) {
            throw "Port $port is occupied by another application."
        }
        continue
    }
    Start-Process $php -ArgumentList @('artisan', 'serve', '--env=staging-local',
        '--host=127.0.0.1', "--port=$port", '--no-reload') `
        -WorkingDirectory (Join-Path $taskRoot 'Schedio-main') -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $taskRoot ".tools/staging/server-$port.log") `
        -RedirectStandardError (Join-Path $taskRoot ".tools/staging/server-$port-error.log") | Out-Null
}
$workers = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'php.exe' -and $_.CommandLine -like "*$taskRoot*" `
        -and $_.CommandLine -like '*queue:work*' -and $_.CommandLine -like '*--env=staging-local*'
}
if (-not $workers) {
    Start-Process $php -ArgumentList @('artisan', 'queue:work', '--env=staging-local',
        '--sleep=1', '--tries=1') -WorkingDirectory (Join-Path $taskRoot 'Schedio-main') `
        -WindowStyle Hidden -RedirectStandardOutput (Join-Path $taskRoot '.tools/staging/queue.log') `
        -RedirectStandardError (Join-Path $taskRoot '.tools/staging/queue-error.log') | Out-Null
}
Write-Output 'Local staging services are ready. Android API: http://10.0.2.2:8088/api/v1/'
