$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\ThreeCameraCommon.ps1"

& "$PSScriptRoot\Initialize-ThreeCameraOBS.ps1" -Quiet

try {
    $guidePath = Join-Path (Get-ThreeCameraRoot) 'README_CN.md'

    Start-Process -FilePath $guidePath | Out-Null
    Write-Host "Opened guide: $guidePath"
}
catch {
    Write-Host ''
    Write-Host "Open guide failed: $($_.Exception.Message)"
    exit 1
}
