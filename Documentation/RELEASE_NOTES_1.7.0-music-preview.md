# SilkPlayer 1.7.0-music-preview 版本更新说明 / Release Notes (Preview Draft)

此文档为 `feature/music-mode-revamp` 分支本地预览版说明草案（尚未生成正式全架构 DMG，部分交互细节仍在讨论与复验中）。
This document is a preview draft for the `feature/music-mode-revamp` branch (no universal distribution DMG has been built yet; selected interaction details remain under review).

---

## 核心特性 / Key Features

- **音乐模式可折叠两段式视图 / Collapsible Two-Stage Music Mode**:
  - 新增收起/展开队列开关（`Cmd+L` 或点击卡片边框居中胶囊指示器），收起后进入紧凑两段式控制面板（标准宽度目标高度 `224 pt`，大屏扩展宽度 `232 pt`），并支持纵向拖拽磁吸切换与展开高度记忆。
  - Added a collapsible queue toggle (`Cmd+L` or the centered border notch), shrinking into a compact two-stage mini console (`224 pt` / `232 pt` target height) with magnetic vertical-drag snapping and expanded height persistence.
- **半透明液态玻璃视觉与低功耗重绘优化 / Liquid Glass Canvas & CPU Reduction**:
  - 使用固定布局与渲染服务层动画（`VinylSpinningLayerView`、`MiniPlayingBarsHostView`、`Canvas` 频谱表），降低音频播放期间主进程与 `WindowServer` 的重绘负载；外层窗口背景采用深色烟熏半透明材质。
  - Replaced heavy per-frame view invalidation with render-server CoreAnimation layers and fixed-frame `Canvas` rendering to lower playback CPU and `WindowServer` overhead over a translucent smoked glass backdrop.
- **音乐模式交互与视频 HUD 隔离 / Music Mode Interaction & HUD Isolation**:
  - 音乐模式下支持从界面空白边距及非控件区域拖拽移动窗口（保留顶部/底部 `6 pt` 纵向调整边缘），并屏蔽视频专用的进度条悬停缩略图预览与纵向拉伸尺寸比例 HUD，视频模式行为保持不变。
  - Enabled window dragging from blank margins and non-control gaps (preserving `6 pt` top/bottom vertical resize edges) while suppressing video thumbnail hover previews and the resize dimension HUD in Music Mode without altering Video Mode.

---

## 系统要求 / Requirements

- **操作系统 / OS**: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- **芯片架构 / Architecture**: 当前预览构建仅包含 `arm64` 本地应用包（正式发布版将提供 Universal Binary `arm64 + x86_64`） / Current preview build contains local `arm64` `.app` bundle only (official release will ship Universal Binary `arm64 + x86_64`)

---

## 安装方式 / Installation

1. 当前内部预览版已直接构建并安装至 `/Applications/SilkPlayer.app`（构建命令 `./Scripts/package_app.sh 1.7.0-music-preview arm64 --app-only`）。
   The internal preview build has been assembled and installed directly to `/Applications/SilkPlayer.app` via `./Scripts/package_app.sh 1.7.0-music-preview arm64 --app-only`.
2. 待正式发版版本号定稿并执行全架构打包测试后，提供 Universal DMG 公开下载镜像（`ISSUE-015`、`ISSUE-016` 已于当前预览分支收口验证）。
   Universal DMG public distribution will proceed once the final release version number and universal build verification are confirmed (`ISSUE-015` and `ISSUE-016` are resolved and verified on the current preview branch).
