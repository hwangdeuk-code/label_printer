#flutter pub run pub_version_plus:main build
dart run tool/generate_version.dart
#if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter build windows
