$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Pin native tools to verified release assets so rebuilding a tag is reproducible.
$cache = Join-Path ([IO.Path]::GetTempPath()) 'Baballonia-dependencies'
New-Item -ItemType Directory -Path $cache -Force | Out-Null

function Get-Dependency {
    param([string]$Url, [string]$FileName, [string]$Sha256, [string]$ExistingFile)

    if ($ExistingFile -and (Test-Path -LiteralPath $ExistingFile) -and
        (Get-FileHash -LiteralPath $ExistingFile -Algorithm SHA256).Hash -eq $Sha256) {
        return $ExistingFile
    }

    $destination = Join-Path $cache $FileName
    if ((Test-Path -LiteralPath $destination) -and
        (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq $Sha256) {
        return $destination
    }

    $partial = "$destination.download"
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $partial -TimeoutSec 600
            if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ne $Sha256) {
                throw "SHA-256 mismatch for $FileName"
            }
            Move-Item -LiteralPath $partial -Destination $destination -Force
            return $destination
        }
        catch {
            if ($attempt -eq 3) { throw }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

$trainer = Join-Path $PSScriptRoot 'src/Baballonia.Desktop/Calibration/Windows/Trainer/BabbleTrainer.exe'
$overlay = Join-Path $PSScriptRoot 'src/Baballonia.Desktop/Calibration/Windows/Overlay'
$firmwareTools = Join-Path $PSScriptRoot 'src/Baballonia/Firmware/Windows'
foreach ($directory in @((Split-Path -Parent $trainer), $overlay, $firmwareTools)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$trainerAsset = Get-Dependency `
    -Url 'https://github.com/Project-Babble/BabbleTrainer/releases/download/1.5.2/BabbleTrainer-x64.exe' `
    -FileName 'BabbleTrainer-1.5.2-x64.exe' `
    -Sha256 '4eb78e6e04d1270e9d50c0b76787f32a5a245a68218033b511301ffcb2ec8e2a' `
    -ExistingFile $trainer
if ($trainerAsset -ne $trainer) { Copy-Item -LiteralPath $trainerAsset -Destination $trainer -Force }

$overlayAsset = Get-Dependency `
    -Url 'https://github.com/Project-Babble/BabbleCalibration/releases/download/1.0.8/Windows.zip' `
    -FileName 'BabbleCalibration-1.0.8-Windows.zip' `
    -Sha256 '9742179388699b5c74aac5f18c12ff9898d90ffc41c2eb9f14a1a1e6dff825cd'
Expand-Archive -LiteralPath $overlayAsset -DestinationPath $overlay -Force

$espflashAsset = Get-Dependency `
    -Url 'https://github.com/esp-rs/espflash/releases/download/v4.6.0/espflash-x86_64-pc-windows-msvc.zip' `
    -FileName 'espflash-4.6.0-windows-x64.zip' `
    -Sha256 'b2cb4656b067716fe2b3794cf0604b461b2476d06dee7f481704cb6c8495b11c'
Expand-Archive -LiteralPath $espflashAsset -DestinationPath $firmwareTools -Force
