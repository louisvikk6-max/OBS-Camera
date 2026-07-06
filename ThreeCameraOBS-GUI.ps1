Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\ThreeCameraCommon.ps1"

& "$PSScriptRoot\Initialize-ThreeCameraOBS.ps1" -Quiet

$script:Devices = @()
$script:CheckBoxes = @()
$script:OutputRows = @()
$script:IsRecording = $false
$script:CurrentActive = $null
$script:CurrentInstances = @()
$script:CurrentStartTime = $null
$script:LastFiles = @()
$script:Language = 'en'
$script:ApplyingLanguage = $false

function ConvertFrom-UiBase64 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

function New-UiTextTable {
    $english = @{
        InternalTag = 'internal/system'
        SelectCamerasFirst = 'Select one or more cameras first.'
        SlotFormat = 'Slot {0}'
        Browse = 'Browse'
        SelectOutputFolderFormat = 'Select output folder for slot {0}'
        LoadingCameras = 'Loading cameras...'
        NoCameras = 'OBS did not report any cameras.'
        NoCamerasStatus = 'No cameras were detected.'
        SelectMaxCameras = 'Select any number of cameras. OBS instances are created automatically.'
        LoadedCamerasFormat = 'Loaded {0} camera(s).'
        LoadFailedFormat = 'Load failed: {0}'
        CameraLoadFailedFormat = 'Camera load failed: {0}'
        SelectAtLeastOne = 'Select at least one camera.'
        ActiveStateExists = 'An active recording state already exists. Stop it first or run EmergencyStop.'
        OutputFolderEmptyFormat = 'Output folder for slot {0} is empty.'
        OutputFolderNotWritableFormat = 'Output folder for slot {0} is not writable: {1}'
        StartedRecordingFormat = 'Started recording: {0}, {1} camera(s).'
        StartFailedStatusFormat = 'Start failed: {0}'
        StartFailedDialogFormat = 'Start recording failed: {0}'
        StoppedRecordingFormat = 'Stopped recording: {0}'
        SavedFormat = 'Saved: {0}'
        RecordingCompleteFormat = 'Recording complete. Saved {0} file(s).'
        StopFailedStatusFormat = 'Stop failed: {0}'
        StopFailedDialogFormat = 'Stop recording failed: {0}'
        NoLastFiles = 'No completed recording files are available to move.'
        MovedFormat = 'Moved: {0}'
        MovedFilesFormat = 'Moved {0} file(s).'
        NoFilesNeededMove = 'No files needed to move.'
        MoveFailedStatusFormat = 'Move failed: {0}'
        MoveFailedDialogFormat = 'Move failed: {0}'
        RefreshCameras = 'Refresh cameras'
        OpenObs = 'Open OBS windows'
        RequestedObs = 'Requested OBS windows.'
        OpenObsFailedFormat = 'Open OBS failed: {0}'
        EmergencyStop = 'Emergency stop'
        EmergencyConfirm = 'Stop this set of OBS processes?'
        EmergencyDone = 'Emergency stop completed.'
        AvailableCameras = 'Available cameras'
        OutputFolders = 'Output folders'
        Person = 'Person'
        Category = 'Category'
        CategoryRequired = 'Enter a category.'
        CategoryTokenInvalid = 'Category contains invalid filename characters.'
        CategoryPlaceholder = 'Example: groupA / task1 / custom_category'
        UnlimitedHint = 'Select any number of cameras. OBS instances are created automatically.'
        Take = 'Take'
        AdvanceProgress = 'Advance progress after stop'
        StartRecording = 'Start recording'
        StopRecording = 'Stop recording'
        OpenOutput = 'Open output folders'
        MoveLastFiles = 'Move last files'
        CloseActive = 'Recording is active. Stop before closing?'
        FixBlackScreen = 'Fix black screen'
        FixBlackScreenStarted = 'Refreshing selected camera inputs...'
        FixBlackScreenDone = 'Inputs refreshed. If still black, unplug/replug the camera and refresh cameras.'
        FixBlackScreenFailedFormat = 'Fix black screen failed: {0}'
        RestartObs = 'Restart OBS'
        RestartObsConfirm = 'Restart OBS windows now? Do not use while recording.'
        RestartObsDone = 'OBS windows restarted.'
        RestartObsFailedFormat = 'Restart OBS failed: {0}'
        Language = 'Language'
        English = 'English'
        Chinese = 'Chinese'
        NoSelectedForRepair = 'Select the camera(s) to repair first.'
        RepairDuringRecording = 'Cannot repair while recording. Stop recording first.'
        RestartDuringRecording = 'Cannot restart OBS while recording. Stop recording first.'
    }

    $zhBase64 = @{
        InternalTag = '5YaF572uL+ezu+e7nw=='
        SelectCamerasFirst = '6K+35YWI6YCJ5oup5LiA5Liq5oiW5aSa5Liq5pGE5YOP5aS044CC'
        SlotFormat = '5py65L2NIHswfQ=='
        Browse = '6YCJ5oup'
        SelectOutputFolderFormat = '6YCJ5oup5py65L2NIHswfSDnmoTkv53lrZjmlofku7blpLk='
        LoadingCameras = '5q2j5Zyo6K+75Y+W5pGE5YOP5aS0Li4u'
        NoCameras = 'T0JTIOayoeaciei/lOWbnuWPr+eUqOaRhOWDj+WktOOAgg=='
        NoCamerasStatus = '5rKh5pyJ5qOA5rWL5Yiw5Y+v55So5pGE5YOP5aS044CC'
        SelectMaxCameras = '5Y+v6YCJ5oup5Lu75oSP5pWw6YeP5pGE5YOP5aS077yM57O757uf5Lya6Ieq5Yqo5Yib5bu65a+55bqUIE9CUyDlrp7kvovjgII='
        LoadedCamerasFormat = '5bey6K+75Y+WIHswfSDkuKrmkYTlg4/lpLTjgII='
        LoadFailedFormat = '6K+75Y+W5aSx6LSl77yaezB9'
        CameraLoadFailedFormat = '6K+75Y+W5pGE5YOP5aS05aSx6LSl77yaezB9'
        SelectAtLeastOne = '6K+36Iez5bCR6YCJ5oup5LiA5Liq5pGE5YOP5aS044CC'
        ActiveStateExists = '5bey5pyJ5b2V5Yi254q25oCB77yM6K+35YWI5YGc5q2i5b2T5YmN5b2V5Yi25oiW6L+Q6KGM5bqU5oCl5YGc5q2i44CC'
        OutputFolderEmptyFormat = '5py65L2NIHswfSDnmoTkv53lrZjmlofku7blpLnkuLrnqbrjgII='
        OutputFolderNotWritableFormat = '5py65L2NIHswfSDnmoTkv53lrZjmlofku7blpLnkuI3lj6/lhpnvvJp7MX0='
        StartedRecordingFormat = '5byA5aeL5b2V5Yi277yaezB977yMezF9IOi3r+OAgg=='
        StartFailedStatusFormat = '5byA5aeL5aSx6LSl77yaezB9'
        StartFailedDialogFormat = '5byA5aeL5b2V5Yi25aSx6LSl77yaezB9'
        StoppedRecordingFormat = '5YGc5q2i5b2V5Yi277yaezB9'
        SavedFormat = '5bey5L+d5a2Y77yaezB9'
        RecordingCompleteFormat = '5b2V5Yi25a6M5oiQ77yM5bey5L+d5a2YIHswfSDkuKrmlofku7bjgII='
        StopFailedStatusFormat = '5YGc5q2i5aSx6LSl77yaezB9'
        StopFailedDialogFormat = '5YGc5q2i5b2V5Yi25aSx6LSl77yaezB9'
        NoLastFiles = '5rKh5pyJ5Y+v56e75Yqo55qE5LiK5qyh5b2V5Yi25paH5Lu244CC'
        MovedFormat = '5bey56e75Yqo77yaezB9'
        MovedFilesFormat = '5bey56e75YqoIHswfSDkuKrmlofku7bjgII='
        NoFilesNeededMove = '5rKh5pyJ6ZyA6KaB56e75Yqo55qE5paH5Lu244CC'
        MoveFailedStatusFormat = '56e75Yqo5aSx6LSl77yaezB9'
        MoveFailedDialogFormat = '56e75Yqo5aSx6LSl77yaezB9'
        RefreshCameras = '5Yi35paw5pGE5YOP5aS0'
        OpenObs = '5omT5byAIE9CUyDnqpflj6M='
        RequestedObs = '5bey6K+35rGC5omT5byAIE9CUyDnqpflj6PjgII='
        OpenObsFailedFormat = '5omT5byAIE9CUyDlpLHotKXvvJp7MH0='
        EmergencyStop = '5bqU5oCl5YGc5q2i'
        EmergencyConfirm = '56Gu5a6a5YGc5q2i6L+Z5aWXIE9CUyDov5vnqIvlkJfvvJ8='
        EmergencyDone = '5bey5a6M5oiQ5bqU5oCl5YGc5q2i44CC'
        AvailableCameras = '5Y+v55So5pGE5YOP5aS0'
        OutputFolders = '5L+d5a2Y5paH5Lu25aS5'
        Person = '5Lq65ZGY'
        Category = '57G75Yir'
        CategoryRequired = '6K+35aGr5YaZ57G75Yir44CC'
        CategoryTokenInvalid = '57G75Yir5LiN6IO95YyF5ZCr5paH5Lu25ZCN6Z2e5rOV5a2X56ym44CC'
        CategoryPlaceholder = '5L6L5aaC77yaQee7hCAvIOS7u+WKoTEgLyDoh6rlrprkuYnnsbvliKs='
        UnlimitedHint = '5Y+v6YCJ5oup5Lu75oSP5pWw6YeP5pGE5YOP5aS077yM57O757uf5Lya6Ieq5Yqo5Yib5bu65a+55bqUIE9CUyDlrp7kvovjgII='
        Take = '5qyh5pWw'
        AdvanceProgress = '5YGc5q2i5ZCO5o6o6L+b6L+b5bqm'
        StartRecording = '5byA5aeL5b2V5Yi2'
        StopRecording = '5YGc5q2i5b2V5Yi2'
        OpenOutput = '5omT5byA5L+d5a2Y5L2N572u'
        MoveLastFiles = '56e75Yqo5LiK5qyh5paH5Lu2'
        CloseActive = '5b2T5YmN5q2j5Zyo5b2V5Yi277yM5YWz6Zet5YmN6KaB5YWI5YGc5q2i5ZCX77yf'
        FixBlackScreen = '5L+u5aSN6buR5bGP'
        FixBlackScreenStarted = '5q2j5Zyo5Yi35paw5omA6YCJ5pGE5YOP5aS06L6T5YWl5rqQLi4u'
        FixBlackScreenDone = '5bey5Yi35paw6L6T5YWl5rqQ44CC5aaC5p6c5LuN6buR5bGP77yM6K+36YeN5paw5o+S5ouU5pGE5YOP5aS05ZCO54K55Yi35paw5pGE5YOP5aS044CC'
        FixBlackScreenFailedFormat = '5L+u5aSN6buR5bGP5aSx6LSl77yaezB9'
        RestartObs = '6YeN5ZCvIE9CUw=='
        RestartObsConfirm = '546w5Zyo6YeN5ZCvIE9CUyDnqpflj6PlkJfvvJ/lvZXliLbkuK3kuI3opoHkvb/nlKjjgII='
        RestartObsDone = 'T0JTIOeql+WPo+W3sumHjeWQr+OAgg=='
        RestartObsFailedFormat = '6YeN5ZCvIE9CUyDlpLHotKXvvJp7MH0='
        Language = '6K+t6KiA'
        English = 'RW5nbGlzaA=='
        Chinese = '5Lit5paH'
        NoSelectedForRepair = '6K+35YWI6YCJ5oup6KaB5L+u5aSN55qE5pGE5YOP5aS044CC'
        RepairDuringRecording = '5b2V5Yi25Lit5LiN6IO95L+u5aSN6buR5bGP77yM6K+35YWI5YGc5q2i5b2V5Yi244CC'
        RestartDuringRecording = '5b2V5Yi25Lit5LiN6IO96YeN5ZCvIE9CU++8jOivt+WFiOWBnOatouW9leWItuOAgg=='
    }

    $chinese = @{}
    foreach ($key in $zhBase64.Keys) {
        $chinese[$key] = ConvertFrom-UiBase64 -Value $zhBase64[$key]
    }

    return @{
        en = $english
        zh = $chinese
    }
}

