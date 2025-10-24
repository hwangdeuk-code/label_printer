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

# 특정 태그를 침묵(Silent) 처리하는 헬퍼
function Set-TagSilent {
  param([string]$serial, [string]$tag, [int]$retries = 3)

  # 비영구(log.tag.*) 우선 시도
  for ($i = 0; $i -lt $retries; $i++) {
    & adb -s $serial shell setprop "log.tag.$tag" S 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }
    & adb -s $serial shell setprop "log.tag.$tag" SILENT 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }
    Start-Sleep -Milliseconds 300
  }

  # 영구(persist.log.tag.*)도 시도 (에뮬레이터에선 허용되는 경우가 많음)
  for ($i = 0; $i -lt $retries; $i++) {
    & adb -s $serial shell setprop "persist.log.tag.$tag" S 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }
    & adb -s $serial shell setprop "persist.log.tag.$tag" SILENT 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }
    Start-Sleep -Milliseconds 300
  }

  return $false
}

# 기존: MESA 태그 침묵 처리 (유지)
for ($i = 0; $i -lt 3; $i++) {
  & adb -s $target shell setprop log.tag.MESA S 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { break }
  Start-Sleep -Milliseconds 300
}

# 추가: EGL_emulation 모든 로그 침묵 처리
# - DEBUG/INFO 등 모든 레벨 출력 차단
[void](Set-TagSilent -serial $target -tag 'EGL_emulation' -retries 3)

exit 0
