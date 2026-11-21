# Changelog

All notable changes to **SilkPlayer** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.2] - 2026-11-22

### Fixed
- **双击全屏 Space 转场 WindowServer 驱动死锁彻底修复**:
  - 解耦 Metal 主线程 `layout()` / `setFrameSize()` 与同步渲染请求（`renderCurrentFrameImmediately`），布局期间严格仅更新 `layer.drawableSize`，杜绝在 macOS 全屏跨 Space 动画高频插值期间向 `CAMetalLayer` 同步争抢 `nextDrawable()`，彻底终结因此引发的系统级 `WindowServer` 崩溃与强制注销（退回登录界面）缺陷。
- **剔除私有分屏约束竞争**:
  - 在 `toggleFullscreen()` 入口彻底移除调用 macOS 15 内部平铺机制的未公开私有方法 `_doUpdateTilingConstraintsImmediately`，消除全屏前与系统窗口管理器产生的时序竞争。
- **渲染管线几何防御门禁**:
  - 在 Metal 帧提交前加入图层尺寸正值校验，杜绝在零尺寸或过渡脏尺寸下调用 `nextDrawable()`，进一步巩固 ProMotion 120Hz 高刷新率屏幕与多显示器环境下的图形稳定性。

## [2.0.1] - 2026-11-21

### Fixed
- **AV1 10-bit 核心解码与渲染修复**:
  - 彻底剔除 AV1 的假硬件解码候选与无效硬件格式回调，统一路由至高性能 libdav1d 多线程切片软解，开放 CPU 核心并发池，直通原生 YUV 渲染管线，解决有声无画、黑屏且时间轴停滞问题。
- **音视频主时钟防丢帧死锁**:
  - 重构大时钟差丢帧判定（`diff < -0.250`），增加连续丢帧上限（最多允许丢弃 2 帧追赶时钟），超限立即平滑重锚定音频时钟（`audio.reanchor`），杜绝无限丢帧死循环。
- **冷启动版本更新提示层级与免打扰优化**:
  - 将新版本对话框直接绑定于主视窗，增加全局播放态互斥门控，观影或听歌期间绝不弹窗打扰，仅在静态待机或冷启动就绪时提示，并严格遵循 7 天周期静默期。

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

#### Added
- **播放列表 ⌘F 即时搜索与拼音首字母过滤 (Playlist ⌘F Instant Search & Pinyin Initial Matching - Proposal 022)**:
  - 播放列表内置即时过滤，支持文件名原文字符匹配以及完整中文拼音首字母过滤，海量分集秒级定位。
- **外挂字幕 Subs/ 目录深度递归检索 (Recursive Companion Subtitle Discovery - Proposal 008)**:
  - 自动递归扫描影视同级及 `Subs/`、`Subtitles/` 等多级子目录，智能关联提取同名外挂字幕，免除手动拖拽加载繁琐步骤。
- **全格式高清音频解复用 (Full-Format High-Definition Audio Demuxing)**:
  - Universal FFmpeg 编入 `dts`、`dtshd`、`truehd`、`mlp` 完整解复用库，配合 10MB 前置探测缓冲区彻底消除标准 PCM 假阳性误判。
- **播放列表两步清空防误触确认机制 (Two-Step Playlist Clear Confirmation)**。

#### Changed
- **影院级纯透明悬浮播控栏 (Floating Cinema HUD & Gradient Backing Removal - Proposal 021)**:
  - 彻底移除原有底部深灰不透明方框底板，升级为直接融入视频画面的悬浮控制胶囊，观影视觉更加通透无遮挡。
- **多声道立体声下混软限幅防削顶 (Multichannel Stereo Downmixing Soft-Knee Limiter)**:
  - 双声道播放高规格多声道音轨时，自动应用平滑软限幅算法，杜绝音量过大引起的爆音与 DAC 硬件削顶失真。
- **标准音频播放独立解耦 (Decoupled Standard Audio Playback)**:
  - 免费版双击本地音频文件直接流畅播放，支持 1:1 视窗自由缩放吸附、播放列表抽屉快捷唤出与画布空白处点击播放/暂停，不绑定 Pro 音乐模式，保持轻巧纯粹。
- **起手快甩拖拽平滑跟手度调优 (Window Drag Initiation Optimization - ISSUE-017)**。

#### Fixed
- **多屏扩展全屏防光标误唤醒 (ISSUE-021 / GitHub Issue #7)**:
  - 修复多显示器全屏播放时副屏光标移动导致主屏播放控件异常弹出的问题。
- **竖屏短视频关闭后视窗横屏居中复位 (ISSUE-022 / GitHub Issue #9)**:
  - 修复播放竖屏视频后关闭，主窗口未恢复标准横屏比例的问题。
- **冷启动桌面平铺隔离 (Cold-Start Desktop Tiling Fill State Isolation - ISSUE-018)**:
  - 修复冷启动时异常吸附系统分屏磁贴状态的问题。

## [1.6.0] - 2026-11-12

### Added
- **Context Menu Window Size Presets (Proposal 027 / GitHub Issue #6)**
- **Window Live-Resize Precision Dimension HUD (Proposal 023)**
- **Dynamic EDR Tone-Mapping & Rational Highlight Roll-off (Proposal 013)**
- **Smart Silent Update & Lossless In-Place Overwrite Installer (Proposal 020)**
- **Playlist Drawer Handle Border-Flush Redesign (Proposal 019)**
