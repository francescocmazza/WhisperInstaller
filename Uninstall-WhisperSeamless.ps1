[CmdletBinding()]
param(
    [switch]$RemoveUserData,
    [switch]$Inno
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$InstallRoot = Join-Path $env:LOCALAPPDATA "WhisperSeamless"

Write-Host "Stopping Whisper Seamless..."
try {
    Get-CimInstance Win32_Process |
        Where-Object {
            ($_.Name -ieq "python.exe" -or $_.Name -ieq "pythonw.exe") -and
            $_.CommandLine -match "whisper_key\.main|launch_with_binding\.py"
        } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}

# The physical-key override is a process-local low-level keyboard hook.
# Once the Whisper process is gone, Windows immediately resumes the key's
# original behavior (for VK_APPS this is the standard context menu).
Start-Sleep -Milliseconds 300
$remaining = @(
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.Name -ieq "python.exe" -or $_.Name -ieq "pythonw.exe") -and
            $_.CommandLine -match "whisper_key\.main|launch_with_binding\.py"
        }
)
if ($remaining.Count -gt 0) {
    $remaining | ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 300
}

$bindingFile = Join-Path $env:APPDATA "whisperkey\seamless_binding.ini"
Remove-Item $bindingFile -Force -ErrorAction SilentlyContinue
Write-Host "Physical-key override removed; original Windows key behavior restored."

# Remove the Run entry only if it still points to this install.
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
try {
    $value = (Get-ItemProperty -Path $runKey -Name "WhisperLocal" -ErrorAction Stop).WhisperLocal
    if ($value -match [regex]::Escape($InstallRoot)) {
        Remove-ItemProperty -Path $runKey -Name "WhisperLocal" -ErrorAction SilentlyContinue
    }
} catch {}

$programs = [Environment]::GetFolderPath("Programs")
Remove-Item (Join-Path $programs "Whisper Seamless.lnk") -Force -ErrorAction SilentlyContinue

if ($RemoveUserData) {
    $cfg = Join-Path $env:APPDATA "whisperkey"
    if (Test-Path $cfg) {
        Remove-Item $cfg -Recurse -Force
        Write-Host "Removed Whisper Local user settings/history: $cfg"
    }
}

if (-not $Inno -and (Test-Path $InstallRoot)) {
    Set-Location $env:TEMP
    Remove-Item $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Whisper Seamless removed."
if (-not $RemoveUserData) {
    Write-Host "Preserved Whisper Local user settings/history and the shared Hugging Face model cache."
    Write-Host "The Whisper Seamless physical-key binding itself was removed."
}
