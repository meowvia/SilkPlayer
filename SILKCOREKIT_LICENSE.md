# SilkCoreKit Binary License Agreement (Draft / 许可协议草案)

Copyright (c) 2026 meowvia. All Rights Reserved.

IMPORTANT: PLEASE READ THIS LICENSE AGREEMENT CAREFULLY BEFORE USING, DOWNLOADING, OR DISTRIBUTING SILKCOREKIT.

By downloading, copying, or using the precompiled binary package of SilkCoreKit (`SilkCoreKit.xcframework`), you agree to be bound by the terms and conditions of this Agreement.

---

### 1. Grant of License
Subject to the terms and restrictions herein, the author grants you a revocable, non-exclusive, non-transferable, royalty-free personal license to:
- Use the binary framework solely as an embedded playback and rendering component integrated within the SilkPlayer application.
- Use the binary framework for personal, non-commercial media playback on compatible macOS devices (Apple Silicon).

### 2. License Restrictions
Except as expressly permitted by applicable mandatory law, you agree NOT to, and will not permit any third party to:
- Decompile, disassemble, reverse engineer, decrypt, extract, or otherwise attempt to derive source code, Metal shaders, or algorithms from the `SilkCoreKit` binary library.
- Redistribute, sell, lease, rent, license, sub-license, host, or commercially exploit the `SilkCoreKit` binary library as a standalone package or inside third-party applications without explicit prior written authorization.
- Modify, patch, or tamper with the binary symbols, export tables, metadata, or cryptographic signatures of `SilkCoreKit`.
- Remove, obscure, or alter any copyright notices, trademarks, or proprietary rights notices embedded in or affixed to `SilkCoreKit`.

### 3. Architectural Boundary & Dual-License Structure
- **Boundary Isolation**: `SilkCoreKit` is an independent, closed-source proprietary core library physically and architecturally decoupled from the host application across the standard Swift Package Manager binaryTarget interface (`.binaryTarget(name: "SilkCoreKit", ...)`).
- **Frontend Independence**: The public host player repository (SilkPlayer) is distributed under the GNU Lesser General Public License v3.0 (LGPL-3.0). Modifications, forks, or contributions to the LGPL-licensed host player frontend do NOT grant any rights to the proprietary source code, internal algorithms, or commercial assets of `SilkCoreKit`.

### 4. No Warranty & Limitation of Liability
`SILKCOREKIT` IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY ARISING FROM THE USE OF OR INABILITY TO USE THE SOFTWARE.
