$ErrorActionPreference = 'Stop'

$script:ThreeCameraRoot = Split-Path -Parent $PSScriptRoot
$script:ObsInstallRoot = Join-Path $env:ProgramFiles 'obs-studio'
$script:ObsInstalledExe = Join-Path $script:ObsInstallRoot 'bin\64bit\obs64.exe'
$script:DesktopPath = [Environment]::GetFolderPath('Desktop')
$script:OutputDir = Join-Path $script:DesktopPath 'mm'
$script:StateDir = Join-Path $script:ThreeCameraRoot 'state'

function Get-ThreeCameraRoot {
    return $script:ThreeCameraRoot
}

function Get-ThreeCameraOutputDir {
    return $script:OutputDir
}

function Get-ThreeCameraOutputMapPath {
    return (Join-Path $script:StateDir 'output-folders.json')
}

function Get-ThreeCameraConfiguredOutputDirForCamera {
    param(
        [Parameter(Mandatory = $true)]
        [int]$CameraIndex
    )

    $path = Get-ThreeCameraOutputMapPath
    if (-not (Test-Path -LiteralPath $path)) {
        return ''
    }

    try {
        $map = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($entry in @($map.cameras)) {
            if ([int]$entry.index -eq $CameraIndex -and -not [string]::IsNullOrWhiteSpace([string]$entry.path)) {
                return [string]$entry.path
            }
        }
    }
    catch {
        return ''
    }

    return ''
}

function Get-ThreeCameraOutputDirForCamera {
    param(
        [Parameter(Mandatory = $true)]
        [int]$CameraIndex
    )

    $configured = Get-ThreeCameraConfiguredOutputDirForCamera -CameraIndex $CameraIndex
    if (-not [string]::IsNullOrWhiteSpace($configured)) {
        return $configured
    }

    return (Join-Path (Get-ThreeCameraOutputDir) "cam$CameraIndex")
}

function Save-ThreeCameraOutputFolders {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Folders
    )

    $rows = @()
    foreach ($folder in @($Folders)) {
        $index = [int]$folder.index
        $path = [string]$folder.path
        if ($index -lt 1) {
            throw "Camera index must be 1 or greater: $index"
        }
        if ([string]::IsNullOrWhiteSpace($path)) {
            throw "Output folder for Camera$index is empty."
        }

        $rows += [ordered]@{
            index = $index
            path = $path
        }
    }

    $json = [ordered]@{
        updatedAt = (Get-Date).ToString('s')
        cameras = $rows
    } | ConvertTo-Json -Depth 10

    Write-Utf8NoBomFile -Path (Get-ThreeCameraOutputMapPath) -Content $json
}

function Get-ThreeCameraOutputDirForInstance {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance
    )

    return (Get-ThreeCameraOutputDirForCamera -CameraIndex ([int]$Instance.Index))
}

function Get-ThreeCameraStateDir {
    return $script:StateDir
}

function Get-ThreeCameraMapPath {
    return (Join-Path $script:StateDir 'camera-map.json')
}

function Get-ThreeCameraActiveRecordingPath {
    return (Join-Path $script:StateDir 'active-recording.json')
}

function Get-ThreeCameraProgressPath {
    return (Join-Path $script:StateDir 'capture-progress.json')
}

function Get-ThreeCameraReportPath {
    return (Join-Path $script:StateDir 'capture-report.csv')
}

function Get-ThreeCameraLogPath {
    return (Join-Path $script:StateDir 'capture-log.csv')
}

function Get-ThreeCameraProgress {
    $path = Get-ThreeCameraProgressPath
    if (Test-Path -LiteralPath $path) {
        $progress = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -eq $progress.person) {
            $progress | Add-Member -NotePropertyName person -NotePropertyValue 1
        }
        if ($null -eq $progress.take) {
            $progress | Add-Member -NotePropertyName take -NotePropertyValue 1
        }
        if ($null -eq $progress.completed) {
            $progress | Add-Member -NotePropertyName completed -NotePropertyValue $false
        }
        return $progress
    }

    return [PSCustomObject]@{
        person = 1
        take = 1
        completed = $false
    }
}

function Save-ThreeCameraProgress {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Progress
    )

    $json = [ordered]@{
        person = [int]$Progress.person
        take = [int]$Progress.take
        completed = [bool]$Progress.completed
        updatedAt = (Get-Date).ToString('s')
    } | ConvertTo-Json -Depth 10
    Write-Utf8NoBomFile -Path (Get-ThreeCameraProgressPath) -Content $json
}

function Advance-ThreeCameraProgress {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Progress
    )

    $next = [PSCustomObject]@{
        person = [int]$Progress.person
        take = [int]$Progress.take
        completed = [bool]$Progress.completed
    }

    if ($next.completed) {
        return $next
    }

    if ($next.person -lt 20) {
        $next.person++
    }
    else {
        $next.completed = $true
    }

    Save-ThreeCameraProgress -Progress $next
    return $next
}

