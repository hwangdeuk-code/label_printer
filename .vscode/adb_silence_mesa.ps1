$ErrorActionPreference = 'SilentlyContinue'

# Ensure adb exists
$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) { exit 0 }

# Make sure adb server is up
& adb start-server 1>$null 2>$null

# Enumerate attached devices and pick a target serial (prefer emulator-5554)
$list = & adb devices 2>$null
if ($LASTEXITCODE -ne 0 -or $null -eq $list) { exit 0 }

$serials = @()
foreach ($line in $list) {
  if ($line -match '^\s*(\S+)\s+device\s*$' -and $line -notmatch 'List of devices attached') {
    $serials += $Matches[1]
  }
}

if ($serials.Count -eq 0) { exit 0 }

# emulator-5554가 연결되어 있지 않으면 스크립트를 종료합니다.
if (-not ($serials -contains 'emulator-5554')) {
  exit 0
}

$target = 'emulator-5554'

# Wait for device to be fully ready (avoid 'device not found')
function Wait-ForDeviceReady {
  param([string]$serial, [int]$timeoutSec = 30)
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $deadline) {
    $state = & adb -s $serial get-state 2>$null
    if ($LASTEXITCODE -eq 0 -and $state -and $state.Trim().ToLower() -eq 'device') {
      $boot = & adb -s $serial shell getprop sys.boot_completed 2>$null
      if ($LASTEXITCODE -eq 0 -and $boot -and $boot.Trim() -match '1') {
        return $true
      }
    }
    Start-Sleep -Milliseconds 500
  }
  return $false
}

if (-not (Wait-ForDeviceReady -serial $target -timeoutSec 30)) { exit 0 }

# Try to set log tag with a couple of retries in case of transient races
for ($i = 0; $i -lt 3; $i++) {
  & adb -s $target shell setprop log.tag.MESA S 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { break }
  Start-Sleep -Milliseconds 300
}

exit 0
