# ThreeCameraOBS 使用说明

用途：用 OBS 同时录制多个摄像头。主入口是图形化窗口，可以勾选当前 OBS 能识别的摄像头，并给每一路单独选择保存文件夹。

## 首次使用、搬家或换电脑后

先双击：

```text
Rebuild-ThreeCameraOBS.ps1
```

它会按当前项目目录重新生成：

- `instances\camera*` 下的 OBS 便携实例配置
- 项目目录里的 `ThreeCameraOBS-*.lnk`
- 桌面上的 `ThreeCameraOBS-*.lnk`

完成后再双击：

```text
ThreeCameraOBS-Preflight.lnk
```

预检会确认快捷方式、OBS 实例配置、websocket 端口和输出目录都指向当前项目/当前用户环境。

如果是刚从 GitHub 拉下来的项目，先安装依赖：

```powershell
npm install
```

然后运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Rebuild-ThreeCameraOBS.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Preflight-Check.ps1
```

项目不会提交本机生成的 `instances`、`state`、`.lnk`、OBS 日志、摄像头绑定信息或 `node_modules`。这些内容都由重建脚本在本机重新生成。

上传 GitHub 前可以运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Clean-ForGitHub.ps1
```

它只清理项目目录里的本机生成内容，不会删除桌面快捷方式。

## 推荐入口

日常录制双击：

```text
ThreeCameraOBS-GUI.lnk
```

窗口里可以做这些事：

- `Language`：切换 English / 中文，选择会自动保存。
- `刷新摄像头`：重新读取当前可用摄像头。
- 勾选摄像头：可选择任意数量，程序会自动创建对应 OBS 实例。
- `保存文件夹`：每个机位都可以选择自己的输出目录。
- `人员 / 类别 / Take`：决定文件名前缀；类别由你手动填写。
- `开始录制` / `停止录制`：同时控制所选摄像头。
- `打开保存位置`：打开当前设置的输出目录。
- `修复黑屏 / Fix black screen`：摄像头插拔后画面黑屏时，先勾选对应摄像头，再点这个按钮。
- `重启 OBS / Restart OBS`：如果修复黑屏仍无效，停止录制后重启 OBS 窗口。
- `应急停止`：强制停止这套 OBS 进程。

默认输出目录是：

```text
%USERPROFILE%\Desktop\mm
```

如果在 GUI 里给某一路选择了别的文件夹，之后会优先保存到你选择的文件夹。

## 文件命名

示例：

```text
P01_customCategory_T1_20260703_141500_cam1.mp4
P01_customCategory_T1_20260703_141500_cam2.mp4
P01_customCategory_T1_20260703_141500_cam3.mp4
```

格式：

```text
P<人员编号>_<你填写的类别>_T<Take>_<时间>_cam<机位>.mp4
```

## 维护和清理

双击：

```text
ThreeCameraOBS-Optimize.lnk
```

它会删除冗余文件，并把所有 OBS 实例的 `bin`、`data`、`obs-plugins` 改成指向系统 OBS 的目录联接。它不会删除 OBS 配置，也不会删除录制视频。

## 备用入口

- `ThreeCameraOBS-OpenWindows.lnk`：打开 OBS 窗口检查画面。
- `ThreeCameraOBS-Preflight.lnk`：检查 OBS、Node 依赖、快捷方式和实例配置。
- `ThreeCameraOBS-Optimize.lnk`：清理冗余文件并修复 OBS 实例目录联接。
- `ThreeCameraOBS-EmergencyStop.lnk`：应急停止 OBS 进程。
