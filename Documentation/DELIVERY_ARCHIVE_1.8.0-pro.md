# SilkPlayer 1.8.0-pro 阶段交付与工程归档 (Delivery Archive)

本文档归档分支 `feature/v1.8.0-pro` 在 `1.8.0-pro` 阶段已完成的代码改动、自动化测试状态与实机构建结果。

---

## 1. 工程基准与交付资产

- **开源前端 (`SilkPlayer`)**:
  - 本地路径: `/Volumes/2T/Projects/SilkPlayer/SilkPlayer`
  - 分支: `feature/v1.8.0-pro`
  - 最新 Commit: `ef530d9` (`fix(playback): deduplicate rapid library launches, offload large queue persistence, and add error recovery UI`)
- **闭源内核 (`SilkCoreKit`)**:
  - 本地路径: `/Volumes/2T/Projects/SilkPlayer/SilkCoreKit`
  - 分支: `feature/v1.8.0-pro`
  - 最新 Commit: `7a6956f` (`fix(library): serialize scans, harden SMB/NFS URL resolution, and prevent deleted-source resurrection`)
- **提交作者标准**: `meowvia <meowvia@users.noreply.github.com>`
- **版本命名规范**: `1.8.0-pro`（严格统一去 `v` 前缀）
- **自动化测试状态**: 63/63 项 XCTest 单元测试全数通过，Swift Testing Sanity 测试 100% 绿灯。
- **动态库依赖审计 (`@rpath`)**:
  - 嵌入第三方框架（`Libavcodec`、`Libavformat`、`Libavutil`、`Libswresample`、`Libswscale`）严格对齐 `@rpath`；
  - 闭源 `SilkCoreKit` 作为静态核心集成，无宿主机私有绝对路径泄漏；
  - 代码签名校验: Ad-hoc 签名完整（`valid on disk`，`satisfies its Designated Requirement`）。
- **本机安装交付路径**: `/Applications/SilkPlayer.app`（测试运行正常）。

---

## 2. 本阶段实施成果归档

1. **媒体库管理模式与播放态抽屉交互隔离**
   - 目标文件: `Sources/SilkPlayer/App/AppShellView.swift`
   - 实现逻辑: 增加 `shouldHidePlaylistDrawerForPro: Bool { isProLibraryActive }` 判断，媒体库管理态严格隐藏右侧播放列表悬浮抽屉与触发展开交互；进入全屏/普通视频播放态时，`shouldHidePlaylistDrawer: Bool { false }`，抽屉恢复正常交互。

2. **播放上下文锁定与分集队列组织**
   - 目标文件: `Sources/SilkPlayer/Player/PlayerContainerView.swift`、`SilkCoreKit/Sources/SilkCoreKit/Pro/SilkProLibraryView.swift`
   - 实现逻辑: 电影播放上下文锁定单片 `[movie]`，杜绝跨影片连续播放；剧集播放上下文绑定完整分集序列 `group.episodes`，支持正向跳集与倒退选集。

3. **退出播放态窗口几何缩微与缩放异常修复**
   - 目标文件: `Sources/SilkPlayer/App/AppShellView.swift`、`Sources/SilkPlayer/App/PlayerWindowManager.swift`
   - 实现逻辑: 移除非播放态下 `windowWillResize` 的全屏锁限制；在关闭播放退出至媒体库时，彻底移除直接对根视图强制指定局部尺寸的错误代码（`cv.frame = NSRect(...)`），配置 `cv.autoresizingMask = [.width, .height]` 并重设为 `superview.bounds`，结合 RunLoop 下一周期布局校验，根治界面缩微至左下角 `(0, 0)` 的 AppKit 布局失效问题。

4. **多声道 LPCM 无损音轨输出**
   - 目标文件: `SilkCoreKit/Sources/SilkCoreKit/Engine/SilkAudioEngine.swift`、`SilkPlayerEngine.swift`
   - 实现逻辑: 废除硬编码 2 声道立体声混缩。根据解复用器实际声道数（5.1 六声道、7.1 八声道等）动态分配 CoreAudio `AudioStreamBasicDescription` 与 `AudioChannelLayoutTag`，重采样器 `setupSwrIfNeeded` 匹配多声道交错 Float32 布局，确保 TrueHD/Atmos/DTS-HD MA 源码以 LPCM 格式完整输出至功放/外置声卡。

5. **杜比视界 Profile 7 / Profile 8 动态色调映射 (Dynamic Tone Mapping)**
   - 目标文件: `SilkCoreKit/Sources/SilkCoreKit/DolbyVisionReshape.swift`、`SilkShaderData.swift`、`SilkVideoDecoder.swift`
   - 实现逻辑: 遵循行业标准 P7 -> P8.1 映射规范，利用 HEVC RPU 提取场景峰值亮度 `source_max_pq` 并反算真实 nits。在 Metal 片元着色器中实现双分支渲染：Profile 5 执行 IPTPQc2 多项式重塑，Profile 7 / Profile 8 基于 Base Layer 执行基于场景峰值的平滑亮度滚降映射。

6. **iCloud / NSUbiquitousKeyValueStore 跨设备观看记忆同步**
   - 目标文件: `SilkCoreKit/Sources/SilkCoreKit/Pro/SilkCloudSyncService.swift`、`SilkMediaLibraryEngine.swift`
   - 实现逻辑: 构建无侵入式轻量同步服务，利用 iCloud KVS 结合本地 Application Support 容器存储轻量播放进度记录（指纹格式 `filename::durationBucket`）。在写入播放进度与标记观看状态时向云端广播，并监听云端外部变更通知自动合并。

7. **局域网探测设备卡片对称网格与通用占位符**
   - 目标文件: `SilkCoreKit/Sources/SilkCoreKit/Pro/SilkProLibraryView.swift`
   - 实现逻辑: 将局域网探测到的设备卡片从单行横向溢出重构为双列对称网格（`LazyVGrid(columns: 2)`），去除冗余说明文字，超过 4 台设备启用独立纵向滚动区（高度上限 `108 pt`）；输入框默认占位符采用通用 RFC 1918 规范 `192.168.1.100`。

8. **电影与剧集分类分隔线三段式折叠/展开**
   - 目标文件: `SilkCoreKit/Sources/SilkCoreKit/Pro/SilkProLibraryView.swift`
   - 实现逻辑: 重构 `mediaSectionHeader`，右侧增加轻量胶囊按钮 `SilkSectionCollapseToggle`，支持深浅色主题自适应微交互与辅助工具提示；状态通过 `@AppStorage` 持久化；折叠电影分类后剧集自动上浮至顶部首屏；支持搜索态自动临时展开与分类切换自动兜底。

9. **顶部 HUD 静态胶囊化**
   - 目标文件: `Sources/SilkPlayer/PlayerHUDView.swift`
   - 实现逻辑: 移除居中标题区域的下拉菜单弹窗（`Menu`），还原为非侵入式静态文本胶囊，避免播放中误触。

---

## 3. 测试与验证记录

- 单元测试执行结果:
  `63/63 passed (0 failures)`
- 双架构静态库编译:
  `SilkCoreKit.xcframework` universal release binary (arm64 + x86_64) 编译通过并同步至 `Packages/`。
- 本机部署验证:
  运行 `./scripts/deploy_dev_test.sh arm64`，成功安装并启动 `/Applications/SilkPlayer.app`。
