[CmdletBinding()]
param(
    [switch]$SkipModelDownload,
    [switch]$NoAutostart,
    [switch]$NoLaunch,
    [switch]$FromInno,
    [string]$RecordingHotkey = "f24",
    [ValidateSet("native","physical")]
    [string]$BindingMode = "native",
    [int]$PhysicalKeyVk = 0,
    [string]$PhysicalKeyName = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$UpstreamCommit = "8e05b840fac737d4e0dec0886c6d38d0664f94c8"
$PythonVersion = "3.12.10"
$PythonUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-amd64.exe"

$InstallRoot = Join-Path $env:LOCALAPPDATA "WhisperSeamless"
$RuntimeRoot = Join-Path $InstallRoot "runtime\Python312"
$Python = Join-Path $RuntimeRoot "python.exe"
$PythonW = Join-Path $RuntimeRoot "pythonw.exe"
$LogDir = Join-Path $InstallRoot "install-logs"
$SourceRoot = $PSScriptRoot

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-LastExit([string]$What) {
    if ($LASTEXITCODE -ne 0) {
        throw "$What failed with exit code $LASTEXITCODE"
    }
}

if (-not [Environment]::Is64BitOperatingSystem) {
    throw "This installer supports 64-bit Windows only."
}

New-Item -ItemType Directory -Force -Path $InstallRoot, $LogDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$transcript = Join-Path $LogDir "install-$stamp.log"
Start-Transcript -Path $transcript -Force | Out-Null

try {
    Write-Host "Whisper Seamless 1.2.1" -ForegroundColor Green
    Write-Host "Pinned upstream: Whisper Local 0.18.3 @ $UpstreamCommit"
    Write-Host "Install root: $InstallRoot"
    Write-Host "Recording hotkey: $RecordingHotkey"
    Write-Host "Binding mode: $BindingMode"
    if ($BindingMode -eq "physical") {
        Write-Host "Physical key: $PhysicalKeyName (VK=$PhysicalKeyVk)"
    }

    Write-Step "Stopping any currently-running Whisper Local instance"
    try {
        Get-CimInstance Win32_Process |
            Where-Object {
                ($_.Name -ieq "python.exe" -or
                 $_.Name -ieq "pythonw.exe" -or
                 $_.Name -ieq "whisper-local.exe") -and
                ($_.CommandLine -match "whisper_key\.main|launch_with_binding\.py|whisper-local")
            } |
            ForEach-Object {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
    } catch {
        Write-Warning "Could not enumerate all old processes: $($_.Exception.Message)"
    }

    Write-Step "Copying public support files into the isolated install"
    foreach ($dir in @("patches", "config", "launcher", "scripts")) {
        $src = Join-Path $SourceRoot $dir
        $dst = Join-Path $InstallRoot $dir
        if (Test-Path $src) {
            $srcResolved = (Resolve-Path $src).Path
            $dstResolved = $null
            if (Test-Path $dst) {
                $dstResolved = (Resolve-Path $dst).Path
            }
            if ($srcResolved -ne $dstResolved) {
                New-Item -ItemType Directory -Force -Path $dst | Out-Null
                Copy-Item -Path (Join-Path $src "*") -Destination $dst -Recurse -Force
            }
        }
    }

    if (-not (Test-Path $Python)) {
        Write-Step "Installing private Python $PythonVersion runtime"
        $tmp = Join-Path $env:TEMP "python-$PythonVersion-amd64.exe"
        Invoke-WebRequest -Uri $PythonUrl -OutFile $tmp -UseBasicParsing

        $sig = Get-AuthenticodeSignature -FilePath $tmp
        if ($sig.Status -ne "Valid") {
            throw "Python installer Authenticode signature is not valid: $($sig.Status)"
        }
        if ($sig.SignerCertificate.Subject -notmatch "Python Software Foundation") {
            throw "Unexpected Python installer signer: $($sig.SignerCertificate.Subject)"
        }

        New-Item -ItemType Directory -Force -Path $RuntimeRoot | Out-Null

        $args = @(
            "/quiet",
            "InstallAllUsers=0",
            "TargetDir=`"$RuntimeRoot`"",
            "Include_pip=1",
            "Include_launcher=0",
            "Include_test=0",
            "Include_doc=0",
            "Shortcuts=0",
            "PrependPath=0"
        )
        $p = Start-Process -FilePath $tmp -ArgumentList $args -Wait -PassThru
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        if ($p.ExitCode -ne 0) {
            throw "Python installer failed with exit code $($p.ExitCode)"
        }
    }

    if (-not (Test-Path $Python)) {
        throw "Private Python runtime was not created: $Python"
    }

    if ($BindingMode -eq "physical") {
        Write-Step "Validating Windows physical-key hook"
        & $Python (Join-Path $InstallRoot "scripts\launch_with_binding.py") --selftest-hook
        Assert-LastExit "Physical-key hook self-test"
    }

    Write-Step "Installing pinned Whisper Local 0.18.3"
    & $Python -m pip install --disable-pip-version-check --no-input --upgrade "pip==25.2"
    Assert-LastExit "pip bootstrap"

    $sourceUrl = "https://github.com/drajb/whisper-local/archive/$UpstreamCommit.zip"
    & $Python -m pip install --disable-pip-version-check --no-input --upgrade --force-reinstall $sourceUrl
    Assert-LastExit "Whisper Local install"

    Write-Step "Installing pinned NVIDIA CUDA runtime packages"
    $gpu = $null
    try {
        $gpu = (& nvidia-smi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1).Trim()
    } catch {}
    if (-not $gpu) {
        throw "No NVIDIA GPU/driver detected with nvidia-smi. This public profile targets NVIDIA CUDA."
    }
    Write-Host "Detected NVIDIA GPU: $gpu"

    & $Python -m pip install --disable-pip-version-check --no-input --only-binary=:all: `
        "nvidia-cuda-runtime-cu12==12.9.79" `
        "nvidia-cublas-cu12==12.9.1.4" `
        "nvidia-cudnn-cu12==9.10.2.21"
    Assert-LastExit "NVIDIA runtime install"

    $site = Join-Path $RuntimeRoot "Lib\site-packages"
    $env:PATH = (Join-Path $site "nvidia\cuda_runtime\bin") + ";" +
                (Join-Path $site "nvidia\cublas\bin") + ";" +
                (Join-Path $site "nvidia\cudnn\bin") + ";" + $env:PATH

    Write-Step "Applying seamless continuous-dictation patch"
    & $Python (Join-Path $InstallRoot "patches\apply_seamless_patch.py")
    Assert-LastExit "Seamless patch"

    Write-Step "Merging the selected key binding / MME / continuous configuration"
    $configureScript = Join-Path $InstallRoot "config\configure.py"
    $configureArgs = @(
        "--recording-hotkey", $RecordingHotkey,
        "--binding-mode", $BindingMode
    )
    if ($BindingMode -eq "physical") {
        if ($PhysicalKeyVk -lt 1 -or $PhysicalKeyVk -gt 255) {
            throw "PhysicalKeyVk must be between 1 and 255 in physical binding mode."
        }
        $configureArgs += @(
            "--physical-key-vk", [string]$PhysicalKeyVk,
            "--physical-key-name", $PhysicalKeyName
        )
    }
    & $Python $configureScript @configureArgs
    Assert-LastExit "Configuration"

    Write-Step "Validating CUDA runtime"
    $preflight = Join-Path $InstallRoot "scripts\preflight.py"
    if ($SkipModelDownload) {
        & $Python $preflight
    } else {
        & $Python $preflight --download-model
    }
    Assert-LastExit "CUDA/model preflight"

    Write-Step "Creating Start Menu shortcut"
    $programs = [Environment]::GetFolderPath("Programs")
    $shortcutPath = Join-Path $programs "Whisper Seamless.lnk"
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $env:WINDIR "System32\wscript.exe"
    $shortcut.Arguments = '"' + (Join-Path $InstallRoot "launcher\Launch-Whisper.vbs") + '"'
    $shortcut.WorkingDirectory = $InstallRoot
    $shortcut.Description = "Whisper Seamless local dictation"
    $shortcut.Save()

    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    if (-not $NoAutostart) {
        Write-Step "Enabling per-user start at login"
        New-Item -Path $runKey -Force | Out-Null
        $launch = '"' + (Join-Path $env:WINDIR "System32\wscript.exe") + '" "' +
                  (Join-Path $InstallRoot "launcher\Launch-Whisper.vbs") + '"'
        New-ItemProperty -Path $runKey -Name "WhisperLocal" -Value $launch `
            -PropertyType String -Force | Out-Null
    } else {
        Write-Step "Disabling per-user start at login"
        Remove-ItemProperty -Path $runKey -Name "WhisperLocal" -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "INSTALLATION COMPLETE" -ForegroundColor Green
    if ($BindingMode -eq "physical") {
        Write-Host "$PhysicalKeyName (VK=$PhysicalKeyVk): start continuous dictation"
        Write-Host "Original key behavior is suppressed only while Whisper runs."
        Write-Host "Closing or uninstalling Whisper restores the original Windows key behavior automatically."
    } else {
        Write-Host "$($RecordingHotkey.ToUpperInvariant()): start continuous dictation"
    }
    Write-Host "Esc: stop/cancel the live session"
    Write-Host "Start with Windows: $(-not $NoAutostart)"
    Write-Host "Model: large-v3-turbo / CUDA float16"
    Write-Host "Audio: MME / mono / seamless 30-second rollover"
    Write-Host "Log: $transcript"

    if (-not $NoLaunch) {
        Write-Step "Launching Whisper Seamless"
        Start-Process -FilePath (Join-Path $env:WINDIR "System32\wscript.exe") `
            -ArgumentList ('"' + (Join-Path $InstallRoot "launcher\Launch-Whisper.vbs") + '"')
    }
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
