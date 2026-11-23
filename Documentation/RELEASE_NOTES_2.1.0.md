# SilkPlayer 2.1.0 版本更新说明 / Release Notes

## 版本概括 / Overview

SilkPlayer 2.1.0 是一个重要的体验与架构升级版本，全面重构了外部文件打开与视窗生命周期受控调度，彻底消除双击视频时产生的多余闲置窗口与闪烁启动问题；实现了全画幅视频自适应几何体验革新，竖屏全面对齐 QuickTime 100% 满高标准，横屏升级至 70% 黄金观影比例；重构播放列表侧边抽屉拉手微质感以消除小屏高反差白斑，并正式沉淀全屏转场管线硬件提交互斥治理。

SilkPlayer 2.1.0 is a major UX and architectural release. It completely refactors external file launching and window lifecycle orchestration, permanently eliminating phantom idle windows and startup flicker when opening media from Finder. It introduces full-canvas adaptive geometry upgrades—vertical videos now align with QuickTime's 100% visible height standard and horizontal videos upgrade to a 70% golden viewport ratio. It also refines the playlist drawer handle with anti-halation micro-textures for fractional Retina displays and solidifies Metal presentation lockouts during fullscreen Space transitions.

---

## 核心特性 / Key Features

- 视窗生命周期纯净调度与幽灵开窗根除 / Window Lifecycle Architecture & Phantom Window Elimination:
  彻底移除 WindowGroup 中无意义的外部事件声明，从根源上杜绝访达（Finder）外部双击/右键打开文件时由 SwiftUI 盲目额外实例化第二视窗的缺陷；加固视窗接入逻辑，对多余视窗实施即刻同步隐形（`window.orderOut(nil)`），根除单窗口模式下先闪现弹出再关闭的视觉瑕疵；引入双窗口合法准入守卫与同文件播放聚焦保护，只有当主窗口正在播放且存在有效待播媒体任务（或用户明确按 `⌘N`）时才允许实例化第二视窗，彻底终结前台闲置欢迎屏与后台播放并存的现象。
  Completely removed redundant external event declarations on WindowGroup, preventing SwiftUI from autonomously instantiating extraneous window scenes on Finder launch events. Enforced instantaneous window unmapping (`window.orderOut(nil)`) on discarded duplicate instances, eliminating transient window flashes in single-window mode. Implemented strict dual-window admission guards and duplicate-file focus routing to ensure secondary windows only instantiate when explicitly requested or when the primary window is actively playing external media queues.

- 播放器右上角悬浮返回按钮图标化 / Minimal Circular HUD Return Button:
  移除播放态右上角悬浮胶囊中的文字「返回」，重构为 30x30 圆形液态毛玻璃微质感左箭图标按钮，与右侧常驻图钉和检视器控制键形成严格统一的几何秩序，并提供完备的悬停浮窗提示与快捷键交互。
  Redesigned the top-right playback return button from text "返回" into a minimal 30x30 circular liquid-glass chevron icon, harmonizing geometry with adjacent pin and inspector actions while retaining full native tooltips.

- 设置面板顶部 4 分段导航栏紧凑与全域响应重构 / Compact Settings Tab Navigation & Full Hit-Test Hitbox:
  将设置面板顶部 4 分段 Tab 宽度由 452pt 紧凑收拢至 352pt，消减过宽空隙；重构子分段的点击命中区域，修复透明背景击穿缺陷，实现按钮几何矩形全域 100% 灵敏响应与平滑悬停微高亮。
  Compacted the top settings segmented tab bar from 452pt to 352pt, eliminating awkward dead spacing. Fixed SwiftUI transparent background hit-testing pass-through by binding full-surface content shapes, ensuring instantaneous click responsiveness across 100% of each tab area.

- 全画幅自适应几何革新（提案 033 & 034）/ Full-Canvas Adaptive Geometry Upgrades:
  横屏视频（`aspect >= 1.0`）基准自适应宽度比例由 55% 提升至 70%，显著改善 13~14 寸便携小屏笔记本默认窗口过小、字幕辨识度低的问题，将上下 HUD 对核心画面的遮挡压迫率从 34% 大幅降至 23%，同时严格保留外接 4K/5K 屏幕 88% 宽度与 85% 高度安全呼吸边距；竖屏视频默认垂直铺满当前屏幕可用高度（100% visible height），最低宽度硬性锁定 280pt 杜绝微型缩略图退化，并重构竖屏模式顶部 HUD 为极简置顶返回栏，实现画面主体 100% 无遮挡透出。
  Upgraded horizontal adaptive content sizing from 55% to a 70% golden viewport ratio, significantly enhancing viewing immersion on 13-14 inch MacBooks while reducing HUD overlay coverage from 34% to 23% and preserving 88%/85% display breathing margins on 4K/5K monitors. Aligned vertical videos with QuickTime's edge-to-edge visible screen height with a 280pt locked minimum width, streamlining top vertical controls to flush pin and return actions with zero subtitle or canvas obstruction.

