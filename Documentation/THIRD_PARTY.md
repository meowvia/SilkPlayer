# Third-Party Dependencies & Open Source Notices (第三方开源软件声明与合规指南)

SilkPlayer 遵循严格的开源合规标准与开放核心（Open-Core）架构。本文档详尽披露 SilkPlayer 所依赖的第三方开源组件、其各自适用的许可证、与主程序的链接方式、署名（Attribution）规范，以及源码提供责任（Source Code Redistribution Obligations）。

---

## 1. 核心依赖组件合规审计总表 (Compliance Audit Matrix)

| 组件名称 (Component) | 确切版本 (Version) | 许可证 (License) | 链接方式 (Linkage) | 署名要求 (Attribution) | 源码提供责任 (Source Code Obligation) | 主要用途 (Purpose) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **FFmpeg** | **6.1.2** ("Von Neumann") | **GNU LGPL-3.0**<br>(配置参数 `--disable-gpl --disable-nonfree --enable-version3`) | **动态链接 (Dynamic Framework)**<br>`Libavformat.framework`<br>`Libavcodec.framework`<br>`Libavutil.framework`<br>`Libswresample.framework`<br>`Libswscale.framework`<br>位于 `Contents/Frameworks/` | **必须署名**<br>保留 FFmpeg 开发者版权声明与 LGPL 文本 | **必须提供**<br>提供构建所用源码版本、补丁及完整编译构建脚本，保证用户具备替换库与重链接权利 | 媒体解封装 (Demuxing)、音频解码、备用软件视频解码与时间戳处理 |
| **dav1d** | **1.2.1** (API 6.8.0) | **BSD-2-Clause**<br>(VideoLAN / Two Orioles) | **静态编译嵌入**<br>(静态库 `libdav1d.a` 预编译后嵌入 `Libavcodec.framework`) | **必须署名**<br>分发物中必须包含原始版权声明与免责条款 | **无强制提供要求**<br>(宽松许可证，允许专有或二次分发；我们主动公开构建脚本与源码指引) | 极速汇编优化的 AV1 视频高效解码器 |
| **macOS SDK 系统库** | **macOS 14.0+** | Apple Proprietary / System EULA / BSD | **系统动态链接**<br>`/System/Library/Frameworks/*`<br>`/usr/lib/*` | **遵循商标使用准则**<br>注明 Apple 相关注册商标免责声明 | **不适用**<br>(操作系统内置标准系统运行时与专有驱动) | 原生 UI (SwiftUI/AppKit)、硬件硬解 (VideoToolbox)、音频输出 (AudioToolbox)、GPU 表面渲染 (Metal) |
| **SilkCoreKit** | **主版本跟随** | **商业专有许可证 (Proprietary)**<br>(独立闭源内核组件) | **二进制模块解耦**<br>(Swift Package 二进制 Target，无 GPL 依赖) | **专有版权归属**<br>Copyright © 2026 SilkPlayer | **不提供**<br>(自研专有核心算法，不含 GPL 传染性代码，与 LGPL 前端动态隔离) | 专有 Metal 色彩着色器管线、局域网 SMB/NFS 索引引擎、就地激活引擎 |

---

## 2. LGPL-3.0 合规机制与用户权利保证 (LGPL Compliance Mechanism)

### 2.1 动态链接与“可替换性”保证 (Section 4 of LGPL-3.0)
GNU LGPL-3.0 许可证第 4 节明确规定，使用 LGPL 库的复合作品（Combined Work）必须允许用户**自由修改 LGPL 库并重新链接运行**。
SilkPlayer 严格通过以下架构实现 100% 满足：
1. **纯动态隔离**：所有 FFmpeg 动态库均封装在标准的 macOS `.framework` 目录树中，存放在 `SilkPlayer.app/Contents/Frameworks/` 下；
2. **标准 `@rpath` 寻址**：主可执行文件通过 `@executable_path/../Frameworks` 进行动态加载，未进行任何代码混淆或符号锁定；
3. **用户自主替换验证**：任何高阶用户均可自行下载官方 FFmpeg 源码，根据后文参数编译自定义版本，直接覆盖 `SilkPlayer.app/Contents/Frameworks/` 中的对应 Framework，应用程序即可自动加载运行用户编译的动态库。

