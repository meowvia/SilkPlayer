# SilkPlayer 1.8.0-pro 版本更新说明 / Release Notes

此文档为 `feature/v1.8.0-pro` 分支本地预览与测试阶段发布说明草案。
This document is a preview draft for the `feature/v1.8.0-pro` branch during local testing.

---

## 版本概括 / Overview

SilkPlayer 1.8.0-pro 引入了全新的局域网媒体库架构与单窗口观影管理体系，支持 SMB 2/3、NFS 及本地存储源的增量索引与海报墙呈现，重构了媒体库管理与播放态的上下文抽屉隔离，并对多分类浏览与窗口几何生命周期进行了系统级稳定性优化。

SilkPlayer 1.8.0-pro introduces an integrated local and network media library architecture, supporting SMB 2/3, NFS, and local directory indexing with poster walls, context-isolated playlist drawers between library and playback modes, collapsible section headers, and window lifecycle stability fixes.

---

## 核心特性 / Key Features

- **局域网与本地媒体库管理 / LAN & Local Media Library**:
  - 支持 SMB 2/3、NFS 共享协议挂载与多级共享目录树状探测勾选，支持增量后台扫描与元数据持久化。
  - Added SMB 2/3 and NFS share mounting with multi-level directory tree inspection, background incremental scanning, and metadata persistence.
  - 支持 Bonjour 与 NetBIOS 局域网主机自动探测与规范化网格卡片展示，支持手动输入主机 IP/域名快速连接。
  - Added automatic LAN host discovery (Bonjour / NetBIOS) with normalized two-column grid cards and manual host/IP input.
  - 自动识别影视命名规范，实现电影单片与电视剧集自动归纳分组、多季集展开抽屉展示与继续观看进度恢复。
  - Added automated movie and TV series grouping, season/episode drawer inspection, and continue-watching progress resumption.

- **分类分隔线折叠与展开 / Collapsible Media Section Headers**:
  - 电影与剧集分类分隔线支持三段式展开/收起控制，右侧提供自适应主题高光的紧凑胶囊按钮。
  - Added three-stage expand/collapse controls on Movies and TV Series dividers with theme-adaptive trailing capsule toggles.
  - 折叠状态独立持久化，折叠电影分类后剧集无缝上浮至首屏，无需纵向长距离滚动；支持搜索态自动临时展开与分类过滤自动展开兜底。
  - Persisted collapse preferences across sessions; collapsing movies brings series directly into the top fold, with auto-expansion during search and category filtering.

- **播放上下文与抽屉隔离 / Playback Context & Drawer Isolation**:
  - 媒体库管理态严格隐藏右侧播放列表悬浮抽屉，进入全功能视频播放态后自动恢复抽屉交互。
  - Enforced strict hiding of the right-edge playlist drawer while browsing the media library, automatically re-enabling it during playback.
  - 播放上下文隔离锁定：电影播放严格绑定单片队列，剧集播放自动加载整部全集列表，支持双向自然跳集与连播。
  - Contextual queue locking: movie playback queues only the selected film, while series playback loads the complete series episode queue for sequential viewing.

- **窗口几何还原与 HUD 交互精简 / Window Geometry Restoration & HUD Refinements**:
  - 彻底修复退出播放进入媒体库时界面收缩至左下角的几何缺陷，废除手动硬设 `contentView.frame`，恢复 AppKit `fullSizeContentView` 全量弹性布局。
  - Completely resolved window geometry collapse to the bottom-left corner when exiting playback to the media library, eliminating manual `contentView.frame` mutations in favor of AppKit `fullSizeContentView` automatic layout.
  - 精简顶部 HUD 标题交互，移除顶部下拉菜单弹窗，回归非侵入式静态标题胶囊。
  - Replaced the top HUD dropdown menu with a non-intrusive static title capsule.

- **多声道无损音轨直通 / Multi-Channel Lossless Audio Output**:
  - 重构 CoreAudio 渲染管线，支持 TrueHD、Dolby Atmos、DTS-HD MA 5.1/7.1 声道 LPCM 无损直通输出，废除写死双声道立体声混缩。
  - Overhauled CoreAudio rendering pipeline to support TrueHD, Dolby Atmos, and DTS-HD MA 5.1/7.1 multi-channel LPCM lossless passthrough without downmixing.

- **杜比视界动态色调映射 / Dolby Vision Dynamic Tone Mapping (P7/P8)**:
  - 引入 Profile 7 至 Profile 8.1 行业标准动态映射，从 RPU 中提取场景峰值亮度与 PQ 动态元数据，在 Metal 片元着色器中实现平滑亮度滚降与色调映射。
  - Implemented Profile 7 to Profile 8.1 dynamic tonemapping, extracting RPU scene peak luminance and PQ metadata for smooth luminance roll-off and tonemapping in Metal shaders.

- **iCloud 播放进度与历史跨设备同步 / iCloud Progress & History Sync**:
  - 引入原生 `SilkCloudSyncService`，基于 `NSUbiquitousKeyValueStore` 与轻量同步容器实现多端播放进度与观看状态同步。
  - Introduced native `SilkCloudSyncService` leveraging `NSUbiquitousKeyValueStore` and lightweight containers for seamless cross-device progress and history synchronization.

---

## 系统要求 / Requirements

- **操作系统 / OS**: macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- **芯片架构 / Architecture**: Universal Binary (Apple Silicon `arm64` 与 Intel `x86_64`) / Universal Binary (`arm64` and `x86_64`)

---

## 安装方式 / Installation

1. 本地测试版本已构建并安装至 `/Applications/SilkPlayer.app`。
   The local test build has been assembled and installed directly to `/Applications/SilkPlayer.app`.
2. 正式发版将通过 GitHub Releases 分发带代码签名与公证的 Universal DMG 镜像包。
   Official releases will be distributed via GitHub Releases with signed and notarized Universal DMG images.
