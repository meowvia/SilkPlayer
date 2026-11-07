# SilkPlayer 1.5.0 版本更新说明 / Release Notes

## 简体中文

SilkPlayer 1.5.0 新增交互式音量微调与起播防破音，支持批量剧集自然语义排序，正式提供 Universal 通用双架构镜像，深度优化 4K 高码率与纯音频渲染开销，并全面修复了视窗交互状态缺陷。

### 核心特性

1. 功能更新
- Universal 通用二进制：单安装包原生内嵌 arm64 与 x86_64 双架构，适配 Apple Silicon (M1-M4) 与 Intel 芯片，免转译直接运行。
- 交互式音量微调：悬停展开精度滑块调节音量；引入平滑渐变算法，消除起播与调音瞬态杂音。
- 剧集自然语义排序：递归扫描多层目录扁平化提取媒体，智能识别剧集编号与标签，解决多集乱序错位。

2. 性能优化
- 4K 高码率降耗：优化缓存策略大幅降低 4K 常驻显存；引入条件变量消除 busy-wait 损耗；待机自动停止重绘。
- 纯音频轻量渲染：移除实时高斯模糊降低 CPU 负载；频谱采样降频至 20Hz 并增加动态阈值过滤。

3. 缺陷修复
- 修复置顶、手动拉伸或取消置顶后特定场景双击无法全屏的问题。
- 修复铺满最大化按 Esc 误退出播放的问题，准确缩回原普通尺寸。
- 修复纯音频模式手动拉伸窗口时的边框抖动。

### 系统要求
- 操作系统：macOS 14.0 (Sonoma) 或更高版本
- 架构支持：Universal 通用（推荐）、Apple Silicon (M1-M4)、Intel 64 位
- 图形显示：支持 Metal 硬件加速与 HDR / EDR 显示

### 安装方式
1. 下载 DMG 镜像（推荐 Universal 通用版 SilkPlayer-1.5.0-universal.dmg）。
2. 打开 DMG，将 SilkPlayer.app 拖入 Applications（应用程序）文件夹即可完成安装。

---

## English

SilkPlayer 1.5.0 introduces interactive volume slider adjustments with pre-play pop protection, global natural semantic sorting for multi-folder episode imports, official Universal binary release images natively supporting both Apple Silicon and Intel architectures, deep memory and CPU optimizations for 4K high-bitrate video and pure audio playback, along with comprehensive fixes for window interaction defects.

### Key Features

1. Functional Updates
- Universal Binary Distribution: Native dual-slice images containing arm64 and x86_64, executing natively on Apple Silicon (M1-M4) and Intel Macs without Rosetta 2 translation.
- Interactive Volume Slider & Safe Audio Ramp: Hovering expands a slider for granular volume adjustments; volume ramp algorithm eliminates transient pop noises during initial playback and seek.
- Global Natural Semantic Sorting: Recursive multi-folder scanning with flat media extraction; recognizes episode tags (e.g., S01E01, EP02) to preserve natural sequence.

2. Performance Optimizations
- 4K Video Memory & Pipeline Overhead Reduction: Optimized continuous playback frame caching, slashing resident memory footprint for 4K 10-bit media; introduced condition variables in demuxing to eliminate busy-waiting; pauses glow rendering during idle/pause states.
- Pure Audio Rendering Efficiency: Removed real-time Gaussian blur calculations from album art and glow rendering; throttled spectrum sampler to 20Hz with dynamic threshold deadzone filtering.

3. Bug Fixes
- Fixed a state deadlock where double-clicking failed to enter fullscreen after toggling always-on-top or manual resizing.
- Fixed an issue where pressing Esc in fill-maximized mode exited playback, accurately restoring normal window dimensions.
- Fixed window border jitter during manual window resizing in pure audio mode.

### Requirements
- Operating System: macOS 14.0 (Sonoma) or later
- Architecture: Universal Binary (Recommended), Apple Silicon (M1-M4), Intel 64-bit
- Graphics: Metal hardware acceleration & HDR / EDR display support

### Installation
1. Download the preferred installation image from GitHub Releases (Universal binary recommended).
2. Open the downloaded DMG file.
3. Drag SilkPlayer.app into the Applications folder.