$script:UiText = New-UiTextTable

function Get-UiText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [object[]]$FormatArgs = @()
    )

    $language = $script:Language
    if (-not $script:UiText.ContainsKey($language)) {
        $language = 'en'
    }

    $table = $script:UiText[$language]
    $value = $table[$Key]
    if ([string]::IsNullOrEmpty($value)) {
        $value = $script:UiText.en[$Key]
    }
    if ([string]::IsNullOrEmpty($value)) {
        return $Key
    }

    if ($FormatArgs.Count -gt 0) {
        return ($value -f $FormatArgs)
    }
    return $value
}

function Get-GuiConfigPath {
    return (Join-Path (Get-ThreeCameraStateDir) 'gui-config.json')
}

function Get-DefaultFolderForSlot {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Slot
    )

    $guiConfig = Load-GuiConfig
    if ($guiConfig -and $guiConfig.folders) {
        foreach ($folder in @($guiConfig.folders)) {
            if ([int]$folder.slot -eq $Slot -and -not [string]::IsNullOrWhiteSpace([string]$folder.path)) {
                return [string]$folder.path
            }
        }
    }

    $configured = Get-ThreeCameraConfiguredOutputDirForCamera -CameraIndex $Slot
    if (-not [string]::IsNullOrWhiteSpace($configured)) {
        return $configured
    }

    return (Join-Path (Get-ThreeCameraOutputDir) "cam$Slot")
}

