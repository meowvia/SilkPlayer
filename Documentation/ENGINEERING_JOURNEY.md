# SilkPlayer Engineering Journey & Technical Development Log

This document records the architectural evolution, technical challenges, and iterative problem-solving milestones of the SilkPlayer project from its inception to the v1.0.0 milestone.

---

## 1. Architectural Genesis & The Memory Bottleneck

### 1.1 The Legacy Paradigm & Initial Diagnostics
At the onset of the project, early implementations and prototypes relied on high-level wrappers around legacy playback abstractions. Initial profiling on Apple Silicon hardware revealed significant bottlenecks:
- **Excessive Resident Memory**: 4K video playback frequently pushed resident physical footprint (`phys_footprint`) upwards of 700MB to 850MB.
- **Rendering Overhead**: Intermediate texture copies and unconstrained CALayer redraw loops introduced GPU memory pressure and frame presentation jitter.
- **Decoder Lifecycles**: Decoder contexts and frame buffers failed to purge deterministically when stopping playback or switching files, resulting in creeping memory accumulation.

### 1.2 Migration to Native CAMetalLayer & Zero-Copy Pipeline
To resolve these architectural limitations, SilkPlayer abandoned legacy layer wrappers in favor of a direct, zero-copy Metal graphics pipeline:
- Integrated Apple **VideoToolbox** hardware decompression feeding decoded `CVPixelBuffer` frames backed by native `IOSurface` handles.
- Mapped decoded `IOSurface` planes directly to Metal textures (`MTLTexture`) using `device.makeTexture(descriptor:iosurface:plane:)`, completely eliminating CPU-to-GPU pixel buffer duplication.
- Wrapped high-frequency per-frame render routines inside autorelease pools and bound Metal pipeline states to static singletons.
- **Result**: Memory management and rendering pipeline efficiency were significantly improved, effectively mitigating memory accumulation and rendering jitter during extended 4K playback.

---

## 2. Audio Subsystem & Scrubber Traps

### 2.1 Atmos & Multi-Channel Stream Direct Path
Initial playback of high-bitrate multi-channel audio tracks (such as Dolby TrueHD Atmos 7.1 and DTS-HD Master Audio) occasionally exhibited acoustic crackle or packet desynchronization during stream initiation.
- **Remedy**: Streamlined audio sample delivery by bypassing non-linear intermediate audio filters and routing decoded LPCM packets directly through the native `AVFoundation` hardware pipeline.
- Synchronized audio and video clocks with microsecond-precision presentation timestamps (`PTS`), guaranteeing lip-sync fidelity.

### 2.2 Scrubber Freedom vs. Chapter Bounds Traps
In files containing embedded chapter metadata, early scrubber implementations were constrained by aggressive snapping heuristics, inadvertently forcing user seek operations to lock onto chapter boundaries rather than arbitrary user-specified timestamps.
- **Remedy**: Decoupled timeline UI scrubbing from chapter navigational marks. Scrubber dragging now affords absolute, millisecond-accurate seeking across the entire timeline while retaining chapter markers as purely passive visual indicators.

---

## 3. The Dolby Vision Profile 5 (IPTPQc2) Reverse-Engineering Milestone

### 3.1 Problem Statement: The "Purple / Green" Discoloration
Dolby Vision Profile 5 (`dvhe.05` / `dvh1.05`) is widely used by major streaming services. Unlike standard HDR10 or Dolby Vision Profile 8, Profile 5 does not employ traditional Rec.2020 YCbCr color encoding. Instead, it utilizes:
- A proprietary **IPTPQc2** non-linear color space.
- Dynamic Reference Processing Unit (**RPU**) reshaping metadata transmitted via frame side data.
- Absence of standard backward-compatible SDR/HDR10 base layers.

When rendered by players lacking Profile 5 demuxing and shader reshaping (such as standard non-tone-mapped playback pipelines), the video presents an intense, unwatchable magenta/green color distortion.

