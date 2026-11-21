# SilkPlayer 2.0.1 版本更新说明 / Release Notes

## 版本概括 / Overview

SilkPlayer 2.0.1 是一个稳定性与核心解码管线紧急修复补丁，重点修复了 AV1 10-bit 编码格式视频有声音无画面且时间轴停滞的问题，优化了音视频主时钟同步防丢帧死锁机制，并完善了冷启动版本更新提示在主界面的呈现与播放态免打扰逻辑。
SilkPlayer 2.0.1 is a stability and playback pipeline hotfix release. It resolves an issue where 10-bit AV1 videos played audio without video output or progress tracking, improves master clock synchronization against drop-frame deadlocks, and refines cold-start update prompt presentation to prevent interrupting active playback.

---

## 核心特性 / Key Features

- AV1 10-bit 解码与渲染修复 / AV1 10-bit Decoding & Rendering:
  彻底移除 AV1 假硬件解码路径，统一路由至高性能 libdav1d 多线程切片软解码器，直通原生 YUV 渲染管线，彻底修复特定 AV1 影片黑屏且时间轴停滞问题。
  Eliminated simulated hardware decoding fallbacks for AV1, routing all AV1 streams directly to high-performance libdav1d multi-threaded slice decoding to resolve black screens and frozen progress bars.

- 音视频主时钟防丢帧死锁 / Master Clock Anti-Deadlock Sync:
  重构大时钟差丢帧逻辑，设置连续丢帧上限并引入音频时钟平滑重锚定，杜绝严重落后时陷入无限丢帧死锁。
  Restructured large-delta master clock frame dropping with a strict consecutive drop cap and smooth timeline re-anchoring, preventing infinite drop-frame cascades.

- 冷启动更新弹窗层级与免打扰 / Cold-Start Update Presentation:
  将版本更新对话框直接绑定于主视窗，增加播放态全局互斥门控，观影或听歌期间绝不弹窗打扰，仅在静态待机或冷启动就绪时提示，并严格遵循每周一次的静默提醒周期。
  Mounted update confirmation dialogs directly to the main window while enforcing strict playback mutual exclusion: alerts never interrupt active video or music playback, presenting only during static idle states while maintaining the 7-day cadence.

---

## 系统要求 / Requirements

- 操作系统 / OS: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- 芯片架构 / Architecture: Universal 通用二进制（原生支持 Apple Silicon 与 Intel 64 位芯片）/ Universal Binary (Apple Silicon & Intel 64-bit)
- 图形显示 / Graphics: 支持 Metal 硬件加速与 HDR / EDR 显示 / Metal hardware acceleration & HDR / EDR display supported

---

## 安装方式 / Installation

1. 下载并打开 `SilkPlayer-2.0.1-universal.dmg`；
2. 将 `SilkPlayer.app` 拖拽至 `Applications` 文件夹；
3. 如遇首次打开系统安全提示，请前往「系统设置 → 隐私与安全性」点击「仍要打开」。

1. Download and open `SilkPlayer-2.0.1-universal.dmg`;
2. Drag `SilkPlayer.app` into the `Applications` folder;
3. If prompted by macOS Gatekeeper, navigate to "System Settings → Privacy & Security" and click "Open Anyway".
