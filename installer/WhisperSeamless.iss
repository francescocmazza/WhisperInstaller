; Whisper Seamless Inno Setup definition
#define MyAppName "Whisper Seamless"
#define MyAppVersion "1.2.0"
#define MyAppPublisher "Whisper Seamless contributors"
#define MyAppExeName "Whisper-Seamless-Setup-1.2.0.exe"

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
OutputBaseFilename=Whisper-Seamless-Setup-1.2.0
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
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install-WhisperSeamless.ps1"" -FromInno -RecordingHotkey ""{code:GetSelectedHotkey}"" -BindingMode ""{code:GetBindingMode}"" -PhysicalKeyVk {code:GetPhysicalKeyVk} -PhysicalKeyName ""{code:GetPhysicalKeyName}"" {code:GetAutostartSwitch}"; \
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

  VK_SHIFT = $10;
  VK_CONTROL = $11;
  VK_MENU = $12;
  VK_ESCAPE = $1B;
  VK_LWIN = $5B;
  VK_RWIN = $5C;
  VK_APPS = $5D;
  VK_F1 = $70;
  VK_F24 = $87;

var
  ConfigPage: TWizardPage;
  HotkeyCombo: TNewComboBox;
  CurrentHotkeyLabel: TNewStaticText;
  HotkeyStatusLabel: TNewStaticText;
  CaptureLabel: TNewStaticText;
  CaptureEdit: TNewEdit;
  CaptureButton: TNewButton;
  AutostartCheck: TNewCheckBox;
  CurrentAutostartLabel: TNewStaticText;

  CurrentWhisperHotkey: String;
  CurrentBindingMode: String;
  CurrentPhysicalKeyVk: Integer;
  CurrentPhysicalKeyName: String;

  SelectedWhisperHotkey: String;
  SelectedBindingMode: String;
  SelectedPhysicalKeyVk: Integer;
  SelectedPhysicalKeyName: String;
  SelectedHotkeyConflict: Boolean;

  CaptureSuppressVk: Word;
  UpdatingControls: Boolean;

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

function ReadYamlWhisperHotkey: String;
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

procedure ReadCurrentBinding;
var
  BindingFile: String;
begin
  BindingFile := ExpandConstant('{userappdata}\whisperkey\seamless_binding.ini');
  CurrentBindingMode := Lowercase(
    GetIniString('Binding', 'Mode', '', BindingFile));
  CurrentPhysicalKeyName :=
    GetIniString('Binding', 'Display', '', BindingFile);
  CurrentPhysicalKeyVk := StrToIntDef(
    GetIniString('Binding', 'VirtualKey', '0', BindingFile), 0);

  if CurrentBindingMode = 'physical' then
  begin
    CurrentWhisperHotkey := 'f24';
    Exit;
  end;

  CurrentBindingMode := 'native';
  CurrentWhisperHotkey := ReadYamlWhisperHotkey;
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

function PhysicalKeyDisplayName(Key: Word): String;
begin
  case Key of
    VK_APPS:
      Result := 'Menu / Context Menu';
    $08:
      Result := 'Backspace';
    $09:
      Result := 'Tab';
    $0D:
      Result := 'Enter';
    $13:
      Result := 'Pause';
    $14:
      Result := 'Caps Lock';
    $20:
      Result := 'Space';
    $21:
      Result := 'Page Up';
    $22:
      Result := 'Page Down';
    $23:
      Result := 'End';
    $24:
      Result := 'Home';
    $25:
      Result := 'Left Arrow';
    $26:
      Result := 'Up Arrow';
    $27:
      Result := 'Right Arrow';
    $28:
      Result := 'Down Arrow';
    $2C:
      Result := 'Print Screen';
    $2D:
      Result := 'Insert';
    $2E:
      Result := 'Delete';
    $90:
      Result := 'Num Lock';
    $91:
      Result := 'Scroll Lock';
  else
    if (Key >= VK_F1) and (Key <= VK_F24) then
      Result := 'F' + IntToStr(Key - VK_F1 + 1)
    else if (Key >= $41) and (Key <= $5A) then
      Result := Chr(Key)
    else if (Key >= $30) and (Key <= $39) then
      Result := Chr(Key)
    else
      Result := 'Virtual key ' + IntToStr(Key);
  end;
end;

