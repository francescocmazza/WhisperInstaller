; Whisper Seamless Inno Setup definition
#define MyAppName "Whisper Seamless"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "Whisper Seamless contributors"
#define MyAppExeName "Whisper-Seamless-Setup-1.1.0.exe"

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
OutputBaseFilename=Whisper-Seamless-Setup-1.1.0
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
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install-WhisperSeamless.ps1"" -FromInno -RecordingHotkey ""{code:GetSelectedHotkey}"" {code:GetAutostartSwitch}"; \
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

[Code]
const
  MOD_ALT = $0001;
  MOD_CONTROL = $0002;
  MOD_SHIFT = $0004;
  MOD_WIN = $0008;
  MOD_NOREPEAT = $4000;
  HOTKEY_TEST_ID = $51A7;

var
  ConfigPage: TWizardPage;
  HotkeyCombo: TNewComboBox;
  CurrentHotkeyLabel: TNewStaticText;
  HotkeyStatusLabel: TNewStaticText;
  AutostartCheck: TNewCheckBox;
  CurrentAutostartLabel: TNewStaticText;
  CurrentWhisperHotkey: String;
  SelectedWhisperHotkey: String;
  SelectedHotkeyConflict: Boolean;

function RegisterHotKey(hWnd: HWND; id: Integer; fsModifiers, vk: Cardinal): Boolean;
  external 'RegisterHotKey@user32.dll stdcall';
function UnregisterHotKey(hWnd: HWND; id: Integer): Boolean;
  external 'UnregisterHotKey@user32.dll stdcall';

function NormalizeHotkey(Value: String): String;
begin
  Value := Lowercase(Trim(Value));
  StringChangeEx(Value, ' ', '', True);
  Result := Value;
end;

function RemoveYamlQuotes(Value: String): String;
begin
  Result := Trim(Value);
  if (Length(Result) >= 2) and (Result[1] = '"') and
     (Result[Length(Result)] = '"') then
  begin
    Delete(Result, Length(Result), 1);
    Delete(Result, 1, 1);
  end;
end;

function ReadCurrentWhisperHotkey: String;
var
  Lines: TArrayOfString;
  I, P: Integer;
  S, Value: String;
begin
  Result := '';
  if not LoadStringsFromFile(
    ExpandConstant('{userappdata}\whisperkey\user_settings.yaml'), Lines) then
    Exit;

  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    S := Trim(Lines[I]);
    if Pos('recording_hotkey:', Lowercase(S)) = 1 then
    begin
      Value := Trim(Copy(S, Length('recording_hotkey:') + 1, Length(S)));
      P := Pos('#', Value);
      if P > 0 then
        Value := Trim(Copy(Value, 1, P - 1));
      Result := NormalizeHotkey(RemoveYamlQuotes(Value));
      P := Pos('|', Result);
      if P > 0 then
        Result := NormalizeHotkey(Copy(Result, 1, P - 1));
      Exit;
    end;
  end;
end;

function KeyNameToVirtualKey(KeyName: String; var VirtualKey: Cardinal): Boolean;
var
  N, P: Integer;
begin
  Result := False;
  KeyName := Lowercase(KeyName);

  if (Length(KeyName) >= 2) and (KeyName[1] = 'f') then
  begin
    N := StrToIntDef(Copy(KeyName, 2, Length(KeyName) - 1), 0);
    if (N >= 1) and (N <= 24) then
    begin
      VirtualKey := $6F + N;
      Result := True;
      Exit;
    end;
  end;

  if KeyName = 'space' then
  begin
    VirtualKey := $20;
    Result := True;
    Exit;
  end;

  if Length(KeyName) = 1 then
  begin
    P := Pos(KeyName, 'abcdefghijklmnopqrstuvwxyz');
    if P > 0 then
    begin
      VirtualKey := 64 + P;
      Result := True;
      Exit;
    end;

    P := Pos(KeyName, '0123456789');
    if P > 0 then
    begin
      VirtualKey := 47 + P;
      Result := True;
      Exit;
    end;
  end;
end;

function ParseHotkey(Value: String; var Modifiers, VirtualKey: Cardinal): Boolean;
var
  Work, Token, KeyName: String;
  P: Integer;
begin
  Result := False;
  Modifiers := MOD_NOREPEAT;
  VirtualKey := 0;
  Work := NormalizeHotkey(Value);
  KeyName := '';

  while Work <> '' do
  begin
    P := Pos('+', Work);
    if P > 0 then
    begin
      Token := Copy(Work, 1, P - 1);
      Delete(Work, 1, P);
    end
    else
    begin
      Token := Work;
      Work := '';
    end;

    if Token = 'ctrl' then
      Modifiers := Modifiers or MOD_CONTROL
    else if Token = 'alt' then
      Modifiers := Modifiers or MOD_ALT
    else if Token = 'shift' then
      Modifiers := Modifiers or MOD_SHIFT
    else if Token = 'win' then
      Modifiers := Modifiers or MOD_WIN
    else if KeyName = '' then
      KeyName := Token
    else
      Exit;
  end;

  if not KeyNameToVirtualKey(KeyName, VirtualKey) then
    Exit;

  { Never allow a bare letter, digit or Space to become a global dictation key. }
  if (Modifiers = MOD_NOREPEAT) and
     ((Length(KeyName) = 1) or (KeyName = 'space')) then
    Exit;

  Result := True;
