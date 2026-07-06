param(
    [switch]$SkipDesktopShortcuts
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\ThreeCameraCommon.ps1"

try {
    Assert-OBSInstalled

    New-DirectoryIfMissing -Path (Get-ThreeCameraOutputDir)
    New-DirectoryIfMissing -Path (Get-ThreeCameraStateDir)
    foreach ($instance in Get-ThreeCameraInstances) {
        New-DirectoryIfMissing -Path (Get-ThreeCameraOutputDirForInstance -Instance $instance)
    }

    Ensure-ThreeCameraInstancesReady -Count (Get-ThreeCameraInstanceCount)

    $folderShortcuts = @(New-ThreeCameraShortcuts -Directory (Get-ThreeCameraRoot))
    $desktopShortcuts = @()
    if (-not $SkipDesktopShortcuts) {
        $desktopShortcuts = @(New-ThreeCameraShortcuts -Directory $script:DesktopPath)
    }

    Write-Host 'ThreeCameraOBS rebuild completed.'
    Write-Host "Project root: $(Get-ThreeCameraRoot)"
    Write-Host "Output root: $(Get-ThreeCameraOutputDir)"
    Write-Host "Instance count: $(Get-ThreeCameraInstanceCount)"
    Write-Host "Project shortcuts: $($folderShortcuts.Count)"
    if (-not $SkipDesktopShortcuts) {
        Write-Host "Desktop shortcuts: $($desktopShortcuts.Count)"
    }
}
catch {
    Write-Host ''
    Write-Host "ThreeCameraOBS rebuild failed: $($_.Exception.Message)"
    exit 1
}
