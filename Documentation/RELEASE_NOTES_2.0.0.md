# SilkPlayer 2.0.0 版本更新说明 / Release Notes

## 版本概括 / Overview

SilkPlayer 2.0.0 是自项目发布以来规模最大的一次里程碑更新。本次版本引入了独立的折叠式双形态音乐播放视窗、由内而外深度重构的高质感「冰蓝」与四色主题矩阵、原生局域网 SMB / NFS 影视媒体库与多声道 LPCM 无损音频输出；同时为免费版带来了 ⌘F 即时拼音搜歌、多级子目录外挂字幕递归索引、影院级纯透明悬浮播控栏以及全套高保真音频解复用加固。更新全面遵循双轨制架构，在为开源用户提供永久免费、稳定纯净播放底座的同时，为专业用户交付强劲的家庭影音与音乐生产力体验。

SilkPlayer 2.0.0 marks the largest milestone update since the project's inception. This release introduces a collapsible two-stage music player window, an optically refined "Ice Blue" theme alongside a 4-theme system matrix, native LAN SMB/NFS media library indexing, and multichannel LPCM lossless audio output. For the free edition, it brings ⌘F instant Pinyin search in playlists, recursive companion subtitle indexing across nested folders, an unoccluded floating cinema HUD, and full-format HD audio demuxing. Designed around a strict dual-track architecture, SilkPlayer maintains a permanent, zero-clutter free core while delivering an expansive media center experience for Pro users.

---

## 专业版特性 / Pro Edition Features

### 1. 独立折叠式音乐播放器视窗 / Collapsible Two-Stage Music Window
- **双形态自由折叠 (Dual Morphing Geometries)**:
  支持在 188pt 极简聚焦态与 420pt 展开列表态之间一键平滑折叠，窗口宽度智能自适应，完美融入桌面侧边或配合多任务视窗分屏使用。
  Smoothly toggles between a 188pt minimal playback card and a 420pt expanded queue view with fixed-width ergonomics, tailored for compact multitasking or side-by-side desk placement.
- **物理惯性仿真黑胶与自适应声学共振光环 (Acoustic Vinyl & Visualizer)**:
  内置基于物理角速度模拟的匀速旋转黑胶唱片视图，联动音轨低频、中频与高频能量动态驱动外层五重呼吸共鸣光环。
  Features an inertia-simulated rotating vinyl disc coupled with a multi-band dynamic acoustic halo driven in real time by bass, mid, and treble audio levels.
- **菜单栏常驻微型播控与 Dock 零驻留 (Status Bar Background Playback)**:
  支持将音乐播放器一键收起至 macOS 顶部菜单栏，Dock 栏图标无感隐匿，点击菜单栏图标即可原地呼出悬浮控制卡片与歌词信息。
  Enables seamless minimization to the macOS status bar with zero Dock footprint; clicking the menu bar icon instantly reveals a lightweight floating playback capsule.

### 2. 高质感「冰蓝」与四色主题矩阵 / Curated 4-Theme Matrix
- **全新「冰蓝」（Ice Blue）通透材质**:
  摒弃传统纯黑实板，全线接入 macOS 原生 `behindWindow` 毛玻璃透光底板，搭配冷色天青微渐变与极光棱镜切边高光，点缀色采用液态电光冰青（`#00DCFA`）。
  Engineered with native macOS `behindWindow` vibrancy, deep arctic gradients, and subtle prismatic specular edges, paired with a vibrant hyper-electric aqua accent.
- **符合 WCAG AAA 顶级可识别度对比度**:
  主标题与核心文字升级为超高纯冷白（`#FFFFFF`，对比度高达 19.5:1），次级说明文字采用通透天青灰（`#A8B8C8`，对比度 9.4:1），彻底解决深色模式下文字发灰看不清的问题。
  Upgraded primary text to pure cold white (19.5:1 contrast) and secondary labels to celestial cyan-gray (9.4:1 contrast), vastly exceeding WCAG AAA accessibility standards.
