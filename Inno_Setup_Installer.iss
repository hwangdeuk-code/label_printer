#define XAppName "LabelPrinter"
#define EAppName "LabelPrinter.exe"
#define VerHandle FileOpen("version.txt")
#define RawVersion FileRead(VerHandle)
#expr FileClose(VerHandle)
#undef VerHandle
#define XAppVersion Trim(RawVersion)

; 1) 설치 프로그램 기본 정보
[Setup]
AppId={{A1B2C3D4-E5F6-47A8-9ABC-0123456789AB}}								; 반드시 고정 GUID로
AppName={#XAppName}
AppPublisher=Innowireless Co., Ltd.
AppVersion={#XAppVersion}
ArchitecturesInstallIn64BitMode=x64

; 사용자 폴더 강제 (비승격, UAC 불필요)
PrivilegesRequired=lowest
DefaultDirName={localappdata}\{#XAppName}
AlwaysUsePersonalGroup=yes
DefaultGroupName=Accuver

OutputDir=.\installer
OutputBaseFilename=Setup_{#XAppName}_v{#XAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#EAppName}
CloseApplications=yes
RestartApplications=no

; 2) 설치할 파일 지정
[Files]
; 상대경로로 Release 폴더 내 모든 파일을 복사
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
; 프로젝트에 포함된 서드파티 네이티브 DLL(예: FreeTDS sybdb.dll 등)
Source: "windows\Libraries\bin\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs skipifsourcedoesntexist
; Microsoft Visual C++ 2015–2022 (x64) 런타임
Source: "{sys}\vcruntime140_1.dll"; DestDir: "{app}"; Flags: external skipifsourcedoesntexist ignoreversion
Source: "{sys}\vcruntime140.dll";   DestDir: "{app}"; Flags: external skipifsourcedoesntexist ignoreversion
Source: "{sys}\msvcp140.dll";       DestDir: "{app}"; Flags: external skipifsourcedoesntexist ignoreversion
Source: "{sys}\msvcp140_1.dll";     DestDir: "{app}"; Flags: external skipifsourcedoesntexist ignoreversion
Source: "{sys}\msvcp140_2.dll";     DestDir: "{app}"; Flags: external skipifsourcedoesntexist ignoreversion

; 3) 시작 메뉴 & 바탕화면 바로가기
[Icons]
Name: "{group}\{#XAppName}"; Filename: "{app}\{#EAppName}"
Name: "{userdesktop}\{#XAppName}"; Filename: "{app}\{#EAppName}"

; 4) 설치 완료 후 자동 실행 (선택)
[Run]
Filename: "{app}\{#EAppName}"; \
  Description: "Launch {#XAppName}"; \
  Flags: nowait postinstall skipifsilent

; 5) 언인스톨러 설정 (Inno Setup이 자동으로 생성)
;    기본으로 [UninstallDelete] 섹션 등이 추가됨