end;

function HotkeyIsAvailable(Value: String): Boolean;
var
  Modifiers, VirtualKey: Cardinal;
begin
  Result := False;
  if not ParseHotkey(Value, Modifiers, VirtualKey) then
    Exit;

  Result := RegisterHotKey(WizardForm.Handle, HOTKEY_TEST_ID, Modifiers, VirtualKey);
  if Result then
    UnregisterHotKey(WizardForm.Handle, HOTKEY_TEST_ID);
end;

function ExistingAutostartEnabled: Boolean;
begin
  Result := RegValueExists(
    HKEY_CURRENT_USER,
    'Software\Microsoft\Windows\CurrentVersion\Run',
    'WhisperLocal');
end;

procedure UpdateHotkeyStatus(Sender: TObject);
var
  Candidate: String;
  Modifiers, VirtualKey: Cardinal;
begin
  Candidate := NormalizeHotkey(HotkeyCombo.Text);
  SelectedHotkeyConflict := False;

  if not ParseHotkey(Candidate, Modifiers, VirtualKey) then
  begin
    HotkeyStatusLabel.Caption :=
      'Formato non valido. Usa F1-F24 oppure Ctrl/Alt/Shift/Win + A-Z, 0-9 o Space.';
    HotkeyStatusLabel.Font.Color := clRed;
    Exit;
  end;

  if (CurrentWhisperHotkey <> '') and
     (Candidate = NormalizeHotkey(CurrentWhisperHotkey)) then
  begin
    HotkeyStatusLabel.Caption :=
      'Associazione attuale di Whisper: ' + Uppercase(Candidate) +
      '. Verrà mantenuta salvo modifica.';
    HotkeyStatusLabel.Font.Color := clWindowText;
    Exit;
  end;

  if HotkeyIsAvailable(Candidate) then
  begin
    HotkeyStatusLabel.Caption :=
      'Disponibile: Windows non rileva un''altra registrazione globale per questa combinazione.';
    HotkeyStatusLabel.Font.Color := clGreen;
  end
  else
  begin
    SelectedHotkeyConflict := True;
    HotkeyStatusLabel.Caption :=
      'Attenzione: questa combinazione risulta già registrata da Windows o da un''altra applicazione. ' +
      'Windows non espone in modo affidabile il nome del programma che la possiede.';
    HotkeyStatusLabel.Font.Color := clRed;
  end;
end;

procedure InitializeWizard;
var
  I: Integer;
  ExistingInstall: Boolean;
