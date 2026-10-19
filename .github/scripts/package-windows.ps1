param(
    [Parameter(Mandatory)][string]$Version,
    [string]$PublishDirectory,
    [string]$InstallerPath,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version must use the form 1.2.3.' }
if (-not $PublishDirectory) {
    $PublishDirectory = Join-Path $repository 'src/Baballonia.Desktop/bin/Release/net10.0/win-x64/publish'
}

$required = @(
    'Baballonia.Desktop.exe', 'Baballonia.Desktop.dll', 'Baballonia.dll',
    'Baballonia.Desktop.runtimeconfig.json', 'coreclr.dll', 'hostfxr.dll',
    'LocalSettings.json', 'eyeModel.onnx', 'faceModel.onnx', 'font.ttf',
    'onnxruntime.dll', 'DirectML.dll', 'OpenCvSharpExtern.dll', 'libSkiaSharp.dll',
    'zh-CN/Baballonia.resources.dll', 'zh-TW/Baballonia.resources.dll',
    'Modules/Baballonia.OpenCVCapture.dll', 'Modules/Baballonia.SerialCameraCapture.dll',
    'Modules/Baballonia.IPCameraCapture.dll', 'Modules/Baballonia.VFTCapture.dll',
    'Calibration/Windows/Trainer/BabbleTrainer.exe',
    'Calibration/Windows/Trainer/baseline_L.pth',
    'Calibration/Windows/Trainer/baseline_R.pth',
    'Calibration/Windows/Overlay/BabbleCalibration.x86_64.exe',
    'Calibration/Windows/Overlay/BabbleCalibration.x86_64.pck',
    'Firmware/Windows/espflash.exe', 'Firmware/Binaries/BabbleFirmware1.3.bin'
)
foreach ($relative in $required) {
    $path = Join-Path $PublishDirectory $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) {
        throw "Missing runtime file: $relative"
    }
}
$runtimeConfig = Get-Content -LiteralPath (Join-Path $PublishDirectory 'Baballonia.Desktop.runtimeconfig.json') -Raw | ConvertFrom-Json
if (-not $runtimeConfig.runtimeOptions.includedFrameworks) { throw 'The application must include the .NET runtime.' }
$trainer = Join-Path $PublishDirectory 'Calibration/Windows/Trainer/BabbleTrainer.exe'
if ((Get-FileHash -LiteralPath $trainer -Algorithm SHA256).Hash -ne '4eb78e6e04d1270e9d50c0b76787f32a5a245a68218033b511301ffcb2ec8e2a') {
    throw 'The bundled calibration trainer is incomplete or does not match the pinned version.'
}
if ($VerifyOnly) { return }
if (-not $InstallerPath -or -not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
    throw 'The compiled NSIS installer is required.'
}

$artifacts = Join-Path $repository 'artifacts/release'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$zip = Join-Path $artifacts "Baballonia.$Version.win-x64.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($PublishDirectory, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
$installer = Join-Path $artifacts "Baballonia.Setup.$Version.exe"
Copy-Item -LiteralPath $InstallerPath -Destination $installer -Force
$checksums = foreach ($path in @($zip, $installer)) {
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($path))"
}
[IO.File]::WriteAllLines((Join-Path $artifacts 'SHA256SUMS.txt'), $checksums, [Text.Encoding]::ASCII)
