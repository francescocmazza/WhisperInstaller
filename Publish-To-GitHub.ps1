[CmdletBinding()]
param(
    [string]$RepoName = "WhisperInstaller",
    [string]$ReleaseTag = "v1.0.0"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Assert-Exit([string]$What) {
    if ($LASTEXITCODE -ne 0) { throw "$What failed with exit code $LASTEXITCODE" }
}

& gh auth status
Assert-Exit "gh auth status"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw "Python is required for the local safety scan." }
& $python.Source (Join-Path $PSScriptRoot "scripts\check_secrets.py")
Assert-Exit "secret scan"

if (-not (Test-Path (Join-Path $PSScriptRoot ".git"))) {
    & git init -b main
    Assert-Exit "git init"
}
& git add .
Assert-Exit "git add"
if (& git status --porcelain) {
    & git commit -m "Publish Whisper Seamless installer"
    Assert-Exit "git commit"
}

$remote = (& git remote get-url origin 2>$null)
if (-not $remote) {
    & gh repo create $RepoName --public --source . --remote origin --push --description "Reproducible Windows/NVIDIA installer for Whisper Local 0.18.3 with seamless continuous dictation."
    Assert-Exit "gh repo create"
} else {
    & git push -u origin main
    Assert-Exit "git push"
}

if (-not (& git tag --list $ReleaseTag)) {
    & git tag -a $ReleaseTag -m "Whisper Seamless $ReleaseTag"
}
& git push origin $ReleaseTag
Assert-Exit "git push tag"
