# SilkPlayer 2.2.0 交付归档与资产凭证 / Delivery Archive

### 1. 工程基准与版本信息
- 交付版本：`2.2.0`（严格去 `v` 前缀）
- 代码分支：`main`
- 交付范围：
  - 媒体库适用范围与交互对齐：设置与侧边抽屉更名为「媒体库 / 媒体源」，覆盖本地目录、外置硬盘与 NAS 共享；本机目录选择器支持多选并针对访达挂载的网络卷提示风险及引导至 SMB/NFS；关闭「启用媒体库」时回归标准列表抽屉与持久化记忆
  - 媒体库详情页实时音视频规格探测：移除初始文件名正则猜测，改由 `SilkMediaLibraryEngine.enrichMediaSpecsIfNeeded` 按需调用 `avformat_open_input` 实测并持久化至 SQLite（识别 8K/4K/1080P/720P、Dolby Vision/HDR10+/HDR10/HLG、HEVC/AV1/H.264、DD+ Atmos/TrueHD Atmos/DTS:X 与声道数）；移除详情页冗余「从头播放」胶囊
  - 黑边环境光柔化（Pro 专属 · 提案 026）：在 `kernel.metal` 与 `SilkMetalRenderView` 新增下采样双 pass 高斯模糊环境光填充，由 `SilkProLicenseEngine.shared.isProActive` 与设置项 `ambientLetterboxFill` 双重门控，默认关闭
  - 全屏右侧悬停展开播放列表（提案 037）：全屏状态下悬停右侧把手约 100ms 展开、移出约 250ms 收起；窗口模式保持手动点击 / `P`
  - 网络断流 8 秒看门狗（提案 038）：为 `SilkDemuxer` 增加 `cancelOpen()` 与非本地卷 8 秒超时期，配合 `SilkPlayerEngine.openAsync` 8 秒看门狗
  - 端内更新摘要展示与免费版空白画布轻引导：更新提示解析 `notes_zh` / `notes_en` / GitHub `body`；空白画布底部提供点击前往设置后解锁 `×` 的一次性轻引导胶囊，设置「媒体库 [PRO]」后方提供直达 `https://silkplayer.com/#pricing` 的入口；免费态媒体库开关视觉统一置为关闭状态
- 自动化测试状态：
  - `run_tests.sh`（本地真实 `SilkCoreKit.xcframework` + 模拟 CI `SilkCoreKitMock` 双轨全量测试，含 72 项 `SilkPlayerTests` 与 `SwiftTestingSanityTests`）全部通过无失败

### 2. 交付产物与校验基准
- 安装镜像文件：`SilkPlayer-2.2.0-universal.dmg`
- 文件完整路径：`/Volumes/2T/Projects/SilkPlayer/SilkPlayer/build/SilkPlayer-2.2.0-universal.dmg`
- SHA-256 校验和：`9282cfac7493d7ce191577566f28e158a1b242338fb56f97dedc58cb8be64`
- 镜像文件体积：`25,211,144` 字节
- 镜像内附文件：`SilkPlayer.app`、`Applications` 软链接、`安装指南_Installation_Guide.txt`（已更新官网域名为 `https://silkplayer.com` 与 2.2.0 激活指引）
- 架构支持：Apple Silicon (`arm64`) + Intel 64-bit (`x86_64`) Universal 二进制
- 依赖审计：`otool -L` 全量 `@rpath` 合规（镜像挂载前后双重复核通过），ad-hoc inside-out 签名校验通过

### 3. 文档与事实源映射
- 发布说明：`Documentation/RELEASE_NOTES_2.2.0.md`
- 变更记录：`CHANGELOG.md`
- 官网版本接口准备：`Website/functions/api/version.js`（已预置 `2.2.0` 中英文亮点映射）