- **深灰、冰蓝、暖白、青瓷 4 套主题全局联动**:
  全局覆盖主界面、播放视窗、偏好设置与影视媒体库，一键切换全局视觉色彩。
  Full aesthetic alignment across the main window, HUD, Settings, and Pro Media Library.

### 3. 原生局域网 SMB / NFS 影视媒体库 / Pro LAN Media Library
- **免挂载局域网服务自动发现**:
  内置 Bonjour / NetBIOS 局域网协议栈，无需在访达手动挂载磁盘即可直接扫描并串流回放 NAS、家庭服务器与软路由上的 4K HDR 电影与剧集。
  Zero-configuration discovery and streaming for SMB 2/3 and NFS network shares without requiring manual Finder mounting.
- **影视折叠分类与在架切集抽屉 (Season Switcher)**:
  智能聚合多季剧集为单一卡片，右侧抽屉直接展示分季列表与全集进度，支持电影/剧集折叠卡片切换与播放历史云端同步。
  Aggregates multi-season TV series into single smart cards with in-drawer season/episode switching, collapsible category dividers, and cloud progress sync.

### 4. 多声道 LPCM 无损音频输出 / Multichannel LPCM Lossless Output
- **离散 5.1 / 7.1 声道无损直通**:
  CoreAudio 管线直接匹配外接家庭影院功放或多声道声卡，原生输出杜比 TrueHD、Dolby Atmos 与 DTS-HD Master Audio 多声道离散音频流。
  Directly outputs discrete 5.1 and 7.1 channel LPCM streams to AV receivers and external DACs without forced stereo fold-down.

---

## 免费版特性 / Free Edition Features

### 1. 播放列表 ⌘F 即时搜索与拼音简拼 / Playlist ⌘F Instant Search
- **全拼与首字母模糊匹配**:
  在右侧边栏播放列表中按 `⌘F` 即可原地呼出搜索栏，支持中文全拼、拼音首字母简拼（如 `zwy` 直搜《钟无艳》）与不区分大小写的英文字符过滤。
  Press `⌘F` in the playlist drawer to instantly filter media via full Pinyin, Pinyin initials, or fuzzy English search.
- **列表即时定位与安全复位**:
  支持键盘上下键直跳播放与单曲移除，按 `Esc` 键平滑退出搜索并恢复完整队列。
  Allows rapid keyboard navigation, inline track removal, and smooth restoration of the full queue upon pressing `Esc`.

### 2. 外挂字幕多级子目录递归扫描 / Recursive Companion Subtitle Search
- **深度索引 Subs 子文件夹**:
  自动扫描媒体目录下的 `Subs/`、`subtitles/`、`Sub/` 等专用子文件夹，自动匹配同名或模糊关联的 ASS、SSA、SRT、VTT、SUB 字幕文件并即时挂载。
  Recursively indexes nested `Subs/` and `subtitles/` subdirectories to automatically associate companion subtitle files.

### 3. 影院级纯透明悬浮播控栏 / Floating Cinema HUD
- **消灭深灰矩形框遮挡**:
  彻底移除了原时间轴与底部控制区外围的深灰半透明长条渐变矩形框，界面转为 100% 透明纯悬浮形态。
  Eliminated the clunky dark gradient box beneath the timeline, unlocking an unoccluded cinema-grade floating control layout.
- **高对比度微投影保障**:
  进度条时间文字与轨道增加原生柔和投影（`shadow 0.60`），确保在明亮高光画面或透明毛玻璃下均清晰锐利。
  Enhanced typography and scrubber track drop-shadows for sharp contrast against vivid HDR scenes and frosted glass.

### 4. 全格式高清音频解复用支持 / HD Audio Demuxing Support
- **编入 Universal DTS / TrueHD 编解码库**:
  编入包含 `dts`、`dtshd`、`truehd`、`mlp` 解复用器与对应解码器的 Universal FFmpeg 库，全面支持 DTS-CD、DTS-ES 等格式解析。
  Embedded complete DTS, DTS-HD MA, and Dolby TrueHD demuxers for smooth native playback of specialized lossless audio files.

