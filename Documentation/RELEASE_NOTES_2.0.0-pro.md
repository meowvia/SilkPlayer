# SilkPlayer Pro 2.0.0-pro Release Notes

## 版本概括 / Overview
SilkPlayer Pro 2.0.0-pro 重点优化了高负载资源占用与播放列表视觉排版，全面适配暖白等明亮主题色彩系统，实现了媒体库分类状态记忆闭环，并新增了播放列表未加载时长的后台静默探测机制。

SilkPlayer Pro 2.0.0-pro focuses on resource optimization, playlist visual refinement, full multi-theme adaptability, persistent media library category state across playback transitions, and asynchronous background duration probing for multi-episode series.

---

## 核心特性 / Key Features

### 中文
1. **播放器内存与 CPU 负载优化**：彻底剥离高能耗声学计算逻辑，常态物理内存占用稳固在 42MB 左右，CPU 占用保持 0.0%，完全杜绝无序磁盘 I/O。
2. **多主题与暖白色彩系统深度适配**：抽屉背景、边框、卡片选中态与文字色彩全链路接入调色盘，暖白主题下正文切换为深暖炭棕色（#2B231C），彻底解决高亮反光与刺眼问题。
3. **媒体库分类状态持久记忆**：在“电影”或“剧集”视图下进入全屏播放，关闭播放退出后始终精准保持在当前分类视图下。
4. **播放列表视觉重构与律动指示**：行首剧集编号与双位序号实现等宽左对齐，消除任何横向位移；卡片右侧集成轻量 3 柱律动波形，悬停时平滑让位给快捷操作。
5. **进度条标记纯净化**：彻底清除进度条轨道上的片头/片尾推测标记，恢复纯净的原生进度条显示。
6. **剧集列表时长异步补全**：新增轻量后台探测管道，多集电视剧载入时自动解析各集时长并无感刷新列表。

### English
1. **Resource & Memory Footprint Optimization**: Decoupled intensive acoustic compute loops, stabilizing active playback memory around 42MB with 0.0% idle CPU and zero unwanted disk I/O.
2. **Full Multi-Theme & Warm White Refinement**: Drawer surfaces, borders, selection capsules, and typography fully integrated with the palette; warm white theme adopts deep warm charcoal text (#2B231C) for enhanced readability.
3. **Persistent Media Library Category State**: Entering playback from Movies or Series tabs consistently returns to the exact same category view upon exit.
4. **Playlist Layout Grid & Equalizer Indicator**: Episode badges and index numbers strictly aligned with fixed widths; a lightweight 3-bar playing equalizer is positioned on the trailing edge, smoothly yielding to hover actions.
5. **Clean Progress Track**: Completely eliminated speculative intro/outro notches from the scrubber track for a distraction-free experience.
6. **Asynchronous Duration Probing**: Introduced a background probing pipeline that automatically resolves missing episode durations upon playlist loading.

---

## 系统要求 / Requirements
- macOS 14.0 (Sonoma) 或更高版本 / macOS 14.0 (Sonoma) or later
- Apple Silicon (M1/M2/M3/M4 系列) 原生支持 / Apple Silicon native support

---

## 安装方式 / Installation
直接下载并挂载安装镜像，将 `SilkPlayer.app` 拖入 `/Applications` 应用程序目录即可完成更新。
Mount the universal DMG image and drag `SilkPlayer.app` to your `/Applications` directory.