function Get-ThreeCameraInstanceCount {
    $count = 3
    $instancesRoot = Join-Path $script:ThreeCameraRoot 'instances'
    if (Test-Path -LiteralPath $instancesRoot) {
        foreach ($dir in Get-ChildItem -LiteralPath $instancesRoot -Directory -ErrorAction SilentlyContinue) {
            if ($dir.Name -match '^camera(\d+)$') {
                $index = [int]$Matches[1]
                if ($index -gt $count) {
                    $count = $index
                }
            }
        }
    }

    return $count
}

function Get-ThreeCameraInstances {
    param(
        [int]$Count = 0
    )

    if ($Count -lt 1) {
        $Count = Get-ThreeCameraInstanceCount
    }

    $instances = @()
    for ($i = 1; $i -le $Count; $i++) {
        $root = Join-Path $script:ThreeCameraRoot "instances\camera$i"
        $instances += [PSCustomObject]@{
            Index = $i
            Name = "camera$i"
            Root = $root
            Exe = Join-Path $root 'bin\64bit\obs64.exe'
            Port = 4455 + $i
            Profile = "Camera$i"
            SceneCollection = "Camera$i"
            Scene = "Camera$i"
            Source = "Camera $i"
            FilePrefix = "cam$i"
        }
    }
    return $instances
}

function New-DirectoryIfMissing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-DirectoryIfMissing -Path $parent
    }

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Assert-OBSInstalled {
    if (-not (Test-Path -LiteralPath $script:ObsInstalledExe)) {
        throw "OBS was not found at $script:ObsInstalledExe"
    }
}

function New-OBSJunctionIfMissing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LinkPath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if (Test-Path -LiteralPath $LinkPath) {
        return
    }

    New-Item -ItemType Junction -Path $LinkPath -Target $TargetPath | Out-Null
}

