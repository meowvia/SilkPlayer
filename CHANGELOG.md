# Changelog

All notable changes to **SilkPlayer** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-10-15

### Added
- **Resonance Corona & Audiophile Vinyl Turntable**:
  - Circular acoustic resonance corona (`Resonance Corona`) dynamically reacting to real-time playback amplitude with centered glow emission.
  - Centered vinyl disc with continuous 60fps rotation driven by `TimelineView` and deterministic playback synchronization.
  - High-fidelity audiophile metal tonearm with high-contrast cartridge, visible stylus needle, and calibrated tracking kinematics synced with audio duration.
  - Expanded 32-band real-time audio horizon spectrum analyzer.
- **Dynamic Upcoming Track Preview**:
  - Responsive upcoming track indicator positioned underneath title metadata with 18pt offset indent.
  - 0ms reactive synchronization with `PlaylistManager` across single repeat, playlist repeat, shuffle (aligned PRNG seeds), and sequential queue boundaries.
- **Universal Audio Format Support**:
  - Direct playback, drag-and-drop ingestion, and playlist queuing for lossless FLAC, Monkey's Audio (APE), Apple Lossless (ALAC), WAV, AAC, MP3, and OGG.
  - Audio mode 1:1 proportional free resizing eliminating full-height screen snaps and Dock boundary invasion.

### Fixed
- **Zero-Flicker Track Transitions**:
  - Audio state keepalive and layout constraints preservation eliminating window re-layout flashes, black blinks, and vinyl rotation jerks during rapid song switches.
- **Window Geometry Stability**:
  - Orientation-aware window size memory read/write loop with safe dimension clamping and aspect ratio reset defense.
- **Core Stability**:
  - Eliminated audio playback deadlocks, timeline render re-entry loops, and dock boundary layout issues.
- **Metal Render Pipeline Compatibility & Fallback Defense**:
  - Enforced macOS 14.0 minimum deployment target for Metal shader bytecode (`air64_v26-apple-macosx14.0.0`) and added two-tier MSL source runtime compilation fallback (`dev.makeLibrary(source:)`), eliminating black screen rendering failures across varied macOS versions and GPU drivers.

---

## [1.0.0] - 2026-10-11

### Added
- **SilkCoreKit Proprietary Architecture**: Standardized core proprietary media subsystems into `SilkCoreKit.xcframework`:
  - **SilkPlayback Engine**: Swift 6 strict concurrency playback engine with VideoToolbox hardware decoding and native AudioUnit synchronized master clock.
  - **SilkRender Pipeline**: Metal 3 zero-copy GPU direct presentation with proprietary Dolby Vision Profile 5 (IPTPQc2) RPU dynamic color reshaping shaders.
  - **SilkThumb Engine**: Dedicated keyframe extraction and adaptive memory two-tier LRU caching pipeline (`SilkThumbEngine`), rendering instantaneous 16:9 hover previews and chapter cues.
- **Pure LGPL-3.0 Dynamic Architecture**: Built standalone lightweight dynamic XCFrameworks for core media processing libraries (`Libavcodec`, `Libavformat`, `Libavutil`, `Libswresample`, `Libswscale`) using pure LGPL configuration (`--disable-gpl --disable-nonfree --enable-shared --disable-static --enable-version3`).
- **Dynamic Linking & Bundle Assembly**: Conforming fully to LGPL-3.0 dynamic linking with `@rpath` dynamic framework linkage inside `Contents/Frameworks/`.
- **Inside-Out Code Signing**: Implemented layered code signing for embedded dynamic frameworks and the main application bundle.
- **Performance & Energy Optimizations**:
  - Configured `CAMetalLayer.framebufferOnly = true` to activate Apple GPU direct scanout, reducing GPU memory bandwidth and thermal footprint.
  - Wrapped high-frequency packet demuxing and frame rendering loops in fine-grained `autoreleasepool` scopes, strictly flattening physical resident memory (RSS).
  - Added periodic `CVMetalTextureCacheFlush` every 120 frames to bound CoreVideo texture cache residency.
- **Window Management & HIG Alignment**:
  - Implemented 0.16s `DispatchWorkItem` debounce isolating single-click pause from double-click fullscreen toggles.
  - Enabled 3.0pt drag threshold handoff to native macOS 15 Sequoia WindowServer tiling with 8pt border resize guard.
  - Blu-ray PGS canonical canvas normalization and dynamic typography sizing.
- **Automated Regression Suite**: Verified all 480 test assertions and 4-sample real-world playback stress benchmarks pass cleanly with 0 regressions.

### Changed
- **Terminology & Copywriting Standardization**: Systematically aligned documentation, user interface descriptions, and settings metadata with industry-standard terminology.
- **Project Licensing**: Formally released under GNU Lesser General Public License v3.0 (LGPL-3.0).

---

## [1.0.1] - 2026-10-08

### Added
- **Timeline Hover Preview (`SilkThumbnailEngine`)**:
  - Added keyframe thumbnail extraction using native FFmpeg C interfaces (`libavformat`, `libavcodec`, `libswscale`).
  - Container support for MP4, MKV, MOV, WebM, TS, M2TS, AVI, FLV, ProRes, etc.
  - Basic luminance and color tone-mapping for HDR10 and Dolby Vision (Profile 5 & 8) content using PQ LUT and Reinhard tone mapping.
  - Direct bitmap memory transfer using `CGDataProvider` and `NSBitmapImageRep` with BGRA pixel layout.
- **Scrubber Hover Card View (`ScrubberHoverCardView`)**:
  - Anchored 16:9 preview canvas (`156 × 88`) positioned above the progress track.
  - Displays chapter title and timestamps with transient image caching.

