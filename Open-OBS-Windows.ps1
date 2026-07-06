$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\ThreeCameraCommon.ps1"

& "$PSScriptRoot\Initialize-ThreeCameraOBS.ps1" -Quiet

foreach ($instance in Get-ThreeCameraInstances) {
    Start-ThreeCameraOBSInstance -Instance $instance
}

Write-Host 'OBS windows were requested.'
Write-Host 'Use ThreeCameraOBS-GUI to select cameras and start recording.'
