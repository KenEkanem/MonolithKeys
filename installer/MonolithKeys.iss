; MonolithKeys installer (Inno Setup 6).
;
; Build after `flutter build windows --release`:
;   iscc /DAppVersion=1.0.0 installer\MonolithKeys.iss
;
; Installs for the current user by default (no administrator prompt), with an
; option to install for all users. Settings live in %APPDATA%\MonolithKeys and
; are kept across upgrades.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define AppName "MonolithKeys"
#define AppExe "MonolithKeys.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{37169598-82D6-4BAC-AFF1-6B43666FE57E}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=MonolithKeys
AppPublisherURL=https://kennedyekanem.tech
AppSupportURL=https://kennedyekanem.tech
AppContact=support@kennedyekanem.tech
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoDescription={#AppName} installer
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\build\installer
OutputBaseFilename=MonolithKeys-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter={#AppExe}
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Restart Manager cannot see a window-less tray app reliably, so make sure it
; is closed before its files are removed.
Filename: "{sys}\taskkill.exe"; Parameters: "/IM {#AppExe} /F"; Flags: runhidden; RunOnceId: "StopMonolithKeys"

[UninstallDelete]
Type: dirifempty; Name: "{app}"

[Code]
const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    // The app adds this entry itself when "Start with Windows" is on.
    RegDeleteValue(HKEY_CURRENT_USER, RunKey, '{#AppName}');
  if CurUninstallStep = usPostUninstall then
  begin
    if not UninstallSilent and
       (MsgBox('Also remove your MonolithKeys settings and logs?', mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES) then
    begin
      DelTree(ExpandConstant('{userappdata}\{#AppName}'), True, True, True);
      DelTree(ExpandConstant('{localappdata}\{#AppName}'), True, True, True);
    end;
  end;
end;
