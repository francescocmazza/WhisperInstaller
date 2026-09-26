; Whisper Seamless Inno Setup definition
#define MyAppName "Whisper Seamless"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Whisper Seamless contributors"
#define MyAppExeName "Whisper-Seamless-Setup-1.0.0.exe"

[Setup]
AppId={{A31A6F39-5017-42DE-A35E-BD60BF1DCC72}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\WhisperSeamless
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
OutputDir=Output
OutputBaseFilename=Whisper-Seamless-Setup-1.0.0
UninstallDisplayName={#MyAppName}
SetupLogging=yes

[Files]
Source: "..\Install-WhisperSeamless.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Uninstall-WhisperSeamless.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\VERSION.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\patches\*"; DestDir: "{app}\patches"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\launcher\*"; DestDir: "{app}\launcher"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\scripts\*"; DestDir: "{app}\scripts"; Flags: ignoreversion recursesubdirs createallsubdirs

[Run]
Filename: "powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install-WhisperSeamless.ps1"" -FromInno"; \
    StatusMsg: "Installing isolated Python, Whisper Local, CUDA runtime and model..."; \
    Flags: waituntilterminated

[UninstallRun]
Filename: "powershell.exe"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Uninstall-WhisperSeamless.ps1"" -Inno"; \
    Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{app}\runtime"
Type: filesandordirs; Name: "{app}\install-logs"
Type: filesandordirs; Name: "{app}\patches"
Type: filesandordirs; Name: "{app}\config"
Type: filesandordirs; Name: "{app}\launcher"
Type: filesandordirs; Name: "{app}\scripts"
Type: files; Name: "{app}\Install-WhisperSeamless.ps1"
Type: files; Name: "{app}\Uninstall-WhisperSeamless.ps1"
Type: files; Name: "{app}\VERSION.json"