### 3.2 Engineering the Metal Fragment Pipeline
SilkPlayer resolved this challenge by engineering a complete, hardware-accelerated Profile 5 reshaping pipeline in native Metal Shading Language (`MSL`):
1. **RPU Demuxing & Parsing**:
   - Intercepted `AV_FRAME_DATA_DOVI_METADATA` packets from demuxed video streams.
   - Designed a fail-safe initializer (`DolbyVisionReshapeUniforms.init?`) parsing non-linear offset vectors, 3x3 color transformation matrices, and dynamic polynomial curves (`coeffs` and `pivots`) across luma ($I$) and chroma ($P$, $T$) channels.
   - Dynamically calculated base-layer bit depth (`bl_bit_depth`, typically 10-bit with normalization divisor 1023.0).
2. **GPU Fragment Processing (`displayYCCTexture`)**:
   - Handled non-linear offset subtraction and piece-wise polynomial reshaping directly on the GPU.
   - Applied the strict color matrix conversion order: non-linear IPTPQc2 space $\to$ LMS color space $\to$ Perceptual Quantizer (PQ, SMPTE ST 2084) inverse transformation $\to$ Rec.2020 linear RGB $\to$ Display P3 target space.
3. **Verification**:
   - Validated against standard reference UHD streaming remuxes and color test patterns. Skin tones and primary branding colors render with natural balance, closely matching reference outputs.
   - *Technical Boundary Note*: While verified on standard reference streams, community validation across atypical containers and extreme bitrates remains an ongoing open-source benchmark.

---

## 4. Subtitle Typography & CJK Composite Glyph Remediation

### 4.1 Root Cause of the "Lego Wireframe" Artifact
During playback of multi-language releases with embedded text subtitles (SRT, WebVTT, ASS), Chinese/Japanese/Korean (CJK) characters rendered via Apple AppKit / CoreText with `.strokeWidth` attributes exhibited severe internal black intersecting lines (dubbed "Lego wireframe artifacts").
- **Technical Cause**: In AppKit CoreText, complex ideographs (such as PingFang SC) are synthesized from multiple overlapping vector contours. Invoking vector stroke drawing on composite glyphs outlines each constituent sub-contour individually, exposing inner intersecting structural lines.

### 4.2 Two-Pass 8-Directional Solid Fill Dilation (Pure Fill Dilation)
To permanently eliminate inner outline cross-stitching while preserving high-contrast legibility across bright HDR scenes:
1. **Zero Stroke Policy**: Completely removed `.strokeWidth` from all attributed string pipelines.
2. **Two-Pass Solid Fill Dilation**:
   - Evaluated solid black fill text (`blackAttrText`) across 8 discrete Cartesian offset vectors: $(\pm d, 0)$, $(0, \pm d)$, and $(\pm d, \pm d)$ where step $d = \max(1.5, \text{fontSize} \times 0.035)$.
   - Because standard solid fills utilize non-zero winding union rules, overlapping internal contours naturally fuse into a unified silhouette with zero internal intersecting lines.
3. **Ambient Drop Shadow & Core Fill**:
   - Superimposed a soft high-contrast ambient drop shadow for bright backgrounds.
   - Rendered centered pure white fill text (`whiteAttrText`) over the origin.
4. **Descender Margin Guard**: Expanded bounding box margins to encompass font descenders ($\text{abs}(\text{descender})$), ensuring characters with downward strokes (`g, j, p, q, y` and CJK base strokes) never suffer viewport clipping.
5. **Memory Cache**: Bound generated subtitle images to an 8-entry thread-safe LRU cache (`SubtitleImageCache`), bounding memory consumption within ~5MB and recycling allocations instantly upon media termination.

---

## 5. macOS 15 Sequoia Video-Adaptive Split Screen Tiling

### 5.1 Native WindowServer Drag Handoff
In earlier builds, dragging the playback canvas was handled via manual window origin mutations (`window.setFrameOrigin`). Consequently, macOS WindowServer was unaware of the user-initiated drag session, completely inhibiting macOS 15 Sequoia native screen edge snapping and tiling previews during playback.
- **Remedy**: Routed canvas movement exceeding a 3.0pt stationary threshold to `window.performDrag(with: event)`. This seamlessly transfers the drag session to WindowServer, enabling native Sequoia edge-collision detection and translucent split-screen snap guides.

### 5.2 Resolution-Adaptive Aspect-Ratio Geometry (Adaptive Tiling)
Standard macOS window tiling stretches docked windows to 50% width and 100% height. For a 16:9 or 2.39:1 widescreen video, this forces unnecessary black letterbox bars on the top and bottom.
- **Adaptive Solution**: In `PlayerWindowDelegate.windowWillResize`, SilkPlayer intercepts tiling requests and adaptively calculates the target height from the video's intrinsic aspect ratio:
  $$\text{targetHeight} = \text{round}\left(\frac{\text{targetWidth}}{\text{baseAspect}}\right)$$
- If the video is landscape, the window hugs the video height without vertical letterbox bars, vertically centering itself within the docked display partition in `windowDidResize`.
- When the player is idle (no video loaded), it conforms to standard full-column tiling.

---

## 6. Strict Swift 6 Concurrency & Zero Data-Race Safety

SilkPlayer is fully compiled under the Swift 6 compiler with complete strict concurrency checking enabled (`.swiftLanguageMode(.v6)`):
- All AppKit and SwiftUI UI components, window delegates, and state models are isolated to `@MainActor`.
- Asynchronous tasks and background frame extractors operate within dedicated `actor` types (`BackgroundFrameExtractor`).
- Inter-thread communication relies strictly on `Sendable` value types, eliminating data races across playback pipelines.

---

## 7. 时间轴悬停预览引擎 (SilkThumb Engine)

### 7.1 FFmpeg C 接口绑定与按需关键帧检索
为了支持 MKV、TS、FLV 等非系统原生容器的快速抽帧，SilkPlayer 实现了轻量高效的 `SilkThumb Engine` (`SilkThumbnailEngine`) 模块：
- **C 接口轻量绑定**：通过 Swift 直接调用 FFmpeg 底层（`libavformat`、`libavcodec`、`libswscale`），在后台工作队列中执行关键帧定位（Keyframe Seek）。
- **媒体容器覆盖**：覆盖 MP4, MKV, MOV, WebM, TS, M2TS, AVI, FLV, ProRes 等常见封装。

### 7.2 HDR10 与杜比视界色调映射
在标准动态范围显示器上预览 HDR 帧时，直接转换往往会导致画面色彩失真或偏暗：
- **SMPTE ST 2084 (PQ) 查找表 (LUT)**：建立 4096 级快速电平查询表，减少浮点指数运算开销。
- **BT.2020 到 BT.709 转换矩阵**：
  $$\begin{bmatrix} R_{709} \\ G_{709} \\ B_{709} \end{bmatrix} = \begin{bmatrix} 1.6605 & -0.5876 & -0.0728 \\ -0.1246 & 1.1329 & -0.0083 \\ -0.0182 & -0.1006 & 1.1187 \end{bmatrix} \begin{bmatrix} R_{2020} \\ G_{2020} \\ B_{2020} \end{bmatrix}$$
- **Reinhard 亮度压缩**：引入色调映射曲线，尽量保留高光和阴影部分的可视细节。
- **杜比视界 Profile 5 适配**：针对 IPTPQc2 信号进行灰阶与亮度抽取，改善默认解码可能产生的偏色与黑屏。

### 7.3 内存位图直显与画框交互优化
- **BGRA 格式匹配**：将解码后像素与 macOS `DeviceRGB` 内存布局对齐，直接构建 `CGDataProvider` 与 `NSBitmapImageRep`，避免磁盘中间文件读写。
- **固定 16:9 画框与缓存机制**：采用 `156 × 88` 固定尺寸预览画布，避免因尺寸频繁重算导致的界面跳动，并结合缓存锁减少光标滑过时的视觉闪烁。

---

## 8. Open Source Dependencies & Acknowledgements

SilkPlayer builds upon foundational open-source media technologies and gratefully acknowledges:

1. **[FFmpeg](https://ffmpeg.org)** / **[FFmpegKit](https://github.com/arthenica/ffmpeg-kit)** (LGPL-3.0 / GPL-3.0) — Container demuxing, audio decoding, and subtitle parsing.
2. **[libplacebo](https://code.videolan.org/videolan/libplacebo)** & **[mpv](https://github.com/mpv-player/mpv)** (LGPL-2.1+ / GPL-2.0+) — Reference color science and IPTPQc2 transform research.