function Get-SafeDeviceText {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Device
    )

    $text = Get-ThreeCameraDeviceDisplayName -Device $Device
    if (Test-IsBuiltInCamera -Device $Device) {
        $text = "$text  ($(Get-UiText -Key 'InternalTag'))"
    }
    return $text
}

function Save-GuiConfig {
    $selectedValues = @()
    foreach ($checkBox in @($script:CheckBoxes)) {
        if ($checkBox.Checked) {
            $selectedValues += [string]$checkBox.Tag.Value
        }
    }

    $folders = @()
    foreach ($row in @($script:OutputRows)) {
        $folders += [ordered]@{
            slot = [int]$row.Slot
            path = [string]$row.TextBox.Text
        }
    }

    $state = [ordered]@{
        selectedDeviceValues = $selectedValues
        folders = $folders
        person = [int]$personBox.Value
        category = [string]$categoryBox.Text
        take = [int]$takeBox.Value
        advanceProgress = [bool]$advanceCheck.Checked
        language = [string]$script:Language
        updatedAt = (Get-Date).ToString('s')
    } | ConvertTo-Json -Depth 20

    Write-Utf8NoBomFile -Path (Get-GuiConfigPath) -Content $state
}

function Load-GuiConfig {
    $path = Get-GuiConfigPath
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }

    try {
        return Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Get-SelectedDevices {
    $selected = @()
    foreach ($checkBox in @($script:CheckBoxes)) {
        if ($checkBox.Checked) {
            $selected += $checkBox.Tag
        }
    }
    return $selected
}

function Set-StatusText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $statusBox.AppendText("[$((Get-Date).ToString('HH:mm:ss'))] $Text`r`n")
    $statusBox.SelectionStart = $statusBox.Text.Length
    $statusBox.ScrollToCaret()
}

function Update-OutputRows {
    $outputPanel.Controls.Clear()
    $script:OutputRows = @()

    $selected = @(Get-SelectedDevices)
    if ($selected.Count -eq 0) {
        $empty = New-Object System.Windows.Forms.Label
        $empty.AutoSize = $true
        $empty.Text = Get-UiText -Key 'SelectCamerasFirst'
        $empty.Margin = New-Object System.Windows.Forms.Padding(4, 8, 4, 4)
        [void]$outputPanel.Controls.Add($empty)
        return
    }

    for ($i = 0; $i -lt $selected.Count; $i++) {
        $slot = $i + 1
        $device = $selected[$i]

        $row = New-Object System.Windows.Forms.TableLayoutPanel
        $row.ColumnCount = 4
        $row.RowCount = 1
        $row.Width = 740
        $row.Height = 34
        $row.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
        [void]$row.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 78)))
        [void]$row.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 42)))
        [void]$row.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 58)))
        [void]$row.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 72)))

        $slotLabel = New-Object System.Windows.Forms.Label
        $slotLabel.Text = Get-UiText -Key 'SlotFormat' -FormatArgs @($slot)
        $slotLabel.Dock = 'Fill'
        $slotLabel.TextAlign = 'MiddleLeft'

        $deviceLabel = New-Object System.Windows.Forms.Label
        $deviceLabel.Text = Get-SafeDeviceText -Device $device
        $deviceLabel.Dock = 'Fill'
        $deviceLabel.TextAlign = 'MiddleLeft'
        $deviceLabel.AutoEllipsis = $true

        $folderBox = New-Object System.Windows.Forms.TextBox
        $folderBox.Dock = 'Fill'
        $folderBox.Text = Get-DefaultFolderForSlot -Slot $slot

        $browseButton = New-Object System.Windows.Forms.Button
        $browseButton.Text = Get-UiText -Key 'Browse'
        $browseButton.Dock = 'Fill'

        $rowInfo = [PSCustomObject]@{
            Slot = $slot
            Device = $device
            TextBox = $folderBox
        }
        $browseButton.Tag = $rowInfo
        $browseButton.Add_Click({
            $info = $this.Tag
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = Get-UiText -Key 'SelectOutputFolderFormat' -FormatArgs @($info.Slot)
            if (-not [string]::IsNullOrWhiteSpace($info.TextBox.Text) -and (Test-Path -LiteralPath $info.TextBox.Text)) {
                $dialog.SelectedPath = $info.TextBox.Text
            }
            if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
                $info.TextBox.Text = $dialog.SelectedPath
                Save-GuiConfig
            }
        })

        [void]$row.Controls.Add($slotLabel, 0, 0)
        [void]$row.Controls.Add($deviceLabel, 1, 0)
        [void]$row.Controls.Add($folderBox, 2, 0)
        [void]$row.Controls.Add($browseButton, 3, 0)
        [void]$outputPanel.Controls.Add($row)
        $script:OutputRows += $rowInfo
    }
}