function Get-ProfileIniContent {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance
    )

    $out = (Get-ThreeCameraOutputDirForInstance -Instance $Instance).Replace('\', '\\')
    $prefix = $Instance.FilePrefix
    return @"
[General]
Name=$($Instance.Profile)

[Output]
Mode=Simple
FilenameFormatting=$prefix`_%CCYY-%MM-%DD_%hh-%mm-%ss
DelayEnable=false
DelaySec=20
DelayPreserve=true
Reconnect=true
RetryDelay=2
MaxRetries=25
BindIP=default
IPFamily=IPv4+IPv6
NewSocketLoopEnable=false
LowLatencyEnable=false

[Stream1]
IgnoreRecommended=false
EnableMultitrackVideo=false
MultitrackVideoMaximumAggregateBitrateAuto=true
MultitrackVideoMaximumVideoTracksAuto=true

[SimpleOutput]
FilePath=$out
RecFormat2=hybrid_mp4
VBitrate=6000
ABitrate=160
UseAdvanced=false
Preset=veryfast
NVENCPreset2=p5
RecQuality=Stream
RecRB=false
RecRBTime=20
RecRBSize=512
RecRBPrefix=Replay
StreamAudioEncoder=aac
RecAudioEncoder=aac
RecTracks=1
StreamEncoder=x264
RecEncoder=x264

[AdvOut]
ApplyServiceSettings=true
UseRescale=false
TrackIndex=1
VodTrackIndex=2
Encoder=obs_x264
RecType=Standard
RecFilePath=$out
RecFormat2=hybrid_mp4
RecUseRescale=false
RecTracks=1
RecEncoder=none
FLVTrack=1
StreamMultiTrackAudioMixes=1
FFOutputToFile=true
FFFilePath=$out
FFExtension=mp4
FFVBitrate=6000
FFVGOPSize=250
FFUseRescale=false
FFIgnoreCompat=false
FFABitrate=160
FFAudioMixes=1
Track1Bitrate=160
Track2Bitrate=160
Track3Bitrate=160
Track4Bitrate=160
Track5Bitrate=160
Track6Bitrate=160
RecSplitFileTime=15
RecSplitFileSize=2048
RecRB=false
RecRBTime=20
RecRBSize=512
AudioEncoder=ffmpeg_aac
RecAudioEncoder=ffmpeg_aac

[Video]
BaseCX=1920
BaseCY=1080
OutputCX=1920
OutputCY=1080
FPSType=0
FPSCommon=30
FPSInt=30
FPSNum=30
FPSDen=1
ScaleType=bicubic
ColorFormat=NV12
ColorSpace=709
ColorRange=Partial
SdrWhiteLevel=300
HdrNominalPeakLevel=1000

[Audio]
MonitoringDeviceId=default
MonitoringDeviceName=Default
SampleRate=48000
ChannelSetup=Stereo
MeterDecayRate=23.53
PeakMeterType=0

[Panels]
CookieId=ThreeCamera$($Instance.Index)
"@
}

function Get-UserIniContent {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance
    )

    return @"
[General]
Pre19Defaults=false
Pre21Defaults=false
Pre23Defaults=false
Pre24.1Defaults=false
ConfirmOnExit=true
HotkeyFocusType=NeverDisableHotkeys
FirstRun=true

[Basic]
Profile=$($Instance.Profile)
ProfileDir=$($Instance.Profile)
SceneCollection=$($Instance.SceneCollection)
SceneCollectionFile=$($Instance.SceneCollection).json
ConfigOnNewProfile=true
"@
}

function New-SceneItemObject {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance,

        [Parameter(Mandatory = $true)]
        [string]$SourceUuid
    )

    return [ordered]@{
        name = $Instance.Source
        source_uuid = $SourceUuid
        visible = $true
        locked = $false
        rot = 0.0
        scale_ref = [ordered]@{ x = 1920.0; y = 1080.0 }
        align = 5
        bounds_type = 2
        bounds_align = 5
        bounds_crop = $false
        crop_left = 0
        crop_top = 0
        crop_right = 0
        crop_bottom = 0
        id = 1
        group_item_backup = $false
        pos = [ordered]@{ x = 0.0; y = 0.0 }
        pos_rel = [ordered]@{ x = -1.0; y = -1.0 }
        scale = [ordered]@{ x = 1.0; y = 1.0 }
        scale_rel = [ordered]@{ x = 1.0; y = 1.0 }
        bounds = [ordered]@{ x = 1920.0; y = 1080.0 }
        bounds_rel = [ordered]@{ x = 0.0; y = 0.0 }
        scale_filter = 'disable'
        blend_method = 'default'
        blend_type = 'normal'
        show_transition = [ordered]@{ duration = 0 }
        hide_transition = [ordered]@{ duration = 0 }
        private_settings = [ordered]@{}
    }
}

function New-SceneCollectionObject {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance,

        [string]$VideoDeviceId = ''
    )

    $sceneUuid = [Guid]::NewGuid().ToString()
    $sourceUuid = [Guid]::NewGuid().ToString()
    $canvasUuid = '6c69626f-6273-4c00-9d88-c5136d61696e'

    $items = @()
    $sources = @()
    $idCounter = 0

    if (-not [string]::IsNullOrWhiteSpace($VideoDeviceId)) {
        $items = @(New-SceneItemObject -Instance $Instance -SourceUuid $sourceUuid)
        $idCounter = 1
    }

    $sceneSource = [ordered]@{
        prev_ver = 536870913
        name = $Instance.Scene
        uuid = $sceneUuid
        id = 'scene'
        versioned_id = 'scene'
        settings = [ordered]@{
            id_counter = $idCounter
            custom_size = $false
            items = $items
        }
        mixers = 0
        sync = 0
        flags = 0
        volume = 1.0
        balance = 0.5
        enabled = $true
        muted = $false
        'push-to-mute' = $false
        'push-to-mute-delay' = 0
        'push-to-talk' = $false
        'push-to-talk-delay' = 0
        hotkeys = [ordered]@{
            'OBSBasic.SelectScene' = @()
            'libobs.show_scene_item.1' = @()
            'libobs.hide_scene_item.1' = @()
        }
        deinterlace_mode = 0
        deinterlace_field_order = 0
        monitoring_type = 0
        canvas_uuid = $canvasUuid
        private_settings = [ordered]@{}
    }

    $sources += $sceneSource

    if (-not [string]::IsNullOrWhiteSpace($VideoDeviceId)) {
        $sources += [ordered]@{
            prev_ver = 536870913
            name = $Instance.Source
            uuid = $sourceUuid
            id = 'dshow_input'
            versioned_id = 'dshow_input'
            settings = [ordered]@{
                video_device_id = $VideoDeviceId
                last_video_device_id = $VideoDeviceId
                res_type = 0
                audio_output_mode = 0
                deactivate_when_not_showing = $false
                buffering = 0
            }
            mixers = 0
            sync = 0
            flags = 0
            volume = 1.0
            balance = 0.5
            enabled = $true
            muted = $true
            'push-to-mute' = $false
            'push-to-mute-delay' = 0
            'push-to-talk' = $false
            'push-to-talk-delay' = 0
            hotkeys = [ordered]@{
                'libobs.mute' = @()
                'libobs.unmute' = @()
                'libobs.push-to-mute' = @()
                'libobs.push-to-talk' = @()
            }
            deinterlace_mode = 0
            deinterlace_field_order = 0
            monitoring_type = 0
            private_settings = [ordered]@{}
        }
    }

    return [ordered]@{
        current_scene = $Instance.Scene
        current_program_scene = $Instance.Scene
        scene_order = @([ordered]@{ name = $Instance.Scene })
        name = $Instance.SceneCollection
        sources = $sources
        groups = @()
        quick_transitions = @()
        transitions = @()
        saved_projectors = @()
        canvases = @()
        current_transition = ''
        transition_duration = 300
        preview_locked = $false
        scaling_enabled = $false
        scaling_level = 0
        scaling_off_x = 0.0
        scaling_off_y = 0.0
        modules = [ordered]@{
            'scripts-tool' = @()
            'output-timer' = [ordered]@{
                streamTimerHours = 0
                streamTimerMinutes = 0
                streamTimerSeconds = 30
                recordTimerHours = 0
                recordTimerMinutes = 0
                recordTimerSeconds = 30
                autoStartStreamTimer = $false
                autoStartRecordTimer = $false
                pauseRecordTimer = $true
            }
            'auto-scene-switcher' = [ordered]@{
                interval = 300
                non_matching_scene = ''
                switch_if_not_matching = $false
                active = $false
                switches = @()
            }
        }
        resolution = [ordered]@{ x = 1920; y = 1080 }
        version = 2
    }
}

function Write-SceneCollection {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance,

        [string]$VideoDeviceId = '',

        [switch]$Force
    )

    $sceneFile = Join-Path $Instance.Root "config\obs-studio\basic\scenes\$($Instance.SceneCollection).json"
    if ((Test-Path -LiteralPath $sceneFile) -and -not $Force) {
        return
    }

    $scene = New-SceneCollectionObject -Instance $Instance -VideoDeviceId $VideoDeviceId
    $json = $scene | ConvertTo-Json -Depth 80
    Write-Utf8NoBomFile -Path $sceneFile -Content $json
}

function Ensure-ThreeCameraInstanceReady {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance
    )

    New-DirectoryIfMissing -Path $Instance.Root

    New-OBSJunctionIfMissing -LinkPath (Join-Path $Instance.Root 'bin') -TargetPath (Join-Path $script:ObsInstallRoot 'bin')
    New-OBSJunctionIfMissing -LinkPath (Join-Path $Instance.Root 'data') -TargetPath (Join-Path $script:ObsInstallRoot 'data')
    New-OBSJunctionIfMissing -LinkPath (Join-Path $Instance.Root 'obs-plugins') -TargetPath (Join-Path $script:ObsInstallRoot 'obs-plugins')

    $configRoot = Join-Path $Instance.Root 'config\obs-studio'
    New-DirectoryIfMissing -Path $configRoot
    New-DirectoryIfMissing -Path (Join-Path $configRoot 'basic\profiles')
    New-DirectoryIfMissing -Path (Join-Path $configRoot 'basic\scenes')
    New-DirectoryIfMissing -Path (Join-Path $configRoot 'plugin_config\obs-websocket')

    $profileDir = Join-Path $configRoot "basic\profiles\$($Instance.Profile)"
    New-DirectoryIfMissing -Path $profileDir

    Write-Utf8NoBomFile -Path (Join-Path $profileDir 'basic.ini') -Content (Get-ProfileIniContent -Instance $Instance)
    Write-Utf8NoBomFile -Path (Join-Path $configRoot 'user.ini') -Content (Get-UserIniContent -Instance $Instance)
    Write-Utf8NoBomFile -Path (Join-Path $configRoot 'global.ini') -Content @"
[General]
MaxLogs=10
InfoIncrement=-1
ProcessPriority=Normal
EnableAutoUpdates=false
BrowserHWAccel=true

[Video]
Renderer=Direct3D 11

[Audio]
DisableAudioDucking=true
"@

    $websocketConfig = [ordered]@{
        alerts_enabled = $false
        auth_required = $false
        first_load = $false
        server_enabled = $true
        server_password = ''
        server_port = $Instance.Port
    } | ConvertTo-Json -Depth 10
    Write-Utf8NoBomFile -Path (Join-Path $configRoot 'plugin_config\obs-websocket\config.json') -Content $websocketConfig

    Write-SceneCollection -Instance $Instance
}

function Ensure-ThreeCameraInstancesReady {
    param(
        [int]$Count = 3
    )

    if ($Count -lt 1) {
        $Count = 1
    }

    foreach ($instance in Get-ThreeCameraInstances -Count $Count) {
        Ensure-ThreeCameraInstanceReady -Instance $instance
    }
}

function Get-ThreeCameraOBSProcesses {
    $roots = @(Get-ThreeCameraInstances | ForEach-Object { $_.Root })
    $processes = @()

    try {
        $all = Get-CimInstance Win32_Process -Filter "Name = 'obs64.exe'" -ErrorAction Stop
        foreach ($proc in $all) {
            foreach ($root in $roots) {
                if ($proc.CommandLine -and $proc.CommandLine.Contains($root)) {
                    $processes += $proc
                    break
                }
            }
        }

        return $processes
    }
    catch {
        $all = @(Get-Process -Name 'obs64' -ErrorAction SilentlyContinue)
        foreach ($proc in $all) {
            foreach ($root in $roots) {
                if ($proc.Path -and $proc.Path.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $processes += [PSCustomObject]@{
                        ProcessId = $proc.Id
                        CommandLine = $proc.Path
                    }
                    break
                }
            }
        }
    }

    return $processes
}

function Start-ThreeCameraOBSInstance {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance,

        [switch]$Minimized
    )

    $alreadyRunning = Get-ThreeCameraOBSProcesses | Where-Object { $_.CommandLine.Contains($Instance.Root) }
    if ($alreadyRunning) {
        return
    }

    $args = @(
        '--portable',
        '--multi',
        '--disable-updater',
        '--profile', $Instance.Profile,
        '--collection', $Instance.SceneCollection
    )

    $workingDir = Split-Path -Parent $Instance.Exe
    if ($Minimized) {
        Start-Process -FilePath $Instance.Exe -ArgumentList $args -WorkingDirectory $workingDir -WindowStyle Minimized | Out-Null
    }
    else {
        Start-Process -FilePath $Instance.Exe -ArgumentList $args -WorkingDirectory $workingDir | Out-Null
    }
}

function Stop-ThreeCameraOBSProcesses {
    param(
        [switch]$Force
    )

    $processes = @(Get-ThreeCameraOBSProcesses)
    if ($processes.Count -eq 0) {
        return
    }

    foreach ($proc in $processes) {
        try {
            if ($Force) {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
            }
            else {
                $p = Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue
                if ($p) {
                    $p.CloseMainWindow() | Out-Null
                }
            }
        }
        catch {
        }
    }
}

function New-DesktopShortcut {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [string]$Hotkey = '',

        [switch]$NoExit,

        [string]$Directory = $script:DesktopPath
    )

    New-DirectoryIfMissing -Path $Directory
    $shortcutPath = Join-Path $Directory "$Name.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Get-ThreeCameraPowerShellPath
    $noExitArg = ''
    if ($NoExit) {
        $noExitArg = '-NoExit '
    }
    $shortcut.Arguments = "-NoProfile $noExitArg-ExecutionPolicy Bypass -File `"$ScriptPath`""
    $shortcut.WorkingDirectory = $script:ThreeCameraRoot
    $shortcut.IconLocation = $script:ObsInstalledExe
    if (-not [string]::IsNullOrWhiteSpace($Hotkey)) {
        $shortcut.Hotkey = $Hotkey
    }
    $shortcut.Save()
}

