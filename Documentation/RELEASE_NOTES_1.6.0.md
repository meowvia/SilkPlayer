# SilkPlayer 1.6.0 版本更新说明 / Release Notes

## 版本概括 / Overview

SilkPlayer 1.6.0 新增偏好设置界面重构、窗口拉伸实时尺寸提示、HDR 动态高光映射优化、右键窗口比例预设及 Universal 通用镜像更新支持，并修复了菜单栏与窄窗口底栏控件布局问题。
SilkPlayer 1.6.0 introduces a redesigned Settings interface, live window resize dimensions, improved HDR highlight tone-mapping, context menu window size presets, and Universal update support, along with menu bar and narrow-window control fixes.

---

## 核心特性 / Key Features

- **窗口拉伸实时尺寸与画幅比例 / Live Window Resize Dimensions**:
  - 拖拽调整窗口大小时，在光标附近实时显示当前像素尺寸（如 `1920 × 1080`）与标准画幅比例（`16:9`、`4:3`、`21:9` 等）；匹配片源原始分辨率时显示 `100%` 标识。
  - Displays live pixel dimensions and standard aspect ratios near the cursor while resizing, showing a `100%` badge when matching the video's native resolution.
- **视频右键窗口大小预设 / Context Menu Window Size Presets**:
  - 视频画面右键「窗口大小」子菜单提供 `50%`、`75%`、`100%` 与「恢复默认」选项；基于当前视频长宽比与桌面可用区自动贴合边缘且不裁切画面与字幕，已达当前档位或越界方向自动置灰，全屏、纯音频或无媒体时自动禁用。
  - Added a `Window Size` right-click submenu (`50%`, `75%`, `100%`, `Reset to Default`) that fits the video aspect ratio inside the desktop visible area without cropping frames or subtitles, with boundary item gating and automatic disablement in fullscreen, audio-only, or unloaded states.
- **重构偏好设置窗口 / Redesigned Settings**:
  - 将设置整合为「通用」、「播放」、「关于」三个标签页（520 × 490 pt 固定布局），新增全屏时钟显示、截图格式与存储路径选择、快进快退步长调节及鼠标滚轮行为配置。
  - Consolidated preferences into General, Playback, and About tabs (fixed 520 × 490 pt layout), adding a fullscreen clock overlay, screenshot format and path options, seek interval settings, and mouse wheel actions.
- **HDR 高光渲染优化 / Improved HDR Highlights**:
  - 优化 HDR10 与杜比视界在高光区域的动态色调映射，基于屏幕实际 EDR 余量平滑压缩高光细节，减少过曝发白。
  - Improved dynamic highlight tone-mapping for HDR10 and Dolby Vision based on screen EDR headroom to preserve bright scene details.
- **播放列表侧边拉手改进 / Refined Playlist Handle**:
  - 播放列表侧边拉手改用透明细线框并紧贴窗口边缘，减少对画面的遮挡。
  - Redesigned the playlist drawer handle with a transparent three-sided outline flush against the window edge to minimize video obstruction.
- **检查更新与端内升级 / Check for Updates & In-Place Upgrades**:
  - 支持冷启动低频后台检测与在「关于」面板手动检查 GitHub 新版本；确认更新后自动下载 Universal 通用镜像并在位无损替换应用，保留历史记录与偏好配置。
  - Added quiet cold-start and manual release checks in About, downloading the Universal DMG image for lossless in-place upgrades while preserving history and preferences.
- **界面与菜单栏修复 / Interface & Menu Bar Fixes**:
  - 合并顶部菜单栏重复「窗口」条目并移除失效尺寸菜单；修复竖屏与极窄窗口下底栏音量滑块与「下一首」按钮重叠的问题，并在溢出菜单补充静音入口。
  - Consolidated duplicate top Window menu items and removed the redundant size menu; fixed bottom volume slider overlap with the Next button in narrow/portrait windows and added mute to the overflow menu.

---

## 系统要求 / Requirements

- **操作系统 / OS**: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- **芯片架构 / Architecture**: Universal 通用二进制，原生支持 Apple Silicon 与 Intel 64 位芯片 / Universal Binary supporting Apple Silicon and Intel 64-bit natively
- **图形显示 / Graphics**: 支持 Metal 硬件加速与 HDR / EDR 显示 / Metal hardware acceleration & HDR / EDR display support

---

## 安装方式 / Installation

1. 下载并打开通用安装包 `SilkPlayer-1.6.0-universal.dmg`；
   Download and open `SilkPlayer-1.6.0-universal.dmg`;
2. 将 `SilkPlayer.app` 拖入 `Applications`（应用程序）文件夹即可完成安装；
   Drag `SilkPlayer.app` into your `Applications` folder;
3. 首次启动若提示未签名，可在「系统设置」->「隐私与安全性」中选择「仍要打开」。
   If prompted by Gatekeeper on first launch, click "Open Anyway" in System Settings -> Privacy & Security.
