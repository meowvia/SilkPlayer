# SilkPlayer 1.6.0 版本更新说明 / Release Notes

## 版本概括 / Overview

SilkPlayer 1.6.0 重构了偏好设置界面，新增窗口拖拽实时尺寸指示与右键缩放预设，优化了 HDR 动态高光映射与跳转性能，并支持端内检查更新。
SilkPlayer 1.6.0 introduces a redesigned Settings window, live window resize dimension HUD, context menu window size presets, improved HDR highlight tone-mapping and seek performance, and built-in update checking.

---

## 核心特性 / Key Features

- 偏好设置重构 / Redesigned Settings:
  按 macOS 原生规范整合为通用、播放、关于三个标签页，新增启动视窗行为与播放历史开关。
  Consolidated into General, Playback, and About tabs per macOS standards, adding startup window options and a playback history toggle.

- 窗口尺寸指示与右键预设 / Resize Dimensions & Presets:
  拖拽窗口实时显示当前分辨率与画幅比例；视频右键菜单新增 50%、75%、100% 窗口预设。
  Displays live resolution and aspect ratio during window resize; added 50%, 75%, and 100% window size presets to the video right-click menu.

- HDR 高光与渲染优化 / HDR Highlights & Rendering:
  优化 HDR10 与杜比视界动态高光映射，减少过曝发白；优化跳转缓冲机制，减少画面闪回。
  Enhanced dynamic highlight tone-mapping for HDR10 and Dolby Vision to reduce highlight clipping; optimized seek buffering to eliminate frame flashback.

- 检查更新 / Check for Updates:
  支持关于面板手动检查与后台低频检测，支持端内直接下载升级。
  Added manual update checks in the About tab and quiet background release checks, with in-place download and upgrade support.

- 界面细节优化 / Interface Refinements:
  播放列表侧边拉手改用贴边透明细线框；窄窗口下采用垂直弹出音量条防遮挡；清理顶栏重复的窗口菜单项。
  Redesigned the playlist drawer handle as a border-flush transparent wireframe; adopted a vertical popover volume slider on narrow windows; merged duplicate Window menu items.

---

## 系统要求 / Requirements

- 操作系统 / OS: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- 芯片架构 / Architecture: Universal 通用二进制（原生支持 Apple Silicon 与 Intel 64 位芯片）/ Universal Binary (Apple Silicon & Intel 64-bit)
- 图形显示 / Graphics: 支持 Metal 硬件加速与 HDR / EDR 显示 / Metal hardware acceleration & HDR / EDR display supported

---

## 安装方式 / Installation

1. 打开 SilkPlayer-1.6.0-universal.dmg 镜像。
   Open the SilkPlayer-1.6.0-universal.dmg image.
2. 将 SilkPlayer.app 拖入 Applications（应用程序）文件夹即可完成安装或覆盖。
   Drag SilkPlayer.app into the Applications folder to install or update.