function Update-ProgressControls {
    $progress = Get-ThreeCameraProgress
    if ([bool]$progress.completed) {
        $personBox.Value = 20
        $takeBox.Value = 1
        return
    }

    $personBox.Value = [decimal]([int]$progress.person)
    $takeBox.Value = [decimal]([int]$progress.take)
}

function Refresh-Cameras {
    param(
        [switch]$RepairSelectedInputs
    )

    $cameraPanel.Controls.Clear()
    $script:CheckBoxes = @()
    $script:Devices = @()

    $hint = New-Object System.Windows.Forms.Label
    $hint.AutoSize = $true
    $hint.Text = Get-UiText -Key 'UnlimitedHint'
    $hint.Margin = New-Object System.Windows.Forms.Padding(4, 3, 4, 6)
    [void]$cameraPanel.Controls.Add($hint)

    $loading = New-Object System.Windows.Forms.Label
    $loading.AutoSize = $true
    $loading.Text = Get-UiText -Key 'LoadingCameras'
    [void]$cameraPanel.Controls.Add($loading)
    $form.Refresh()

    try {
        $instance = (Get-ThreeCameraInstances)[0]
        $script:Devices = @(Get-OBSVideoDevices -Instance $instance)
        $cameraPanel.Controls.Clear()
        $hint = New-Object System.Windows.Forms.Label
        $hint.AutoSize = $true
        $hint.Text = Get-UiText -Key 'UnlimitedHint'
        $hint.Margin = New-Object System.Windows.Forms.Padding(4, 3, 4, 6)
        [void]$cameraPanel.Controls.Add($hint)

        if ($script:Devices.Count -eq 0) {
            $none = New-Object System.Windows.Forms.Label
            $none.AutoSize = $true
            $none.Text = Get-UiText -Key 'NoCameras'
            [void]$cameraPanel.Controls.Add($none)
            Set-StatusText (Get-UiText -Key 'NoCamerasStatus')
            Update-OutputRows
            return
        }

        $config = Load-GuiConfig
        $selectedValues = @()
        if ($config -and $config.selectedDeviceValues) {
            $selectedValues = @($config.selectedDeviceValues | ForEach-Object { [string]$_ })
        }

        foreach ($device in @($script:Devices)) {
            $checkBox = New-Object System.Windows.Forms.CheckBox
            $checkBox.AutoSize = $true
            $checkBox.Width = 720
            $checkBox.Text = Get-SafeDeviceText -Device $device
            $checkBox.Tag = $device
            $checkBox.Margin = New-Object System.Windows.Forms.Padding(4, 3, 4, 3)
            if ($selectedValues -contains [string]$device.Value) {
                $checkBox.Checked = $true
            }
            $checkBox.Add_CheckedChanged({
                Update-OutputRows
                Save-GuiConfig
            })
            [void]$cameraPanel.Controls.Add($checkBox)
            $script:CheckBoxes += $checkBox
        }

        Update-OutputRows
        Set-StatusText (Get-UiText -Key 'LoadedCamerasFormat' -FormatArgs @($script:Devices.Count))
        if ($RepairSelectedInputs) {
            Repair-SelectedCameraInputsQuiet
        }
    }
    catch {
        $cameraPanel.Controls.Clear()
        $errorLabel = New-Object System.Windows.Forms.Label
        $errorLabel.AutoSize = $true
        $errorLabel.Text = Get-UiText -Key 'LoadFailedFormat' -FormatArgs @($_.Exception.Message)
        [void]$cameraPanel.Controls.Add($errorLabel)
        Set-StatusText (Get-UiText -Key 'CameraLoadFailedFormat' -FormatArgs @($_.Exception.Message))
    }
}

function Get-CaptureBaseName {
    $categoryRaw = [string]$categoryBox.Text
    if ([string]::IsNullOrWhiteSpace($categoryRaw)) {
        throw (Get-UiText -Key 'CategoryRequired')
    }
    $category = Convert-ToSafeToken -Value $categoryRaw
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    return ('P{0:D2}_{1}_T{2}_{3}' -f [int]$personBox.Value, $category, [int]$takeBox.Value, $timestamp)
}

function Set-GuiOBSDevice {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Instance,

        [Parameter(Mandatory = $true)]
        [string]$VideoDeviceId,

        [switch]$Recreate
    )

    $settings = @{
        video_device_id = $VideoDeviceId
        last_video_device_id = $VideoDeviceId
        res_type = 0
        audio_output_mode = 0
        deactivate_when_not_showing = $false
        buffering = 0
    }

    if ($Recreate) {
        try {
            Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'RemoveInput' -RequestData @{
                inputName = $Instance.Source
            } -QuietErrors | Out-Null
        }
        catch {
        }
    }

    $inputExists = $false
    try {
        Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'GetInputSettings' -RequestData @{
            inputName = $Instance.Source
        } | Out-Null
        $inputExists = $true
    }
    catch {
        $inputExists = $false
    }

    if ($inputExists) {
        Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'SetInputSettings' -RequestData @{
            inputName = $Instance.Source
            inputSettings = $settings
            overlay = $true
        } | Out-Null
        return
    }

    Invoke-OBSNodeRequest -Port $Instance.Port -RequestType 'CreateInput' -RequestData @{
        sceneName = $Instance.Scene
        inputName = $Instance.Source
        inputKind = 'dshow_input'
        inputSettings = $settings
        sceneItemEnabled = $true
    } | Out-Null
}

