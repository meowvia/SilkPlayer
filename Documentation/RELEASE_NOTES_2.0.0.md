# SilkPlayer 2.0.0 版本更新说明 / Release Notes

## 版本概括 / Overview

SilkPlayer 2.0.0 是自项目发布以来规模最大的里程碑更新，标志着播放器正式迈入全新的 2.x 时代。

本次版本核心聚焦专业版（Pro Edition）的全面功能跃升，重磅引入了面向局域网与本地存储的影视媒体库系统，支持局域网服务快速自动发现、影视媒体智能识别与快速配置整理；同时深度打造了专属独立音频播放器，提供两段式自由折叠播放模式与全格式高清无损音频回放优化。

关于免费版（Standard Edition）：随着大版本更新，免费版的基础播放功能不会被阉割、仍将持续保持免费开放，免费版本的现有功能仍将在未来一段时间内继续维护。如果喜欢 SilkPlayer，可以选择升级解锁 Pro，这对开发者将是极大的激励与支持。

SilkPlayer 2.0.0 marks the largest milestone update since the project's inception, advancing the player into the new 2.x era.

This release focuses on delivering a comprehensive feature leap for the Pro Edition, introducing a LAN and local media library system with rapid auto-discovery of network shares, intelligent media identification, and effortless library configuration. Simultaneously, it debuts a dedicated independent audio player featuring a collapsible two-stage interface and playback optimizations for all lossless HD audio formats.

Regarding the Standard (Free) Edition: Across this major release, core playback features remain uncompromised and permanently free, with existing capabilities continuously maintained. If you enjoy SilkPlayer, upgrading to unlock Pro provides tremendous encouragement and support for ongoing development.

---

## 专业版核心特性 / Pro Edition Features

### 1. 原生局域网与本地影视媒体库 / Native LAN & Local Media Library
- **极速配置与免挂载网络服务自动发现 (Rapid Setup & Zero-Config Auto Discovery)**:
  内置原生局域网协议栈，无需在系统访达中手动挂载磁盘，即可自动扫描发现局域网内的存储设备（全面支持 SMB 2/3 与 NFS 协议），实现局域网与本地媒体资源整合、极速播放。
  Built-in native network protocol stack automatically discovers storage devices across local shares (fully supporting SMB 2/3 and NFS) without manual Finder mounting, unifying LAN and local media for instantaneous streaming.
- **影视剧集智能识别与结构化整理 (Intelligent Media Indexing & Organization)**:
  自动解析媒体文件名与目录层级，智能提取剧集季数、集数等元数据，将多季剧集自动归拢为结构化统一卡片，告别零散杂乱的文件列表。
  Automatically parses filenames and directory hierarchies to extract seasons and episode metadata, grouping multi-season series into structured unified cards and replacing cluttered file listings.
- **在架切集抽屉与全集进度管理 (Episode Drawer & Playback Progress)**:
  点击剧集卡片即可在右侧展开切集抽屉，清晰浏览全季分集列表；自动记忆每一集的独立播放进度与断点位置，支持本地与 iCloud 云端进度无缝同步。
  Clicking any media card opens a side drawer displaying the complete episode catalog; automatically remembers playback checkpoints per episode with seamless local and iCloud cloud progress sync.
- **外挂字幕与多音轨自动关联 (Companion Subtitle & Audio Track Matching)**:
  针对影视文件自动建立同名字幕与多语言音轨关联，配合高速流式缓冲引擎，让局域网 4K HDR 大码率影视播放即点即播。
  Automatically associates companion subtitles and multilingual audio tracks, backed by a high-throughput streaming buffer for buffer-free local 4K HDR playback.

### 2. 独立音频播放器与全格式播放优化 / Dedicated Audio Player & Lossless Optimization
- **双形态自由折叠视窗 (Two-Stage Morphing Window)**:
  提供专属独立音乐播放界面，支持在极简小卡片与展开播放列表之间平滑折叠切换，贴合桌面随手摆放与多任务分屏需求。
  Offers a dedicated music window that smoothly toggles between a minimal compact card and an expanded playlist queue, tailored for desk placement and split-screen multitasking.