### 2.2 源码提供与构建脚本公示 (Source Code Redistribution)
根据 LGPL-3.0 要求，本工程在公开代码库中完整公示构建 FFmpeg 动态库的全部细节：
- **FFmpeg 官方源码归档**: [https://ffmpeg.org/releases/ffmpeg-6.1.2.tar.xz](https://ffmpeg.org/releases/ffmpeg-6.1.2.tar.xz)
  - SHA-256 校验和: `3b624649725ecdc96573b2ca895e0f56545f9119049c6934c9f13042127202b8`
- **构建环境与脚本源码**: 位于开源工程 `SilkPlayer_LGPL_Build/` 目录：
  - `build_dual_arch_with_dav1d.sh`: 完整的 Universal 2 (arm64 + x86_64) 双架构编译脚本；
  - `package_xcframeworks.sh`: 打包与重签名脚本。

### 2.3 严禁 GPL 污染防线 (Zero GPL Contamination)
FFmpeg 内部包含部分遵循 GNU GPL 许可证的组件（如 libx264, libx265, libxvid 等）。为避免闭源扩展及宿主受到 GPL 强传染性条款的波及，SilkPlayer 的 FFmpeg 构建参数明确设置：
- `--disable-gpl`：彻底关闭所有 GPL 模块；
- `--disable-nonfree`：彻底剔除非自由许可证代码；
- `--enable-version3`：明确按 LGPL-3.0 模式构建。

---

## 3. FFmpeg 构建参数完整记录

```bash
./configure \
  --prefix=/tmp/build \
  --enable-shared \
  --disable-static \
  --enable-pic \
  --enable-version3 \
  --disable-gpl \
  --disable-nonfree \
  --arch=arm64 \
  --target-os=darwin \
  --cc=clang \
  --cxx=clang++ \
  --extra-cflags='-arch arm64 -mmacosx-version-min=14.0 -O3' \
  --extra-ldflags='-arch arm64 -mmacosx-version-min=14.0' \
  --enable-neon \
  --enable-asm \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --enable-avcodec \
  --enable-avformat \
  --enable-avutil \
  --enable-swresample \
  --enable-swscale \
  --disable-avdevice \
  --disable-avfilter \
  --disable-postproc \
  --disable-programs \
  --disable-doc \
  --enable-network \
  --enable-protocols \
  --enable-bsfs \
  --enable-parsers \
  --enable-libdav1d \
  --enable-decoder=libdav1d \
  --disable-muxers \
  --enable-muxer=flac \
  --enable-muxer=dash \
  --enable-muxer=hevc \
  --enable-muxer=m4v \
  --enable-muxer=matroska \
  --enable-muxer=mov \
  --enable-muxer=mp4 \
  --enable-muxer=mpegts \
  --enable-muxer=webm \
  --enable-muxer=nut \
  --disable-encoders \
  --enable-encoder=aac \
  --enable-encoder=alac \
  --enable-encoder=flac \
  --enable-encoder=pcm_s16le \
  --enable-encoder=pcm_s24le \
  --enable-encoder=pcm_f32le \
  --enable-encoder=h264_videotoolbox \
  --enable-encoder=hevc_videotoolbox \
  --enable-encoder=prores \
  --enable-encoder=prores_videotoolbox \
  --disable-demuxers \
  --enable-demuxer=aac \
  --enable-demuxer=ac3 \
  --enable-demuxer=aiff \
  --enable-demuxer=amr \
  --enable-demuxer=ape \
  --enable-demuxer=asf \
  --enable-demuxer=ass \
  --enable-demuxer=av1 \
  --enable-demuxer=avi \
  --enable-demuxer=caf \
  --enable-demuxer=concat \
  --enable-demuxer=dash \
  --enable-demuxer=data \
  --enable-demuxer=dv \
  --enable-demuxer=eac3 \
  --enable-demuxer=flac \
  --enable-demuxer=flv \
  --enable-demuxer=h264 \
  --enable-demuxer=hevc \
  --enable-demuxer=hls \
  --enable-demuxer=live_flv \
  --enable-demuxer=loas \
  --enable-demuxer=m4v \
  --enable-demuxer=matroska \
  --enable-demuxer=mov \
  --enable-demuxer=mp3 \
  --enable-demuxer=mpegps \
  --enable-demuxer=mpegts \
  --enable-demuxer=mpegvideo \
  --enable-demuxer=nut \
  --enable-demuxer=ogg \
  --enable-demuxer=rm \
  --enable-demuxer=rtsp \
  --enable-demuxer=rtp \
  --enable-demuxer=srt \
  --enable-demuxer=vc1 \
  --enable-demuxer=wav \
  --enable-demuxer=webm_dash_manifest \
  --disable-decoders \
  --enable-decoder=av1 \
  --enable-decoder=dca \
  --enable-decoder=dxv \
  --enable-decoder=ffv1 \
  --enable-decoder=ffvhuff \
  --enable-decoder=flv \
  --enable-decoder=h263 \
  --enable-decoder=h263i \
  --enable-decoder=h263p \
  --enable-decoder=h264 \
  --enable-decoder=hap \
  --enable-decoder=hevc \
  --enable-decoder=huffyuv \
  --enable-decoder=indeo5 \
  --enable-decoder=mjpeg \
  --enable-decoder=mjpegb \
  --enable-decoder=mpeg1video \
  --enable-decoder=mpeg2video \
  --enable-decoder=mpegvideo \
  --enable-decoder=mts2 \
  --enable-decoder=prores \
  --enable-decoder=rv10 \
  --enable-decoder=rv20 \
  --enable-decoder=rv30 \
  --enable-decoder=rv40 \
  --enable-decoder=snow \
  --enable-decoder=svq3 \
  --enable-decoder=tscc \
  --enable-decoder=txd \
  --enable-decoder=wmv1 \
  --enable-decoder=wmv2 \
  --enable-decoder=wmv3 \
  --enable-decoder=vc1 \
  --enable-decoder=vp6 \
  --enable-decoder=vp6a \
  --enable-decoder=vp6f \
  --enable-decoder=vp7 \
  --enable-decoder=vp8 \
  --enable-decoder=vp9 \
  --enable-decoder=aac \
  --enable-decoder=aac_latm \
  --enable-decoder=ac3 \
  --enable-decoder=adpcm_ms \
  --enable-decoder=alac \
  --enable-decoder=amrnb \
  --enable-decoder=amrwb \
  --enable-decoder=ape \
  --enable-decoder=cook \
  --enable-decoder=dca \
  --enable-decoder=dolby_e \
  --enable-decoder=eac3 \
  --enable-decoder=flac \
  --enable-decoder=mp1 \
  --enable-decoder=mp2 \
  --enable-decoder=mp3 \
  --enable-decoder=opus \
  --enable-decoder=pcm_s16le \
  --enable-decoder=pcm_s16be \
  --enable-decoder=pcm_s24le \
  --enable-decoder=pcm_s24be \
  --enable-decoder=pcm_s32le \
  --enable-decoder=pcm_s32be \
  --enable-decoder=pcm_f32le \
  --enable-decoder=pcm_f32be \
  --enable-decoder=pcm_u8 \
  --enable-decoder=sonic \
  --enable-decoder=truehd \
  --enable-decoder=tta \
  --enable-decoder=vorbis \
  --enable-decoder=wmav1 \
  --enable-decoder=wmav2 \
  --enable-decoder=ass \
  --enable-decoder=ccaption \
  --enable-decoder=dvbsub \
  --enable-decoder=dvdsub \
  --enable-decoder=mpl2 \
  --enable-decoder=movtext \
  --enable-decoder=pgssub \
  --enable-decoder=srt \
  --enable-decoder=ssa \
  --enable-decoder=subrip \
  --enable-decoder=xsub \
  --enable-decoder=webvtt \
  --enable-decoder=rawvideo
```

---

## 4. 用户重新编译与重链接指南 (User Relinking Instructions)

为充分践行 LGPL-3.0 赋予用户的技术权利，任何用户均可按以下步骤自行替换 SilkPlayer 所使用的多媒体动态库：

1. **获取并编译 FFmpeg**：
   下载官方 FFmpeg 6.1.2 源码，执行上述 configure 参数并运行 `make -j8 && make install`；
2. **封装为 XCFramework 或 Dynamic Framework**：
   将生成的 `libavcodec.dylib` 等通过 `install_name_tool` 调整其 `LC_ID_DYLIB` 为 `@rpath/Libavcodec.framework/Versions/A/Libavcodec`，放入 Framework 结构体中；
3. **在已安装的 App 中就地替换**：
   ```bash
   # 直接替换目标 App 中的动态库目录
   cp -R /path/to/your/Libavcodec.framework /Applications/SilkPlayer.app/Contents/Frameworks/
   # 对替换后的 Framework 执行 ad-hoc 签名以满足 macOS 安全审计
   codesign --force --sign - /Applications/SilkPlayer.app/Contents/Frameworks/Libavcodec.framework
   codesign --force --sign - /Applications/SilkPlayer.app
   ```
4. **验证运行**：
   启动 `/Applications/SilkPlayer.app`，控制台日志将打印加载自定义动态库的符号，证明用户重链接完全成功。

---

## 5. 法定版权与许可正文公示 (Legal Notices & Attributions)

### 5.1 FFmpeg
```text
FFmpeg is a trademark of Fabrice Bellard, originator of the FFmpeg project.
FFmpeg is licensed under the GNU Lesser General Public License version 3.0 (LGPLv3).
Copyright (c) 2000-2024 the FFmpeg developers.
This software uses libraries from the FFmpeg project under the LGPLv3.
SilkPlayer does not claim ownership of FFmpeg code.
Full LGPLv3 license text: https://www.gnu.org/licenses/lgpl-3.0.html
```

### 5.2 dav1d
```text
Copyright (c) 2018-2023, VideoLAN and dav1d authors. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### 5.3 平台与商标声明 (Trademarks & Disclaimers)
- **Apple, macOS, Apple Silicon, Metal, VideoToolbox, AudioToolbox, AppKit, SwiftUI** 均为 Apple Inc. 在美国及其他国家/地区的注册商标。
- **Dolby, Dolby Vision, Dolby TrueHD** 均为杜比实验室（Dolby Laboratories Licensing Corporation）的商标或注册商标。
- SilkPlayer 为独立研发的多媒体播放器项目，与 Apple Inc. 或杜比实验室无任何赞助、隶属或官方背书关系。
