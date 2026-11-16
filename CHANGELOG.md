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

#### Added
- **播放列表 ⌘F 即时搜索与拼音首字母过滤 (Proposal 022)**:
  - 边栏抽屉播放列表支持按 ⌘F 即时呼出搜索栏，支持中文全拼、拼音首字母简拼（如输入 "zwy" 匹配《钟无艳》）与不区分大小写的英文字符过滤；
  - 支持键盘方向键选曲与一键清除，按 Esc 键平滑退出搜索并恢复完整列表。
- **外挂字幕多级目录递归检索挂载 (Proposal 008)**:
  - 扩展同名外挂字幕自动扫描逻辑至媒体目录下的 `Subs/`、`subtitles/`、`Sub/` 等多层子目录，支持 ASS、SSA、SRT、VTT、SUB 等常用格式。
- **清空列表二次确认防误触保护**:
  - 抽屉列表底部“清空”按钮引入 3 秒高亮确认倒计时防误触状态机，彻底防止误清空播放列表。
- **全格式高清音频解复用编解码库集成**:
  - Universal FFmpeg 库全面编入 `dts`、`dtshd`、`truehd`、`mlp` 解复用器与对应解码器，原生解析 DTS-CD 与高清无损音轨。

#### Changed
- **影院级纯透明悬浮播控栏 (Proposal 021)**:
  - 彻底移除底栏时间轴与控制区原有的深灰半透明长条渐变衬底，转为 100% 透明纯悬浮形态，配合原生微投影（`shadow 0.60`），消除大灰框视觉压迫感。
- **窗口起手快甩拖拽响应优化 (ISSUE-017)**:
  - 优化拖拽启动阈值至 4.0pt 并向系统传递原始事件，消除快速甩动视窗时的初始粘滞感与光标分离。
- **多声道立体声下混软限幅器 (Soft Limiter)**:
  - 内核引入平滑 `tanh` 软限幅算法（`applySoftLimiter`），当下混多声道（如 DTS-ES 6.1）至双声道物理硬件时，将总电平稳固收敛在 0 dBFS 以内，消除 DAC 削顶爆音。
- **音频容器 10MB 深度预探测加固**:
  - 解复用器前置配置 10MB 探测缓冲区与 2.0s 分析时长，确保复杂容器结构在打开瞬间即可完成流属性定型。

#### Fixed
- **多显示器扩展屏全屏播放副屏光标误唤醒 (ISSUE-021 / GitHub Issue #7)**:
  - 引入物理屏幕绝对坐标命中过滤，在副屏或外部桌面移动光标时，主屏严格保持纯净沉浸态。
- **竖屏短视频关闭后视窗比例异常 (ISSUE-022 / GitHub Issue #9)**:
  - 退出播放切回空状态时增加纵横比保护门控，自动将纵向窗口平滑居中复位为标准 16:9 横向视窗（960 × 540）并重置约束。
- **标准 PCM 音频播放偶发刺耳啸叫与解码崩溃**:
  - 彻底移除了音频消费管线中粗暴的 2 字节嗅探逻辑，消除了正常波形随机撞车 AC-3 同步字引发的假阳性重置缺陷，保护标准 PCM 纯净直通。
- **冷启动桌面平铺隔离 (ISSUE-018)**:
  - 启动时主动清除 macOS 窗口平铺属性记忆，强制按标准横向窗口居中呈现，杜绝冷启动铺满屏。

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