- 播放列表侧边抽屉拉手微质感重构（提案 035）/ Playlist Drawer Handle Micro-Texture Refinement:
  针对非整数倍 Retina 缩放下细微描边与实心箭头混合产生高反差粗糙白斑的视觉割裂，静默状态下透明度大幅收敛至微弱漫反射态（描边 0.22 / 箭头 0.26），并注入 0.18 微弱吸光底色阻断像素白光扩散；增加灵敏悬停呼吸反馈，光标划入时平滑过渡至 0.65 描边与 0.75 箭头，完美融入整套液态毛玻璃视觉语言。
  Refined the playlist drawer edge handle to eliminate harsh white haloing on fractional Retina displays. Default idle opacity now features a subtle ambient reflection (stroke 0.22, arrow 0.26) paired with a 0.18 anti-halation dark backing, smoothly blooming into a 0.65/0.75 responsive hover feedback that integrates seamlessly into the ultra-thin material aesthetic.

- 媒体库窗口拉伸尺寸 HUD 智能抑制与右键菜单极简收拢 / Media Library Resize HUD Suppression & Context Menu Simplification:
  在媒体库海报墙与影视详情页浏览状态下拖拽调整窗口大小时，智能屏蔽视频高宽比 HUD（如 16:9 / 2.39:1），保持纯净的无遮挡目录式自适应缩放浏览体验，仅在实际视频播放态下恢复尺寸指示；遵循奥卡姆剃刀原则彻底剔除电影卡片右键菜单中歧义冗余的「重置为未观看」与「标记为已看完」，播放状态重置完全收拢至继续观看区域卡片右上角 `X` 移除动作与右键「从头播放」，极大降低右键视觉干扰并实现交互职责的高度收拢。
  Suppressed the video aspect-ratio dimension HUD overlay when resizing windows in media library and detail browsing states, delivering a distraction-free grid browsing experience. Streamlined movie poster context menus by removing both redundant "Mark as Unwatched" and "Mark as Watched" options, strictly consolidating progress reset behaviors into the Continue Watching dismiss action and dedicated "Play from Beginning" commands.

- 全屏转场生命周期与渲染提交流程治理 / Fullscreen Exit Lifecycle & Presentation Lockout:
  彻底移除退出全屏阶段针对窗口坐标的同步非法改帧（`setFrame`），几何反算完全交由 AppKit 原生异步接管；在 Metal 渲染视图中引入硬件提交流程互斥锁（`isTransitioningLock`），转场期间安全短路 `layer.nextDrawable()` 提交，结合防重入互斥与 3 秒看门狗复位，根除极端多显示器与高频切换环境下可能引发的系统显示服务（WindowServer）死锁卡顿。
  Removed synchronous window frame modifications during fullscreen exit transitions, returning geometry restoration to AppKit's asynchronous lifecycle. Introduced hardware presentation lockouts (`isTransitioningLock`) in the Metal render view to short-circuit frame delivery during Space transitions, eliminating WindowServer watchdog deadlocks under multi-display configurations.

---

## 系统要求 / Requirements

- 操作系统 / OS: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- 芯片架构 / Architecture: Universal 通用二进制（原生支持 Apple Silicon 与 Intel 64 位芯片）/ Universal Binary (Apple Silicon & Intel 64-bit)
- 图形显示 / Graphics: 支持 Metal 硬件加速与 HDR / EDR 显示 / Metal hardware acceleration & HDR / EDR display supported

---

## 安装方式 / Installation

1. 下载并打开 `SilkPlayer-2.1.0-universal.dmg`；
2. 将 `SilkPlayer.app` 拖拽至 `Applications` 文件夹；
3. 如遇首次打开系统安全提示，请前往「系统设置 → 隐私与安全性」点击「仍要打开」。

1. Download and open `SilkPlayer-2.1.0-universal.dmg`;
2. Drag `SilkPlayer.app` into the `Applications` folder;
3. If prompted by macOS Gatekeeper, navigate to "System Settings → Privacy & Security" and click "Open Anyway".
