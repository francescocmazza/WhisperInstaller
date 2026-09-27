$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$isccCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 7\ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 7\ISCC.exe")
) | Where-Object { $_ -and (Test-Path $_) }

if (-not $isccCandidates) {
    throw "Inno Setup 6 or 7 not found. Install it first, or use the included GitHub Actions workflow."
}

& $isccCandidates[0] ".\installer\WhisperSeamless.iss"
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup build failed with exit code $LASTEXITCODE"
}

Write-Host "Built: installer\Output\Whisper-Seamless-Setup-1.2.1.exe" -ForegroundColor Green