function Repair-SelectedCameraInputs {
    if ($script:IsRecording) {
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'RepairDuringRecording'), 'ThreeCameraOBS') | Out-Null
        return
    }

    $selected = @(Get-SelectedDevices)
    if ($selected.Count -lt 1) {
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'NoSelectedForRepair'), 'ThreeCameraOBS') | Out-Null
        return
    }
    try {
        Set-StatusText (Get-UiText -Key 'FixBlackScreenStarted')
        Ensure-ThreeCameraInstancesReady -Count $selected.Count
        $instances = @(Get-ThreeCameraInstances -Count $selected.Count)
        for ($i = 0; $i -lt $selected.Count; $i++) {
            Write-SceneCollection -Instance $instances[$i] -VideoDeviceId ([string]$selected[$i].Value) -Force
            Start-ThreeCameraOBSInstance -Instance $instances[$i]
        }

        for ($i = 0; $i -lt $instances.Count; $i++) {
            $instance = $instances[$i]
            Wait-OBSNodeControl -Port $instance.Port -TimeoutMilliseconds 60000
            Set-GuiOBSDevice -Instance $instance -VideoDeviceId ([string]$selected[$i].Value) -Recreate
        }

        Set-StatusText (Get-UiText -Key 'FixBlackScreenDone')
    }
    catch {
        Set-StatusText (Get-UiText -Key 'FixBlackScreenFailedFormat' -FormatArgs @($_.Exception.Message))
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'FixBlackScreenFailedFormat' -FormatArgs @($_.Exception.Message)), 'ThreeCameraOBS') | Out-Null
    }
}

function Restart-GuiOBSWindows {
    if ($script:IsRecording) {
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'RestartDuringRecording'), 'ThreeCameraOBS') | Out-Null
        return
    }

    if ([System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'RestartObsConfirm'), 'ThreeCameraOBS', 'YesNo') -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    try {
        Stop-ThreeCameraOBSProcesses -Force
        foreach ($instance in Get-ThreeCameraInstances) {
            Start-ThreeCameraOBSInstance -Instance $instance
        }
        Set-StatusText (Get-UiText -Key 'RestartObsDone')
    }
    catch {
        Set-StatusText (Get-UiText -Key 'RestartObsFailedFormat' -FormatArgs @($_.Exception.Message))
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'RestartObsFailedFormat' -FormatArgs @($_.Exception.Message)), 'ThreeCameraOBS') | Out-Null
    }
}

function Repair-SelectedCameraInputsQuiet {
    if ($script:IsRecording) {
        return
    }

    $selected = @(Get-SelectedDevices)
    if ($selected.Count -lt 1) {
        return
    }

    try {
        Ensure-ThreeCameraInstancesReady -Count $selected.Count
        $instances = @(Get-ThreeCameraInstances -Count $selected.Count)
        for ($i = 0; $i -lt $selected.Count; $i++) {
            Write-SceneCollection -Instance $instances[$i] -VideoDeviceId ([string]$selected[$i].Value) -Force
            Start-ThreeCameraOBSInstance -Instance $instances[$i] -Minimized
        }

        for ($i = 0; $i -lt $instances.Count; $i++) {
            $instance = $instances[$i]
            Wait-OBSNodeControl -Port $instance.Port -TimeoutMilliseconds 60000
            Set-GuiOBSDevice -Instance $instance -VideoDeviceId ([string]$selected[$i].Value) -Recreate
        }
    }
    catch {
        Set-StatusText (Get-UiText -Key 'FixBlackScreenFailedFormat' -FormatArgs @($_.Exception.Message))
    }
}

function Start-GuiRecording {
    if ($script:IsRecording) {
        return
    }

    $selected = @(Get-SelectedDevices)
    if ($selected.Count -lt 1) {
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'SelectAtLeastOne'), 'ThreeCameraOBS') | Out-Null
        return
    }
    $activePath = Get-ThreeCameraActiveRecordingPath
    if (Test-Path -LiteralPath $activePath) {
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'ActiveStateExists'), 'ThreeCameraOBS') | Out-Null
        return
    }

    try {
        $folderRows = @()
        foreach ($row in @($script:OutputRows)) {
            $folder = [string]$row.TextBox.Text
            if ([string]::IsNullOrWhiteSpace($folder)) {
                throw (Get-UiText -Key 'OutputFolderEmptyFormat' -FormatArgs @($row.Slot))
            }
            New-DirectoryIfMissing -Path $folder
            if (-not (Test-ThreeCameraDirectoryWritable -Path $folder)) {
                throw (Get-UiText -Key 'OutputFolderNotWritableFormat' -FormatArgs @($row.Slot, $folder))
            }
            $folderRows += [ordered]@{
                index = [int]$row.Slot
                path = $folder
            }
        }
        Save-ThreeCameraOutputFolders -Folders $folderRows
        Save-GuiConfig

        Ensure-ThreeCameraInstancesReady -Count $selected.Count
        $instances = @(Get-ThreeCameraInstances -Count $selected.Count)
        for ($i = 0; $i -lt $selected.Count; $i++) {
            Write-SceneCollection -Instance $instances[$i] -VideoDeviceId ([string]$selected[$i].Value) -Force
        }

        $base = Get-CaptureBaseName
        for ($i = 0; $i -lt $instances.Count; $i++) {
            Start-ThreeCameraOBSInstance -Instance $instances[$i]
        }

        foreach ($instance in @($instances)) {
            Wait-OBSNodeControl -Port $instance.Port -TimeoutMilliseconds 60000
            $device = $selected[$instance.Index - 1]
            Set-GuiOBSDevice -Instance $instance -VideoDeviceId ([string]$device.Value)
            Set-OBSRecordingPrefix -Instance $instance -Prefix "$base`_cam$($instance.Index)"
        }

        $startTime = Get-Date
        Start-RecordingsTogether -Instances $instances | Out-Null

        $category = Convert-ToSafeToken -Value ([string]$categoryBox.Text)
        $captures = @()
        foreach ($instance in @($instances)) {
            $device = $selected[$instance.Index - 1]
            $captures += [ordered]@{
                index = [int]$instance.Index
                prefix = "$base`_cam$($instance.Index)"
                port = [int]$instance.Port
                deviceName = [string]$device.Name
                deviceValue = [string]$device.Value
                outputDir = Get-ThreeCameraOutputDirForInstance -Instance $instance
            }
        }

        $active = [PSCustomObject]@{
            base = $base
            person = [int]$personBox.Value
            category = $category
            take = [int]$takeBox.Value
            startTime = $startTime.ToString('o')
            captures = $captures
        }
        $json = $active | ConvertTo-Json -Depth 20
        Write-Utf8NoBomFile -Path $activePath -Content $json

        $script:CurrentActive = $active
        $script:CurrentInstances = $instances
        $script:CurrentStartTime = $startTime
        $script:IsRecording = $true
        $script:LastFiles = @()

        $startButton.Enabled = $false
        $stopButton.Enabled = $true
        $refreshButton.Enabled = $false
        Set-StatusText (Get-UiText -Key 'StartedRecordingFormat' -FormatArgs @($base, $selected.Count))
    }
    catch {
        Set-StatusText (Get-UiText -Key 'StartFailedStatusFormat' -FormatArgs @($_.Exception.Message))
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'StartFailedDialogFormat' -FormatArgs @($_.Exception.Message)), 'ThreeCameraOBS') | Out-Null
    }
}

