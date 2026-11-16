# SilkPlayer 1.7.0 版本更新说明 / Release Notes

## 版本概括 / Overview

SilkPlayer 1.7.0 带来了更通透纯净的影院级无边框浮动播控栏，在抽屉播放列表中新增 ⌘F 即时搜索与拼音首字母过滤，支持子目录外挂字幕递归识别，并全面编入 DTS-CD 等全格式高清音频解复用与软限幅防护；同时彻底修复了多显示器全屏播放时副屏光标误唤醒，以及退出播放竖屏媒体时视窗纵横比恢复异常的问题。
SilkPlayer 1.7.0 introduces an edge-to-edge floating cinema HUD, adds ⌘F instant search and Pinyin filtering to the playlist drawer, enables recursive companion subtitle discovery across subdirectories, and integrates full-format high-definition audio demuxing with soft-knee limiting for DTS-CD tracks. It also resolves secondary display cursor wakeups during fullscreen playback and fixes window aspect ratio restoration issues after closing vertical media.

---

## 核心特性 / Key Features

- 影院级纯透明悬浮播控栏 / Floating Cinema HUD:
  彻底移除底栏时间轴与控制区原有的深灰半透明渐变衬底，转为纯净悬浮形态，消除遮挡，提升视觉通透感。
  Eliminated the translucent dark gradient backing beneath the scrubber and transport controls, transitioning to a clean floating HUD with natural shadows for an unoccluded viewing experience.

- 播放列表 ⌘F 即时搜索与拼音过滤 / Instant Search & Pinyin Matching:
  右侧边栏播放列表支持按 ⌘F 呼出搜索栏，支持全拼、拼音首字母简拼（如输入 "zwy" 匹配《钟无艳》）与不区分大小写的模糊搜索。
  Added ⌘F instant search to the playlist drawer, supporting full Pinyin, Pinyin initials, and case-insensitive fuzzy filtering for rapid track location.

- 外挂字幕子目录递归索引 / Recursive Subtitle Search:
  外挂同名字幕自动挂载逻辑扩展至媒体所在目录的 Subs、subtitles、Sub 等子文件夹，支持 ASS、SSA、SRT、VTT、SUB 等常用格式。
  Expanded companion subtitle detection to scan nested Subs, subtitles, and Sub subdirectories for matching ASS, SSA, SRT, VTT, and SUB subtitles.

- 高清音频解复用与下混软限幅 / HD Audio Demuxing & Limiter:
  编入支持 DTS、DTS-HD MA、Dolby TrueHD 的 Universal FFmpeg 编解码库，引入防削顶软限幅器，确保 DTS-CD 等多声道音源在双声道设备上平顺下混无爆音。
  Embedded Universal FFmpeg libraries with full DTS, DTS-HD MA, and Dolby TrueHD demuxers, paired with a soft-knee limiter to prevent clipping and popping when downmixing multichannel audio to stereo output.

- 视窗快甩拖拽跟踪与清空防误触 / Interaction Refinements:
  优化画面拖拽启动阈值至 4.0pt 并直通原生拖拽链，消除快甩拖动视窗时的初始粘滞感；播放列表清空按钮加入 3 秒二次确认防误触机制。
  Tuned window dragging threshold to 4.0pt with native event forwarding to eliminate initial grab latency; introduced a 3-second two-step confirmation timeout on the playlist clear button.

---

## 问题修复 / Bug Fixes

- 修复多显示器扩展屏全屏播放时，在副屏或外部桌面移动鼠标误唤醒主屏控制栏与时间轴的问题（GitHub Issue #7）。
  Fixed an issue where moving the mouse cursor on secondary displays incorrectly woke the player HUD and timeline during fullscreen playback (GitHub Issue #7).

- 修复播放 9:16 等竖屏视频后关闭，播放器视窗残留在手机比例导致欢迎界面被严重挤压变形的问题，退出时自动平滑居中复位为标准 16:9 横屏视窗（GitHub Issue #9）。
  Fixed an issue where closing a portrait video left the window in a narrow smartphone aspect ratio, automatically restoring a centered 16:9 desktop frame on playback close (GitHub Issue #9).

- 修复标准双声道 PCM WAV 音频流转期因随机波形采样触发假阳性误判重置解码器、导致持续尖锐高频啸叫的缺陷。
  Resolved a decoder reset flaw triggered by false-positive stream sniffing on standard PCM WAV tracks, eliminating high-frequency distortion during playback and scrubbing.

- 修复冷启动受 macOS 系统平铺记忆影响导致播放器异常铺满屏幕的问题，冷启动强制按标准横向窗口居中呈现。
  Prevented macOS window tiling persistence from expanding cold-launched windows to full screen, ensuring a centered standard desktop launch frame.

---

## 系统要求 / Requirements

- 操作系统 / OS: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- 芯片架构 / Architecture: Universal 通用二进制（原生支持 Apple Silicon 与 Intel 64 位芯片）/ Universal Binary (Apple Silicon & Intel 64-bit)
- 图形显示 / Graphics: 支持 Metal 硬件加速与 HDR / EDR 显示 / Metal hardware acceleration & HDR / EDR display supported

---

## 安装方式 / Installation

1. 打开 SilkPlayer-1.7.0-universal.dmg 镜像。
   Open the SilkPlayer-1.7.0-universal.dmg image.
2. 将 SilkPlayer.app 拖入 Applications（应用程序）文件夹即可完成安装或覆盖。
   Drag SilkPlayer.app into the Applications folder to install or update.
