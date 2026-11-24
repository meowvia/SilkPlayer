# SilkPlayer 2.1.1 交付归档与资产凭证 / Delivery Archive

### 1. 工程基准与版本信息
- 交付版本：`2.1.1`（严格去 `v` 前缀）
- 代码分支：`main`
- 交付范围：
  - 杜比视界 Profile 8.4 与 HLG 色彩映射全面修正（Metal 着色器 `f4` 实现 ITU-R BT.2100 HLG 逆 OETF + 动态系统 Gamma OOTF）
  - 全色阶（`AVCOL_RANGE_JPEG`）与有限色阶（Limited Range）在 HLG 与 PQ 着色器中的动态分支支持
  - 色彩空间正交仲裁解耦（`SilkColorArbitration.resolve`），解耦 BT.2020 非恒定亮度与 PQ 传输函数绑定，强化 Profile 8.2 SDR 显式降级与 Profile 5 假冒 BT.709 标签防伪拦截
  - 全流程生命周期状态重置与黑屏清空（`SilkPlayerEngine` open/openAsync/stopPipeline/selectTrack 与 `SilkMetalRenderView.clear()`）
  - 4K 高码率与 8K 超高清缓冲调度与流控优化，长时间大文件播放内存与显存保持轻量稳定
- 自动化单测状态：
  - `DolbyVisionRoutingTests`: 6/6 通过（0 失败，0.005 秒秒级通过）
  - 全量自动化测试 100% 通过无回退

### 2. 交付产物与校验基准
- 安装镜像文件：`SilkPlayer-2.1.1-universal.dmg`
- 文件完整路径：`/Volumes/2T/Projects/SilkPlayer/SilkPlayer/build/SilkPlayer-2.1.1-universal.dmg`
- SHA-256 校验和：`6f1898d75846143a711c3e8ce79e8186c276504d56f8d48629640ce0853144b8`
- 镜像文件体积：`24,254,851 字节`
- 架构支持：Apple Silicon (arm64) + Intel 64-bit (x86_64) Universal 二进制
- 依赖审计：`@rpath` 合规，无外部宿主私有绝对路径泄漏

### 3. 文档与事实源映射
- 发布说明：`Documentation/RELEASE_NOTES_2.1.1.md`
- 变更记录：`CHANGELOG.md`
- 官网维护：`Website/README.md`
