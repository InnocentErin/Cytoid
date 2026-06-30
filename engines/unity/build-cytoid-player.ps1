#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UnityPath = "C:\Program Files\Unity\Hub\Editor\6000.0.75f1\Editor\Unity.exe",
    [string]$ProjectPath,
    [string]$OutputPath,
    [switch]$Package,
    [switch]$KeepLog
)

$ErrorActionPreference = "Stop"

# Param defaults cannot use $PSScriptRoot; resolve paths at runtime.
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot "Builds\CytoidPlayer"
}
$ProjectPath = (Resolve-Path $ProjectPath).Path
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

$exeName = "CytoidPlayer"
$method = "CytoidCoreBuild.BuildCytoidPlayerWindows64"

function Write-Info($message) {
    Write-Host "[build-cytoid-player] $message" -ForegroundColor Cyan
}

# 1. Stop any running player that might lock build outputs.
$running = Get-Process -Name $exeName -ErrorAction SilentlyContinue
if ($running) {
    Write-Info "Stopping running $exeName.exe process(es)..."
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# 2. Validate Unity editor path.
if (-not (Test-Path $UnityPath)) {
    throw "Unity editor not found at: $UnityPath`nInstall Unity 6000.0.75f1 or pass -UnityPath."
}

if (-not (Test-Path (Join-Path $ProjectPath "ProjectSettings\ProjectVersion.txt"))) {
    throw "Unity project not found at: $ProjectPath"
}

Write-Info "Project: $ProjectPath"
Write-Info "Output:  $OutputPath"

# 3. Clean previous build output.
if (Test-Path $OutputPath) {
    Write-Info "Cleaning previous build output: $OutputPath"
    Remove-Item -Recurse -Force $OutputPath
}

$logFile = "$OutputPath\build.log"
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

# 4. Run Unity batchmode build.
Write-Info "Starting Windows x64 IL2CPP build..."
$unityArgs = @(
    "-batchmode",
    "-quit",
    "-projectPath", $ProjectPath,
    "-executeMethod", $method,
    "-logFile", $logFile
)

$unityProcess = Start-Process -FilePath $UnityPath -ArgumentList $unityArgs -PassThru -Wait
$exitCode = $unityProcess.ExitCode

$builtExe = Join-Path $OutputPath "CytoidPlayer.exe"
if (-not (Test-Path $builtExe)) {
    $logTail = if (Test-Path $logFile) {
        Get-Content $logFile -Tail 40 | Out-String
    } else {
        "(log file missing)"
    }
    throw "Build outputs are missing: $builtExe`nSee log: $logFile`n`n$logTail"
}

if ($exitCode -ne 0) {
    Write-Warning "Unity reported exit code $exitCode, but $builtExe exists; treating build as successful."
}

# 5. Remove folders Unity marks as non-shippable.
Write-Info "Removing non-shippable debug folders..."
Get-ChildItem -Path $OutputPath -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "*DoNotShip*" -or
    $_.Name -like "*BackUpThisFolder_ButDontShipItWithYourGame*"
} | Remove-Item -Recurse -Force

# 6. Remove build log unless requested.
if (-not $KeepLog -and (Test-Path $logFile)) {
    Remove-Item -Force $logFile
}

# 7. Optional zip package.
if ($Package) {
    $zipPath = Join-Path $PSScriptRoot "Builds\CytoidPlayer.zip"
    if (Test-Path $zipPath) {
        Remove-Item -Force $zipPath
    }
    Write-Info "Packaging $zipPath ..."
    Compress-Archive -Path "$OutputPath\*" -DestinationPath $zipPath
    Write-Info "Package ready: $zipPath"
}

Write-Info "Build complete: $OutputPath"
