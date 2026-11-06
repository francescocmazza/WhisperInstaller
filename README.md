# Whisper Local Seamless Installer — Windows

Reproducible installer for long-form local Whisper dictation on Windows, based
on **Whisper Local 0.18.3** with a seamless 30-second rollover patch.

## v1.3.3 — robust Python runtime + captured hotkeys

v1.3.3 changes the Windows Python bootstrap architecture. If Python 3.12 x64 is
already installed, Whisper Seamless reuses it only as the **base interpreter**
and creates an isolated virtual environment under
`%LOCALAPPDATA%\WhisperSeamless\runtime\Python312`.

This avoids trying to register a second copy of the same Python version through
Windows Installer. If Python 3.12 is absent, the installer first installs the
official Python base runtime and then creates the same isolated venv.

The launcher and Doctor support both the new venv layout
(`Scripts\python.exe`) and the legacy private-runtime layout.

### Capture hotkey combinations

The configuration page can now capture a complete native hotkey chord. Click
**Cattura combinazione**, hold the modifier(s), and press the final key.

Example for an Italian/European keyboard:

- hold **Alt**;
- press the **< >** key;
- the installer displays **Alt + <**;
- internally it stores the Windows OEM key code (VK_OEM_102 / 226) in a format
  supported by Whisper's global hotkey backend.

Captured modifier chords are registered as normal global hotkeys. They do not
use the physical-key suppression hook and do not permanently remap the keyboard.

## True start/stop toggle

In toggle mode, the configured recording hotkey now behaves as a true toggle:
first press starts recording; second press stops, transcribes, and remains
stopped. The seamless 30-second rollover still keeps long dictation gapless, so
the separate continuous auto-restart mode is disabled in this profile.

## NVIDIA CUDA or CPU INT8

The installer now supports PCs without an NVIDIA GPU.

The **Prestazioni Whisper** page offers:

- **Auto** — use NVIDIA CUDA/float16 when a working NVIDIA GPU is detected,
  otherwise fall back to CPU/INT8;
- **NVIDIA CUDA** — require NVIDIA and use float16;
- **CPU INT8** — run entirely on the processor; no NVIDIA GPU required.

Model choices:

- **Auto** — Large-V3-Turbo on NVIDIA CUDA, Medium on CPU;
- **large-v3-turbo** — highest accuracy, heavier on CPU;
- **medium** — recommended CPU balance;
- **small** — fastest option for CPU-only dictation.

On Intel/AMD machines without NVIDIA, the current CTranslate2 backend uses the
CPU. Intel integrated GPU and Intel NPU are not yet used by this installer
profile. They may be targeted separately through an OpenVINO backend in a future
release.

## Press the physical key you want

The installer can capture either a normal modifier combination (for example
**Alt + <**) or a single physical key directly. This includes the Windows **Menu / Context Menu key** next to the right
Ctrl key (`VK_APPS`, virtual-key code `0x5D`).

Physical-key mode uses a process-local Windows low-level keyboard hook. It does
not write `Scancode Map`, keyboard firmware, or any permanent keyboard remap.
The original key behavior returns automatically when Whisper exits and after
uninstall.

## Installed dictation behavior

- configurable native hotkey or reversible physical-key binding;
- default native hotkey: F24;
- Esc stops/cancels;
- MME mono input;
- persistent microphone stream and 500 ms pre-roll;
- seamless automatic 30-second chunks;
- the next chunk records while the previous chunk is processed;
- no stop clip at automatic boundaries;
- real-time silence auto-stop disabled;
- interior long-pause splicing disabled to avoid cutting words;
- optional silent Start-with-Windows.

## Recommended installer

Use the latest release executable:

```text
Whisper-Seamless-Setup-1.3.3.exe
```

For a CPU-only machine, leave **Compute backend = Auto** or explicitly select
**CPU - INT8**.

Leave the model on **Auto** unless you have a specific preference. On CPU-only
machines Auto selects `medium` to reduce post-recording latency; NVIDIA systems
select `large-v3-turbo`.

### PowerShell examples

Automatic hardware selection:

```powershell
.\Install-WhisperSeamless.ps1 -ComputeBackend auto -WhisperModel large-v3-turbo
```

Force CPU INT8:

```powershell
.\Install-WhisperSeamless.ps1 -ComputeBackend cpu -WhisperModel large-v3-turbo
```

Faster CPU profile:

```powershell
.\Install-WhisperSeamless.ps1 -ComputeBackend cpu -WhisperModel small
```

Physical Menu key:

```powershell
.\Install-WhisperSeamless.ps1 -BindingMode physical -PhysicalKeyVk 93 -PhysicalKeyName "Menu / Context Menu" -ComputeBackend cpu
```

## Intel Core Ultra / NPU note

Intel Core Ultra processors can expose CPU, Intel integrated graphics and an NPU.
This v1.3.3 profile intentionally keeps the stable Whisper Local
`faster-whisper/CTranslate2` backend, so non-NVIDIA systems use CPU INT8.
OpenVINO can target Intel CPU/GPU/NPU and is a separate optimization path rather
than silently changing the transcription backend.

## Validation

For continuous dictation, speak for at least 70 seconds across the 30 s and
60 s boundaries. No automatic stop clip should be heard and the beginning of
the next phrase should not disappear.

For physical-key mode:

1. with Whisper running, press the selected key and confirm that Whisper reacts;
2. if using the Menu key, confirm that no context menu appears while Whisper runs;
3. close Whisper and confirm that the original key action returns.

Diagnostics:

```powershell
.\scripts\Doctor.ps1
```

## Security

The public repository excludes credentials, personal settings, transcripts,
audio, logs, model caches and machine-specific input device IDs. See
`SECURITY.md` and the automated `scripts/check_secrets.py` check.

## Uninstall

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-WhisperSeamless.ps1
```

User settings/history and the shared Hugging Face cache are preserved by default.
Add `-RemoveUserData` only when you also want those removed.
