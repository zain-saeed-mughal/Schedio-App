param(
    [string]$BindHost = '127.0.0.1',
    [switch]$Restart
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$php = Join-Path $taskRoot '.tools/php/php.exe'
$ports = @(8090, 8091)

$iniDir = Join-Path $taskRoot '.tools/php/dev-ini'
New-Item -ItemType Directory -Force -Path $iniDir | Out-Null
Set-Content -Path (Join-Path $iniDir 'zz-local-dev.ini') -Value 'opcache.enable=0' -Encoding ascii
$env:PHP_INI_SCAN_DIR = $iniDir

& $php (Join-Path $PSScriptRoot 'verify_local_sqlite.php')
if ($LASTEXITCODE -ne 0) { throw 'SQLite compatibility isolation verification failed.' }

if ($Restart) {
    Get-CimInstance Win32_Process | Where-Object {
        $_.Name -eq 'php.exe' -and $_.CommandLine -like "*$taskRoot*" -and
        ($_.CommandLine -like '* -S *' -or $_.CommandLine -like '*artisan*serve*')
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Start-Sleep -Seconds 1
}

foreach ($port in $ports) {
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        $existing = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener[0].OwningProcess)"
        if (-not $existing.CommandLine.Contains($taskRoot)) { throw "Port $port is occupied." }
        continue
    }
    Start-Process $php -ArgumentList @('artisan', 'serve', '--env=staging-sqlite-local',
        "--host=$BindHost", "--port=$port", '--no-reload') `
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
Remove-Item Env:PHP_INI_SCAN_DIR

$probeHost = if ($BindHost -eq '0.0.0.0') { '127.0.0.1' } else { $BindHost }
$url = "http://${probeHost}:$($ports[0])/api/v1/auth/registration-options"
$healthy = $false
foreach ($attempt in 1..10) {
    Start-Sleep -Seconds 1
    try {
        $response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 $url
        if ($response.StatusCode -eq 200 -and $response.Headers['Content-Type'] -like 'application/json*') {
            $healthy = $true
            break
        }
    } catch {}
}
if (-not $healthy) {
    throw "The local API at $url did not return JSON. Rerun with -Restart to replace stale servers."
}
Write-Output "SQLite compatibility API is healthy: $url"
