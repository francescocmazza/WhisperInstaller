# Whisper Local Seamless Installer — Windows / NVIDIA

Reproducible installer for long-form local Whisper dictation on Windows/NVIDIA,
based on **Whisper Local 0.18.3** with a seamless 30-second rollover patch.

## Installed profile

- Whisper Local `0.18.3`, pinned to commit `8e05b840fac737d4e0dec0886c6d38d0664f94c8`
- `large-v3-turbo`, NVIDIA CUDA, `float16`
- F24 starts continuous dictation; Esc stops/cancels
- MME mono input
- persistent microphone stream and upstream 500 ms pre-roll
- automatic 30-second chunks with capture continuing while the previous chunk is transcribed
- no stop clip at automatic boundaries
- real-time silence auto-stop disabled
- interior long-pause splicing disabled to avoid cutting words at silence boundaries

## Recommended installer

Use the generated standalone installer in the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Whisper-Seamless-Installer-1.0.0.ps1
```

The SHA-256 is stored beside it. GitHub Actions regenerates the standalone
installer from the committed source and also builds
`Whisper-Seamless-Setup-1.0.0.exe` as a workflow artifact.

For development/modular installation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-WhisperSeamless.ps1
```

Default install directory: `%LOCALAPPDATA%\WhisperSeamless`.
Existing `%APPDATA%\whisperkey\user_settings.yaml` is backed up before merging
only the required profile settings.

### Switches

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
