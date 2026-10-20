$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'start_local_sqlite.ps1')
$devices = adb devices | Select-String -Pattern '\tdevice$'
if (-not $devices) {
    throw 'No phone found. Plug it in with USB debugging on and accept the prompt on the phone.'
}
adb reverse tcp:8090 tcp:8090 | Out-Null
Write-Output 'Phone port 8090 now reaches this computer.'
Set-Location (Join-Path $taskRoot 'schedio_mobile')
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8090/api/v1/