function IsForbiddenPhysicalKey(Key: Word): Boolean;
begin
  Result :=
    (Key = VK_SHIFT) or
    (Key = VK_CONTROL) or
    (Key = VK_MENU) or
    (Key = VK_LWIN) or
    (Key = VK_RWIN) or
    (Key = VK_ESCAPE);
end;

function BindingDescription(
  Mode: String; NativeHotkey: String; PhysicalVk: Integer;
  PhysicalName: String): String;
begin
  if Mode = 'physical' then
  begin
    if PhysicalName = '' then
      PhysicalName := 'VK ' + IntToStr(PhysicalVk);
    Result := PhysicalName + ' (tasto fisico)';
  end
  else if NativeHotkey <> '' then
    Result := Uppercase(NativeHotkey)
  else
    Result := 'nessuna';
end;

procedure UpdateHotkeyStatus(Sender: TObject);
var
  Candidate: String;
  Modifiers, VirtualKey: Cardinal;
begin
  SelectedHotkeyConflict := False;

  if SelectedBindingMode = 'physical' then
  begin
    if SelectedPhysicalKeyVk = VK_APPS then
    begin
      HotkeyStatusLabel.Caption :=
        'Tasto rilevato: Menu / Context Menu (VK_APPS, 0x5D). ' +
        'Funzione Windows attuale: apre il menu contestuale. ' +
        'Mentre Whisper è in esecuzione questa funzione verrà soppressa e il tasto avvierà Whisper. ' +
        'Chiudendo o disinstallando Whisper, il menu contestuale originale torna automaticamente.';
      HotkeyStatusLabel.Font.Color := clGreen;
    end
    else
    begin
      HotkeyStatusLabel.Caption :=
        'Tasto fisico selezionato: ' + SelectedPhysicalKeyName + '. ' +
        'Il comportamento normale di questo tasto verrà soppresso SOLO mentre Whisper è in esecuzione. ' +
        'Alla chiusura/disinstallazione di Whisper il comportamento originale torna automaticamente.';
      HotkeyStatusLabel.Font.Color := clWindowText;
    end;
    Exit;
  end;

  Candidate := NormalizeHotkey(HotkeyCombo.Text);

  if not ParseHotkey(Candidate, Modifiers, VirtualKey) then
  begin
    HotkeyStatusLabel.Caption :=
      'Formato non valido. Usa F1-F24 oppure Ctrl/Alt/Shift/Win + A-Z, 0-9 o Space.';
    HotkeyStatusLabel.Font.Color := clRed;
    Exit;
  end;

  if (CurrentBindingMode = 'native') and
     (CurrentWhisperHotkey <> '') and
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

procedure NativeHotkeyChanged(Sender: TObject);
begin
  if UpdatingControls then
    Exit;

  SelectedBindingMode := 'native';
  SelectedPhysicalKeyVk := 0;
  SelectedPhysicalKeyName := '';
  CaptureEdit.Text := 'Nessun tasto fisico selezionato';
  UpdateHotkeyStatus(nil);
end;

procedure CaptureButtonClick(Sender: TObject);
begin
  CaptureEdit.Text := 'Premi ora il tasto fisico da dedicare a Whisper...';
  CaptureEdit.SetFocus;
end;

procedure CaptureKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Name: String;
begin
  if IsForbiddenPhysicalKey(Key) then
  begin
    CaptureEdit.Text :=
      'Questo tasto è riservato a funzioni essenziali di Whisper/Windows. Scegline un altro.';
    CaptureSuppressVk := Key;
    Key := 0;
    Exit;
  end;

  Name := PhysicalKeyDisplayName(Key);
  SelectedBindingMode := 'physical';
  SelectedPhysicalKeyVk := Key;
  SelectedPhysicalKeyName := Name;
  CaptureSuppressVk := Key;

  UpdatingControls := True;
  try
    CaptureEdit.Text := Name + '  [VK=' + IntToStr(Key) + ']';
  finally
    UpdatingControls := False;
  end;

  UpdateHotkeyStatus(nil);
  Key := 0;
end;

procedure CaptureKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (CaptureSuppressVk <> 0) and (Key = CaptureSuppressVk) then
  begin
    CaptureSuppressVk := 0;
    Key := 0;
  end;
end;

procedure InitializeWizard;
var
  I: Integer;
  ExistingInstall: Boolean;
  CurrentDescription: String;
