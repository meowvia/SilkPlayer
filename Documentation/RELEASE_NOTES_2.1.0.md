# SilkPlayer 2.1.0 版本更新说明 / Release Notes

## 版本概括 / Overview

SilkPlayer 2.1.0 重点解决了长期困扰日常使用的几个痛点体验：彻底消除了双击视频时误打开多个多余空白窗口的缺陷；全面重构了横竖屏视频的开窗大小，告别小屏看不清字幕与竖屏缩小成缩略图的糟糕体验；音量支持最高放大至 200%；精简优化了界面控件与 Pro 影视库交互；同时解决了全屏切换时可能引发的系统卡死与退回登录界面的严重稳定性问题。

SilkPlayer 2.1.0 focuses on resolving key day-to-day usability pain points: permanently eliminating redundant blank windows when opening videos from Finder; fully redesigning default window sizes for horizontal and vertical videos to fix cramped subtitle reading and tiny vertical video windows; extending maximum volume up to 200%; refining interface controls and Pro Media Library interactions; and eliminating critical system freezes and logout crashes during fullscreen Space transitions.

---

## 核心体验改进与优化 / Key Improvements & Optimizations

### 1. 视窗与打开体验 [通用] / Window & Launch Experience [Standard]
- 解决打开视频多弹空白窗口的问题 / Eliminate Extra Blank Windows on Launch:
  修复在访达（Finder）双击或右键打开视频时，经常会额外弹出一个多余空白窗口并伴随闪烁的现象。
  Fixed an issue where opening videos from Finder via double-click or context menu would frequently spawn an unwanted extra blank window with transient screen flicker.
- 解决重复打开同一视频多开窗口的问题 / Prevent Duplicate Windows for the Same Video:
  如果某个视频已经在播放，再次打开它时会自动聚焦切换到该窗口，不再重复开启新窗口。
  Opening a video that is already playing now automatically brings its existing window to focus instead of spawning a duplicate window.
- 消除打开视频时欢迎界面的瞬态闪烁 / Eliminate Welcome Screen Flicker on Launch:
  双击视频直接流畅进入播放，不再出现拖拽界面的瞬间闪白。
  Launching external media files now opens smoothly directly into playback without a transient flash of the drop-zone welcome screen.

### 2. 画面与视窗比例重构 [通用] / Canvas & Window Sizing Overhaul [Standard]
- 优化横屏视频默认开窗大小 / Optimized Default Horizontal Window Sizing:
  解决在 13~14 寸 MacBook 等小屏设备上默认开窗过小、字幕辨识困难的问题。默认播放尺寸由原先的 55% 提升至 70%，画面更舒展，且大幅减少了上下控制栏对视频主体的遮挡。
  Resolved the issue of cramped default windows and poor subtitle readability on 13-14 inch MacBooks. The default window width ratio is upgraded from 55% to 70%, delivering a more spacious picture while significantly reducing HUD overlay on video content.
- 重构竖屏视频播放体验 / Overhauled Vertical Video Playback:
  解决竖屏短视频打开时严重缩水、变成难以看清的微型小窗口的问题。现在竖屏视频默认撑满屏幕可用高度，并锁定最小宽度。
  Resolved the issue where vertical short videos shrank into tiny, unreadable thumbnail windows. Vertical videos now vertically fill the entire available screen height by default with a locked minimum width.
- 精简竖屏视频顶部遮挡 / Streamlined Vertical Video Top Bar:
  竖屏播放时自动隐藏居中的长标题和参数标签，仅保留最简返回与置顶按钮，防止横条遮盖竖屏人物面部或字幕。
  Automatically hides the center title capsule and format badges during vertical video playback, keeping only the pin and return buttons to prevent controls from obstructing video subjects or subtitles.

### 3. 声音体验升级 [通用] / Audio Experience Upgrades [Standard]
- 支持音量最高放大至 200% / Up to 200% Volume Boost:
  解决部分电影或录像本身声音偏小、即便将 Mac 系统音量拉到最大依然听不清的痛点，并内置防破音处理，音量偏好支持自动记忆。
  Added up to 200% volume amplification to resolve low-volume source videos that remained hard to hear even at max system volume, featuring built-in distortion protection and persistent volume settings.

### 4. 界面交互细节优化 [通用] / Interface Refinements [Standard]
- 精简播放器右上角返回按钮 / Streamlined Top-Right Return Button:
  将原本写着汉字“返回”的悬浮按钮，替换为更小巧清爽的圆圈小箭头，视觉更统一。
  Replaced the text "返回" button in the top-right corner with a clean, compact circular chevron icon that visually aligns with adjacent controls.
