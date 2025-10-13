Place required 64-bit native DLLs here so they will be copied next to the app executable at build/install time.

For mssql_connection (FreeTDS DB-Lib), add the following files (x64 builds):
- sybdb.dll
- ct.dll (sometimes required by dependent tools)
- (optional) libeay32.dll / ssleay32.dll if your FreeTDS build depends on OpenSSL 1.0.x, or libcrypto-3-x64.dll / libssl-3-x64.dll for OpenSSL 3.x builds.

Recommended sources:
- Prebuilt FreeTDS for Windows x64 (DB-Lib):
  * https://github.com/vfrz/freetds-msvc/releases (DB-Lib: sybdb.dll)
  * or build from source with MSVC.

After placing DLLs:
1) Clean and rebuild the Windows target so CMake install step copies DLLs:
   - From VS Code: Flutter: Clean Project, then build Windows
   - Or in terminal (PowerShell):
     flutter clean; flutter pub get; flutter run -d windows

2) Verify at runtime that sybdb.dll is located beside label_printer.exe.
