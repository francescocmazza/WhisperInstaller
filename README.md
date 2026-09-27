# Whisper Local Seamless Installer — Windows / NVIDIA

Reproducible installer for long-form local Whisper dictation on Windows/NVIDIA,
based on **Whisper Local 0.18.3** with a seamless 30-second rollover patch.

## v1.1.0 installer configuration UI

The Windows `.exe` installer now includes a dedicated **Whisper configuration**
page before installation:

- choose the global dictation hotkey instead of being forced to use F24;
- F13-F24 are offered first because they are rarely used by normal applications;
- common modifier combinations are also offered, and a compatible custom value can be typed;
- the installer reads and displays the **current Whisper hotkey** when upgrading/reconfiguring;
- it tests whether the selected hotkey can be registered globally by Windows;
- if Windows reports the combination as already registered/reserved, the installer warns and requires explicit confirmation before continuing;
- if the selected hotkey differs from the current Whisper binding, the installer asks for explicit confirmation before changing it;
- a checkbox enables or disables **Start Whisper automatically when I sign in to Windows** and reflects the current state on existing installations.

Windows can reliably tell us whether a global hotkey is already registered, but it
does **not** provide a reliable public API that identifies the process that owns
that registration. For this reason the installer reports `available` or
`already registered by Windows/another application`, rather than inventing an
application name.

## Installed profile

- Whisper Local `0.18.3`, pinned to commit `8e05b840fac737d4e0dec0886c6d38d0664f94c8`
- `large-v3-turbo`, NVIDIA CUDA, `float16`
- configurable global hotkey (default: F24); Esc stops/cancels
- MME mono input
- persistent microphone stream and upstream 500 ms pre-roll
- automatic 30-second chunks with capture continuing while the previous chunk is transcribed
- no stop clip at automatic boundaries
- real-time silence auto-stop disabled
- interior long-pause splicing disabled to avoid cutting words at silence boundaries

## Recommended installer

Use the latest release executable:

```text
Whisper-Seamless-Setup-1.1.0.exe
```

The graphical installer is the recommended path because it exposes the hotkey
and autostart controls described above.

For development/modular installation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-WhisperSeamless.ps1 -RecordingHotkey f24
```

The standalone PowerShell installer also accepts a hotkey from the command line:

```powershell
.\Whisper-Seamless-Installer-1.1.0.ps1 -RecordingHotkey "ctrl+alt+space"
```

Add `-NoAutostart` to explicitly disable Start-with-Windows.

Default install directory: `%LOCALAPPDATA%\WhisperSeamless`.
Existing `%APPDATA%\whisperkey\user_settings.yaml` is backed up before merging
only the required profile settings.

### Other switches

```powershell
.\Install-WhisperSeamless.ps1 -SkipModelDownload
.\Install-WhisperSeamless.ps1 -NoAutostart
.\Install-WhisperSeamless.ps1 -NoLaunch
```

## Validation

After installation, dictate continuously for at least 70 seconds while speaking
across both the 30 s and 60 s boundaries. No automatic stop clip should be heard
and the beginning of the next phrase should not disappear. Press Esc while
speaking to verify that capture stops and does not restart.

Diagnostics:

```powershell
.\scripts\Doctor.ps1
```

## Build validation

Pull requests run the full Windows installer build, including Inno Setup
compilation. This catches errors in the custom configuration wizard before they
can reach `main`.

## Security

This public repository intentionally excludes credentials, personal settings,
transcripts, audio, logs, model caches and machine-specific input device IDs.
See `SECURITY.md` and the automated `scripts/check_secrets.py` check.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-WhisperSeamless.ps1
```

User settings/history and the shared Hugging Face cache are preserved by
default. Add `-RemoveUserData` only when you explicitly want them removed.
