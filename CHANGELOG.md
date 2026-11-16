# Changelog

All notable changes to **SilkPlayer** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-11-16

### 专业版 (Pro Edition)

#### Added
- **独立折叠音乐模式视窗 (Collapsible Two-Stage Music Window - Proposal 024)**:
  - 深度重构音频播放体验，推出两段式独立音乐模式界面（顶层聚焦卡片 + 底部折叠抽屉列表），支持 188pt / 420pt 自由折叠缩放；
  - 搭载全物理惯性平滑旋转黑胶唱片（`FloatingVinylDiscView`）与多频段自适应声学共振光环（`AudioVisualizerHaloView`）；
  - 支持状态栏常驻微型播控与 Dock 图标静默隐匿（Proposal 025），点击状态栏图标即可呼出紧凑音频小窗。
- **全新高质感「冰蓝」与 4 色主题矩阵 (Curated Theme Matrix - Proposal 028)**:
  - 引入全新「冰蓝」（Ice Blue）主题：基于 macOS 原生 `behindWindow` 毛玻璃透光底板，搭配深邃冷青渐变与极光棱镜切光折射边，主点缀色采用液态电光冰青（`#00DCFA`）；
  - 全局文字对比度提升至 WCAG AAA 顶级标准（主文本超亮纯冷白 `#FFFFFF` 对比度达 19.5:1，次级文本通透天青灰 `#A8B8C8` 达 9.4:1）；
  - 提供深灰、冰蓝、暖白、青瓷 4 套高质感色彩矩阵，全局联动主界面、播放播控、设置与局域网媒体库。
- **局域网 SMB / NFS 影视媒体库 (Pro LAN Media Library - Proposal 017 & 029)**:
  - 原生支持局域网 SMB 2/3、NFS 自动服务发现与远程挂载，极速索引 NAS 与私有服务器影视资产；
  - 影视卡片支持多季剧集智能识别与在架切集抽屉（Season Switcher），折叠式分类（电影/剧集）与进度云端同步。
- **全格式无损音频与多声道输出管线 (Multichannel LPCM Output)**:
  - CoreAudio 渲染管线深度适配多声道 Float32 LPCM 无损直通（5.1 / 7.1 声道），原生保留 TrueHD、Dolby Atmos 与 DTS-HD Master Audio 空间沉浸声场。

### 免费版 (Standard Edition)

- **维护与支持说明 (Maintenance Notice)**:
  - 随着大版本更新，免费版的基础播放功能不会被阉割、仍将持续保持免费开放，免费版本的现有功能仍将在未来一段时间内继续维护；
  - 原定于 1.7.0 之后版本的功能更新、优化和修复进度已随本次大版本更新提前至 1.7.0 版本发布；2.0.0 免费版完成 2.x 底层架构底座平滑对齐，无独立新增功能。全部核心特性详见 1.7.0 发布说明。

## [1.7.0] - 2026-11-16

### Added
- **Playlist ⌘F Instant Search & Pinyin Initial Matching (Proposal 022)**
- **Recursive Companion Subtitle Discovery (Proposal 008)**
- **Two-Step Playlist Clear Confirmation**
- **Full-Format High-Definition Audio Demuxing (`dts`, `dtshd`, `truehd`, `mlp`)**

### Changed
- **Floating Cinema HUD & Gradient Backing Removal (Proposal 021)**
- **Window Drag Initiation Optimization (ISSUE-017)**
- **Multichannel Stereo Downmixing Soft-Knee Limiter**
- **Audio Container Deep Probing (10MB Buffer)**

### Fixed
- **Multi-Screen Fullscreen Secondary Display Cursor Wakeup (ISSUE-021 / GitHub Issue #7)**
- **Vertical Video Window Geometry Restoration (ISSUE-022 / GitHub Issue #9)**
- **Standard PCM Audio Stream False-Positive Sniffing Distortion**
- **Cold-Start Desktop Tiling Fill State Isolation (ISSUE-018)**

## [1.6.0] - 2026-11-12

### Added
- **Context Menu Window Size Presets (Proposal 027 / GitHub Issue #6)**
- **Window Live-Resize Precision Dimension HUD (Proposal 023)**
- **Dynamic EDR Tone-Mapping & Rational Highlight Roll-off (Proposal 013)**
- **Smart Silent Update & Lossless In-Place Overwrite Installer (Proposal 020)**
- **Playlist Drawer Handle Border-Flush Redesign (Proposal 019)**
