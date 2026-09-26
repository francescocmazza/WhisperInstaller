$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$iscc = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) {
    throw "Inno Setup 6 not found. Install it first, or use the included GitHub Actions workflow."
}

& $iscc ".\installer\WhisperSeamless.iss"
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup build failed with exit code $LASTEXITCODE"
}

Write-Host "Built: installer\Output\Whisper-Seamless-Setup-1.0.0.exe" -ForegroundColor Green
