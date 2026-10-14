# Third-Party Dependencies & Open Source Notices (第三方开源软件声明)

SilkPlayer relies on open-source libraries and native platform frameworks. This document outlines third-party components, their licenses, source repositories, exact versions, build configurations, and redistribution terms in accordance with open-source licensing standards.

---

## 1. Primary Open-Source Dependencies

| Component | License | Origin / Repository | Linkage | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **FFmpeg** (v6.1.2) | **LGPL-3.0** (构建参数 `--disable-gpl --enable-version3`，不含 GPL 组件) | [FFmpeg Official](https://ffmpeg.org) | Dynamic Frameworks (`Libavformat`, `Libavcodec`, `Libswscale`, `Libavutil`, `Libswresample`) | Media container demuxing (MKV, MP4, WebM, etc.), audio decoding, and software video fallbacks. |
| **libplacebo / mpv** | **LGPL-2.1+ / GPL-2.0+** | [libplacebo](https://code.videolan.org/videolan/libplacebo) / [mpv](https://github.com/mpv-player/mpv) | Reference Only (No compiled code linked) | Reference color science and international standard (ITU-R BT.2124 / SMPTE ST 2084) specification verification. |

---

## 2. FFmpeg Source Code, Build Configuration & Relinking Guide

### 2.1 Upstream Source & Verification
- **Exact Version**: FFmpeg 6.1.2 ("Von Neumann")
- **Official Source Archive**: [https://ffmpeg.org/releases/ffmpeg-6.1.2.tar.xz](https://ffmpeg.org/releases/ffmpeg-6.1.2.tar.xz)
- **SHA-256 Checksum**: `3b624649725ecdc96573b2ca895e0f56545f9119049c6934c9f13042127202b8`

### 2.2 Configure Parameters
FFmpeg dynamic frameworks used by SilkPlayer are built strictly with `--disable-gpl` and `--enable-version3`:

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
  --disable-htmlpages \
  --disable-manpages \
  --disable-podpages \
  --disable-txtpages \
  --disable-xlib \
  --disable-libxcb \
  --disable-libxcb-shm \
  --disable-libxcb-xfixes \
  --disable-libxcb-shape \
  --disable-sdl2 \
  --enable-network \
  --enable-protocols \
  --enable-bsfs \
  --enable-parsers \
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

> [!NOTE]
> Future builds note (C4): When re-compiling FFmpeg dynamic libraries, configure MUST specify `--prefix=/tmp/build` or a standardized clean install prefix to avoid machine-specific user directory paths being recorded in library headers or install_names.

### 2.3 User Relinking Instructions (LGPL Relinkability)
In accordance with LGPL-3.0 requirements, users have the right to modify and relink the LGPL-licensed FFmpeg libraries with SilkPlayer:
1. Rebuild FFmpeg with your desired modifications using the configure flags above.
2. Package the resulting dynamic libraries into XCFramework bundles (`Libavcodec.xcframework`, `Libavformat.xcframework`, `Libavutil.xcframework`, `Libswresample.xcframework`, `Libswscale.xcframework`).
3. Replace the corresponding xcframework directories under `Packages/` in the SilkPlayer project.
4. Execute `swift build -c release` to recompile and link SilkPlayer against your custom FFmpeg frameworks.

---

## 3. Platform Frameworks (Apple macOS SDK)

The following system frameworks are provided by Apple Inc. as part of the macOS SDK:

| Framework | Provider | Availability | Purpose |
| :--- | :--- | :--- | :--- |
| **Metal / QuartzCore** | Apple Inc. | macOS 14.0+ | Direct GPU surface rendering (`CAMetalLayer`). |
| **VideoToolbox** | Apple Inc. | macOS 14.0+ | Hardware-accelerated decoding (HEVC, H.264, ProRes, VP9). |
| **AudioToolbox / AVFoundation** | Apple Inc. | macOS 14.0+ | Audio output rendering, channel layout management, system volume integration. |
| **AppKit / SwiftUI** | Apple Inc. | macOS 14.0+ | Native window management, display synchronization, event monitors, and user interface. |

---

## 4. License Compliance & Architectural Boundaries

- **SilkPlayer Repository Licensing**: This public repository of SilkPlayer is licensed under the **GNU Lesser General Public License v3.0 (LGPL-3.0)**.
- **Proprietary Architecture & Physical Isolation**: Proprietary intellectual property, including the SilkPlayback Engine (hardware decode & audio master clock), SilkRender Pipeline (Metal 3 & Dolby Vision Profile 5 IPTPQc2 GPU reshaping pipeline), and SilkThumb Engine (fast-seek & LRU thumbnail caching architectures), are physically decoupled and isolated in `SilkCoreKit`.
- **Public Open-Source Notice**: All public frontend source code of SilkPlayer is accessible under LGPL-3.0 terms.
- **Third-Party Open-Source Notice**: Third-party components bundled or linked retain their respective upstream copyrights and licensing terms. See individual upstream repositories for corresponding upstream source code.

---

## 5. Trademarks & Disclaimers

- **Apple, macOS, Apple Silicon, Metal, VideoToolbox, AppKit, and SwiftUI** are registered trademarks of Apple Inc. in the United States and other countries.
- **Dolby, Dolby Vision, and Dolby TrueHD** are trademarks or registered trademarks of Dolby Laboratories Licensing Corporation.
- **DTS and DTS-HD** are trademarks or registered trademarks of DTS, Inc.
- SilkPlayer is an independent open-source project and is **not** endorsed by, affiliated with, or sponsored by Apple Inc., Dolby Laboratories, or DTS Inc.
- This software is distributed under the terms of the LGPL-3.0 license on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
