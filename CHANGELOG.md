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
  - 沉浸式详情页双栏响应式设计（2/3 影视规格/剧情简介/选集 + 1/3 智能关联推荐），结合多维偏好加权算法；
  - 剧集选集播放按键独立放大（30×30 pt），单击即播；
  - 播放器与媒体库物理层级完全解耦，原生自适应窗口比例还原，彻底消除黑边；
  - 播放器右上角退出交互重构为高质感毛玻璃「‹ 返回」胶囊按钮，左上角格式信息清爽通透；
  - 剧集网格全面虚拟化（`LazyVGrid`），彻底根除行内抽屉连击彩虹圈死锁；
  - 影视卡片支持多季剧集智能识别与在架切集抽屉（Season Switcher），折叠式分类（电影/剧集）与进度云端同步。
- **全格式无损音频与多声道输出管线 (Multichannel LPCM Output)**:
  - CoreAudio 渲染管线深度适配多声道 Float32 LPCM 无损直通（5.1 / 7.1 声道），原生保留 TrueHD、Dolby Atmos 与 DTS-HD Master Audio 空间沉浸声场。
- **本地 .NFO 元数据解析引擎 (Local NFO Metadata Engine)**:
  - 兼容 Kodi、Jellyfin、Emby 与 TinyMediaManager 的 XML 规范，自动关联 `<stem>.nfo`、`movie.nfo` 与 `tvshow.nfo`，离线提取海报、剧情简介、年代、评分与流派并持久化至 SQLite 媒体库。

#### Fixed
- 修复影片详情页背景在冰蓝等半透明主题下穿透露出媒体库海报墙的问题，注入 `solidBackgroundBase` 100% 遮罩基底；
- 修复青瓷浅色主题在独立音乐模式和播放进度条中失效退化为深色模式的问题；
- 修复局域网挂载等模态弹窗在弹出时系统默认在取消按钮绘制蓝色焦点框的问题（引入底层 `SilkSheetFocusRingSuppressor`）；
- 修复快捷键速查表与偏好设置激活区硬编码系统强调色的问题，全局对齐主题色与深浅外观；
- 修复影片详情页「从头播放」按钮因未透传参数导致回落读取历史断点的问题；
- 修复详情页按空格无法起播、按 Esc 无法关闭详情的问题（放行全局键盘拦截器并绑定焦点）；
- 修复后台听歌模式下在访达双击视频打开时，Dock 图标与 Cmd+Tab 切换项处于失踪状态的问题；
- 修复在局域网挂载弹窗输入或浏览详情页时按 Cmd+W 误杀主窗口的问题（重构为优先退出弹窗或详情页）；
- 修复海报卡片因并挂单击与双击手势导致的 300~400ms 点击粘滞延迟，解决批量模式下双击复选卡顿问题。

### 免费版 (Standard Edition)

- **维护与支持说明 (Maintenance Notice)**:
  - 随着大版本更新，免费版的基础播放功能不会被阉割、仍将持续保持免费开放，免费版本的现有功能仍将在未来一段时间内继续维护；
  - 纯音频播放模式与 Pro 独立音乐模式彻底物理与逻辑解耦，免费版 100% 继承 1.7.0 经典交互与视窗几何基准（引入 `PlaybackPresentationMode` 显式呈现模式状态机）；
  - 全面恢复 1.7.0 右侧边框悬浮抽屉拉手（`<`）、快捷键 `P` 与 `⌘P` 呼出播放列表抽屉能力；
  - 全面恢复 1.7.0 双轴平滑拖拽视窗缩放（最小 380×380），彻底切断 520pt 强制锁宽与边框回弹抖动；
  - 唱盘视图恢复纯净黑胶与标题排版，移除临时入侵性控件，画布空白单击直达播放/暂停；
  - 原定于 1.7.0 之后版本的功能更新、优化和修复进度已随本次大版本更新提前至 1.7.0 版本发布；2.0.0 免费版完成 2.x 底层架构底座平滑对齐，全部核心特性详见 1.7.0 发布说明。

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