function Get-ThreeCameraPowerShellPath {
    return (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
}

function Get-ThreeCameraShortcutDefinitions {
    return @(
        [PSCustomObject]@{ Name = 'ThreeCameraOBS-GUI'; Script = 'ThreeCameraOBS-GUI.ps1'; Hotkey = ''; NoExit = $false },
        [PSCustomObject]@{ Name = 'ThreeCameraOBS-Optimize'; Script = 'Optimize-Folder.ps1'; Hotkey = ''; NoExit = $true },
        [PSCustomObject]@{ Name = 'ThreeCameraOBS-OpenWindows'; Script = 'Open-OBS-Windows.ps1'; Hotkey = ''; NoExit = $true },
        [PSCustomObject]@{ Name = 'ThreeCameraOBS-EmergencyStop'; Script = 'Emergency-Stop.ps1'; Hotkey = ''; NoExit = $true },
        [PSCustomObject]@{ Name = 'ThreeCameraOBS-Preflight'; Script = 'Preflight-Check.ps1'; Hotkey = ''; NoExit = $true },
        [PSCustomObject]@{ Name = 'ThreeCameraOBS-Guide'; Script = 'Open-Guide.ps1'; Hotkey = ''; NoExit = $true },
        [PSCustomObject]@{ Name = 'ThreeCameraOBS-Rebuild'; Script = 'Rebuild-ThreeCameraOBS.ps1'; Hotkey = ''; NoExit = $true }
    )
}

function New-ThreeCameraShortcuts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    $created = @()
    foreach ($shortcut in Get-ThreeCameraShortcutDefinitions) {
        $scriptPath = Join-Path $script:ThreeCameraRoot $shortcut.Script
        if (Test-Path -LiteralPath $scriptPath) {
            New-DesktopShortcut -Name $shortcut.Name -ScriptPath $scriptPath -Hotkey $shortcut.Hotkey -NoExit:([bool]$shortcut.NoExit) -Directory $Directory
            $created += (Join-Path $Directory "$($shortcut.Name).lnk")
        }
    }

    return $created
}

