; Comunimate installer (Inno Setup). Built by build.ps1 - don't run directly.
; Installs per-user (no admin prompt), starts with Windows, and launches the
; tray helper, which then installs the WoW add-on and downloads the voice model.

#define AppName "Comunimate"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef DistDir
  #define DistDir "dist\Comunimate"
#endif

[Setup]
AppId={{6F2B9C1E-4C7A-4E8E-9C2D-3B7A5E1F0C42}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppName}
DefaultDirName={localappdata}\Programs\{#AppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\release
OutputBaseFilename=Comunimate-Setup-{#AppVersion}
SetupIconFile=build\comunimate.ico
UninstallDisplayIcon={app}\Comunimate.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=force
RestartApplications=no

[InstallDelete]
; Upgrades: drop the previous version's bundled files first, so nothing stale
; (old art, old libraries) is left behind and copied into WoW.
Type: filesandordirs; Name: "{app}\_internal"

[Files]
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Registry]
; Start with Windows (the tray menu can turn this off).
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\Comunimate.exe"""; Flags: uninsdeletevalue

[Icons]
Name: "{userprograms}\{#AppName}"; Filename: "{app}\Comunimate.exe"

[Run]
Filename: "{app}\Comunimate.exe"; Description: "Start {#AppName} now"; Flags: nowait postinstall

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/IM Comunimate.exe /F"; Flags: runhidden; RunOnceId: "StopComunimate"
