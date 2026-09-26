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
            $_.CommandLine -match "whisper_key\.main"
        } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}

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
    Write-Host "Preserved %APPDATA%\whisperkey and the shared Hugging Face model cache."
}
