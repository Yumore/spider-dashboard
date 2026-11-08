#ifndef BuildDir
  #error BuildDir must point to the Flutter Windows Release directory.
#endif

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#ifndef AppExe
  #define AppExe "dashboard.exe"
#endif

[Setup]
AppId={{D57056E5-A8B7-4C4A-A7F1-684B5BE9E7A1}
AppName=Spider Worker
AppVersion={#AppVersion}
AppPublisher=Yumore
DefaultDirName={autopf}\Spider Worker
DefaultGroupName=Spider Worker
UninstallDisplayName=Spider Worker
OutputBaseFilename=spider-worker
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Spider Worker"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\Spider Worker"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked
