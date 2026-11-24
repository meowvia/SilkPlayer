# SilkPlayer 2.1.1 发布说明 / Release Notes

## 版本概括 / Overview
SilkPlayer 2.1.1 是一次专注于高规格媒体播放性能优化与色彩渲染修复的重要更新。本版本全面重构了 4K 及 8K 超高清片源的缓冲流控机制，显著降低了长时间播放时的内存与显存消耗；同时彻底修复了杜比视界 Profile 8.4 (HLG) 的高光过曝与色阶误判缺陷，确保极端码率下的流畅输出与色彩精准还原。

SilkPlayer 2.1.1 is an essential update focused on high-specification media playback performance optimization and color rendering fixes. This release completely refactors the buffer flow control architecture for 4K and 8K Ultra-HD content, significantly reducing system and GPU memory consumption during extended playback. It also resolves highlight overexposure and color range misdetection in Dolby Vision Profile 8.4 (HLG), ensuring smooth output and precise color fidelity even at extreme bitrates.

---

## 优化与改进 / Optimizations & Improvements

### 4K 与 8K 超高清播放性能与内存控制 / 4K & 8K Ultra-HD Performance and Memory Management
- **中文**：全面重构了高规格视频的缓冲调度与内存流控机制，大幅降低播放 4K 高码率及 8K 超高清片源时的系统内存与显存占用，彻底杜绝内存随播放时长持续增长，长时间大文件播放更加轻盈稳定。
- **English**: Overhauled the buffer scheduling and stream flow control architecture for high-spec media, substantially reducing system and GPU memory footprint during 4K high-bitrate and 8K Ultra-HD playback to ensure lightweight, sustained operation without memory accumulation.

### 极限高码率播放流畅度与拖拽响应 / Smooth Extreme Bitrate Playback and Responsive Seeking
- **中文**：优化了硬件解码与渲染管线的衔接效率，面对数百兆码率的极限片源依然保持平稳流畅；大幅提升了进度条任意拖拽（Seek）的响应速度，全程稳定零丢帧。
- **English**: Streamlined handoff efficiency between hardware decoding and the rendering pipeline, maintaining smooth playback across extreme bitrates (hundreds of Mbps) with rapid timeline seeking and zero dropped frames.

### 切片与轨道切换资源周转 / Stream and Track Switching Resource Turnover
- **中文**：提升了切换音轨、字幕或切换下一部视频时的底层资源回收效率，切换过渡干脆利落，消除界面延迟与卡顿感。
- **English**: Improved resource recycling during audio/subtitle track changes and playlist transitions, delivering prompt transitions without interface latency or stutter.

---

## 问题修复 / Bug Fixes

### 杜比视界 Profile 8.4 与 HLG 色彩过曝 / Dolby Vision Profile 8.4 & HLG Color Overexposure
- **中文**：修复了 iPhone 录制及特定流媒体 Profile 8.4 视频高光惨白、过曝泛白的问题，准确还原画面原本的明暗层次与色彩细节。
- **English**: Resolved highlight overexposure and washed-out visuals in iPhone-recorded and streaming Profile 8.4 content, accurately restoring highlight hierarchy and dynamic range.

### 色彩与色阶范围误判 / Color and Dynamic Range Misdetection
- **中文**：修复了部分视频全色阶（Full Range）暗部发灰以及特定 SDR 片源被误判为 HDR 导致的偏色缺陷，画面黑位与色彩表现更加扎实精准。
- **English**: Corrected Full Range dark-level elevation and false HDR routing on specific SDR sources, delivering accurate black levels and color fidelity.

---

## 系统要求 / System Requirements
- **macOS**：macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- **架构 / Architecture**：Universal 胖二进制（原生支持 Apple Silicon M 系列与 Intel 64 位芯片） / Universal binary (Native support for Apple Silicon M-series and Intel 64-bit processors)
- **推荐硬件 / Recommended Hardware**：配备 Apple Silicon 芯片（M1 / M2 / M3 / M4 系列）的 Mac 设备以获得最佳硬件解码与 Metal 渲染效能 / Mac with Apple Silicon (M1/M2/M3/M4) for optimal hardware decoding and Metal rendering efficiency

---

## 安装方式 / Installation
1. 下载 `SilkPlayer-2.1.1-universal.dmg` 安装镜像；
2. 双击打开镜像，将 `SilkPlayer.app` 拖移至 `Applications`（应用程序）文件夹即可完成安装。

1. Download the `SilkPlayer-2.1.1-universal.dmg` installer image;
2. Open the DMG image and drag `SilkPlayer.app` into your `Applications` folder to complete installation.

### 校验和 / Checksum
- **SHA-256**: `6f1898d75846143a711c3e8ce79e8186c276504d56f8d48629640ce0853144b8`