function Get-UniqueDestinationPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Path
    }

    $dir = Split-Path -Parent $Path
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $ext = [System.IO.Path]::GetExtension($Path)

    for ($i = 2; $i -lt 1000; $i++) {
        $candidate = Join-Path $dir "$base`_$i$ext"
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw "Could not find a unique destination path for $Path"
}

function Convert-ToSafeToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $token = $Value.Trim()
    $token = $token -replace '[\\/:*?"<>|]+', '_'
    $token = $token -replace '\s+', '_'
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'Empty token is not allowed.'
    }
    return $token
}

function Test-IsBuiltInCamera {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Device
    )

    $text = "$($Device.Name) $($Device.Value) $($Device.DeviceID)"
    $blocked = @(
        'Integrated Camera',
        'Integrated Webcam',
        'Internal Camera',
        'Built-in Camera',
        'Laptop Camera',
        'Remote Desktop',
        'RDCAMERA'
    )

    foreach ($keyword in $blocked) {
        if ($text.IndexOf($keyword, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }

    return $false
}

function Get-ThreeCameraDeviceDisplayName {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Device
    )

    $name = [string]$Device.Name
    $value = [string]$Device.Value
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [string]$Device.DeviceID
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        return $name
    }

    $id = $value -replace '[^A-Za-z0-9_&.-]+', '_'
    if ($id.Length -gt 32) {
        $id = $id.Substring($id.Length - 32)
    }

    return "$name [$id]"
}

