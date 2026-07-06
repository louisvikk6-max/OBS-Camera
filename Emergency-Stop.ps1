$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\ThreeCameraCommon.ps1"

& "$PSScriptRoot\Initialize-ThreeCameraOBS.ps1" -Quiet

try {
    $processes = @(Get-ThreeCameraOBSProcesses)
    if ($processes.Count -gt 0) {
        Stop-ThreeCameraOBSProcesses -Force
        Write-Host "Stopped dedicated OBS processes: $($processes.Count)"
    }
    else {
        Write-Host 'No dedicated three-camera OBS processes were running.'
    }

    $activePath = Get-ThreeCameraActiveRecordingPath
    if (Test-Path -LiteralPath $activePath) {
        Remove-Item -LiteralPath $activePath -Force
        Write-Host 'Cleared active recording state.'
    }
    else {
        Write-Host 'No active recording state was present.'
    }

    Write-Host 'Emergency stop completed. Existing video files were not deleted.'
}
catch {
    Write-Host ''
    Write-Host "Emergency stop failed: $($_.Exception.Message)"
    exit 1
}
