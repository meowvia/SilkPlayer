# Third-Party Dependencies & Open Source Notices (第三方开源软件声明)

SilkPlayer relies on open-source libraries and native platform frameworks. This document outlines the third-party components, their licenses, source repositories, and redistribution terms in accordance with open-source licensing standards.

---

## 1. Primary Open-Source Dependencies

| Component | License | Origin / Repository | Linkage | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **FFmpeg / FFmpegKit** | **LGPL-3.0 / GPL-3.0** | [FFmpeg](https://ffmpeg.org) / [arthenica/ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit) | Embedded Framework (`Libavformat`, `Libavcodec`, `Libswscale`, `Libavutil`) | Media container demuxing (MKV, MP4, WebM, etc.), audio decoding, and software video fallbacks. |

---

## 2. Platform Frameworks (Apple macOS SDK)

The following system frameworks are provided by Apple Inc. as part of the macOS SDK:

| Framework | Provider | Availability | Purpose |
| :--- | :--- | :--- | :--- |
| **Metal / QuartzCore** | Apple Inc. | macOS 14.0+ | Direct GPU surface rendering (`CAMetalLayer`). |
| **VideoToolbox** | Apple Inc. | macOS 14.0+ | Hardware-accelerated decoding (HEVC, H.264, ProRes, VP9). |
| **AudioToolbox / AVFoundation** | Apple Inc. | macOS 14.0+ | Audio output rendering, channel layout management, system volume integration. |
| **AppKit / SwiftUI** | Apple Inc. | macOS 14.0+ | Native window management, display synchronization, event monitors, and user interface. |

---

## 3. License Compliance & Architectural Boundaries

- **SilkPlayer Repository Licensing**: This public repository of SilkPlayer is licensed under the **GNU Lesser General Public License v3.0 (LGPL-3.0)**.
- **Proprietary Architecture & Physical Isolation**: Proprietary intellectual property, including the SilkPlayback Engine (hardware decode & audio master clock), SilkRender Pipeline (Metal 3 & Dolby Vision Profile 5 IPTPQc2 GPU reshaping shaders), and SilkThumb Engine (fast-seek & LRU thumbnail caching architectures), are physically decoupled and isolated in `SilkCoreKit` (`/Volumes/2T/SilkCoreKit`).
- **Commercial & Closed-Source Compliance Roadmap**:
  - In accordance with LGPL-3.0 / LGPL-2.1 Section 4 guidelines, any proprietary or commercial redistribution of the host application requires that third-party FFmpeg components be built strictly in **pure LGPL mode** (`--disable-gpl`) and linked dynamically (`Contents/Frameworks/`).
  - This architecture preserves user relinkability rights for LGPL libraries while providing full legal protection for the host player's proprietary UI, playback engine (`SilkPlayback Engine`), rendering pipeline (`SilkRender Pipeline`), thumbnail engine (`SilkThumb Engine`), and `SilkCoreKit` IP under standard commercial end-user license agreements (EULA).
- **Public Open-Source Notice**: All public frontend source code of SilkPlayer is accessible under LGPL-3.0 terms.
- **Third-Party Open-Source Notice**: Third-party components bundled or linked retain their respective upstream copyrights and licensing terms. See individual upstream repositories for corresponding upstream source code.

---

## 4. Trademarks & Disclaimers

- **Apple, macOS, Apple Silicon, Metal, VideoToolbox, AppKit, and SwiftUI** are registered trademarks of Apple Inc. in the United States and other countries.
- **Dolby, Dolby Vision, and Dolby TrueHD** are trademarks or registered trademarks of Dolby Laboratories Licensing Corporation.
- **DTS and DTS-HD** are trademarks or registered trademarks of DTS, Inc.
- SilkPlayer is an independent open-source project and is **not** endorsed by, affiliated with, or sponsored by Apple Inc., Dolby Laboratories, or DTS Inc.
- This software is distributed under the terms of the GPL-3.0 license on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
