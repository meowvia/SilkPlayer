# SilkPlayer 2.0.1 交付成果与技术归档 (Delivery Archive)

本文档归档 SilkPlayer 2.0.1 紧急热修复补丁版本全量开发成果、技术实现路径、验证数据与交付资产。

---

## 1. 核心待办实施成果归档

### 1.1 AV1 10-bit 核心解码与渲染管线修复
- **目标与根因**:
  - 用户播放 AV1 10-bit 电影视频（如《复仇者联盟4：终局之战.mkv》，编码 `av1 (libdav1d), yuv420p10le`）时，出现有声音、无画面、时间轴停在 0 秒不走动的问题（仅进度条预览能看到画面）。
  - 根因分析：
    1. `SilkVideoDecoder` 错误地将 AV1 列为 Apple VideoToolbox 硬件上下文候选，并在软解回退时因强挂 VideoToolbox 格式回调导致解码器无法正常产出有效帧；
    2. 解码器单线程限制导致高码率 10-bit 软解性能不足；
    3. `SilkPlayerEngine` 主时钟同步判定中，当视频严重落后主时钟（`diff < -0.250`）时陷入 100% 丢帧的无限死循环，且未重同步音频时钟，导致视频帧被永久丢弃，时间轴无法推进。
- **技术实现路径**:
  - 在 `SilkCoreKit/Sources/SilkCoreKit/Engine/SilkVideoDecoder.swift` 中：
    - 彻底剔除假硬解候选，AV1 格式统一且唯一路由到 `libdav1d` 高性能软解；
    - `isHardwareCandidate` 严格限定于 H264、HEVC、ProRes、VP9；
    - `get_format` 仅在 `isHardware == true` 时生效，软解直通原生 YUV 像素输出；
    - 软解开放多核心切片线程池（`thread_count = max(2, min(8, CPU_CORES))`，`thread_type = FF_THREAD_SLICE`）；
  - 在 `SilkCoreKit/Sources/SilkCoreKit/Engine/SilkPlayerEngine.swift` 中：
    - 重构大时钟差丢帧逻辑，设置连续丢帧上限（最多允许丢弃 2 帧追赶时钟）；
    - 超限立即调用 `audio.reanchor(to: pts)` 平滑重锚定音频时钟，强制当前视频帧渲染上屏，彻底消除丢帧雪崩。

### 1.2 冷启动版本更新提示在主界面的呈现与播放态免打扰
- **目标与根因**:
  - 原冷启动版本更新弹窗挂载层级较深，且容易在用户双击打开视频播放时弹出打扰观影。
- **技术实现路径**:
  - 在 `SilkPlayer/Sources/SilkPlayer/App/AppShellView.swift` 中：
    - 将更新对话框直接挂载至主视窗，增加播放态全局互斥门控：
      ```swift
      .alert(
          L10n.tr("New version ...", "发现新版本 ..."),
          isPresented: Binding(
              get: { UpdateService.shared.isShowingUpdateAlert && !isSecondaryWindow && !isPlaying },
              set: { UpdateService.shared.isShowingUpdateAlert = $0 }
          )
      )
      ```
  - 在 `SilkPlayer/Sources/SilkPlayer/Shared/UpdateService.swift` 中：
    - 检测到远程新版本时首先核查全局会话播放状态 `PlayerWindowManager.shared.sessions.contains { $0.player?.isPlaying == true }`；
    - 播放中保持静默，仅维持设置页红点标记；仅在静态待机态触发弹窗提示；
    - 严格遵循 7 天周期静默期（`LastColdStartReminderDate`），用户拒绝后 7 天内不再弹出。

---

## 2. 交付资产与校验和 (Delivery Assets & Checksums)

- **应用版本**: `2.0.1`
- **目标分支**: `release/2.0.0`
- **通用安装镜像**: `SilkPlayer-2.0.1-universal.dmg` (23MB)
- **SHA-256 校验和**:
  ```
  0d84bca55e49d15d176be2ef22b8035b6103dc39b0f1d4a69be1b02d0a62e35b
  ```
- **架构支持**: Universal Fat Binary (`arm64` + `x86_64`)
- **动态库依赖审计**: 100% `@rpath` 隔离与 Apple 原生系统框架，零外部硬编码绝对路径
- **代码签名与沙箱**: Ad-hoc inside-out codesign + entitlements 严格校验通过