---

## 通用体验与细节优化 / General Enhancements

- **起手快甩拖拽平滑跟手 (ISSUE-017)**:
  优化画面拖拽启动阈值至 4.0pt 并向系统传递原始事件，消除快速甩动视窗时的初始粘滞感。
  Tuned window grab threshold to 4.0pt with native event forwarding, eliminating grab hesitation during rapid dragging.
- **多声道立体声下混防削顶软限幅 (Soft Limiter)**:
  引入平滑 `tanh` 软限幅算法，下混多声道音频至立体声耳机或双声道喇叭时将电平收敛在 0 dBFS 以内，消除 DAC 削顶爆音。
  Integrated an in-place `tanh` soft-knee limiter to prevent DAC square-wave clipping when downmixing multichannel audio to stereo.
- **清空列表二次确认防误触**:
  抽屉清空按钮引入 3 秒高亮确认倒计时状态机，彻底防止误清空播放列表。
  Added a 3-second two-step confirmation state machine to prevent accidental playlist clearing.
- **音频容器 10MB 深度探测**:
  解复用器前置配置 10MB 探测缓冲区与 2.0s 分析时长，大幅增强特殊容器的流识别稳定性。
  Expanded demuxer probe buffer to 10MB, ensuring instant stream layout resolution.

---

## 问题修复 / Bug Fixes

- **修复多显示器扩展屏全屏播放副屏光标误唤醒 (ISSUE-021 / GitHub Issue #7)**:
  加入物理屏幕坐标命中过滤，在副屏或外部桌面移动鼠标不再误触发主屏全屏播控唤醒。
  Fixed secondary display cursor movement inadvertently waking the fullscreen HUD on multi-monitor setups.
- **修复竖屏短视频关闭后视窗比例异常 (ISSUE-022 / GitHub Issue #9)**:
  退出播放时增加纵横比保护门控，自动将纵向窗口平滑居中复位为标准 16:9 横向视窗（960 × 540）。
  Fixed window remaining stuck in a narrow phone ratio after closing portrait videos by restoring a centered 16:9 desktop frame.
- **彻底根除标准 PCM 音频播放偶发刺耳啸叫**:
  删除了音频管线中粗暴的 2 字节嗅探逻辑，消除了正常波形随机撞车 AC-3 同步字引发的假阳性重置缺陷。
  Eliminated false-positive AC-3 stream sniffing that previously reset the decoder on normal PCM tracks.
- **修复冷启动受系统平铺恢复影响铺满屏幕 (ISSUE-018)**:
  启动时主动清理 macOS 窗口平铺持久化属性，强制按标准横向窗口居中呈现。
  Purged macOS window tiling persistence on cold launch to prevent unexpected full-screen expansion.

---

## 系统要求 / Requirements

- **操作系统 / OS**: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- **芯片架构 / Architecture**: Universal 通用二进制（原生支持 Apple Silicon M 系列与 Intel 64 位芯片）/ Universal Binary (Apple Silicon & Intel 64-bit)
- **图形显示 / Graphics**: 支持 Metal 硬件加速与 HDR / EDR 显示 / Metal hardware acceleration & HDR / EDR display supported

---

## 安装方式 / Installation

1. 打开 `SilkPlayer-2.0.0-universal.dmg` 镜像；
   Open the `SilkPlayer-2.0.0-universal.dmg` disk image.
2. 将 `SilkPlayer.app` 拖入 `Applications`（应用程序）文件夹即可完成安装或覆盖；
   Drag `SilkPlayer.app` into the Applications folder to install or upgrade.
3. 已激活 Pro 用户在更新后自动保持授权状态与专享特性。
   Existing Pro users automatically retain their active license entitlements.
