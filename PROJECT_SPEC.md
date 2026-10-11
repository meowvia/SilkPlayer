# SilkPlayer 项目技术规格书

> 一款专为 macOS 设计的本地媒体播放器，基于 Swift 6 与 Apple 原生框架构筑。

---

## 1. 核心技术选型
- **目标平台**: macOS 14.0+ (Sonoma / Sequoia)
- **目标架构**: Apple Silicon (arm64 独占)
- **开发语言**: Swift 6 (Strict Concurrency 严格并发检查)
- **界面体系**: SwiftUI + AppKit 深度集成 (遵循 Apple 人机交互指南)
- **专有核心库**: SilkCoreKit.xcframework (物理闭源隔离)
  - **回放核心**: SilkPlayback Engine (纯 Swift 6 严格并发架构 + VideoToolbox 硬件加速解码)
  - **渲染核心**: SilkRender Pipeline (CAMetalLayer 纹理直显 + Metal 3 着色器 + 杜比视界 Profile 5 RPU 动态色彩重塑)
  - **抽帧核心**: SilkThumb Engine (轻量高效按需关键帧检索 + 两级内存 LRU 缓存)
- **媒体监控**: FSEvents 异步文件系统变更监控
- **元数据与存储**: 结构化原子持久化索引 + 内存与磁盘两级 LRU 缩略图缓存

---

## 2. 核心产品原则
1. **格式兼容性**: 基于自研解复用调度与 VideoToolbox / FFmpeg 核心解码，支持常见音视频容器格式（MKV, MP4, MOV, WebM, AVI, TS, M2TS 等）、主流视频编码（H.264, HEVC, AV1, VP9, ProRes 等）、多声道音频编码（TrueHD, DTS-HD MA, AC3, E-AC3, FLAC, AAC 等）及字幕格式（ASS/SSA, PGS, SRT, WebVTT 等）。
2. **能效与内存控制**: 基于 CAMetalLayer 硬件纹理直显，优化解码与渲染管线数据流转，持续控制系统开销与内存占用。
3. **原生设计规范**: 遵循 Apple HIG 窗口与交互标准，半透明毛玻璃播控 HUD，集成式侧边抽屉，原生多标签偏好设置。
4. **隐私保护**: 本地单机运行，无网络遥测数据收集。
5. **挂载卷与外部存储支持**: 支持本地磁盘、外置存储及通过 Finder 挂载的网络共享卷（SMB/NFS）。

---

## 3. 开发阶段与里程碑
- [x] **Phase 1: 核心播放原型验证** (基础硬解与播放管道验证)
- [x] **Phase 2: 原生播放界面开发** (拖拽交互、播控栏、快捷键、音轨与字幕选择)
- [x] **Phase 3: 本地媒体库索引** (FSEvents 变更监控、递归扫描与元数据持久化)
- [x] **Phase 4: 播放列表与连续播控** (自动切集、播放进度持久化与断点续播)
- [x] **Phase 5: 架构解耦与偏好设置** (状态流与渲染解耦、结构化偏好设置)
- [x] **Phase 6: 外置与网络挂载卷优化** (外置驱动器与 SMB 挂载卷流式缓冲优化)
- [x] **Phase 7: 窗口系统与全屏管理** (多窗口拓扑管理、空间集合行为规范)
- [x] **Phase 8: 工程化与协议合规就绪** (GitHub 规范配置、双语文档、LGPL-3.0 许可协议、自动化测试)
- [x] **Phase 9: 自研播放架构重构** (落地自研 Native SilkPlayback Engine + VideoToolbox + CAMetalLayer 硬件加速管线)
- [x] **Phase 10: 窗口交互规范、全格式字幕引擎** (窗口原生等比缩放、蓝光 PGS 标准画布归一化与文本字幕自适应大字号、光标自动隐去、全套自动化测试 480 项断言全部通过)
- [x] **Phase 11: 时间轴悬停预览与基础色彩映射** (实现基于底层 FFmpeg C 接口的按需抽帧预览，支持 MP4、MKV 等常见容器关键帧检索，加入针对 HDR10 与杜比视界 Profile 5/8 的基础色调映射，优化 16:9 预览画框与平滑缓存)
- [x] **Phase 12: 自研原生三大核心主干合并与性能调优** (清空旧框架依赖，落地纯 Swift 6 严格并发管线，开启 CAMetalLayer.framebufferOnly 硬件直显，循环 autoreleasepool 内存优化，480 项自动化测试全绿验证)
- [x] **Phase 13: 纯净 LGPL-3.0 动态 XCFramework 架构迁移与闭源合规 (v1.0.0 发布基线)** (消除 --enable-gpl 传染性，构建纯净轻量动态核心库，完成 @rpath 动态加载与分层代码签名，实现商业闭源合规与三大核心统合)
