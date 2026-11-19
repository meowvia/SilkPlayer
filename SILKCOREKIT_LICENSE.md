# SilkCoreKit Binary License Agreement (许可协议)

Copyright (c) 2026 meowvia. All Rights Reserved.

IMPORTANT: PLEASE READ THIS LICENSE AGREEMENT CAREFULLY BEFORE USING, DOWNLOADING, OR DISTRIBUTING SILKCOREKIT.

By downloading, copying, or using the precompiled binary package of SilkCoreKit (`SilkCoreKit.xcframework`), you agree to be bound by the terms and conditions of this Agreement.

---

### 1. Grant of License
Subject to the terms and restrictions herein, the author grants you a revocable, non-exclusive, non-transferable license to:
- **Community / Standard Edition**: Use the precompiled binary framework solely as an embedded playback and rendering component integrated within the SilkPlayer application for personal, non-commercial media playback on compatible macOS devices.
- **Pro Edition**: Use the advanced playback, rendering, and cloud synchronization features of the binary framework in accordance with a valid commercial license key or active subscription granted by meowvia.

### 2. License Restrictions
Except as expressly permitted by applicable mandatory law or as set forth below, you agree NOT to, and will not permit any third party to:
- Decompile, disassemble, reverse engineer, decrypt, extract, or otherwise attempt to derive source code, Metal shaders, or proprietary algorithms from the `SilkCoreKit` binary library.
- Redistribute, sell, lease, rent, license, sub-license, host, or commercially exploit the `SilkCoreKit` binary library as a standalone package or inside third-party applications without explicit prior written authorization from meowvia.
- Modify, patch, or tamper with the binary symbols, export tables, metadata, or cryptographic signatures of `SilkCoreKit`.
- Remove, obscure, or alter any copyright notices, trademarks, or proprietary rights notices embedded in or affixed to `SilkCoreKit`.

**LGPL-3.0 Safe Harbor & Debugging Carve-Out**:
Nothing in this Section 2 or this Agreement shall restrict, limit, or impair the licensee's rights under Section 4 of the GNU Lesser General Public License v3.0 (LGPL-3.0) to inspect, debug, modify, or relink dynamically linked third-party LGPL libraries (specifically the embedded FFmpeg dynamic frameworks), or to conduct reverse engineering strictly to the extent necessary to debug modifications to such dynamically linked LGPL libraries.

### 3. Architectural Boundary & Dual-License Structure
- **Boundary Isolation**: `SilkCoreKit` is an independent, closed-source proprietary core library physically and architecturally decoupled from the host application across the standard Swift Package Manager binaryTarget interface (`.binaryTarget(name: "SilkCoreKit", ...)`).
- **Frontend Independence**: The public host player repository (SilkPlayer) is distributed under the GNU Lesser General Public License v3.0 (LGPL-3.0). Modifications, forks, or contributions to the LGPL-licensed host player frontend do NOT grant any rights to the proprietary source code, internal algorithms, or commercial assets of `SilkCoreKit`.
- **Redistribution Terms**: Redistribution of compiled binary packages of SilkPlayer embedding `SilkCoreKit` is permitted for official releases and non-commercial personal forks, provided all third-party license notices, this Agreement, and applicable LGPL notices remain intact. Commercial redistribution or bundling requires prior written authorization.

### 4. No Warranty & Limitation of Liability
`SILKCOREKIT` IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY ARISING FROM THE USE OF OR INABILITY TO USE THE SOFTWARE.

### 5. Commercial Licensing & OEM Inquiries (商业与 OEM 授权)
The closed-source playback engine, demuxing optimizations, hardware acceleration pipelines, and Metal zero-copy direct rendering modules within `SilkCoreKit` are available for commercial OEM licensing, bespoke embedding into third-party commercial applications, and enterprise custom licensing.

For enterprise licensing, evaluation builds, commercial integration agreements, or custom business inquiries, please contact:
- **Commercial Licensing Email**: `support@1999909.xyz`
- **Product Official Website**: `https://silkplayer.1999909.xyz`

