# 1. build apk
flutter build apk --release --target-platform=android-arm64

# 1. pubspec.yaml 에서 version 줄을 찾아서 순수 버전 문자열(예: 1.2.3)만 추출
$version = (Get-Content .\pubspec.yaml |
    Where-Object { $_ -match '^\s*version\s*:' } |
    ForEach-Object { $_ -replace '^\s*version\s*:\s*','' }
  ).Split('+')[0].Trim()

# 2. 원본 APK 경로와 대상 파일명 설정
$sourceApk = ".\build\app\outputs\flutter-apk\app-release.apk"
$destDir   = ".\installer"
$destName  = "LabelPrinter.v$version.apk"
$destPath  = Join-Path $destDir $destName

# 3. 복사 실행
Copy-Item -Path $sourceApk -Destination $destPath

Write-Host "Copied APK to '$destPath'."
