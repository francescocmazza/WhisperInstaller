$ErrorActionPreference = "Stop"

$root = Join-Path $env:LOCALAPPDATA "WhisperSeamless"
$python = Join-Path $root "runtime\Python312\python.exe"
$site = Join-Path $root "runtime\Python312\Lib\site-packages"

if (-not (Test-Path $python)) {
    throw "Whisper Seamless runtime not found: $python"
}

$env:PATH = (Join-Path $site "nvidia\cuda_runtime\bin") + ";" +
            (Join-Path $site "nvidia\cublas\bin") + ";" +
            (Join-Path $site "nvidia\cudnn\bin") + ";" + $env:PATH

& $python -m whisper_key.main --doctor
exit $LASTEXITCODE
