# SilkPlayer 2.0.0-pro 阶段交付与工程归档 (Delivery Archive)

本文档归档分支 `feature/v2.0.0-pro` 在 `2.0.0-pro` 阶段已完成的代码改动、自动化测试状态与实机构建结果。

---

## 1. 工程基准与交付资产

- **开源前端 (`SilkPlayer`)**:
  - 本地路径: `/Volumes/2T/Projects/SilkPlayer/SilkPlayer`
  - 分支: `feature/v2.0.0-pro`
  - 最新 Commit: `84628e6` (`fix(player): remove remaining intro outro markers, add trailing drawer playing equalizer, and support async duration probing`)
- **闭源内核 (`SilkCoreKit`)**:
  - 本地路径: `/Volumes/2T/Projects/SilkPlayer/SilkCoreKit`
  - 分支: `feature/v2.0.0-pro`
  - 最新 Commit: `3504a8e` (`build(core): update xcframework and embedded shader artifacts`)
- **提交作者标准**: `meowvia <meowvia@users.noreply.github.com>`
- **版本命名规范**: `2.0.0-pro`（严格统一去 `v` 前缀）
- **自动化测试状态**: 63/63 项 XCTest 单元测试全数通过，构建验证 100% 绿灯。
- **动态库依赖审计 (`@rpath`)**:
  - 嵌入第三方框架（`Libavcodec`、`Libavformat`、`Libavutil`、`Libswresample`、`Libswscale`）严格对齐 `@rpath`；
  - 闭源 `SilkCoreKit` 作为静态核心编译打包并集成，无宿主机私有绝对路径泄漏；
  - 代码签名校验: Ad-hoc 签名完整（`valid on disk`，`satisfies its Designated Requirement`）。
- **本机安装交付路径**: `/Applications/SilkPlayer.app`（测试运行正常）。

---

## 2. 本阶段实施成果归档

1. **音频指纹彻底下线并归档为远期技术储备（PROPOSAL-012）**
   - 目标文件: `Sources/SilkPlayer/Player/AudioIntroDetector.swift`（彻底删除）、`Documentation/FEATURE_PROPOSALS.md`
   - 实现逻辑: 彻底清除了多线程并发声学特征提取与大文件音频解复用逻辑，清理了 `SilkAudioIntroCache` 与 `SilkGoldenIntroTemplates` 本地缓存。播放器物理内存稳定在 42.8MB，CPU 保持 0.0%，完全杜绝磁盘 I/O 读盘开销。提案 012 归档为远期技术储备。

2. **暖白与多主题全链路适配**
   - 目标文件: `Sources/SilkPlayer/Player/SilkUnifiedDrawerView.swift`、`SilkLibraryTheme.swift`
   - 实现逻辑: 抽屉背景、边框、卡片选中态与文字色彩全量接入 `SilkLibraryTheme`。在暖白主题下，正文文字采用深暖炭棕色（`#2B231C`），高亮选中态采用赤陶暖橙色（`accentColor`），彻底解决浅色主题下字体刺眼、对比度不足的问题。

3. **媒体库分类状态记忆与导航闭环**
   - 目标文件: `SilkCoreKit/Sources/SilkCoreKit/Pro/SilkProLibraryView.swift`
   - 实现逻辑: 将当前激活的 `videoFilter`、`domain`、`selectedSourceId` 改造为 `@AppStorage` 持久化，并在视图重新挂载时自动恢复。用户在“电影”或“剧集”分类下进入全屏播放，关闭播放退出后 100% 保持在原分类视图下。

4. **播放列表播放指示器与排版重构**
   - 目标文件: `Sources/SilkPlayer/Player/SilkUnifiedDrawerView.swift`
   - 实现逻辑: 彻底移除行首插入的跳动波形与暂停图标。所有行的行首角标（`E01`、`E02`）与双位序号固定等宽严格左对齐（46pt / 22pt），彻底消除错位断层感；在卡片最右侧（通过 Spacer 隔离）新增精致的 3 柱 mini 律动音波，Hover 时平滑淡隐让位给操作按钮。

5. **片头/片尾标记彻底除根**
   - 目标文件: `Sources/SilkPlayer/HUD/PlayerScrubberView.swift`、`Sources/SilkPlayer/PlayerCore.swift`、`Sources/SilkPlayer/PlayerHUDView.swift`、`Sources/SilkPlayer/Player/EpisodeSkipManager.swift`（彻底删除）
   - 实现逻辑: 彻底移除了 `EpisodeSkipManager` 与进度条 Canvas 上的片头片尾标记（`introMarkerX`/`outroMarkerX`）及吸附算法，启动时清除 `SilkEpisodeSkipMemory` 缓存，进度条恢复为纯净轨道。

6. **播放列表时长后台异步补全**
   - 目标文件: `Sources/SilkPlayer/Playlist/MediaDurationProbe.swift`、`Sources/SilkPlayer/Playlist/PlaylistManager.swift`、`Sources/SilkPlayer/Playlist/PlaylistModels.swift`
   - 实现逻辑: 建立轻量异步探测管道，优先通过 `AVURLAsset` 异步解析文件头，底层 fallback 至 FFmpeg 原生 demuxer。播放列表载入时后台静默补全 `duration <= 0` 的剧集时长并刷新列表，解决各分集时长空白问题。
