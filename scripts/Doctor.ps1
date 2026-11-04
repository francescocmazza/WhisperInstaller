$ErrorActionPreference = "Stop"

$root = Join-Path $env:LOCALAPPDATA "WhisperSeamless"
$venvPython = Join-Path $root "runtime\Python312\Scripts\python.exe"
$legacyPython = Join-Path $root "runtime\Python312\python.exe"
$python = if (Test-Path $venvPython) { $venvPython } else { $legacyPython }
$site = Join-Path $root "runtime\Python312\Lib\site-packages"

if (-not (Test-Path $python)) {
    throw "Whisper Seamless runtime not found in venv or legacy layout."
}

$env:PATH = (Join-Path $site "nvidia\cuda_runtime\bin") + ";" +
            (Join-Path $site "nvidia\cublas\bin") + ";" +
            (Join-Path $site "nvidia\cudnn\bin") + ";" + $env:PATH

& $python -m whisper_key.main --doctor
exit $LASTEXITCODE
