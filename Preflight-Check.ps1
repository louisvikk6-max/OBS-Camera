$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\ThreeCameraCommon.ps1"

& "$PSScriptRoot\Initialize-ThreeCameraOBS.ps1" -Quiet

function Add-CheckRow {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.ArrayList]$Rows,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [bool]$Pass,

        [string]$Detail = ''
    )

    $status = 'FAIL'
    if ($Pass) {
        $status = 'PASS'
    }

    [void]$Rows.Add([PSCustomObject]@{
        status = $status
        check = $Name
        detail = $Detail
    })
}

function Get-ShortcutInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    return [PSCustomObject]@{
        Path = $Path
        TargetPath = [string]$shortcut.TargetPath
        Arguments = [string]$shortcut.Arguments
        WorkingDirectory = [string]$shortcut.WorkingDirectory
        IconLocation = [string]$shortcut.IconLocation
    }
}

function Get-ExpectedShortcutArguments {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Definition
    )

    $scriptPath = Join-Path (Get-ThreeCameraRoot) $Definition.Script
    $noExitArg = ''
    if ([bool]$Definition.NoExit) {
        $noExitArg = '-NoExit '
    }

    return "-NoProfile $noExitArg-ExecutionPolicy Bypass -File `"$scriptPath`""
}

function Test-ThreeCameraShortcut {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [Parameter(Mandatory = $true)]
        [ref]$Detail
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $Detail.Value = "missing: $Path"
        return $false
    }

    try {
        $info = Get-ShortcutInfo -Path $Path
        $expectedTarget = Get-ThreeCameraPowerShellPath
        $expectedArgs = Get-ExpectedShortcutArguments -Definition $Definition
        $expectedWorkingDir = Get-ThreeCameraRoot

        if (-not $info.TargetPath.Equals($expectedTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
            $Detail.Value = "target is $($info.TargetPath)"
            return $false
        }

        if (-not $info.Arguments.Equals($expectedArgs, [System.StringComparison]::OrdinalIgnoreCase)) {
            $Detail.Value = "arguments are $($info.Arguments)"
            return $false
        }

        if (-not $info.WorkingDirectory.Equals($expectedWorkingDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            $Detail.Value = "working directory is $($info.WorkingDirectory)"
            return $false
        }

        $Detail.Value = $Path
        return $true
    }
    catch {
        $Detail.Value = $_.Exception.Message
        return $false
    }
}

function ConvertFrom-OBSIniPath {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    return $Value.Replace('\\', '\')
}

function Test-ProfileOutputPaths {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance,

        [Parameter(Mandatory = $true)]
        [ref]$Detail
    )

    $profilePath = Join-Path $Instance.Root "config\obs-studio\basic\profiles\$($Instance.Profile)\basic.ini"
    if (-not (Test-Path -LiteralPath $profilePath)) {
        $Detail.Value = "missing: $profilePath"
        return $false
    }

    $expected = [System.IO.Path]::GetFullPath((Get-ThreeCameraOutputDirForInstance -Instance $Instance))
    $requiredKeys = @('FilePath', 'RecFilePath', 'FFFilePath')
    $found = @{}

    foreach ($line in Get-Content -Path $profilePath -Encoding UTF8) {
        if ($line -match '^(FilePath|RecFilePath|FFFilePath)=(.*)$') {
            $found[$Matches[1]] = ConvertFrom-OBSIniPath -Value $Matches[2]
        }
    }

    $bad = @()
    foreach ($key in $requiredKeys) {
        if (-not $found.ContainsKey($key)) {
            $bad += "$key missing"
            continue
        }

        $actual = [System.IO.Path]::GetFullPath([string]$found[$key])
        if (-not $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)) {
            $bad += "$key=$actual"
        }
    }

    if ($bad.Count -gt 0) {
        $Detail.Value = "expected $expected; $($bad -join '; ')"
        return $false
    }

    $Detail.Value = $expected
    return $true
}

function Get-StalePathMatches {
    $root = Get-ThreeCameraRoot
    $currentUser = [Environment]::UserName
    $profilePattern = 'C:[\\/]+Users[\\/]+([^\\/\s"''<>|]+)'
    $duplicateSegmentPattern = '([\\/]+)([^\\/\s"''<>|]+)\1\2(?=$|[\\/]+|\s|"|''|<|>|\|)'
    $extensions = @('.ps1', '.psm1', '.psd1', '.mjs', '.json', '.ini', '.md', '.txt', '.cmd', '.bat', '.yaml', '.yml', '.lnk')
    $stalePathHits = @()

    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue) {
        $fullName = $file.FullName
        if ($fullName -match '\\node_modules\\') {
            continue
        }
        if ($fullName -match '\\instances\\camera\d+\\(bin|data|obs-plugins)\\') {
            continue
        }
        if ($fullName.EndsWith('\state\preflight-report.txt', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if ($extensions -notcontains $file.Extension.ToLowerInvariant()) {
            continue
        }

        $relative = $fullName.Substring($root.Length).TrimStart('\')
        if ($file.Extension.Equals('.lnk', [System.StringComparison]::OrdinalIgnoreCase)) {
            try {
                $info = Get-ShortcutInfo -Path $fullName
                foreach ($value in @($info.Arguments, $info.WorkingDirectory, $info.IconLocation)) {
                    foreach ($profileMatch in [regex]::Matches([string]$value, $profilePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                        $userName = [string]$profileMatch.Groups[1].Value
                        if (-not $userName.Equals($currentUser, [System.StringComparison]::OrdinalIgnoreCase)) {
                            $stalePathHits += "${relative} uses non-current user profile '$userName'"
                        }
                    }

                    if ([regex]::IsMatch([string]$value, $profilePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                        foreach ($duplicateMatch in [regex]::Matches([string]$value, $duplicateSegmentPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                            $segment = [string]$duplicateMatch.Groups[2].Value
                            if (-not [string]::IsNullOrWhiteSpace($segment)) {
                                $stalePathHits += "${relative} repeats path segment '$segment'"
                            }
                        }
                    }
                }

                if ($stalePathHits.Count -ge 10) {
                    return $stalePathHits
                }
            }
            catch {
            }
            continue
        }

        $lineNumber = 0
        foreach ($line in Get-Content -Path $fullName -Encoding UTF8 -ErrorAction SilentlyContinue) {
            $lineNumber++

            foreach ($profileMatch in [regex]::Matches($line, $profilePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                $userName = [string]$profileMatch.Groups[1].Value
                if (-not $userName.Equals($currentUser, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $stalePathHits += "${relative}:$lineNumber uses non-current user profile '$userName'"
                    if ($stalePathHits.Count -ge 10) {
                        return $stalePathHits
                    }
                }
            }

            if ([regex]::IsMatch($line, $profilePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                foreach ($duplicateMatch in [regex]::Matches($line, $duplicateSegmentPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                    $segment = [string]$duplicateMatch.Groups[2].Value
                    if (-not [string]::IsNullOrWhiteSpace($segment)) {
                        $stalePathHits += "${relative}:$lineNumber repeats path segment '$segment'"
                    }
                    if ($stalePathHits.Count -ge 10) {
                        return $stalePathHits
                    }
                }
            }
        }

    }

    return $stalePathHits
}

try {
    $rows = New-Object System.Collections.ArrayList

    Add-CheckRow -Rows $rows -Name 'OBS installed' -Pass (Test-Path -LiteralPath $script:ObsInstalledExe) -Detail $script:ObsInstalledExe
    Add-CheckRow -Rows $rows -Name 'Output folder writable' -Pass (Test-ThreeCameraDirectoryWritable -Path (Get-ThreeCameraOutputDir)) -Detail (Get-ThreeCameraOutputDir)
    Add-CheckRow -Rows $rows -Name 'Node dependency' -Pass (Test-Path -LiteralPath (Join-Path (Get-ThreeCameraRoot) 'node_modules\obs-websocket-js')) -Detail 'obs-websocket-js'

    foreach ($instance in Get-ThreeCameraInstances) {
        Add-CheckRow -Rows $rows -Name "Camera$($instance.Index) OBS exe" -Pass (Test-Path -LiteralPath $instance.Exe) -Detail $instance.Exe
        Add-CheckRow -Rows $rows -Name "Camera$($instance.Index) profile" -Pass (Test-Path -LiteralPath (Join-Path $instance.Root "config\obs-studio\basic\profiles\$($instance.Profile)\basic.ini")) -Detail $instance.Profile
        Add-CheckRow -Rows $rows -Name "Camera$($instance.Index) scene" -Pass (Test-Path -LiteralPath (Join-Path $instance.Root "config\obs-studio\basic\scenes\$($instance.SceneCollection).json")) -Detail $instance.SceneCollection

        $websocketConfigPath = Join-Path $instance.Root 'config\obs-studio\plugin_config\obs-websocket\config.json'
        $portOk = $false
        if (Test-Path -LiteralPath $websocketConfigPath) {
            $websocketConfig = Get-Content -Path $websocketConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $portOk = ([int]$websocketConfig.server_port -eq [int]$instance.Port) -and ([bool]$websocketConfig.server_enabled)
        }
        Add-CheckRow -Rows $rows -Name "Camera$($instance.Index) websocket port" -Pass $portOk -Detail "expected $($instance.Port)"

        $outputPathDetail = ''
        $outputPathOk = Test-ProfileOutputPaths -Instance $instance -Detail ([ref]$outputPathDetail)
        Add-CheckRow -Rows $rows -Name "Camera$($instance.Index) output path" -Pass $outputPathOk -Detail $outputPathDetail
    }

    foreach ($shortcut in Get-ThreeCameraShortcutDefinitions) {
        $shortcutName = "$($shortcut.Name).lnk"

        $folderPath = Join-Path (Get-ThreeCameraRoot) $shortcutName
        $folderDetail = ''
        $folderOk = Test-ThreeCameraShortcut -Path $folderPath -Definition $shortcut -Detail ([ref]$folderDetail)
        Add-CheckRow -Rows $rows -Name "Project shortcut $shortcutName" -Pass $folderOk -Detail $folderDetail

        $desktopShortcutPath = Join-Path $script:DesktopPath $shortcutName
        $desktopDetail = ''
        $desktopOk = Test-ThreeCameraShortcut -Path $desktopShortcutPath -Definition $shortcut -Detail ([ref]$desktopDetail)
        Add-CheckRow -Rows $rows -Name "Desktop shortcut $shortcutName" -Pass $desktopOk -Detail $desktopDetail
    }

    $staleMatches = @(Get-StalePathMatches)
    $staleDetail = 'none'
    if ($staleMatches.Count -gt 0) {
        $staleDetail = $staleMatches -join '; '
    }
    Add-CheckRow -Rows $rows -Name 'Known stale path tokens' -Pass ($staleMatches.Count -eq 0) -Detail $staleDetail

    $windowsDevices = @(Get-ThreeCameraWindowsDevices)
    $blockedCount = 0
    foreach ($device in $windowsDevices) {
        if (Test-IsBuiltInCamera -Device ([PSCustomObject]@{ Name = $device.Name; Value = ''; DeviceID = $device.DeviceID })) {
            $blockedCount++
        }
    }
    Add-CheckRow -Rows $rows -Name 'Windows camera devices detected' -Pass ($windowsDevices.Count -ge 1) -Detail "$($windowsDevices.Count) detected; $blockedCount blocked"

    Add-CheckRow -Rows $rows -Name 'GUI workflow available' -Pass (Test-Path -LiteralPath (Join-Path (Get-ThreeCameraRoot) 'ThreeCameraOBS-GUI.ps1')) -Detail 'dynamic camera selection, custom category naming, and per-slot output folders'

    $reportPath = Join-Path (Get-ThreeCameraStateDir) 'preflight-report.txt'
    $lines = @()
    $lines += "ThreeCameraOBS preflight report"
    $lines += "Generated: $((Get-Date).ToString('s'))"
    $lines += ''
    foreach ($row in $rows) {
        $lines += ("[{0}] {1} - {2}" -f $row.status, $row.check, $row.detail)
    }
    Write-Utf8NoBomFile -Path $reportPath -Content ($lines -join [Environment]::NewLine)

    Write-Host "Preflight report: $reportPath"
    $rows | Format-Table -AutoSize

    $failures = @($rows | Where-Object { $_.status -eq 'FAIL' })
    if ($failures.Count -gt 0) {
        Write-Host ''
        Write-Host "Preflight completed with $($failures.Count) item(s) needing attention."
        exit 1
    }

    Write-Host ''
    Write-Host 'Preflight passed.'
}
catch {
    Write-Host ''
    Write-Host "Preflight failed: $($_.Exception.Message)"
    exit 1
}