function Test-ThreeCameraDirectoryWritable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $probe = Join-Path $Path ('.three-camera-write-test-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        Write-Utf8NoBomFile -Path $probe -Content 'ok'
        Remove-Item -LiteralPath $probe -Force
        return $true
    }
    catch {
        try {
            if (Test-Path -LiteralPath $probe) {
                Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
        }
        return $false
    }
}

function Get-ThreeCameraWindowsDevices {
    $cameraText = [string][char]0x6444 + [string][char]0x50CF
    $photoText = [string][char]0x76F8 + [string][char]0x673A
    try {
        return @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object {
            $_.PNPClass -in @('Camera','Image') -or
            $_.Name -match 'Camera|Webcam|USB Video' -or
            $_.Name -match $cameraText -or
            $_.Name -match $photoText -or
            $_.DeviceID -match 'RDCAMERA'
        })
    }
    catch {
        Write-Host "Windows camera device check skipped: $($_.Exception.Message)"
        return @()
    }
}

function Invoke-OBSNodeControl {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [switch]$QuietErrors
    )

    $nodeScript = Join-Path $script:ThreeCameraRoot 'obs-control.mjs'
    if ($QuietErrors) {
        $output = & node $nodeScript @Arguments 2>$null
    }
    else {
        $output = & node $nodeScript @Arguments
    }
    if (-not $?) {
        throw "Node OBS control failed: $output"
    }

    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    return $text | ConvertFrom-Json
}

function Wait-OBSNodeControl {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port,

        [int]$TimeoutMilliseconds = 60000
    )

    Invoke-OBSNodeControl -Arguments @('wait', [string]$Port, [string]$TimeoutMilliseconds) | Out-Null
}

function Invoke-OBSNodeRequest {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port,

        [Parameter(Mandatory = $true)]
        [string]$RequestType,

        [hashtable]$RequestData = @{},

        [switch]$QuietErrors
    )

    $json = $RequestData | ConvertTo-Json -Depth 50 -Compress
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json))
    return Invoke-OBSNodeControl -Arguments @('request', [string]$Port, $RequestType, "base64:$encoded") -QuietErrors:$QuietErrors
}

function Start-OBSNodeRecordings {
    param(
        [Parameter(Mandatory = $true)]
        [int[]]$Ports
    )

    $args = @('batch-start') + ($Ports | ForEach-Object { [string]$_ })
    return Invoke-OBSNodeControl -Arguments $args
}

function Stop-OBSNodeRecordings {
    param(
        [Parameter(Mandatory = $true)]
        [int[]]$Ports
    )

    $args = @('batch-stop') + ($Ports | ForEach-Object { [string]$_ })
    return Invoke-OBSNodeControl -Arguments $args
}

function Expand-OBSNodeResponses {
    param(
        [AllowNull()]
        [object]$Responses
    )

    $expanded = @()
    foreach ($response in @($Responses)) {
        if ($null -eq $response) {
            continue
        }

        if ($response -is [System.Array]) {
            $expanded += @(Expand-OBSNodeResponses -Responses $response)
            continue
        }

        $expanded += $response
    }

    return $expanded
}

