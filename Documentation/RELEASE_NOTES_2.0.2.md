# SilkPlayer 2.0.2 版本更新说明 / Release Notes

## 版本概括 / Overview

SilkPlayer 2.0.2 是一个紧急稳定性维护补丁，重点修复了双击全屏或跨桌面 Space 动画期间由主线程 Metal 布局与系统 WindowServer 争抢图层缓冲区导致的死锁崩溃（WindowServer 强杀注销退回登录界面）问题，移除了全屏前的非公开平铺约束调用，并增强了渲染管线对极端几何状态的防御。
SilkPlayer 2.0.2 is a critical stability hotfix. It resolves an issue where toggling fullscreen or transitioning across Spaces caused a circular deadlock between main-thread Metal layout and macOS WindowServer drawable allocation (triggering a WindowServer watchdog crash and session logout), eliminates private window tiling selector invocations, and strengthens render pipeline resilience during rapid geometry mutations.

---

## 核心特性 / Key Features

- Metal 布局与渲染管线解耦 / Metal Layout & Render Decoupling:
  解耦主线程 `layout()` / `setFrameSize()` 与同步渲染请求（`renderCurrentFrameImmediately`），布局时严格仅更新 `layer.drawableSize` 几何尺寸，杜绝在 macOS 全屏跨 Space 动画高频插值期间向 `CAMetalLayer` 同步争抢 `nextDrawable()`，彻底终结由此引发的 WindowServer 看门狗熔断与系统注销。
  Decoupled main-thread view layout and frame resizing from synchronous frame presentation (`renderCurrentFrameImmediately`). During fullscreen Space transitions, layout passes strictly update `layer.drawableSize` without contending for `CAMetalLayer.nextDrawable()`, completely preventing WindowServer watchdog timeouts and session logouts.

- 剔除私有分屏约束竞争 / Private Tiling Constraint Removal:
  在 `toggleFullscreen()` 入口彻底移除针对 macOS 15 内部平铺机制的私有选择器调用，消除进入全屏动画前与系统窗口管理器产生的时序竞争。
  Eliminated private tiling constraint selector invocations in `toggleFullscreen()`, removing timing hazards with the system window manager prior to fullscreen animations.

- 渲染管线几何防御 / Render Pipeline Geometry Guards:
  在 Metal 渲染帧提交前增加图层有效尺寸保护，严禁在零尺寸或过渡脏尺寸下执行 `nextDrawable()`，进一步加固高刷新率（120Hz ProMotion）与多显示器环境下的图形稳定性。
  Added defensive size validation prior to frame submission, preventing `nextDrawable()` from executing on zero or uninitialized layer dimensions to ensure rock-solid stability on ProMotion 120Hz and multi-display environments.

- 字幕渲染防重叠与关闭状态持久化 / Subtitle Multi-Cue Defense & Disablement Persistence:
  修复了 ASS 特效字幕九宫格对齐（`\an7` / `\an8` / `\an9` 顶部与 `\an1` / `\an2` / `\an3` 底部）在解析时丢失导致同屏多字幕叠字的问题，重构文本字幕渲染容器为自适应垂直堆叠（`VStack`），实现人物姓名与台词天然分离排版；引入 `isSubtitleDisabledByUser` 用户显式状态锁，修复选择“关闭字幕”后被音视频轨刷新机制越权自动回选激活的逻辑缺陷，确保关闭字幕后彻底清空画布与停止解码。
  Restored ASS alignment tag parsing (`\an7`-`\an9` top, `\an1`-`\an3` bottom) to prevent character labels and dialogues from collapsing onto the same vertical coordinate, and refactored text subtitle layouts with responsive vertical stacks (`VStack`) to eliminate visual overlap. Introduced explicit user disablement locking (`isSubtitleDisabledByUser`) to resolve an issue where track synchronization unexpectedly re-selected disabled subtitles.

---

## 系统要求 / Requirements

- 操作系统 / OS: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- 芯片架构 / Architecture: Universal 通用二进制（原生支持 Apple Silicon 与 Intel 64 位芯片）/ Universal Binary (Apple Silicon & Intel 64-bit)
- 图形显示 / Graphics: 支持 Metal 硬件加速与 HDR / EDR 显示 / Metal hardware acceleration & HDR / EDR display supported

---

## 安装方式 / Installation

1. 下载并打开 `SilkPlayer-2.0.2-universal.dmg`；
2. 将 `SilkPlayer.app` 拖拽至 `Applications` 文件夹；
3. 如遇首次打开系统安全提示，请前往「系统设置 → 隐私与安全性」点击「仍要打开」。

1. Download and open `SilkPlayer-2.0.2-universal.dmg`;
2. Drag `SilkPlayer.app` into the `Applications` folder;
3. If prompted by macOS Gatekeeper, navigate to "System Settings → Privacy & Security" and click "Open Anyway".
