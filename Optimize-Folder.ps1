param(
    [switch]$KeepPortableTest
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\ThreeCameraCommon.ps1"

function Remove-DirectoryIfUnderRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $resolvedPath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
    $resolvedRoot = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Root).Path)
    if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside root: $resolvedPath"
    }

    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

try {
    Assert-OBSInstalled

    Write-Host 'Optimizing ThreeCameraOBS folder...'
    Write-Host "Using OBS installation: $script:ObsInstallRoot"

    Stop-ThreeCameraOBSProcesses -Force

    foreach ($instance in Get-ThreeCameraInstances) {
        New-DirectoryIfMissing -Path $instance.Root

        $links = @(
            [PSCustomObject]@{ Name = 'bin'; Target = Join-Path $script:ObsInstallRoot 'bin' },
            [PSCustomObject]@{ Name = 'data'; Target = Join-Path $script:ObsInstallRoot 'data' },
            [PSCustomObject]@{ Name = 'obs-plugins'; Target = Join-Path $script:ObsInstallRoot 'obs-plugins' }
        )

        foreach ($link in $links) {
            $path = Join-Path $instance.Root $link.Name
            if (Test-Path -LiteralPath $path) {
                Remove-DirectoryIfUnderRoot -Path $path -Root $instance.Root
            }
            New-OBSJunctionIfMissing -LinkPath $path -TargetPath $link.Target
            Write-Host "Linked $path -> $($link.Target)"
        }
    }

    if (-not $KeepPortableTest) {
        $portableRoot = Join-Path (Split-Path -Parent $PSScriptRoot) '_obs_portable_test'
        if (Test-Path -LiteralPath $portableRoot) {
            Remove-DirectoryIfUnderRoot -Path $portableRoot -Root (Split-Path -Parent $PSScriptRoot)
            Write-Host "Removed redundant portable OBS copy: $portableRoot"
        }
    }

    foreach ($backup in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'instances') -Recurse -File -Filter '*.bak' -ErrorAction SilentlyContinue) {
        Remove-Item -LiteralPath $backup.FullName -Force
        Write-Host "Removed backup file: $($backup.FullName)"
    }

    foreach ($logDir in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'instances') -Recurse -Directory -Filter 'logs' -ErrorAction SilentlyContinue) {
        foreach ($logFile in Get-ChildItem -LiteralPath $logDir.FullName -File -ErrorAction SilentlyContinue) {
            Remove-Item -LiteralPath $logFile.FullName -Force
        }
        Write-Host "Cleared OBS logs: $($logDir.FullName)"
    }

    $oldFiles = @(
        'Configure-Cameras.ps1',
        'Record-Control.ps1',
        'Toggle-Record.ps1',
        'Test-Record.ps1',
        'Verify-Files.ps1',
        'Set-Progress.ps1',
        'Reset-Progress.ps1',
        'Status-Check.ps1',
        'ThreeCameraOBS-Configure.lnk',
        'ThreeCameraOBS-Record.lnk',
        'ThreeCameraOBS-ManualRecord.lnk',
        'ThreeCameraOBS-Status.lnk',
        'ThreeCameraOBS-ResetProgress.lnk',
        'ThreeCameraOBS-SetProgress.lnk',
        'ThreeCameraOBS-VerifyFiles.lnk',
        'ThreeCameraOBS-TestRecord.lnk'
    )
    foreach ($file in $oldFiles) {
        $path = Join-Path $PSScriptRoot $file
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
            Write-Host "Removed legacy file: $path"
        }
    }

    $oldStateFiles = @('capture-report.csv', 'camera-map.json', 'capture-progress.json')
    foreach ($file in $oldStateFiles) {
        $path = Join-Path (Get-ThreeCameraStateDir) $file
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
            Write-Host "Removed legacy state file: $path"
        }
    }

    & "$PSScriptRoot\Initialize-ThreeCameraOBS.ps1" -Quiet
    Write-Host 'Optimization complete.'
}
catch {
    Write-Host ''
    Write-Host "Optimization failed: $($_.Exception.Message)"
    exit 1
}