function Get-OBSVideoDevices {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance
    )

    Start-ThreeCameraOBSInstance -Instance $Instance -Minimized
    Wait-OBSNodeControl -Port $Instance.Port -TimeoutMilliseconds 60000

    $probeName = '__three_camera_probe'
    try {
        Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'RemoveInput' -RequestData @{
            inputName = $probeName
        } -QuietErrors | Out-Null
    }
    catch {
    }

    try {
        Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'CreateInput' -RequestData @{
            sceneName = $Instance.Scene
            inputName = $probeName
            inputKind = 'dshow_input'
            inputSettings = @{}
            sceneItemEnabled = $false
        } | Out-Null

        $response = Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'GetInputPropertiesListPropertyItems' -RequestData @{
            inputName = $probeName
            propertyName = 'video_device_id'
        }

        $devices = @()
        foreach ($item in @($response.propertyItems)) {
            $name = [string]$item.itemName
            $value = [string]$item.itemValue

            if ([string]::IsNullOrWhiteSpace($value)) {
                continue
            }

            if ($value -eq 'disabled') {
                continue
            }

            $devices += [PSCustomObject]@{
                Name = $name
                Value = $value
            }
        }

        return $devices | Sort-Object Value -Unique
    }
    finally {
        try {
            Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'RemoveInput' -RequestData @{
                inputName = $probeName
            } -QuietErrors | Out-Null
        }
        catch {
        }
    }
}

function Assert-ThreeExternalCamerasConfigured {
    param(
        [switch]$CheckOnline
    )

    $mapPath = Get-ThreeCameraMapPath
    if (-not (Test-Path -LiteralPath $mapPath)) {
        throw 'Three external cameras are not configured yet. Plug them in and run ThreeCameraOBS-Configure first.'
    }

    $cameraMap = Get-Content -Path $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($cameraMap.cameras).Count -ne 3) {
        throw 'Camera map is incomplete. Run ThreeCameraOBS-Configure again.'
    }

    $seenValues = @{}
    foreach ($camera in @($cameraMap.cameras)) {
        $value = [string]$camera.value
        if ([string]::IsNullOrWhiteSpace($value)) {
            throw "Configured Camera$($camera.index) has an empty device id. Run ThreeCameraOBS-Configure again."
        }

        if ($seenValues.ContainsKey($value)) {
            throw "Configured Camera$($camera.index) duplicates another camera. Run ThreeCameraOBS-Configure again."
        }
        $seenValues[$value] = $true

        if (Test-IsBuiltInCamera -Device ([PSCustomObject]@{ Name = $camera.name; Value = $camera.value; DeviceID = '' })) {
            throw "Configured Camera$($camera.index) matches the internal/system camera block list. Run ThreeCameraOBS-Configure again."
        }
    }

    foreach ($instance in Get-ThreeCameraInstances) {
        $scenePath = Join-Path $instance.Root "config\obs-studio\basic\scenes\$($instance.SceneCollection).json"
        if (-not (Test-Path -LiteralPath $scenePath)) {
            throw "Missing scene file for Camera$($instance.Index): $scenePath"
        }

        $scene = Get-Content -Path $scenePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $source = @($scene.sources | Where-Object { $_.id -eq 'dshow_input' }) | Select-Object -First 1
        if (-not $source -or [string]::IsNullOrWhiteSpace([string]$source.settings.video_device_id)) {
            throw "Camera$($instance.Index) is not bound to an external camera. Run ThreeCameraOBS-Configure first."
        }

        if (Test-IsBuiltInCamera -Device ([PSCustomObject]@{ Name = $source.name; Value = $source.settings.video_device_id; DeviceID = '' })) {
            throw "Camera$($instance.Index) is bound to an internal/system camera and was blocked."
        }
    }

    if ($CheckOnline) {
        $firstInstance = (Get-ThreeCameraInstances)[0]
        $currentDevices = @(Get-OBSVideoDevices -Instance $firstInstance)
        $currentValues = @{}
        foreach ($device in $currentDevices) {
            $value = [string]$device.Value
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $currentValues[$value] = $device
            }
        }

        foreach ($camera in @($cameraMap.cameras)) {
            $value = [string]$camera.value
            if (-not $currentValues.ContainsKey($value)) {
                throw "Configured Camera$($camera.index) is not currently visible to OBS. Check USB connection and run ThreeCameraOBS-Configure again if needed."
            }

            $device = $currentValues[$value]
            if (Test-IsBuiltInCamera -Device $device) {
                throw "Configured Camera$($camera.index) is currently detected as an internal/system camera and was blocked."
            }
        }
    }

    return $cameraMap
}

function Set-OBSRecordingPrefix {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance,

        [Parameter(Mandatory = $true)]
        [string]$Prefix
    )

    $outputDir = Get-ThreeCameraOutputDirForInstance -Instance $Instance
    New-DirectoryIfMissing -Path $outputDir
    Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'SetProfileParameter' -RequestData @{
        parameterCategory = 'SimpleOutput'
        parameterName = 'FilePath'
        parameterValue = $outputDir
    } | Out-Null

    Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'SetProfileParameter' -RequestData @{
        parameterCategory = 'Output'
        parameterName = 'FilenameFormatting'
        parameterValue = $Prefix
    } | Out-Null
}

