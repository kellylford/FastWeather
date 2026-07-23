; Inno Setup script for WeatherFast (Windows).
;
; Per-user install (no administrator rights) into %LocalAppData%, so the in-app
; updater can download and run a new installer without elevation - mirroring the
; per-user model QuickMail uses via Velopack. The version is passed by the CI
; build with /DMyAppVersion=x.y.z; it defaults to 0.0.0 for local test compiles.
;
; Build locally (after `python build.py` in ../windows):
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=1.1 weatherfast.iss

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#define MyAppName "WeatherFast"
#define MyAppPublisher "Kelly Ford"
#define MyAppExeName "WeatherFast.exe"
#define MyAppURL "https://github.com/kellylford/FastWeather"

[Setup]
; Stable AppId so upgrades replace the prior install (never change this GUID).
AppId={{7C2F1B84-3A6E-4E2B-9C1D-9E7A4F0B21A5}
; The running app holds this named mutex; lets the installer detect and wait
; for it to close before replacing the (in-app auto-update) executable.
AppMutex=WeatherFastRunning
CloseApplications=yes
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\WeatherFast
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=Output
OutputBaseFilename=WeatherFast-{#MyAppVersion}-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoVersion={#MyAppVersion}
VersionInfoProductName={#MyAppName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; The PyInstaller one-file build output (produced by ../windows/build.py).
Source: "..\windows\dist\WeatherFast.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autostartmenu}\WeatherFast"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\WeatherFast"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch WeatherFast"; Flags: nowait postinstall skipifsilent
