# Whisper Local Seamless Installer — Windows / NVIDIA

Reproducible installer for long-form local Whisper dictation on Windows/NVIDIA,
based on **Whisper Local 0.18.3** with a seamless 30-second rollover patch.

## v1.2.1 — press the key you want

### Windows 64-bit hook fix

v1.2.1 fixes a Windows 64-bit ABI bug in v1.2.0. `GetModuleHandleW`
was being called without an explicit pointer-sized ctypes return type, so its
64-bit module handle could be truncated before being passed to
`SetWindowsHookExW`. On affected machines the physical-key bridge failed with
`WinError 126 (The specified module could not be found)`.

The Win32 signatures are now explicit and pointer-sized, `use_last_error=True`
is used for accurate diagnostics, and CI performs a real
`WH_KEYBOARD_LL` install/remove test on Windows instead of merely importing the
module.


The Windows installer includes a configuration page where you can either choose
a normal global hotkey or simply **click the capture field and press the physical
key you want to dedicate to Whisper**.

This includes the Windows **Menu / Context Menu key** next to the right Ctrl key
(`VK_APPS`, virtual-key code `0x5D`).

When that key is selected, the installer explains its current Windows behavior
(opens the context menu) and asks for explicit confirmation before taking it over.

### Reversible physical-key override

Physical-key mode is intentionally **not** implemented with a permanent keyboard
remap. Whisper does not write Windows `Scancode Map`, does not change keyboard
firmware and does not permanently alter the key in the registry.

Instead, while Whisper is running, a process-local Windows low-level keyboard
hook:

1. detects the selected physical key;
2. suppresses its normal Windows/application action;
3. invokes the Whisper recording action directly.

When Whisper exits, the hook disappears with the process and the original key
behavior returns immediately. The uninstaller also stops all Whisper/binding
processes and removes `%APPDATA%\whisperkey\seamless_binding.ini`.

For the Menu key this means:

> Whisper running → the key controls Whisper and does not open the context menu.  
> Whisper closed/uninstalled → the same key opens the normal context menu again.

There is no persistent remapping that needs to be reconstructed during uninstall.

## Installer configuration UI

The wizard can:

- capture a physical key by pressing it;
- show the current Whisper binding when upgrading/reconfiguring;
- show the known default Windows action for the Menu/Context Menu key;
- require confirmation before replacing the current Whisper binding;
- require confirmation before suppressing a physical key's normal behavior;
- choose normal F1-F24 or modifier-based global hotkeys manually;
- test normal global hotkeys for Windows registration conflicts;
- enable or disable **Start Whisper automatically when I sign in to Windows**.

For ordinary global hotkeys, Windows can tell us whether the combination is
already registered but does not expose a reliable public API identifying the
owning process. The installer therefore reports the conflict without inventing
an application name.

## Installed profile

- Whisper Local `0.18.3`, pinned to commit `8e05b840fac737d4e0dec0886c6d38d0664f94c8`
- `large-v3-turbo`, NVIDIA CUDA, `float16`
- configurable native hotkey or reversible physical-key binding
- default native hotkey: F24
- Esc stops/cancels
- MME mono input
- persistent microphone stream and upstream 500 ms pre-roll
- automatic 30-second chunks with capture continuing while the previous chunk is transcribed
- no stop clip at automatic boundaries
- real-time silence auto-stop disabled
- interior long-pause splicing disabled to avoid cutting words at silence boundaries

## Recommended installer

Use the latest release executable:

```text
Whisper-Seamless-Setup-1.2.1.exe
```

The graphical `.exe` is recommended because it provides physical key capture
and the autostart controls.

For development/modular installation with a normal hotkey:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-WhisperSeamless.ps1 -RecordingHotkey f24
```

Example physical Menu key installation from PowerShell:

```powershell
.\Install-WhisperSeamless.ps1 -BindingMode physical -PhysicalKeyVk 93 -PhysicalKeyName "Menu / Context Menu"
```

The standalone PowerShell installer accepts the same binding parameters.

## Validation

For continuous dictation, speak for at least 70 seconds across the 30 s and
60 s boundaries. No automatic stop clip should be heard and the next phrase
should not lose its beginning.

For physical-key mode:

1. with Whisper running, press the selected key and confirm that Whisper reacts;
2. for the Menu key, confirm that no context menu appears while Whisper is running;
3. close Whisper and press the key again — its original Windows action must work;
4. uninstall Whisper and verify the same again.

Diagnostics:

```powershell
.\scripts\Doctor.ps1
```

## Build validation

Pull requests run:

- secret/personal-data scanning;
- Python syntax checks;
- a real Windows start/stop test of the low-level keyboard hook;
- Inno Setup compilation of the graphical installer.

## Security

This public repository intentionally excludes credentials, personal settings,
transcripts, audio, logs, model caches and machine-specific input device IDs.
See `SECURITY.md` and the automated `scripts/check_secrets.py` check.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-WhisperSeamless.ps1
```

The uninstaller always removes the Whisper Seamless physical-key binding and
stops the process-local hook, even when normal Whisper Local settings/history
are preserved. Add `-RemoveUserData` only when you also want those other user
settings/history removed.
