# SilkPlayer 渠道分发与收录材料规范

本文档为 SilkPlayer 在第三方长尾获客渠道（包管理器、导航聚合站、开源收录列表）的标准化资产。

---

## 一、 Homebrew Cask 渠道（已全量打通）

官方 Cask 现已正式纳入 `meowvia/homebrew-tap`，所有 Mac 用户均可通过以下命令安装与升级：

### 1. 终端一键安装
```bash
brew install meowvia/tap/silkplayer
```
或：
```bash
brew tap meowvia/tap
brew install --cask silkplayer
```

### 2. 升级命令
```bash
brew upgrade --cask silkplayer
```

- **Cask 文件位置**: `https://github.com/meowvia/homebrew-tap/blob/main/Casks/silkplayer.rb`
- **当前镜像版本**: `2.0.1`
- **SHA-256 校验和**: `0d84bca55e49d15d176be2ef22b8035b6103dc39b0f1d4a69be1b02d0a62e35b`

---

## 二、 AlternativeTo.net 词条录入包（一键复制）

访问 [AlternativeTo Submit Application](https://alternativeto.net/software/create/)，按以下字段直接填入：

- **Application Name**: `SilkPlayer`
- **Platform**: `Mac` (macOS 14.0+)
- **License**: `Open Source / Freemium` (Frontend LGPL-3.0)
- **Official Website**: `https://silkplayer.1999909.xyz/`
- **Source Code URL**: `https://github.com/meowvia/SilkPlayer`
- **Short Description (一句话简介)**:  
  `A fast, native macOS media player built with Swift & Metal. Zero telemetry, pure local playback, and full Dolby Vision support.`
- **Detailed Description (详细说明)**:  
  ```text
  SilkPlayer is a lightweight, high-performance media player designed natively for macOS (built with modern Swift & Metal). It is focused on clean aesthetics, sub-second launch speeds, and true zero-telemetry local playback.

  Key Features:
  - Full Hardware Acceleration: 4K/8K VideoToolbox decoding with ultra-low CPU/RAM footprint.
  - Advanced Color Pipeline: Native Dolby Vision (Profile 5, 8.1), HDR10, and high-fidelity tone mapping.
  - Audio Passthrough & Precision: Bit-perfect multichannel DTS, TrueHD, Dolby Atmos E-AC-3 extraction.
  - Privacy First: Zero tracking, no background analytics, runs 100% locally.
  - Pro Capabilities (Optional): High-speed LAN SMB/NFS media library with zero-proxy metadata scraping and a distraction-free folded mini music mode.
  ```
- **Tags / Categories (标签分类)**:  
  `Video Player`, `Media Player`, `macOS App`, `Swift`, `Dolby Vision`, `HDR`, `Audio Player`, `Open Source`
- **Alternatives to Link (关联替代品)**:  
  - `IINA` (主打原生 Swift、比 IINA 更轻量且资源占用更低)
  - `Infuse` (主打局域网播放与海报墙，免昂贵订阅)
  - `Movist Pro`
  - `VLC Media Player`

---

## 三、 Awesome-Mac 收录 PR 模板

可向 [jaywcjlove/awesome-mac](https://github.com/jaywcjlove/awesome-mac) 的 `README-zh.md` 与 `README.md` 中的「音频与视频 / Audio & Video」分类提交 PR：

```markdown
- [SilkPlayer](https://silkplayer.1999909.xyz/) - 专为 macOS 开发的轻量原生多媒体播放器，支持 4K/8K 硬件解码、杜比视界色彩映射与局域网海报墙。[![Open-Source Software](https://jaywcjlove.github.io/sb/ico/min-oss.svg)](https://github.com/meowvia/SilkPlayer)
```
英文版：
```markdown
- [SilkPlayer](https://silkplayer.1999909.xyz/) - Lightweight native macOS media player built with Swift & Metal, featuring 4K/8K hardware decoding, Dolby Vision, and zero telemetry. [![Open-Source Software](https://jaywcjlove.github.io/sb/ico/min-oss.svg)](https://github.com/meowvia/SilkPlayer)
```

---

## 四、 官网 SEO 基础设施交付状态

- **搜索引擎入口**: 已部署标准 `robots.txt` 与 `sitemap.xml` 至 `https://silkplayer.1999909.xyz/`
- **结构化数据 (JSON-LD)**: 注入 `schema.org/SoftwareApplication` 实体标记
- **国际化与社交卡片**: 完整注入 Open Graph 与 Twitter Card 大图卡片，增强被社交网络爬取时的展示效果。