- 修复偏好设置顶部标签点击不灵敏的问题 / Responsive Settings Tab Navigation:
  解决之前点击设置顶部切换按钮时，只有精准点到文字才有反应、点文字旁边空白处无法切换的问题，现在整个选项区域均可随心点击。
  Fixed an issue where settings navigation tabs only registered clicks directly on the text; the entire tab rectangular area is now 100% clickable.
- 优化播放列表侧边拉手显示 / Refined Playlist Drawer Handle:
  修复播放列表展开把手在部分 Mac 屏幕上边缘发虚、泛白刺眼的问题，光标划过时反馈更平滑。
  Fixed harsh white haloing and blurry edges on the playlist drawer handle across certain Mac displays, providing smoother hover feedback.
- 修复小窗口播放时提示文字被切断的问题 / Fixed Tooltip Clipping on Edge Buttons:
  解决小窗口模式下，鼠标悬停在左右边缘按钮上弹出的提示文字被窗口边框切掉一半的问题。
  Fixed an issue where hover tooltips for leftmost and rightmost controls were partially clipped by the window edges in compact window mode.

---

## 缺陷修复与稳定性提升 / Bug Fixes & Stability Improvements

### 1. 影视媒体库交互优化 [Pro 专属] / Pro Media Library Refinements [Pro]
- 去除影视库拉伸窗口时的无用提示 / Suppressed Aspect Ratio HUD in Media Library:
  修复在媒体库浏览海报墙或查看影片详情时，拖动调节窗口大小画面中间会误跳出“16:9”等视频比例黑框的干扰问题。
  Fixed an issue where resizing the window while browsing posters or movie details erroneously popped up aspect ratio overlays (e.g. 16:9) in the center of the screen.
- 精简电影卡片右键菜单 / Simplified Movie Poster Context Menu:
  删除了右键菜单中多余且容易引起混淆的“标记已看”和“重置未看”选项。想要重新观看，直接右键点击“从头播放”，或在“继续观看”卡片上点击右上角的叉号移除即可。
  Removed redundant and confusing "Mark as Watched" and "Mark as Unwatched" options from movie context menus. To reset progress, simply right-click "Play from Beginning" or click the dismiss button on the Continue Watching card.
- 简化剧集海报集数显示 / Simplified TV Series Episode Count Badges:
  单季剧集右上角角标由原本繁琐的“1 季 · 12 集”直接简化为清爽直观的“12 集”（英文显示为 12 Eps）。
  Streamlined single-season TV badges from verbose "1 季 · 12 集" to clean "12 集" ("12 Eps"), keeping multi-season formats clear.

### 2. 系统级稳定性修复 [通用] / System Stability Fixes [Standard]
- 解决全屏切换导致系统卡顿甚至注销闪退的严重缺陷 / Resolved Fullscreen Freeze & WindowServer Logout Crash:
  彻底修复在频繁进入/退出全屏、多显示器切换或隔空播放时，因画面渲染与系统动画冲突导致整个 Mac 界面卡死、鼠标转彩虹圈甚至直接退回系统登录界面的严重稳定性问题。
  Completely resolved a critical bug where rapid fullscreen transitions, multi-display switching, or AirPlay caused rendering conflicts with macOS system animations, leading to system hangs, spinning beachballs, or abrupt logouts back to the lock screen.

---

## 系统要求 / Requirements

- 操作系统 / OS: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- 芯片架构 / Architecture: Universal 通用二进制（原生支持 Apple Silicon 与 Intel 64 位芯片）/ Universal Binary (Apple Silicon & Intel 64-bit)
- 图形要求 / Graphics: 支持 Metal 硬件加速与 HDR 显示输出 / Metal hardware acceleration & HDR display supported

---

## 安装方式 / Installation

1. 下载并打开 `SilkPlayer-2.1.0-universal.dmg`；
2. 将 `SilkPlayer.app` 拖入 `Applications`（应用程序）文件夹；
3. 首次打开如遇系统安全提示，请前往「系统设置 → 隐私与安全性」点击「仍要打开」。

1. Download and open `SilkPlayer-2.1.0-universal.dmg`;
2. Drag `SilkPlayer.app` into the `Applications` folder;
3. If prompted by macOS Gatekeeper on first launch, navigate to "System Settings → Privacy & Security" and click "Open Anyway".
