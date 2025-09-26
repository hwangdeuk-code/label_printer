<#
  Inno_Setup_Installer.ps1
  - Resolve-Path로 안전 실행(Method A)
  - /Qp -> /Q -> (없음) 자동 폴백
  - ISCC 출력 로그는 Tee-Object로 캡처(/L 미지원 대응)
  - 성공 시 .log / .sha256 파일 삭제
#>

[CmdletBinding()]
param(
    [string]$IssFile     = 'Inno_Setup_Installer.iss',
    [string]$VersionFile = 'version.txt',
    [string]$OutputDir   = 'installer',
    [string]$IsccPath,
    [switch]$NoZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ----- 변수 선제 초기화 (StrictMode 안정) -----
$ISCC    = $null
$absIss  = $null
$absOut  = $null
$logPath = $null
$exePath = $null
$zipPath = $null
$shaPath = $null

# ----- 1) 작업 디렉터리 이동 -----
if ($PSScriptRoot) {
    Set-Location -Path $PSScriptRoot
    $scriptDir = $PSScriptRoot
} else {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location -Path $scriptDir
}

# ----- Helpers -----
function Get-FirstNonEmptyLine {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
    $line = Get-Content -LiteralPath $Path | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1
    if (-not $line) { throw "No non-empty line in $Path" }
    return $line.Trim()
}

function Find-Iscc {
    param([string]$UserProvided)
    if ($UserProvided) {
        if (Test-Path -LiteralPath $UserProvided) { return (Resolve-Path -LiteralPath $UserProvided).Path }
        throw "ISCC.exe not found at user-provided path: $UserProvided"
    }
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 5\ISCC.exe"
    ) | Where-Object { $_ -and $_.Trim() -ne '' }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
    }
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "ISCC.exe not found. Please install Inno Setup or specify -IsccPath."
}

# ----- 2) 버전/파일명 확정 -----
$versionPath  = Join-Path $scriptDir $VersionFile
$XAPP_VERSION = Get-FirstNonEmptyLine -Path $versionPath
$baseName     = "Setup_LabelPrinter_v$XAPP_VERSION"
Write-Host "[INFO] Loaded version: $XAPP_VERSION"
Write-Host "[INFO] Output base name: $baseName"

# ----- 3) ISCC 경로 확정 -----
try {
    $resolved = Find-Iscc -UserProvided $IsccPath
    $ISCC     = (Resolve-Path -LiteralPath $resolved).Path
} catch {
    Write-Error "ISCC.exe not found or not accessible. $($_.Exception.Message)"
    exit 1
}
if (-not (Test-Path -LiteralPath $ISCC)) { Write-Error "ISCC path invalid: $ISCC"; exit 1 }
Write-Host "[INFO] ISCC: $ISCC"

# ----- 4) .ISS 경로 확정 -----
if ([string]::IsNullOrWhiteSpace($IssFile)) { Write-Error "IssFile is empty."; exit 1 }
$issPathCandidate = Join-Path $scriptDir $IssFile
if (-not (Test-Path -LiteralPath $issPathCandidate)) {
    Write-Error "ISS file not found: $issPathCandidate"
    exit 1
}
$absIss = (Resolve-Path -LiteralPath $issPathCandidate).Path
Write-Host "[INFO] ISS: $absIss"

# ----- 5) 출력 폴더/로그 경로 준비 -----
$absOut = Join-Path -Path $scriptDir -ChildPath $OutputDir
if (-not (Test-Path -LiteralPath $absOut)) { New-Item -ItemType Directory -Path $absOut | Out-Null }
$absOut  = (Resolve-Path -LiteralPath $absOut).Path
$logPath = Join-Path $absOut "build_$($XAPP_VERSION)_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }
"=== ISCC Compile Log === $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -LiteralPath $logPath -Encoding UTF8

# ----- 6) 컴파일 (조용 옵션 폴백 + 로그 캡처) -----
$commonArgs = @("/O$absOut", "/F$baseName", "/DAppVersion=$XAPP_VERSION", $absIss)
$quietCandidates  = @('/Qp', '/Q', '')
$compileSucceeded = $false
$exitCode         = 1

Write-Host "[INFO] Compiling..."
foreach ($q in $quietCandidates) {
    $args = @()
    if ($q) { $args += $q }
    $args += $commonArgs

    Add-Content -LiteralPath $logPath -Value "`n--- Attempt with quiet flag: '$q' ---"
    $compileOutput = & $ISCC @args 2>&1 | Tee-Object -FilePath $logPath -Append
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) { $compileSucceeded = $true; break }

    $outText = ($compileOutput | Out-String)
    if ($outText -match 'Unknown option') { continue } else { break }
}
if (-not $compileSucceeded) {
    Write-Error "Inno Setup compilation failed. ExitCode=$exitCode (see log: $logPath)"
    exit $exitCode
}
Write-Host "[OK] Compile success."

# ----- 7) 산출물 확인 -----
$exePath = Join-Path $absOut "$baseName.exe"
if (-not (Test-Path -LiteralPath $exePath)) {
    $latest = Get-ChildItem -LiteralPath $absOut -Filter '*.exe' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) {
        Write-Host "[WARN] Expected EXE not found. Using latest: $($latest.FullName)"
        $exePath = $latest.FullName
    } else {
        Write-Error "Compiled EXE not found in output dir: $absOut"
        exit 1
    }
}
Write-Host "[INFO] EXE: $exePath"

# ----- 8) ZIP 압축 (+ SHA256) -----
if (-not $NoZip) {
    try {
        $zipPath = [System.IO.Path]::ChangeExtension($exePath, '.zip')
        Write-Host "[INFO] Create ZIP archive: $zipPath"
        if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
        Compress-Archive -LiteralPath $exePath -DestinationPath $zipPath -Force
        Write-Host "[OK] ZIP created."

        $fileHash = Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
        if ($null -eq $fileHash) { throw "Get-FileHash returned null." }
        $shaPath = "$zipPath.sha256"
        "$($fileHash.Hash)  $(Split-Path $zipPath -Leaf)" | Out-File -LiteralPath $shaPath -Encoding ASCII
        Write-Host "[OK] SHA256: $shaPath"
    } catch {
        Write-Error "Packaging failed: $($_.Exception.Message)"
        exit 1
    }
}

# ----- 9) 성공 시 log / sha256 삭제 -----
if ($compileSucceeded) {
    if ($logPath -and (Test-Path -LiteralPath $logPath)) { Remove-Item -LiteralPath $logPath -Force }
    if ($shaPath -and (Test-Path -LiteralPath $shaPath)) { Remove-Item -LiteralPath $shaPath -Force }
    Write-Host "[CLEANUP] Removed log and sha256 files after success."
}

Write-Host "[DONE] Build pipeline completed successfully."
exit 0