function Stop-GuiRecording {
    if (-not $script:IsRecording) {
        return
    }

    $completed = $false
    try {
        $results = @(Stop-RecordingsTogether -Instances $script:CurrentInstances)
        Assert-RecordingStopResults -Results $results

        $finalFiles = @()
        foreach ($capture in @($script:CurrentActive.captures)) {
            $instance = $script:CurrentInstances | Where-Object { [int]$_.Index -eq [int]$capture.index } | Select-Object -First 1
            $result = $results | Where-Object { [int]$_.Instance.Index -eq [int]$capture.index } | Select-Object -First 1
            $sourcePath = Resolve-RecordedFile -Instance $instance -OutputPath ([string]$result.OutputPath) -StartTime $script:CurrentStartTime -Prefix ([string]$capture.prefix)
            $finalFiles += $sourcePath
        }

        $stopTime = Get-Date
        Add-CaptureLogRows -Active $script:CurrentActive -Files $finalFiles -StopTime $stopTime | Out-Null

        $activePath = Get-ThreeCameraActiveRecordingPath
        if (Test-Path -LiteralPath $activePath) {
            Remove-Item -LiteralPath $activePath -Force
        }

        if ($advanceCheck.Checked) {
            $progress = [PSCustomObject]@{
                person = [int]$script:CurrentActive.person
                take = [int]$script:CurrentActive.take
                completed = $false
            }
            Save-ThreeCameraProgress -Progress $progress
            Update-ProgressControls
        }

        $script:LastFiles = $finalFiles
        Set-StatusText (Get-UiText -Key 'StoppedRecordingFormat' -FormatArgs @($script:CurrentActive.base))
        foreach ($file in @($finalFiles)) {
            Set-StatusText (Get-UiText -Key 'SavedFormat' -FormatArgs @($file))
        }
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'RecordingCompleteFormat' -FormatArgs @($finalFiles.Count)), 'ThreeCameraOBS') | Out-Null
        $completed = $true
    }
    catch {
        Set-StatusText (Get-UiText -Key 'StopFailedStatusFormat' -FormatArgs @($_.Exception.Message))
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'StopFailedDialogFormat' -FormatArgs @($_.Exception.Message)), 'ThreeCameraOBS') | Out-Null
    }
    finally {
        if ($completed) {
            $script:IsRecording = $false
            $script:CurrentActive = $null
            $script:CurrentInstances = @()
            $script:CurrentStartTime = $null
            $startButton.Enabled = $true
            $stopButton.Enabled = $false
            $refreshButton.Enabled = $true
        }
    }
}

function Move-LastFilesToSelectedFolders {
    if ($script:LastFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'NoLastFiles'), 'ThreeCameraOBS') | Out-Null
        return
    }

    try {
        $moved = @()
        foreach ($file in @($script:LastFiles)) {
            if (-not (Test-Path -LiteralPath $file)) {
                continue
            }

            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file)
            $cameraIndex = 0
            if ($baseName -match '_cam(\d+)$') {
                $cameraIndex = [int]$Matches[1]
            }
            if ($cameraIndex -lt 1) {
                continue
            }

            $row = $script:OutputRows | Where-Object { [int]$_.Slot -eq $cameraIndex } | Select-Object -First 1
            if (-not $row) {
                continue
            }

            $folder = [string]$row.TextBox.Text
            if ([string]::IsNullOrWhiteSpace($folder)) {
                continue
            }

            New-DirectoryIfMissing -Path $folder
            if (-not (Test-ThreeCameraDirectoryWritable -Path $folder)) {
                throw (Get-UiText -Key 'OutputFolderNotWritableFormat' -FormatArgs @($cameraIndex, $folder))
            }

            $destination = Get-UniqueDestinationPath -Path (Join-Path $folder ([System.IO.Path]::GetFileName($file)))
            if ([System.IO.Path]::GetFullPath($file).Equals([System.IO.Path]::GetFullPath($destination), [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            Move-Item -LiteralPath $file -Destination $destination
            $moved += $destination
        }

        if ($moved.Count -gt 0) {
            $script:LastFiles = $moved
            foreach ($file in @($moved)) {
                Set-StatusText (Get-UiText -Key 'MovedFormat' -FormatArgs @($file))
            }
            [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'MovedFilesFormat' -FormatArgs @($moved.Count)), 'ThreeCameraOBS') | Out-Null
        }
        else {
            [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'NoFilesNeededMove'), 'ThreeCameraOBS') | Out-Null
        }
    }
    catch {
        Set-StatusText (Get-UiText -Key 'MoveFailedStatusFormat' -FormatArgs @($_.Exception.Message))
        [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'MoveFailedDialogFormat' -FormatArgs @($_.Exception.Message)), 'ThreeCameraOBS') | Out-Null
    }
}