- **全格式无损高清音频回放 (Full-Format Lossless Playback & Multichannel LPCM)**:
  原生支持 FLAC、APE、WAV、DSD、DTS-CD、TrueHD 等各类高清无损音频格式解析；CoreAudio 渲染管线直接适配多声道 LPCM（5.1 / 7.1）离散直通输出，杜绝立体声强制压缩带来的空间声场损失。
  Native decoding for FLAC, APE, WAV, DSD, DTS-CD, and TrueHD; CoreAudio pipeline natively outputs discrete multichannel LPCM (5.1 / 7.1) without forced stereo downmixing, preserving spatial depth.
- **拟物黑胶与动态音频呼吸光环 (Acoustic Vinyl & Dynamic Visualizer)**:
  内置基于物理角速度模拟的匀速旋转黑胶视窗，联动音轨低频、中频与高频动态能量，实时驱动外层自适应声学光环。
  Features an inertia-simulated rotating vinyl disc coupled with a multi-band dynamic acoustic halo driven in real time by bass, mid, and treble audio levels.
- **菜单栏常驻微型播控与 Dock 零驻留 (Menu Bar Micro-Controller & Zero Dock Footprint)**:
  支持将音乐播放器一键隐匿至 macOS 顶部菜单栏，此时 SilkPlayer 就是一款沉浸式的本地音频播放器，彻底释放 Dock 栏空间；点击菜单栏图标即可原地呼出悬浮控制面板与歌词信息。
  Enables seamless minimization to the macOS menu bar, turning SilkPlayer into an immersive local audio player with zero Dock footprint; clicking the menu bar icon instantly reveals a lightweight floating playback capsule and lyrics.

### 3. 四色主题矩阵 / 4-Theme Color Matrix
- **全新 Pro 视觉主题 (New Pro Visual Theme)**:
  采用通透的 macOS 原生毛玻璃质感底板，呈现通透纯净的视觉观感。
  Engineered with native macOS vibrancy material, delivering an unoccluded, crystalline aesthetic.
- **全局色彩联动 (Global Aesthetic Alignment)**:
  提供深灰、冰蓝、暖白、青瓷 4 套高对比度主题，全局联动主界面、播放视窗、媒体库与偏好设置，无论深色还是浅色环境均能保持舒适清晰的阅读体验。
  Offers 4 high-contrast themes (Dark Gray, Ice Blue, Warm White, Celadon) synchronized across the main window, player HUD, media library, and Settings, ensuring legible viewing in both light and dark environments.

---

## 免费版说明 / Free Edition Notes

- **1.7.0 已就绪核心能力回顾 / 1.7.0 Key Capabilities Summary**:
  - 播放列表 ⌘F 即时搜索与中文拼音首字母过滤；
    Playlist ⌘F instant search with full Pinyin and initialism filtering;
  - 外挂字幕 Subs/ 多级子目录深度递归扫描挂载；
    Deep recursive scanning and mounting of companion subtitles in Subs/ subdirectories;
  - 影院级纯透明悬浮播控栏（彻底移除底栏深灰背景框）；
    Cinema-grade floating transparent HUD (eliminating dark background boxes);
  - DTS、DTS-HD、Dolby TrueHD 完整解复用与软限幅防削顶下混；
    Complete DTS, DTS-HD, and Dolby TrueHD demuxing with soft-knee limiter stereo downmixing;
  - 多屏扩展防光标误唤醒 (ISSUE-021)、竖屏比例自适应居中复位 (ISSUE-022) 与窗口平铺隔离 (ISSUE-018)。
    Multi-display cursor wake-up prevention (ISSUE-021), portrait aspect ratio auto-recentering (ISSUE-022), and window tiling isolation (ISSUE-018).

---

## 系统要求 / Requirements

- **操作系统 / OS**: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- **芯片架构 / Architecture**: Universal 通用二进制（原生支持 Apple Silicon M 系列与 Intel 64 位芯片）/ Universal Binary (Apple Silicon & Intel 64-bit)
- **图形显示 / Graphics**: 支持 Metal 硬件加速与 HDR / EDR 显示 / Metal hardware acceleration & HDR / EDR display supported

---

## 安装与授权 / Installation & Licensing

1. 打开 `SilkPlayer-2.0.0-universal.dmg` 镜像；
   Open the `SilkPlayer-2.0.0-universal.dmg` disk image.
2. 将 `SilkPlayer.app` 拖入 `Applications`（应用程序）文件夹即可完成安装或覆盖升级；
   Drag `SilkPlayer.app` into the Applications folder to install or upgrade.
3. 已激活 Pro 用户在升级后自动保持激活状态与全部专业功能。
   Existing Pro users automatically retain their active license entitlements and all professional capabilities.
