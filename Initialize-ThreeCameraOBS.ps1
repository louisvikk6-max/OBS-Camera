param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\ThreeCameraCommon.ps1"

Assert-OBSInstalled
New-DirectoryIfMissing -Path (Get-ThreeCameraOutputDir)
New-DirectoryIfMissing -Path (Get-ThreeCameraStateDir)
foreach ($instance in Get-ThreeCameraInstances) {
    New-DirectoryIfMissing -Path (Get-ThreeCameraOutputDirForInstance -Instance $instance)
}

$guidePath = Join-Path $PSScriptRoot 'README_CN.md'

Ensure-ThreeCameraInstancesReady -Count 3

New-ThreeCameraShortcuts -Directory (Get-ThreeCameraRoot) | Out-Null

if (-not $Quiet) {
    Write-Host 'Three-camera OBS workspace is ready.'
    Write-Host "Output folder: $(Get-ThreeCameraOutputDir)"
    Write-Host "Guide: $guidePath"
    Write-Host "Folder shortcuts: $((Get-ThreeCameraShortcutDefinitions | ForEach-Object { $_.Name }) -join ', ')"
}
