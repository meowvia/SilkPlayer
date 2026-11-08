# SilkPlayer 1.6.0 发布说明 (Release Notes)

## 中文版本

### 1. 版本概括
SilkPlayer 1.6.0 是一次聚焦于画质渲染重构、macOS 人机交互规范化及端内更新闭环的综合迭代版本。本版本全面升级了 HDR10 与杜比视界高光动态色调映射管线，彻底解决了大光比场景下的高光死白问题；偏好设置模块完全遵循 macOS HIG 规范完成三标签页重构；播放列表拉手实现边框贴合与极简透明线框；新增端内智能静默更新检测服务与无损覆盖升级能力；全面治理自动化测试焦点隔离，杜绝后台跑测对前台播放视窗的干扰。

### 2. 核心特性
- **HDR10 与杜比视界动态 EDR 高光软滚降色调映射**：
  - 动态获取当前屏幕物理头顶高度（EDR Headroom）并注入 Metal 片元着色器；
  - 严格以 ITU-R BT.2408 漫反射白电平（203 尼特，$Y \le 1.0$）为安全拐点，中低光 1:1 绝对保真直通；
  - 超高光区引入一阶导数连续的有理函数平滑滚降曲线，按感知亮度等比缩放 RGB 三通道，保护色彩饱和度与向阳细节，彻底根治蓝天白云死白过曝痛点；
  - 兼容 Apple Silicon XDR 屏幕与普通 SDR 屏幕自适应渲染。
- **偏好设置模块 macOS HIG 规范化全量重构**：
  - 聚焦收拢为通用（General）、播放（Playback）、关于（About）三大标准顶级标签页；
  - 视窗尺寸定格为 520 × 400 pt，采用标准表单两列键值排布，全 Tab 零纵向滚动条；
  - 100% 采用 macOS 官方标准界面术语，将底层硬解、防爆音与字幕加载收拢为系统默认保障；
  - 关于页面原生渲染官方真实品牌 AppIcon 矢量资产及 Universal Binary 架构标识。
- **播放列表侧边拉手边框贴合与极简透明线框重构**：
  - 彻底移除实心毛玻璃材质，底色 100% 镂空穿透，画面内容无遮挡；
  - 采用 1.0pt 单像素顶/左/底三边微轮廓线，右侧平齐闭合，窗口与全屏模式下均 0pt 贴紧边框；
  - 指示三角微调为 9.5pt 高度与 2.0pt 进深的微扁平箭头，进深收窄至 5.0pt，保留 20pt 交互热区。
- **智能静默更新检测与无损在位覆盖安装**：
  - 冷启动后台异步静默检测 GitHub Releases 最新版本；
  - 弹窗直观显示目标版本号（“发现新版本 x.x.x，是否立即更新？”），仅提供“是”与“否”两个选项；
  - 点击“否”立即启动 7 天免打扰门禁，同时在偏好设置“关于”Tab 图标常驻 6pt 微型红点；
  - 点击“是”端内完成当前架构 DMG 下载与在位覆盖安装，平滑重启，100% 完整保留用户播放历史、断点记忆与播放列表。
- **自动化测试抢焦隔离治理 (ISSUE-014)**：
  - 在窗口调度与全屏流转中增加测试运行态判定，测试环境下跳过全局激活与强制置前指令，前台观影零失焦闪烁。
- **策略与产品叙事规范化**：
  - 全面清理代码与文档中的绝对化词汇，确立“原生轻量与极简设计，无内置广告与冗余后台常驻进程”的长期产品原则。

### 3. 系统要求
- 操作系统：macOS 14.0 (Sonoma) 或更高版本；
- 硬件架构：Apple Silicon (M1/M2/M3/M4 系列芯片) 及 Intel 64 位处理器 (Universal Binary 原生双架构运行)。

### 4. 安装方式
1. 从 GitHub Releases 下载最新安装镜像（推荐 Universal 双架构镜像 `SilkPlayer-1.6.0-universal.dmg`）；
2. 双击打开 DMG 镜像，将 `SilkPlayer.app` 拖入 `Applications`（应用程序）文件夹；
3. 首次启动如遇系统安全提示，在“系统设置 - 隐私与安全性”中点击“仍要打开”即可。

---

## English Version

### 1. Summary
SilkPlayer 1.6.0 is a major update focused on video rendering architecture overhaul, macOS Human Interface Guidelines (HIG) compliance, and in-app silent update lifecycle. This release features an upgraded dynamic tone-mapping pipeline for HDR10 and Dolby Vision, eliminating highlight blowout in high dynamic range scenes; a complete redesign of the Settings window into 3 standard tabs with zero vertical scrollbars; a border-flush transparent wireframe drawer handle; a quiet in-app update service with lossless in-place overwrite upgrades; and automated test focus isolation to eliminate background test interference during playback.

### 2. Key Features
- **Dynamic EDR Tone-Mapping & Rational Highlight Roll-off**:
  - Dynamically injects physical display headroom (`cachedEDRHeadroom`) into Metal fragment shaders for HDR10 and Dolby Vision;
  - Standardizes on ITU-R BT.2408 diffuse white level (203 nits, $Y \le 1.0$) for 1:1 uncompressed absolute fidelity;
  - Introduces a $C^1$-continuous rational shoulder roll-off curve for extreme highlights, scaling RGB channels proportionally to preserve color saturation and cloud textures on both Apple XDR and SDR screens.
- **Native Settings HIG Architecture & Design Overhaul**:
  - Consolidated into 3 standard tabs: General, Playback, and About;
  - Standardized on 520 × 400 pt fixed geometry with zero vertical scrollbars;
  - 100% adoption of standard macOS terminology, moving foundational decoding and safety locks to automated defaults;
  - Native rendering of high-resolution vector AppIcon and Universal Binary architecture indicators in the About tab.
- **Playlist Drawer Handle Border-Flush & Wireframe Redesign**:
  - 100% transparent cutout eliminating visual obstruction;
  - 1.0pt single-pixel outline across top, left, and bottom edges, closing seamlessly flush against the right window border with zero padding;
  - Ultra-slender flattened indicator triangle (9.5pt height, 2.0pt depth) with a 20pt hit target.
- **Smart Silent Update & Lossless In-Place Overwrite Installer**:
  - Asynchronous background cold-start check against GitHub Releases;
  - Pop-up directly displays target version ("New version x.x.x is available. Update now?") with simple "Yes" and "No" options;
  - 7-day quiet cadence gatekeeper upon dismissal, with a persistent 6pt red dot badge on the Settings About tab;
  - In-place background downloader and overwrite updater replacing `/Applications/SilkPlayer.app` while 100% preserving all user history, playlists, and preferences.
- **Automated Testing Focus-Steal Isolation (ISSUE-014)**:
  - Guarded window activation and fullscreen transitions with testing environment checks, eliminating foreground window flashing and focus loss during automated test execution.
- **Policy & Narrative Standardization**:
  - Standardized product messaging to: "Native, lightweight, and minimal design with zero built-in ads and no redundant background processes."

### 3. Requirements
- Operating System: macOS 14.0 (Sonoma) or later;
- Architecture: Apple Silicon (M1/M2/M3/M4 chips) and Intel 64-bit processors (Universal Binary native dual-slice).

### 4. Installation
1. Download the installation DMG from GitHub Releases (Universal binary recommended: `SilkPlayer-1.6.0-universal.dmg`);
2. Open the DMG image and drag `SilkPlayer.app` into the `Applications` folder;
3. On first launch, if prompted by Gatekeeper, allow open in System Settings > Privacy & Security.
