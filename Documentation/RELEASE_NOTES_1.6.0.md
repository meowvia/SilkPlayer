# SilkPlayer 1.6.0 版本更新说明 / Release Notes

SilkPlayer 1.6.0 全面重构原生偏好设置中心并遵循 macOS HIG 规范，恢复断点进度记忆与双播放列表模式，升级 HDR10 与杜比视界动态 EDR 高光滚降色调映射，重构边框贴合的极简透明播放列表拉手，并新增端内静默更新检测服务。
SilkPlayer 1.6.0 overhauls the native Settings panel with macOS HIG compliance, restores playback breakpoint resuming and dual-playlist routing, upgrades HDR10 and Dolby Vision dynamic EDR tone-mapping, redesigns the border-flush transparent playlist drawer handle, and introduces in-app silent update detection.

---

## 核心特性 / Key Features

- **偏好设置模块 macOS HIG 规范化全量重构 (提案 018) / Native Settings HIG Architecture Overhaul (Proposal 018)**:
  - 遵循 macOS 人机交互指南规范，聚焦收拢为通用、播放、关于三大标准标签页，采用 520 × 490 pt 视窗尺寸与全面板零纵向滚动条；
    Consolidates preferences into 3 standard tabs (General, Playback, About) adhering to macOS HIG, standardized on 520 × 490 pt fixed dimensions with zero vertical scrollbars;
  - 通用设置新增全屏时钟 HUD 开关、外观模式切换、截图格式选择（PNG / JPEG）与自定义保存目录；
    General tab adds a Fullscreen Clock HUD overlay toggle, appearance switcher, and configurable screenshot formats (PNG / JPEG) with custom directory selection;
  - 播放设置恢复“记住播放进度”开关，保留“双播放列表模式”（音视频智能分流），支持最近播放历史保留与一键清空，新增快进/快退步长、鼠标滚轮行为绑定与双击操作配置；
    Playback tab restores "Resume Playback Progress" and "Dual Playlist Mode", adds playback history retention with one-click clearing, and introduces configurable seek steps, scroll wheel actions, and double-click behaviors;
  - 关于页面集成官方品牌矢量标识、Universal Binary 架构说明与底层规格参数卡片。
    About tab embeds the official brand vector emblem, Universal Binary architecture details, and core specification cards.
- **HDR10 与杜比视界动态 EDR 高光软滚降色调映射 (提案 013) / Dynamic EDR Tone-Mapping & Rational Highlight Roll-off (Proposal 013)**:
  - 动态获取当前屏幕物理头顶高度（EDR Headroom）注入 Metal 片元着色器；严格以 ITU-R BT.2408 漫反射白电平（203 尼特）为安全拐点，中低光 1:1 绝对保真直通；
    Dynamically injects display physical headroom (EDR Headroom) into Metal shaders, standardizing on ITU-R BT.2408 diffuse white level (203 nits) for 1:1 uncompressed absolute fidelity;
  - 超高光区引入一阶导数连续的有理函数平滑滚降曲线，按感知亮度等比缩放 RGB 三通道，保护色彩饱和度与向阳细节，彻底解决大光比场景高光死白问题。
    Introduces a C1-continuous rational shoulder roll-off curve for extreme highlights, scaling RGB channels proportionately to preserve saturation and textures, eliminating highlight blowout.
- **播放列表侧边拉手边框贴合与极简透明线框重构 (提案 019) / Playlist Drawer Handle Border-Flush & Transparent Stroke Redesign (Proposal 019)**:
  - 彻底移除实心毛玻璃材质，底色 100% 镂空穿透，画面内容无遮挡；
    Replaces solid materials with a 100% transparent cutout, eliminating visual blockage;
  - 采用 1.0pt 极简单像素顶/左/底三边微轮廓线，右侧平齐闭合，窗口与全屏模式下均 0pt 贴紧边框，指示三角进深收窄至 5.0pt。
    Features a 1.0pt delicate outline flush against the window border with zero padding, with the indicator triangle narrowed to 5.0pt.
- **智能静默更新检测与无损在位覆盖安装 (提案 020) / Smart Silent Update & Lossless In-Place Overwrite Installer (Proposal 020)**:
  - 冷启动后台异步检测 GitHub Releases 最新版本；提供简洁弹窗提示，点击“否”启动 7 天免打扰门禁并在关于页面保留微型红点；
    Features asynchronous background release checks against GitHub Releases with minimal binary prompts, a 7-day quiet cadence gatekeeper upon dismissal, and a persistent badge on the About tab;
  - 点击“是”端内完成当前架构 DMG 下载与在位覆盖安装，平滑重启，100% 完整保留用户播放历史、断点记忆与偏好设置。
    Performs end-to-end in-place DMG download and overwrite installation upon confirmation, smoothly restarting while 100% preserving all user history, playlists, and preferences.

---

## 系统要求 / Requirements

- **操作系统 / OS**: macOS 14.0 (Sonoma) 或更高版本
  macOS 14.0 (Sonoma) or later
- **架构支持 / Architecture**:
  - Universal 通用架构（推荐）：单安装包原生适配 Apple Silicon 与 64 位 Intel 芯片，免转译直接运行
    Universal Binary (Recommended): Single package natively supporting both Apple Silicon and 64-bit Intel Macs without translation
  - Apple Silicon (`arm64`)：原生支持 M 系列芯片
    Native support for Apple Silicon M-series chips
  - Intel (`x86_64`)：原生支持 64 位 Intel 处理器机型
    Native support for 64-bit Intel Mac models
- **图形与显示 / Graphics**: 支持 Metal 硬件加速与 HDR / EDR 显示技术
  Supports Metal hardware acceleration and HDR / EDR display technology

---

## 安装方式 / Installation

1. 根据您的偏好下载对应的安装镜像：
   Download the installation package matching your preference:
   - Universal 通用版本（推荐）：下载 `SilkPlayer-1.6.0-universal.dmg`（兼容所有 Apple Silicon 与 Intel 机型）
     Universal (Recommended): Download `SilkPlayer-1.6.0-universal.dmg` (Natively compatible with all Apple Silicon and Intel Macs)
   - Apple Silicon 机型专用：下载 `SilkPlayer-1.6.0-arm64.dmg`（体积更小，仅适配 M 系列芯片）
     Apple Silicon: Download `SilkPlayer-1.6.0-arm64.dmg` (Smaller size, tailored for M-series chips)
   - Intel 机型专用：下载 `SilkPlayer-1.6.0-x86_64.dmg`（仅适配 Intel 芯片）
     Intel: Download `SilkPlayer-1.6.0-x86_64.dmg` (Tailored for Intel-based Macs)
2. 双击打开下载的 DMG 镜像文件。
   Double-click the DMG disk image to mount it.
3. 将 `SilkPlayer.app` 拖入 `Applications`（应用程序）文件夹即可完成安装。
   Drag `SilkPlayer.app` into your `Applications` folder to complete installation.
