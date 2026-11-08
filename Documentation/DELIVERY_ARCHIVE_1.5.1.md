# SilkPlayer 1.5.1 实施成果与修复归档 (Delivery & Fix Archive)

## 1. 版本基本信息
- **交付版本**: `1.5.1`
- **发版日期**: 2026-11-08
- **Git Commit 基准**:
  - 开源前端 (`SilkPlayer`): `7bd0411` (Tag `1.5.1`) / 当前 `main` 为 `3b74d23`
  - 闭源内核 (`SilkCoreKit`): `15b021a` (Tag `1.5.1`)
- **提交作者**: `meowvia <meowvia@users.noreply.github.com>`
- **自动化测试状态**: 60/60 项测试全量通过（100% PASS），AV1 4K（3840×2160）软解实机无头测试通过
- **发布安装镜像与 SHA-256 校验和**:
  - `SilkPlayer-1.5.1-universal.dmg`: `7e6eaa0337291c103d27494928b166064f968349dedcd9fceec729af3ca7a69b`
  - `SilkPlayer-1.5.1-arm64.dmg`: `41e8d0915c8d5e061754be0c6896a964141dba51f1219365271025bfb7bf1012`
  - `SilkPlayer-1.5.1-x86_64.dmg`: `bebc261426abd4fa22272f2f369f4800b97969ba1d371132e9f0aabf2b51611d`
- **动态库依赖审计 (@rpath)**:
  - 零外部路径逃逸，所有 dylib 严格限定在 `@rpath/` 与系统库路径，通过 `package_app.sh` 自动化签名与 Hardened Runtime 校验通过；
  - `libdav1d`（BSD-2-Clause）以静态 FAT 库形式直接合入 `Libavcodec.framework`，外部零独立 dylib 依赖，无缺失崩溃风险。

---

## 2. 缺陷修复归档 (Issues Closed in 1.5.1)

### 2.1 AV1 视频编码画面黑屏缺陷彻底闭环
- **缺陷现象**: 播放封装 AV1 视频编码的 MKV、MP4 及 WebM 媒体时，仅有音频输出，视窗画面呈现黑屏；
- **诱因查实**: FFmpeg 内置 `av1dec.c` 仅为硬件加速代理桩，在 macOS 下缺少 VideoToolbox AV1 硬解支持，且编译时未嵌入 `libdav1d` 软解库，导致解码器无法初始化，解码输出 0 帧；
- **修复方案**:
  1. 底层 FFmpeg 在 Apple Silicon (`arm64`) 与 Intel (`x86_64`) 双架构下编译并静态合入 `libdav1d`；
  2. 闭源内核 `SilkVideoDecoder.swift` 针对 `AV_CODEC_ID_AV1` 路由至 `libdav1d`，并配置多线程切片（`FF_THREAD_SLICE`）软解调度；
  3. 规避对不支持的 AV1 编解码器绑定 VideoToolbox 硬件设备上下文。
- **实测验证**: 4K（3840×2160 25fps）AV1 视频实机首帧就绪延迟压至约 61ms，音画同步稳定渲染。