begin
  CurrentWhisperHotkey := ReadCurrentWhisperHotkey;
  SelectedWhisperHotkey := CurrentWhisperHotkey;
  if SelectedWhisperHotkey = '' then
    SelectedWhisperHotkey := 'f24';

  ConfigPage := CreateCustomPage(
    wpSelectDir,
    'Configurazione Whisper',
    'Scegli la scorciatoia di dettatura e l''avvio automatico.');

  CurrentHotkeyLabel := TNewStaticText.Create(ConfigPage);
  CurrentHotkeyLabel.Parent := ConfigPage.Surface;
  CurrentHotkeyLabel.Left := 0;
  CurrentHotkeyLabel.Top := 8;
  CurrentHotkeyLabel.Width := ConfigPage.SurfaceWidth;
  if CurrentWhisperHotkey <> '' then
    CurrentHotkeyLabel.Caption :=
      'Scorciatoia Whisper attuale: ' + Uppercase(CurrentWhisperHotkey)
  else
    CurrentHotkeyLabel.Caption :=
      'Nessuna configurazione Whisper precedente rilevata. Default: F24';

  HotkeyCombo := TNewComboBox.Create(ConfigPage);
  HotkeyCombo.Parent := ConfigPage.Surface;
  HotkeyCombo.Left := 0;
  HotkeyCombo.Top := CurrentHotkeyLabel.Top + CurrentHotkeyLabel.Height + 12;
  HotkeyCombo.Width := ScaleX(250);
  HotkeyCombo.Style := csDropDown;
  HotkeyCombo.MaxLength := 40;

  for I := 24 downto 13 do
    HotkeyCombo.Items.Add('F' + IntToStr(I));
  for I := 12 downto 1 do
    HotkeyCombo.Items.Add('F' + IntToStr(I));
  HotkeyCombo.Items.Add('Ctrl+Alt+Space');
  HotkeyCombo.Items.Add('Ctrl+Shift+Space');
  HotkeyCombo.Items.Add('Ctrl+Win+Space');
  HotkeyCombo.Items.Add('Alt+Win+Space');
  HotkeyCombo.Items.Add('Ctrl+Alt+W');
  HotkeyCombo.Items.Add('Ctrl+Shift+W');
  HotkeyCombo.Items.Add('Ctrl+Win+W');
  HotkeyCombo.Text := Uppercase(SelectedWhisperHotkey);
  HotkeyCombo.OnChange := @UpdateHotkeyStatus;

  HotkeyStatusLabel := TNewStaticText.Create(ConfigPage);
  HotkeyStatusLabel.Parent := ConfigPage.Surface;
  HotkeyStatusLabel.Left := 0;
  HotkeyStatusLabel.Top := HotkeyCombo.Top + HotkeyCombo.Height + 8;
  HotkeyStatusLabel.AutoSize := False;
  HotkeyStatusLabel.Width := ConfigPage.SurfaceWidth;
  HotkeyStatusLabel.Height := ScaleY(54);
  HotkeyStatusLabel.WordWrap := True;

  ExistingInstall := DirExists(ExpandConstant('{localappdata}\WhisperSeamless'));

  AutostartCheck := TNewCheckBox.Create(ConfigPage);
  AutostartCheck.Parent := ConfigPage.Surface;
  AutostartCheck.Left := 0;
  AutostartCheck.Top := HotkeyStatusLabel.Top + HotkeyStatusLabel.Height + 18;
  AutostartCheck.Width := ConfigPage.SurfaceWidth;
  AutostartCheck.Caption := 'Avvia Whisper automaticamente all''accesso a Windows';
  if ExistingAutostartEnabled then
    AutostartCheck.Checked := True
  else if ExistingInstall then
    AutostartCheck.Checked := False
  else
    AutostartCheck.Checked := True;

  CurrentAutostartLabel := TNewStaticText.Create(ConfigPage);
  CurrentAutostartLabel.Parent := ConfigPage.Surface;
  CurrentAutostartLabel.Left := ScaleX(20);
  CurrentAutostartLabel.Top := AutostartCheck.Top + AutostartCheck.Height + 4;
  CurrentAutostartLabel.Width := ConfigPage.SurfaceWidth - ScaleX(20);
  if ExistingAutostartEnabled then
    CurrentAutostartLabel.Caption := 'Stato attuale: avvio automatico abilitato.'
  else if ExistingInstall then
    CurrentAutostartLabel.Caption := 'Stato attuale: avvio automatico disabilitato.'
  else
    CurrentAutostartLabel.Caption := 'Nuova installazione: avvio automatico proposto come default.';

  UpdateHotkeyStatus(nil);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Candidate: String;
  Modifiers, VirtualKey: Cardinal;
begin
  Result := True;
  if CurPageID <> ConfigPage.ID then
    Exit;

  Candidate := NormalizeHotkey(HotkeyCombo.Text);
  if not ParseHotkey(Candidate, Modifiers, VirtualKey) then
  begin
    MsgBox(
      'La scorciatoia non è valida.' + #13#10 + #13#10 +
      'Usa F1-F24 oppure una combinazione di Ctrl/Alt/Shift/Win con A-Z, 0-9 o Space.',
      mbError, MB_OK);
    Result := False;
    Exit;
  end;

  if (CurrentWhisperHotkey <> '') and
     (Candidate <> NormalizeHotkey(CurrentWhisperHotkey)) then
  begin
    if MsgBox(
      'Whisper usa attualmente ' + Uppercase(CurrentWhisperHotkey) + '.' + #13#10 +
      'Vuoi cambiarla in ' + Uppercase(Candidate) + '?',
      mbConfirmation, MB_YESNO) <> IDYES then
    begin
      Result := False;
      Exit;
    end;
  end;

  UpdateHotkeyStatus(nil);
  if SelectedHotkeyConflict then
  begin
    if MsgBox(
      'La combinazione ' + Uppercase(Candidate) +
      ' risulta già registrata da Windows o da un''altra applicazione.' + #13#10 + #13#10 +
      'Se continui, Whisper potrebbe non riuscire ad acquisirla. Vuoi usarla comunque?',
      mbConfirmation, MB_YESNO) <> IDYES then
    begin
      Result := False;
      Exit;
    end;
  end;

  SelectedWhisperHotkey := Candidate;
end;

function GetSelectedHotkey(Param: String): String;
begin
  if SelectedWhisperHotkey = '' then
    Result := 'f24'
  else
    Result := SelectedWhisperHotkey;
end;

function GetAutostartSwitch(Param: String): String;
begin
  if AutostartCheck.Checked then
    Result := ''
  else
    Result := '-NoAutostart';
end;
