# SilkPlayer 1.6.0 版本更新说明 / Release Notes

SilkPlayer 1.6.0 带来了全新设计的偏好设置窗口、窗口拉伸实时尺寸提示、HDR 动态高光映射优化，并修复了播放进度记忆失效的问题。
SilkPlayer 1.6.0 introduces a redesigned Settings panel, live window resize dimensions, improved HDR highlight tone-mapping, and fixes for playback progress retention.

---

## 核心特性 / Key Features

- **窗口拉伸实时尺寸与画幅比例 / Live Window Resize Dimensions**:
  - 拖拽调整窗口大小时，在窗口顶部居中实时显示当前分辨率（如 `1920 × 1080`）与标准画幅比例（`16:9`、`4:3`、`21:9` 等）；达到片源原始尺寸时显示 `100%` 标识。
  - Shows live window dimensions and standard aspect ratios at the top-center of the window while resizing, with a `100%` badge when matching the video's native resolution.
- **重构偏好设置窗口 / Redesigned Settings**:
  - 重新梳理设置为「通用」、「播放」、「关于」三个面板，界面布局更符合 macOS 原生风格。
  - 新增全屏时钟悬浮、截图格式与存储路径选择、快进快退步长调节以及鼠标滚轮行为配置。
  - Reorganized preferences into General, Playback, and About tabs with a cleaner macOS layout. Added options for fullscreen clock, screenshot format/path, seek intervals, and mouse wheel actions.
- **播放进度记忆与播放列表模式 / Playback Resume & Playlist Modes**:
  - 修复重新打开视频或重启应用时无法恢复上次播放进度的问题。
  - 在设置中提供「单播放列表」与「双播放列表（连续剧与独立影片分流）」两种管理模式。
  - Fixed an issue where playback position was lost after restarting the app. Added an option in Settings to switch between Single Playlist and Dual Playlist modes.
- **HDR 高光渲染优化 / Improved HDR Highlights**:
  - 优化 HDR10 与杜比视界在高光区域的色彩映射，根据显示器实际亮度动态压缩高光细节，减少过曝发白现象。
  - Improved highlight tone-mapping for HDR10 and Dolby Vision based on screen headroom, preserving details in bright scenes.
- **播放列表侧边拉手改进 / Refined Playlist Handle**:
  - 播放列表拉手改用透明细线框并紧贴窗口边缘，减少对画面的遮挡。
  - Redesigned the drawer handle with a subtle transparent outline flush with the window edge to reduce video obstruction.
- **检查更新 / Check for Updates**:
  - 在「关于」面板中支持手动检查新版本，并支持在后台低频检测 GitHub 发布状态。
  - Added manual update checking in the About tab and quiet periodic background release checks.

---

## 系统要求 / Requirements

- **操作系统 / OS**: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- **芯片架构 / Architecture**: Apple Silicon (M 系列芯片) 与 Intel 64 位芯片 (Universal Binary) / Apple Silicon & Intel 64-bit

---

## 安装方式 / Installation

1. 下载并打开 `SilkPlayer-1.6.0-universal.dmg`；
   Download and open `SilkPlayer-1.6.0-universal.dmg`;
2. 将 `SilkPlayer.app` 拖入 `Applications`（应用程序）文件夹即可完成安装；
   Drag `SilkPlayer.app` into your Applications folder;
3. 首次启动若提示未签名，可在「系统设置」->「隐私与安全性」中选择「仍要打开」。
   If prompted by Gatekeeper on first launch, click "Open Anyway" in System Settings -> Privacy & Security.