begin
  ReadCurrentBinding;

  SelectedBindingMode := CurrentBindingMode;
  SelectedWhisperHotkey := CurrentWhisperHotkey;
  SelectedPhysicalKeyVk := CurrentPhysicalKeyVk;
  SelectedPhysicalKeyName := CurrentPhysicalKeyName;

  if (SelectedBindingMode <> 'physical') and (SelectedWhisperHotkey = '') then
    SelectedWhisperHotkey := 'f24';

  ConfigPage := CreateCustomPage(
    wpSelectDir,
    'Configurazione Whisper',
    'Premi il tasto che vuoi usare oppure scegli una combinazione manuale.');

  CurrentDescription := BindingDescription(
    CurrentBindingMode, CurrentWhisperHotkey,
    CurrentPhysicalKeyVk, CurrentPhysicalKeyName);

  CurrentHotkeyLabel := TNewStaticText.Create(ConfigPage);
  CurrentHotkeyLabel.Parent := ConfigPage.Surface;
  CurrentHotkeyLabel.Left := 0;
  CurrentHotkeyLabel.Top := 4;
  CurrentHotkeyLabel.Width := ConfigPage.SurfaceWidth;
  if (CurrentWhisperHotkey <> '') or (CurrentBindingMode = 'physical') then
    CurrentHotkeyLabel.Caption := 'Associazione Whisper attuale: ' + CurrentDescription
  else
    CurrentHotkeyLabel.Caption := 'Nessuna configurazione Whisper precedente rilevata. Default: F24';

  CaptureLabel := TNewStaticText.Create(ConfigPage);
  CaptureLabel.Parent := ConfigPage.Surface;
  CaptureLabel.Left := 0;
  CaptureLabel.Top := CurrentHotkeyLabel.Top + CurrentHotkeyLabel.Height + 12;
  CaptureLabel.Width := ConfigPage.SurfaceWidth;
  CaptureLabel.Caption := 'Metodo consigliato: clicca nel campo e premi fisicamente il tasto che vuoi dedicare a Whisper.';

  CaptureEdit := TNewEdit.Create(ConfigPage);
  CaptureEdit.Parent := ConfigPage.Surface;
  CaptureEdit.Left := 0;
  CaptureEdit.Top := CaptureLabel.Top + CaptureLabel.Height + 6;
  CaptureEdit.Width := ScaleX(315);
  CaptureEdit.ReadOnly := True;
  CaptureEdit.OnKeyDown := @CaptureKeyDown;
  CaptureEdit.OnKeyUp := @CaptureKeyUp;
  if SelectedBindingMode = 'physical' then
    CaptureEdit.Text := SelectedPhysicalKeyName + '  [VK=' + IntToStr(SelectedPhysicalKeyVk) + ']'
  else
    CaptureEdit.Text := 'Clicca qui e premi un tasto';

  CaptureButton := TNewButton.Create(ConfigPage);
  CaptureButton.Parent := ConfigPage.Surface;
  CaptureButton.Left := CaptureEdit.Left + CaptureEdit.Width + ScaleX(8);
  CaptureButton.Top := CaptureEdit.Top - ScaleY(1);
  CaptureButton.Width := ScaleX(95);
  CaptureButton.Height := CaptureEdit.Height + ScaleY(2);
  CaptureButton.Caption := 'Cattura tasto';
  CaptureButton.OnClick := @CaptureButtonClick;

  HotkeyCombo := TNewComboBox.Create(ConfigPage);
  HotkeyCombo.Parent := ConfigPage.Surface;
  HotkeyCombo.Left := 0;
  HotkeyCombo.Top := CaptureEdit.Top + CaptureEdit.Height + 14;
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
  if CurrentBindingMode = 'native' then
    HotkeyCombo.Text := Uppercase(SelectedWhisperHotkey)
  else
    HotkeyCombo.Text := 'F24';
  HotkeyCombo.OnChange := @NativeHotkeyChanged;

  HotkeyStatusLabel := TNewStaticText.Create(ConfigPage);
  HotkeyStatusLabel.Parent := ConfigPage.Surface;
  HotkeyStatusLabel.Left := 0;
  HotkeyStatusLabel.Top := HotkeyCombo.Top + HotkeyCombo.Height + 8;
  HotkeyStatusLabel.AutoSize := False;
  HotkeyStatusLabel.Width := ConfigPage.SurfaceWidth;
  HotkeyStatusLabel.Height := ScaleY(76);
  HotkeyStatusLabel.WordWrap := True;

  ExistingInstall := DirExists(ExpandConstant('{localappdata}\WhisperSeamless'));

  AutostartCheck := TNewCheckBox.Create(ConfigPage);
  AutostartCheck.Parent := ConfigPage.Surface;
  AutostartCheck.Left := 0;
  AutostartCheck.Top := HotkeyStatusLabel.Top + HotkeyStatusLabel.Height + 8;
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
  CurrentAutostartLabel.Top := AutostartCheck.Top + AutostartCheck.Height + 2;
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
  CurrentDescription, NewDescription: String;
