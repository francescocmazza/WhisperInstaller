from pathlib import Path
import base64
import hashlib

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Whisper-Seamless-Installer-1.1.0.ps1"
CHECKSUM = ROOT / "Whisper-Seamless-Installer-1.1.0.ps1.sha256.txt"

PAYLOAD = [
    "Install-WhisperSeamless.ps1",
    "Uninstall-WhisperSeamless.ps1",
    "VERSION.json",
    "patches/apply_seamless_patch.py",
    "config/configure.py",
    "launcher/Launch-Whisper.vbs",
    "scripts/preflight.py",
    "scripts/Doctor.ps1",
]

parts = [r'''[CmdletBinding()]
param(
    [switch]$SkipModelDownload,
    [switch]$NoAutostart,
    [switch]$NoLaunch,
    [string]$RecordingHotkey = "f24"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stage = Join-Path $env:TEMP ("WhisperSeamlessInstaller-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $stage | Out-Null

function Write-EmbeddedFile([string]$RelativePath, [string]$Base64) {
    $target = Join-Path $stage $RelativePath
    $parent = Split-Path -Parent $target
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [IO.File]::WriteAllBytes($target, [Convert]::FromBase64String($Base64))
}

try {
''']

for rel in PAYLOAD:
    b64 = base64.b64encode((ROOT / rel).read_bytes()).decode("ascii")
    parts.append('    $b64 = ""\n')
    for i in range(0, len(b64), 6000):
        parts.append(f'    $b64 += "{b64[i:i+6000]}"\n')
    parts.append(f'    Write-EmbeddedFile "{rel}" $b64\n')

parts.append(r'''
    $childArgs = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $stage "Install-WhisperSeamless.ps1"),
        "-RecordingHotkey", $RecordingHotkey
    )
    if ($SkipModelDownload) { $childArgs += "-SkipModelDownload" }
    if ($NoAutostart) { $childArgs += "-NoAutostart" }
    if ($NoLaunch) { $childArgs += "-NoLaunch" }

    & powershell.exe @childArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Whisper Seamless installation failed with exit code $LASTEXITCODE."
    }
}
finally {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}
''')

OUTPUT.write_text("".join(parts), encoding="utf-8-sig", newline="\n")
sha = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
CHECKSUM.write_text(f"{sha}  {OUTPUT.name}\n", encoding="utf-8")
print(f"Built {OUTPUT.name}")
print(f"SHA256 {sha}")