function Apply-Language {
    if ($null -eq $form) {
        return
    }

    $script:ApplyingLanguage = $true
    $refreshButton.Text = Get-UiText -Key 'RefreshCameras'
    $openButton.Text = Get-UiText -Key 'OpenObs'
    $fixBlackButton.Text = Get-UiText -Key 'FixBlackScreen'
    $restartObsButton.Text = Get-UiText -Key 'RestartObs'
    $emergencyButton.Text = Get-UiText -Key 'EmergencyStop'
    $languageLabel.Text = Get-UiText -Key 'Language'
    $cameraGroup.Text = Get-UiText -Key 'AvailableCameras'
    $outputGroup.Text = Get-UiText -Key 'OutputFolders'
    $personLabel.Text = Get-UiText -Key 'Person'
    $categoryLabel.Text = Get-UiText -Key 'Category'
    $takeLabel.Text = Get-UiText -Key 'Take'
    $advanceCheck.Text = Get-UiText -Key 'AdvanceProgress'
    $startButton.Text = Get-UiText -Key 'StartRecording'
    $stopButton.Text = Get-UiText -Key 'StopRecording'
    $openOutputButton.Text = Get-UiText -Key 'OpenOutput'
    $moveLastButton.Text = Get-UiText -Key 'MoveLastFiles'

    $currentIndex = $languageBox.SelectedIndex
    $languageBox.Items.Clear()
    [void]$languageBox.Items.Add((Get-UiText -Key 'English'))
    [void]$languageBox.Items.Add((Get-UiText -Key 'Chinese'))
    if ($currentIndex -ge 0) {
        $languageBox.SelectedIndex = $currentIndex
    }
    $script:ApplyingLanguage = $false

    Update-OutputRows
    foreach ($checkBox in @($script:CheckBoxes)) {
        $checkBox.Text = Get-SafeDeviceText -Device $checkBox.Tag
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'ThreeCameraOBS'
$form.Size = New-Object System.Drawing.Size(920, 740)
$form.MinimumSize = New-Object System.Drawing.Size(860, 640)
$form.StartPosition = 'CenterScreen'

$main = New-Object System.Windows.Forms.TableLayoutPanel
$main.Dock = 'Fill'
$main.ColumnCount = 1
$main.RowCount = 6
$main.Padding = New-Object System.Windows.Forms.Padding(12)
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 78)))
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 34)))
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 24)))
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 54)))
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 52)))
[void]$main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 42)))
$form.Controls.Add($main)

$topPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$topPanel.Dock = 'Fill'
$topPanel.FlowDirection = 'LeftToRight'
$topPanel.WrapContents = $false

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = 'Refresh cameras'
$refreshButton.Width = 118
$refreshButton.Height = 30
$refreshButton.Add_Click({ Refresh-Cameras -RepairSelectedInputs })

$openButton = New-Object System.Windows.Forms.Button
$openButton.Text = 'Open OBS windows'
$openButton.Width = 130
$openButton.Height = 30
$openButton.Add_Click({
    try {
        foreach ($instance in Get-ThreeCameraInstances) {
            Start-ThreeCameraOBSInstance -Instance $instance
        }
        Set-StatusText (Get-UiText -Key 'RequestedObs')
    }
    catch {
        Set-StatusText (Get-UiText -Key 'OpenObsFailedFormat' -FormatArgs @($_.Exception.Message))
    }
})

$fixBlackButton = New-Object System.Windows.Forms.Button
$fixBlackButton.Text = 'Fix black screen'
$fixBlackButton.Width = 122
$fixBlackButton.Height = 30
$fixBlackButton.Add_Click({ Repair-SelectedCameraInputs })

$restartObsButton = New-Object System.Windows.Forms.Button
$restartObsButton.Text = 'Restart OBS'
$restartObsButton.Width = 100
$restartObsButton.Height = 30
$restartObsButton.Add_Click({ Restart-GuiOBSWindows })

$emergencyButton = New-Object System.Windows.Forms.Button
$emergencyButton.Text = 'Emergency stop'
$emergencyButton.Width = 110
$emergencyButton.Height = 30
$emergencyButton.Add_Click({
    if ([System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'EmergencyConfirm'), 'ThreeCameraOBS', 'YesNo') -eq [System.Windows.Forms.DialogResult]::Yes) {
        Stop-ThreeCameraOBSProcesses -Force
        $script:IsRecording = $false
        $startButton.Enabled = $true
        $stopButton.Enabled = $false
        $refreshButton.Enabled = $true
        $activePath = Get-ThreeCameraActiveRecordingPath
        if (Test-Path -LiteralPath $activePath) {
            Remove-Item -LiteralPath $activePath -Force
        }
        Set-StatusText (Get-UiText -Key 'EmergencyDone')
    }
})

$languageLabel = New-Object System.Windows.Forms.Label
$languageLabel.Text = 'Language'
$languageLabel.AutoSize = $true
$languageLabel.Margin = New-Object System.Windows.Forms.Padding(10, 7, 2, 0)

$languageBox = New-Object System.Windows.Forms.ComboBox
$languageBox.DropDownStyle = 'DropDownList'
$languageBox.Width = 86
[void]$languageBox.Items.Add('English')
[void]$languageBox.Items.Add('Chinese')
$languageBox.SelectedIndex = 0
$languageBox.Add_SelectedIndexChanged({
    if ($script:ApplyingLanguage) {
        return
    }
    if ($languageBox.SelectedIndex -eq 1) {
        $script:Language = 'zh'
    }
    else {
        $script:Language = 'en'
    }
    Apply-Language
    Save-GuiConfig
})

[void]$topPanel.Controls.Add($refreshButton)
[void]$topPanel.Controls.Add($openButton)
[void]$topPanel.Controls.Add($fixBlackButton)
[void]$topPanel.Controls.Add($restartObsButton)
[void]$topPanel.Controls.Add($emergencyButton)
[void]$topPanel.Controls.Add($languageLabel)
[void]$topPanel.Controls.Add($languageBox)
[void]$main.Controls.Add($topPanel, 0, 0)

$cameraGroup = New-Object System.Windows.Forms.GroupBox
$cameraGroup.Text = Get-UiText -Key 'AvailableCameras'
$cameraGroup.Dock = 'Fill'
$cameraPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$cameraPanel.Dock = 'Fill'
$cameraPanel.FlowDirection = 'TopDown'
$cameraPanel.WrapContents = $false
$cameraPanel.AutoScroll = $true
$cameraGroup.Controls.Add($cameraPanel)
[void]$main.Controls.Add($cameraGroup, 0, 1)

$outputGroup = New-Object System.Windows.Forms.GroupBox
$outputGroup.Text = Get-UiText -Key 'OutputFolders'
$outputGroup.Dock = 'Fill'
$outputPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$outputPanel.Dock = 'Fill'
$outputPanel.FlowDirection = 'TopDown'
$outputPanel.WrapContents = $false
$outputPanel.AutoScroll = $true
$outputGroup.Controls.Add($outputPanel)
[void]$main.Controls.Add($outputGroup, 0, 2)

