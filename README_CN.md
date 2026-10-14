<div align="center">

<img src="Resources/AppIcon_1024.png" alt="SilkPlayer Logo" width="160" />

# SilkPlayer

**专为 macOS 打造的原生、轻量化多媒体播放器**  
专注轻量、速度、易用性与纯净的本地观影体验

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![架构](https://img.shields.io/badge/架构-Apple%20Silicon-orange?style=flat-square&logo=apple)](https://www.apple.com/mac/)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift)](https://swift.org)
[![自动化测试](https://img.shields.io/badge/自动化测试-480%20项全部通过-brightgreen?style=flat-square)](scripts/run_tests.sh)
[![开源协议](https://img.shields.io/badge/许可证-LGPL--3.0-blue?style=flat-square)](LICENSE)

[**English**](README.md) · [**简体中文**](README_CN.md)

<br />

<!-- 产品主界面预览图 -->
<img src="Documentation/Screenshots/hero_welcome.png" alt="SilkPlayer 极简启动界面" width="860" />
<br />
<sub><em>极简无边框设计 · 打开即用，直接拖入视频或点击中央图标即可播放</em></sub>

</div>

---

## 功能特性

- **硬件加速回放 (SilkPlayback Engine)**：专为 Apple Silicon 优化，支持市面常见片源流畅播放，音画严格同步。
- **杜比视界色彩重塑 (SilkRender Pipeline)**：优化流媒体单层杜比视界（Profile 5）色彩映射，告别一些播放器呈现“灭霸”的紫色画面。
- **时间轴悬停预览 (SilkThumb Engine)**：鼠标滑过进度条即时浮现剧情缩略图与章节，找画面清晰直观。
- **格式通吃与外挂字幕**：支持 HEVC、H.264、AV1、ProRes 等主流编码，多音轨自由切换，外挂字幕自动加载。
- **原生 macOS 体验**：窗口等比缩放、全屏沉浸播放，播控栏与光标自动淡出，纯净无干扰。
- **单机离线与隐私保护**：纯本地单机运行，无后台守护进程、无广告、无数据收集。

---

## 关于核心库 (SilkCoreKit)

SilkPlayer 的界面与交互完全开源，对所有人免费。底层的播放、渲染与抽帧三大核心封装在独立二进制库 `SilkCoreKit` 中。

SilkCoreKit 花了大量业余时间和心血调试、打磨出来的底层积累，目前为了保障架构稳定，仍处于不断推进测试阶段，因此暂时以闭源二进制提供。后续会视项目发展情况，考虑逐步开源或提供授权。

---

## 界面实机预览画廊 (Preview Gallery)

<div align="center">

### 1. 极简画布与播放列表 (Minimalist Canvas & Playlist Drawer)

| 极简无边框启动态 | 侧边折叠播放列表抽屉 |
| :---: | :---: |
| <img src="Documentation/Screenshots/hero_welcome.png" alt="极简画布" width="410" /> | <img src="Documentation/Screenshots/playlist_drawer.png" alt="播放列表抽屉" width="410" /> |
| *启动后呈现纯黑极简画布，点击中央图标或拖入文件即可播放* | *右侧随手拉出的侧边抽屉，清晰指示当前正在播放的条目，平时收起不遮挡画面* |

<br />

### 2. 高码率回放实测 (SilkPlayback Engine · 4K UHD & 8K 150Mbps)

| 4K UHD 120Mbps 高码率实测 | 8K 7680×4320 150Mbps 极限压测 |
| :---: | :---: |
| <img src="Documentation/Screenshots/playback_4k.png" alt="4K 播放测试" width="410" /> | <img src="Documentation/Screenshots/playback_8k.png" alt="8K 播放测试" width="410" /> |
| *实测 4K UHD 120Mbps 10-bit 高码率水母测试片，硬件解码直显流畅* | *实测 8K 7680×4320 150Mbps 极限码率样片，展现硬件解码性能* |

<br />

### 3. 杜比视界色彩重塑与高精度抽帧 (SilkRender & SilkThumb)

| 杜比视界 Profile 5 动态色彩重塑 | 时间轴高精度剧情缩略图预览 |
| :---: | :---: |
| <img src="Documentation/Screenshots/dolby_vision_profile5.png" alt="杜比视界 Profile 5" width="410" /> | <img src="Documentation/Screenshots/timeline_hover_preview.png" alt="进度条剧情预览" width="410" /> |
| *针对流媒体杜比视界（Profile 5）动态色彩校正，画面通透自然，告别偏绿发灰* | *鼠标滑过进度条时即时浮现剧情画框，方便快速找到精彩镜头* |

<br />

### 4. 色彩真实还原与技术规格面板

| 威尼斯水城高动态真实日光光影 | 技术规格与 SilkCoreKit 核心架构 |
| :---: | :---: |
| <img src="Documentation/Screenshots/dolby_vision_venice.png" alt="威尼斯水城杜比视界" width="410" /> | <img src="Documentation/Screenshots/about_specifications.png" alt="技术规格与致谢" width="410" /> |
| *威尼斯水城样片测试，日光与水波阴影过渡柔和真实* | *原生偏好设置面板，清楚标明 v1.0.0 技术规格、三大专有核心与合规依据* |

</div>

---

## 系统环境要求

- **操作系统**：macOS 14.0 (Sonoma) 或 macOS 15.0+ (Sequoia)
- **硬件架构**：Apple Silicon (M 系列芯片)

---

## 安装与运行

### 方式一：Homebrew 一键安装（推荐）
```bash
brew install --cask meowvia/tap/silkplayer
```

### 方式二：DMG 手动安装
1. 从 [Releases](https://github.com/meowvia/SilkPlayer/releases) 页面下载最新的 `SilkPlayer-1.0.0.dmg`；
2. 双击打开并将 **SilkPlayer.app** 拖入「应用程序」文件夹；
3. **若打开时提示“已损坏”或“无法验证开发者”**（开源应用未向苹果购买高额证书），在终端执行一行命令即可秒开：
   ```bash
   xattr -cr /Applications/SilkPlayer.app
   ```
   *(也可在 Mac「系统设置」➔「隐私与安全性」中点击「仍要打开」)*

---

### 从源码自行编译
如果您希望自行构建应用：
```bash
git clone https://github.com/meowvia/SilkPlayer.git
cd SilkPlayer

# 运行全套自动化测试套件
./scripts/run_tests.sh

# 编译打包最终发布版 DMG (产物输出至 build/ 目录)
./scripts/package_app.sh
```

> **构建说明**：
> - FFmpeg 五个核心多媒体库以动态 framework（LGPL-3.0）形式直接附带在工程 `Packages/` 目录下；
> - 核心解码与渲染引擎 `SilkCoreKit` 为二进制库（静态链接），在执行 `swift build` 或打包时由 SwiftPM 自动从 GitHub Releases 下载对应的预编译 XCFramework 压缩包；本地开发者亦可遵循 [CONTRIBUTING.md](CONTRIBUTING.md) 放入本地编译的 `Packages/SilkCoreKit.xcframework` 进行开发。

---

## 项目现状与后续规划

SilkPlayer 是业余时间独立开发的一款播放器。低系统资源占用与优秀稳定性一直是本项目追求的核心目标，目前已有一些明确的优化探索方向，并在持续迭代打磨，力求达到不输主流播放器的综合水准。

受限于业余精力和测试样本有限，在播放某些小众或特殊编码视频时偶发兼容问题在所难免。如果您在使用中遇到问题或有改进建议，欢迎随时提交 [Issues](https://github.com/meowvia/SilkPlayer/issues)，我会尽可能在后续更新中持续跟进。


---

## 开源项目致谢

SilkPlayer 衷心致谢以下开源基石项目：

- **[FFmpeg](https://ffmpeg.org)** (LGPL-3.0 动态 framework)
- **[libplacebo](https://code.videolan.org/videolan/libplacebo)** 与 **[mpv](https://github.com/mpv-player/mpv)** (LGPL-2.1+，色彩科学与国际标准对照参考)

### 商标与声明
- Apple, macOS, Apple Silicon, Metal, VideoToolbox, AppKit 及 SwiftUI 为 Apple Inc. 的注册商标；
- Dolby 及 Dolby Vision 为 Dolby Laboratories 的注册商标；
- SilkPlayer 为独立软件项目，与 Apple Inc. 或 Dolby Laboratories 无附属或背书关系。

### 架构与开源许可证（双轨许可结构）
- **前台应用（SilkPlayer）**：遵循 [GNU Lesser General Public License v3.0 (LGPL-3.0)](LICENSE) 许可协议，开源前端完全自由分发；
- **多媒体底层库（FFmpeg）**：五个基础库（Libavcodec, Libavformat, Libavutil, Libswresample, Libswscale）均为 LGPL-3.0 动态 framework 链接；
- **核心引擎（SilkCoreKit）**：遵循独立的专有组件使用协议 [SILKCOREKIT_LICENSE.md](SILKCOREKIT_LICENSE.md)，免费供个人非商业使用，作为 SilkPlayer 组件通过 Swift package 物理隔离；
- 详细依赖与重新链接说明请参见 [THIRD_PARTY.md](Documentation/THIRD_PARTY.md)。
