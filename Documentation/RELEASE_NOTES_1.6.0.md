# SilkPlayer 1.6.0 版本更新说明 / Release Notes

## 版本概括 / Overview

基于 1.5.1 版本，SilkPlayer 1.6.0 新增偏好设置界面重构、窗口拉伸实时尺寸提示、右键窗口大小预设、HDR 动态高光映射与跳转稳定性优化以及内置版本检查更新，并统一优化了竖屏与窄窗口下的交互布局。
Building on version 1.5.1, SilkPlayer 1.6.0 introduces a redesigned Settings window, live window resize dimensions, context menu window size presets, improved HDR highlight tone-mapping and seek stability, and built-in update checking, along with refined layouts for portrait and narrow windows.

---

## 核心特性 / Key Features

- **偏好设置界面重构 / Redesigned Settings Window**:
  - 将原有设置整合为「通用」、「播放」、「关于」三个标签页，采用 520 × 490 pt 固定窗口布局，精简次级开关，在「通用」中提供启动视窗行为选项，并在「播放」中新增媒体播放历史保留开关。
  - Consolidated Settings into General, Playback, and About tabs in a fixed 520 × 490 pt layout, streamlined redundant toggles, added Startup Window behavior options in General, and added a Playback History retention toggle under Playback.
- **窗口拉伸实时尺寸与右键大小预设 / Live Resize Dimensions & Context Menu Presets**:
  - 拖拽调整窗口边缘时，在窗口顶部居中实时显示当前像素尺寸（如 `1920 × 1080`）与标准画幅比例（`16:9`、`4:3`、`21:9`、`2.39:1` 等），匹配片源原始分辨率时显示 `100%` 标识。
  - Displays live pixel dimensions and standard aspect ratios at the top-center of the window while resizing, with a `100%` badge when matching native video resolution.
  - 视频画面右键新增「窗口大小」子菜单，提供 `50%`、`75%`、`100%` 与「恢复默认」选项，在桌面可用区内保持原片长宽比缩放且不裁切画面与字幕。
  - Added a `Window Size` right-click submenu (`50%`, `75%`, `100%`, and `Reset to Default`) to scale windows inside the desktop visible area without cropping frames or subtitles.
- **HDR 动态高光映射与渲染优化 / Improved HDR Highlights & Core Stability**:
  - 优化 HDR10 与杜比视界在高光区域的动态色调映射，结合显示器 EDR 余量平滑压缩高光细节，减少过曝发白。
  - Improved dynamic highlight tone-mapping for HDR10 and Dolby Vision using display EDR headroom to preserve highlight details.
  - 优化底层解码缓冲大小与跳转时的纹理缓存清理策略，减少拖拽跳转时的画面闪回与卡顿。
  - Improved demuxer buffer sizing and texture cache flushing during seeks to reduce frame flashback and stuttering.
- **检查更新与端内升级 / Check for Updates & In-Place Upgrades**:
  - 新增启动后台版本检测与「关于」面板手动检查更新，支持 7 天静默提醒周期、更新红点标记以及在位下载替换升级（保留历史记录与偏好设置）。
  - Added startup background and manual release checks in About with a 7-day snooze period, badge indicator, and in-place upgrades that preserve user history and preferences.
- **界面交互与菜单优化 / Interface & Menu Refinements**:
  - 播放列表侧边拉手改为透明三边细线框并紧贴窗口边缘，减少对视频画面的遮挡。
  - Redesigned the playlist drawer handle as a border-flush transparent outline to reduce video obstruction.
  - 优化音乐模式及竖屏/窄窗口底栏控制布局：纯音频模式仅保留核心控制入口；窄窗口下通过纵向弹出音量条及精简间距，避免调节音量时遮挡「下一首」按钮。
  - Streamlined bottom HUD controls for music mode and portrait/narrow windows, using a vertical volume popover on narrow windows so volume adjustments stay clear of the Next button.
  - 将媒体检查器、播放列表与置顶控制并入系统标准「窗口」菜单，消除菜单栏重复的「窗口」项。
  - Merged Media Inspector, Playlist, and Float on Top controls into the native macOS Window menu, eliminating the duplicate Window menu bar item.

---

## 系统要求 / Requirements

- **操作系统 / OS**: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- **芯片架构 / Architecture**: Universal 通用二进制，原生支持 Apple Silicon 与 Intel 64 位芯片 / Universal Binary supporting Apple Silicon and Intel 64-bit natively
- **图形显示 / Graphics**: 支持 Metal 硬件加速与 HDR / EDR 显示 / Metal hardware acceleration & HDR / EDR display support

---

## 安装方式 / Installation

1. 下载并打开 `SilkPlayer-1.6.0-universal.dmg`；
   Download and open `SilkPlayer-1.6.0-universal.dmg`;
2. 将 `SilkPlayer.app` 拖入 `Applications`（应用程序）文件夹即可完成安装；
   Drag `SilkPlayer.app` into your `Applications` folder;
3. 首次启动若触发系统安全提示，可在「系统设置」->「隐私与安全性」中选择「仍要打开」。
   If prompted by macOS Gatekeeper on first launch, click "Open Anyway" in System Settings -> Privacy & Security.