$capturePanel = New-Object System.Windows.Forms.TableLayoutPanel
$capturePanel.Dock = 'Fill'
$capturePanel.ColumnCount = 7
$capturePanel.RowCount = 1
[void]$capturePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 58)))
[void]$capturePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 88)))
[void]$capturePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 72)))
[void]$capturePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$capturePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 48)))
[void]$capturePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 78)))
[void]$capturePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 190)))

$personLabel = New-Object System.Windows.Forms.Label
$personLabel.Text = Get-UiText -Key 'Person'
$personLabel.TextAlign = 'MiddleLeft'
$personLabel.Dock = 'Fill'
$personBox = New-Object System.Windows.Forms.NumericUpDown
$personBox.Minimum = 1
$personBox.Maximum = 999
$personBox.Dock = 'Fill'

$categoryLabel = New-Object System.Windows.Forms.Label
$categoryLabel.Text = Get-UiText -Key 'Category'
$categoryLabel.TextAlign = 'MiddleLeft'
$categoryLabel.Dock = 'Fill'
$categoryBox = New-Object System.Windows.Forms.TextBox
$categoryBox.Dock = 'Fill'
$categoryBox.Text = 'default'
$categoryBox.Add_Leave({ Save-GuiConfig })

$takeLabel = New-Object System.Windows.Forms.Label
$takeLabel.Text = Get-UiText -Key 'Take'
$takeLabel.TextAlign = 'MiddleLeft'
$takeLabel.Dock = 'Fill'
$takeBox = New-Object System.Windows.Forms.NumericUpDown
$takeBox.Minimum = 1
$takeBox.Maximum = 999
$takeBox.Dock = 'Fill'

$advanceCheck = New-Object System.Windows.Forms.CheckBox
$advanceCheck.Text = Get-UiText -Key 'AdvanceProgress'
$advanceCheck.AutoSize = $true
$advanceCheck.Checked = $true
$advanceCheck.Margin = New-Object System.Windows.Forms.Padding(12, 7, 4, 4)

[void]$capturePanel.Controls.Add($personLabel, 0, 0)
[void]$capturePanel.Controls.Add($personBox, 1, 0)
[void]$capturePanel.Controls.Add($categoryLabel, 2, 0)
[void]$capturePanel.Controls.Add($categoryBox, 3, 0)
[void]$capturePanel.Controls.Add($takeLabel, 4, 0)
[void]$capturePanel.Controls.Add($takeBox, 5, 0)
[void]$capturePanel.Controls.Add($advanceCheck, 6, 0)
[void]$main.Controls.Add($capturePanel, 0, 3)

$recordPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$recordPanel.Dock = 'Fill'
$recordPanel.FlowDirection = 'LeftToRight'
$recordPanel.WrapContents = $false

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = Get-UiText -Key 'StartRecording'
$startButton.Width = 118
$startButton.Height = 34
$startButton.Add_Click({ Start-GuiRecording })

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = Get-UiText -Key 'StopRecording'
$stopButton.Width = 118
$stopButton.Height = 34
$stopButton.Enabled = $false
$stopButton.Add_Click({ Stop-GuiRecording })

$openOutputButton = New-Object System.Windows.Forms.Button
$openOutputButton.Text = Get-UiText -Key 'OpenOutput'
$openOutputButton.Width = 128
$openOutputButton.Height = 34
$openOutputButton.Add_Click({
    $folders = @()
    foreach ($row in @($script:OutputRows)) {
        if (-not [string]::IsNullOrWhiteSpace($row.TextBox.Text)) {
            $folders += [string]$row.TextBox.Text
        }
    }
    if ($folders.Count -eq 0) {
        $folders = @(Get-ThreeCameraOutputDir)
    }
    foreach ($folder in ($folders | Select-Object -Unique)) {
        New-DirectoryIfMissing -Path $folder
        Start-Process -FilePath explorer.exe -ArgumentList "`"$folder`""
    }
})

$moveLastButton = New-Object System.Windows.Forms.Button
$moveLastButton.Text = Get-UiText -Key 'MoveLastFiles'
$moveLastButton.Width = 118
$moveLastButton.Height = 34
$moveLastButton.Add_Click({ Move-LastFilesToSelectedFolders })

[void]$recordPanel.Controls.Add($startButton)
[void]$recordPanel.Controls.Add($stopButton)
[void]$recordPanel.Controls.Add($openOutputButton)
[void]$recordPanel.Controls.Add($moveLastButton)
[void]$main.Controls.Add($recordPanel, 0, 4)

$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Dock = 'Fill'
$statusBox.Multiline = $true
$statusBox.ScrollBars = 'Vertical'
$statusBox.ReadOnly = $true
[void]$main.Controls.Add($statusBox, 0, 5)

$form.Add_FormClosing({
    if ($script:IsRecording) {
        $result = [System.Windows.Forms.MessageBox]::Show((Get-UiText -Key 'CloseActive'), 'ThreeCameraOBS', 'YesNoCancel')
        if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
            $_.Cancel = $true
            return
        }
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Stop-GuiRecording
        }
    }
})

$config = Load-GuiConfig
if ($config -and $config.language) {
    $savedLanguage = [string]$config.language
    if ($savedLanguage -in @('en', 'zh')) {
        $script:Language = $savedLanguage
    }
}
Update-ProgressControls
if ($config) {
    try {
        if ($config.person) {
            $personBox.Value = [decimal]([int]$config.person)
        }
        if ($config.category) {
            $categoryBox.Text = [string]$config.category
        }
        if ($config.take) {
            $takeBox.Value = [decimal]([int]$config.take)
        }
        if ($null -ne $config.advanceProgress) {
            $advanceCheck.Checked = [bool]$config.advanceProgress
        }
    }
    catch {
    }
}

if ($script:Language -eq 'zh') {
    $languageBox.SelectedIndex = 1
}
else {
    $languageBox.SelectedIndex = 0
}
Apply-Language
Refresh-Cameras
[void]$form.ShowDialog()