begin
  Result := True;
  if CurPageID <> ConfigPage.ID then
    Exit;

  CurrentDescription := BindingDescription(
    CurrentBindingMode, CurrentWhisperHotkey,
    CurrentPhysicalKeyVk, CurrentPhysicalKeyName);
  NewDescription := BindingDescription(
    SelectedBindingMode, SelectedWhisperHotkey,
    SelectedPhysicalKeyVk, SelectedPhysicalKeyName);

  if SelectedBindingMode = 'physical' then
  begin
    if SelectedPhysicalKeyVk = 0 then
    begin
      MsgBox('Premi un tasto fisico da associare a Whisper.', mbError, MB_OK);
      Result := False;
      Exit;
    end;

    if (CurrentDescription <> 'nessuna') and
       (Lowercase(CurrentDescription) <> Lowercase(NewDescription)) then
    begin
      if MsgBox(
        'Whisper usa attualmente ' + CurrentDescription + '.' + #13#10 +
        'Vuoi cambiarla in ' + NewDescription + '?',
        mbConfirmation, MB_YESNO) <> IDYES then
      begin
        Result := False;
        Exit;
      end;
    end;

    if SelectedPhysicalKeyVk = VK_APPS then
    begin
      if MsgBox(
        'Il tasto Menu / Context Menu apre normalmente il menu contestuale di Windows.' + #13#10 + #13#10 +
        'Se continui, questa funzione verrà soppressa SOLO mentre Whisper è in esecuzione e il tasto avvierà Whisper.' + #13#10 +
        'Chiudendo o disinstallando Whisper, il comportamento originale del tasto verrà ripristinato automaticamente.' + #13#10 + #13#10 +
        'Confermi di voler dedicare questo tasto a Whisper?',
        mbConfirmation, MB_YESNO) <> IDYES then
      begin
        Result := False;
        Exit;
      end;
    end
    else
    begin
      if MsgBox(
        'Confermi di voler dedicare il tasto ' + SelectedPhysicalKeyName + ' a Whisper?' + #13#10 + #13#10 +
        'Il suo comportamento normale sarà soppresso soltanto mentre Whisper è in esecuzione. ' +
        'Alla chiusura o disinstallazione verrà ripristinato automaticamente.',
        mbConfirmation, MB_YESNO) <> IDYES then
      begin
        Result := False;
        Exit;
      end;
    end;

    Exit;
  end;

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

  SelectedWhisperHotkey := Candidate;
  NewDescription := BindingDescription('native', Candidate, 0, '');

  if (CurrentDescription <> 'nessuna') and
     (Lowercase(CurrentDescription) <> Lowercase(NewDescription)) then
  begin
    if MsgBox(
      'Whisper usa attualmente ' + CurrentDescription + '.' + #13#10 +
      'Vuoi cambiarla in ' + NewDescription + '?',
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
end;

function GetSelectedHotkey(Param: String): String;
begin
  if SelectedBindingMode = 'physical' then
    Result := 'f24'
  else if SelectedWhisperHotkey = '' then
    Result := 'f24'
  else
    Result := SelectedWhisperHotkey;
end;

function GetBindingMode(Param: String): String;
begin
  if SelectedBindingMode = 'physical' then
    Result := 'physical'
  else
    Result := 'native';
end;

function GetPhysicalKeyVk(Param: String): String;
begin
  if SelectedBindingMode = 'physical' then
    Result := IntToStr(SelectedPhysicalKeyVk)
  else
    Result := '0';
end;

function GetPhysicalKeyName(Param: String): String;
begin
  if SelectedBindingMode = 'physical' then
    Result := SelectedPhysicalKeyName
  else
    Result := '';
end;

function GetAutostartSwitch(Param: String): String;
begin
  if AutostartCheck.Checked then
    Result := ''
  else
    Result := '-NoAutostart';
end;
