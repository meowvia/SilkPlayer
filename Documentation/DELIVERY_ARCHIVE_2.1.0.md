# SilkPlayer 2.1.0 交付归档与资产凭证 / Delivery Archive

### 1. 工程基准与版本信息
- 交付版本：`2.1.0`（严格去 `v` 前缀）
- 代码分支：`release/2.0.0`
- 交付范围：
  - 视窗生命周期纯净调度与幽灵开窗根除（移除 `handlesExternalEvents`，加固 `handleWindowAcquired` 即刻隐形与准入守卫，同文件直接聚焦）
  - 全画幅自适应几何革新（提案 033 竖屏对齐 QuickTime 满高 + 提案 034 横屏自适应提升至 70% 黄金比例）
  - 提案 035 播放列表侧边抽屉拉手微质感重构（漫反射细线、吸光底色防光晕、悬停呼吸交互）
  - 媒体库窗口拉伸高宽比 HUD 抑制与电影海报右键菜单极简收拢（彻底剔除「重置为未观看」，仅保留「标记为已看完」）
  - 全屏转场 Metal 提交互斥与 Space 调度治理（移除转场 `setFrame`，引入硬件互斥锁与看门狗）
- 自动化单测状态：
  - `GeometryAndTransformTests`: 7/7 通过（0 失败）
  - `PlaylistRegressionTests`: 65/65 通过（0 失败）
  - `ProLibraryAndLicenseTests`: 25/25 通过（0 失败）
  - 全量自动化测试 100% 通过无回退

### 2. 交付产物与校验基准
- 安装镜像文件：`SilkPlayer-2.1.0-universal.dmg`
- 文件完整路径：`/Volumes/2T/Projects/SilkPlayer/SilkPlayer/build/SilkPlayer-2.1.0-universal.dmg`
- SHA-256 校验和：`3ee087b7445043bbda6d4836580b306daab169ea226b376f5b526a80baf38833`
- 架构支持：Apple Silicon (arm64) + Intel 64-bit (x86_64) Universal 二进制
- 依赖审计：`@rpath` 合规，无外部宿主私有绝对路径泄漏

### 3. 文档与事实源映射
- 发布说明：`Documentation/RELEASE_NOTES_2.1.0.md`
- 变更记录：`CHANGELOG.md`
- 提案事实源：`Documentation/FEATURE_PROPOSALS.md`（提案 033、034、035 已全部完成落地）
- 问题治理：`Documentation/KNOWN_ISSUES.md`（ISSUE-021 全屏退出转场死锁已正式关闭治理）