---

## [1.0.0] - 2026-10-05

### Added
- **Blu-ray PGS Canonical Canvas Normalization**: Subtitle bitmaps are mapped according to standard BD-ROM PGS 1920x1080 canvas specifications, ensuring accurate placement in bottom letterboxes across 4K UHD and 1080p media.
- **Text Subtitle Dynamic Sizing**: Overrode hardcoded 16pt styling from FFmpeg SRT/SubRip decoder to dynamically scale typography to video canvas height (~4.6%) and respect user font size presets.
- **Mouse Cursor Autohide Integration**: Implemented hardware display cursor hiding (`CGDisplayHideCursor` / `NSCursor`) synchronized with HUD auto-fading during playback, restoring immediately on mouse movement or pause.
- **Window Mouse Event Dispatch**: Configured `acceptsMouseMovedEvents = true` on the player window for continuous tracking.

---

## [0.5.0] - 2026-10-05

### Added
- **Native SilkEngine & Metal Rendering Pipeline**: Integrated initial hardware decoding directly outputting to `CAMetalLayer` surfaces via Apple VideoToolbox.
- **Aspect Ratio & Window Geometry Enforcement**: Implemented native AppKit window aspect ratio locking (`aspectRatio`, `contentAspectRatio`, and `windowWillResize`), ensuring correct proportions during window resizing and full-screen maximization per macOS standard behavior.
- **Subtitle & Audio Subsystem Overhaul**:
  - Activated Blu-ray PGS keyframe seek decoding (`isSeekImageSubtitle = true`).
  - Corrected PGS bitmap aspect-ratio calculation and letterbox compensation to prevent vertical distortion.
  - Implemented deduplicated subtitle track synchronization (`syncEmbeddedSubtitles`).
  - Added stream language metadata enrichment (`lang`, `codec`) and user-preferred language auto-selection.
  - Bound subtitle delay adjustments directly to the playback engine for real-time offset synchronization.
- **Unified Sidebar Drawer (`SilkUnifiedDrawerView`)**: Unified queue management and media inspection diagnostics into a collapsible sidebar.
- **Native Preferences View (`SilkSettingsView`)**: Multi-tab settings panel covering General, Playback & Controls, Audio & Subtitles, and About, with isolated event routing.
- **Keyboard Shortcuts Alignment**: Assigned `S` to cycle subtitle tracks, `A` to cycle audio tracks, and isolated screenshot capture to `⌘S`.
- **Automated Regression Suite**: Expanded automated test suite to 33 test suites (216 test assertions passing cleanly).

### Changed
- **Dependencies**: Migrated from legacy C bindings to pure Swift Package Manager dependency resolution targeting Apple system frameworks (`Metal`, `QuartzCore`, `VideoToolbox`, `AudioToolbox`, `AVFoundation`) and underlying FFmpeg libraries.
- **Memory Management**: Optimized buffer lifecycles and cache configurations to maintain stable memory usage during extended playback sessions.
- **Diagnostic Tools**: Relocated diagnostic and stress suites into `Tools/DiagnosticSuites/` to maintain clean production build targets.

---

## [0.4.6] - 2026-10-04

### Added
- **Fullscreen Space Compatibility**: Configured `.fullScreenAuxiliary` window behaviors for auxiliary sheets.
- **Event Isolation**: Modal views intercept `Esc` and `⌘W` to dismiss themselves without interrupting the underlying playback session.
- **Format Indicators**: Added format indicator badges for Dolby Vision (`dvhe`/`dvh1`/`dovi`), HDR10, and HLG profiles with tone-mapping toggle (`H`).
- **Safe Area Insets**: Adjusted UI margins to account for macOS window controls and menu bar insets.

### Changed
- **Control Bar Layout**: Standardized control bar button sizing and visual hierarchies.
- **Buffer Configurations**: Optimized streaming read-ahead buffers for local storage and network volumes.

---

## [0.4.5] - 2026-10-03

### Added
- **Settings Reorganization**: Streamlined preferences into structured functional categories.
- **Timeline Hover Indicator**: Added visual seek position indicator during timeline scrubbing.

### Fixed
- **Audio Output Buffering**: Addressed buffer underflow during initial stream setup.

---

## [0.4.4] - 2026-10-02

### Added
- **Dynamic Window Sizing**: Dynamic sizing calculations for auxiliary sheets and dialogs.
- **Visual Materials**: Applied system translucent materials across HUD overlays.

### Fixed
- **Resource Teardown**: Ensured deallocation of pixel buffers and render textures upon closing player windows.

---

## [0.4.3] - 2026-10-01

### Added
- **Multi-Window Support**: Added multi-window topology managed by `PlayerWindowManager`.
- **Network Storage Playback**: Enhanced buffer management for Finder-mounted SMB/NFS network shares.

---

## [0.4.2] - 2026-09-30

### Added
- **Multi-Track Audio**: Added support for selecting between multi-channel audio tracks.
- **Vector Subtitles**: Supported ASS/SSA, SRT, and WebVTT subtitle rendering.
- **Companion Subtitle Pairing**: Automatic loading of companion subtitle files sharing the same directory and base name.

---

## [0.1.0-beta] - 2026-09-28

### Added
- **Initial Native Architecture**: Swift 6 project setup targeting Apple Silicon on macOS 14.0+.
- **VideoToolbox Integration**: Initial pipeline verification for hardware-accelerated video decoding.
- **File System Indexer**: FSEvents-based directory monitoring and metadata persistence.