function Start-RecordingsTogether {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Instances
    )

    $ports = @($Instances | ForEach-Object { [int]$_.Port })
    $responses = @(Expand-OBSNodeResponses -Responses (Start-OBSNodeRecordings -Ports $ports))
    $failures = @($responses | Where-Object { -not [bool]$_.ok })
    if ($failures.Count -gt 0) {
        $startedPorts = @($responses | Where-Object { [bool]$_.ok } | ForEach-Object { [int]$_.port })
        if ($startedPorts.Count -gt 0) {
            Stop-OBSNodeRecordings -Ports $startedPorts | Out-Null
        }

        $messages = @()
        foreach ($failure in $failures) {
            $instance = $Instances | Where-Object { [int]$_.Port -eq [int]$failure.port } | Select-Object -First 1
            $name = "port $($failure.port)"
            if ($instance) {
                $name = "Camera$($instance.Index)"
            }
            $messages += "${name}: $($failure.error)"
        }

        throw "Could not start all selected recordings. Already-started recordings were stopped. $($messages -join '; ')"
    }

    return $responses
}

function Stop-RecordingsTogether {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Instances
    )

    $results = @()
    $ports = @($Instances | ForEach-Object { [int]$_.Port })
    $responses = @(Expand-OBSNodeResponses -Responses (Stop-OBSNodeRecordings -Ports $ports))

    foreach ($instance in $Instances) {
        $match = $responses | Where-Object { [int]$_.port -eq [int]$instance.Port } | Select-Object -First 1
        $outputPath = ''
        if ($match -and $match.response -and $match.response.outputPath) {
            $outputPath = [string]$match.response.outputPath
        }

        $results += [PSCustomObject]@{
            Instance = $instance
            OutputPath = $outputPath
            Ok = [bool]$match.ok
            AlreadyStopped = [bool]$match.alreadyStopped
            Error = [string]$match.error
        }
    }

    return $results
}

function Assert-RecordingStopResults {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results
    )

    $failures = @($Results | Where-Object { -not [bool]$_.Ok })
    if ($failures.Count -eq 0) {
        return
    }

    $messages = @()
    foreach ($failure in $failures) {
        $messages += "Camera$($failure.Instance.Index): $($failure.Error)"
    }

    throw "Could not stop all three recordings. Active recording state was kept so you can retry stop or use ThreeCameraOBS-EmergencyStop. $($messages -join '; ')"
}

function Resolve-RecordedFile {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance,

        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [DateTime]$StartTime,

        [Parameter(Mandatory = $true)]
        [string]$Prefix
    )

    if (-not [string]::IsNullOrWhiteSpace($OutputPath) -and (Test-Path -LiteralPath $OutputPath)) {
        return $OutputPath
    }

    $outputDir = Get-ThreeCameraOutputDirForInstance -Instance $Instance
    $extensions = @('.mp4', '.mkv', '.mov', '.flv')
    $files = Get-ChildItem -Path $outputDir -File -ErrorAction SilentlyContinue |
        Where-Object {
            $extensions -contains $_.Extension.ToLowerInvariant() -and
            $_.LastWriteTime -ge $StartTime.AddSeconds(-10) -and
            ($_.BaseName.StartsWith($Prefix) -or $_.BaseName.StartsWith($Instance.FilePrefix))
        } |
        Sort-Object LastWriteTime -Descending

    if ($files.Count -gt 0) {
        return $files[0].FullName
    }

    throw "Could not find the output file for Camera$($Instance.Index)."
}

function Add-CaptureLogRows {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Active,

        [Parameter(Mandatory = $true)]
        [string[]]$Files,

        [Parameter(Mandatory = $true)]
        [DateTime]$StopTime
    )

    $path = Get-ThreeCameraLogPath
    New-DirectoryIfMissing -Path (Split-Path -Parent $path)

    $rows = @()
    foreach ($file in $Files) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $camera = ''
        if ($baseName -match '_cam(\d+)$') {
            $camera = "cam$($Matches[1])"
        }
        $category = [string]$Active.category

        $rows += [PSCustomObject]@{
            base = [string]$Active.base
            person = ('P{0:D2}' -f [int]$Active.person)
            category = $category
            take = [int]$Active.take
            camera = $camera
            file = $file
            startTime = [string]$Active.startTime
            stopTime = $StopTime.ToString('o')
            loggedAt = (Get-Date).ToString('o')
        }
    }

    if (Test-Path -LiteralPath $path) {
        $rows | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8 -Append
    }
    else {
        $rows | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
    }

    return $rows
}
