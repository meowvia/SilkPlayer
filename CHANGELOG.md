# Changelog

All notable changes to **SilkPlayer** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] - 2026-11-12

### Added
- **Context Menu Window Size Presets (Proposal 027 / GitHub Issue #6)**:
  - Added a `Window Size` submenu (`50%`, `75%`, `100%`, and `Reset to Default`) to the video canvas context menu (`MetalPlayerContainerView`), with dynamic boundary state/enablement gating and automatic disablement in fullscreen, audio-only, or unloaded states.
  - Refactored window geometry helpers (`PlayerGeometry.adaptiveVideoContentSize`, `windowPresetContentSize`, `windowPresetMenuState`) and `PlayerCore.fitWindow(scale:)` / `resetWindowSize()` with aspect-locked uncropped bounding inside desktop visible limits, temporary `minSize` relaxation, maximized-state reset, and percentage OSD feedback.
- **Window Live-Resize Precision Dimension HUD (Proposal 023)**:
  - Dynamically floats a translucent, monospaced dimension badge near the cursor during manual window edge resizing.
  - Reports exact physical pixel dimensions (`width × height`) and standard aspect ratios (`16:9`, `16:10`, `4:3`, `21:9`, `2.39:1`, `1:1`).
  - Automatically identifies native resolution with `100%` badge for pixel-perfect promotional screenshots and professional viewing, smoothly fading out 0.35s after resize ends.
- **Dynamic EDR Tone-Mapping & Rational Highlight Roll-off (Proposal 013)**:
  - Injected dynamic display physical headroom (`cachedEDRHeadroom`) into Metal fragment shaders for HDR10 and Dolby Vision pipelines.
  - Standardized on ITU-R BT.2408 diffuse white reference level ($Y \le 1.0$) for 1:1 uncompressed absolute fidelity.
  - Implemented $C^1$-continuous rational shoulder roll-off for extreme highlights, scaling RGB channels proportionately to prevent solarization, cloud blowout, and chromaticity shift on both Apple XDR and SDR screens.
- **Smart Silent Update & Lossless In-Place Overwrite Installer (Proposal 020)**:
  - Built-in `UpdateService` providing asynchronous background release checking against GitHub API, resolving `-universal.dmg` release assets first via `resolveDownloadURLString` (with architecture fallback).
  - Cold-start prompt displays target latest version number with minimal binary choice ("Yes" / "No") and 7-day quiet cadence gatekeeper upon dismissal.
  - Persistent 6pt red dot indicator on the Settings "About" tab when an update is pending.
  - End-to-end in-place lossless updater replacing `/Applications/SilkPlayer.app` cleanly while 100% preserving all user history, playlists, and preferences.
- **Playlist Drawer Handle Border-Flush Redesign (Proposal 019)**:
  - Replaced solid pill handle with a 100% transparent cutout, eliminating visual blockage.
  - 1.0pt delicate three-sided border with open right edge and 0pt margin flush against the window border.
  - Replaced standard triangle with an ultra-slender 9.5pt flattened indicator triangle.
  - AppKit native view implementation with explicit hit-test lock, permanently preventing NSThemeFrame from triggering window resize dragging.
- **Playback Controls & HUD Customization**:
  - Restored "Resume Playback Progress" toggle and "Dual Playlist Mode" (smart audio/video separation).
  - Added playback history retention toggle and one-click clear history action.
  - Added configurable seek step options, mouse scroll wheel binding (Volume / Seek), and window double-click actions.
  - Added Fullscreen Clock HUD overlay toggle and configurable screenshot formats (PNG / JPEG) with custom directory selection.

### Changed
- **Settings Architecture macOS HIG Overhaul (Proposal 018)**:
  - Consolidated settings into 3 standard top-level tabs: General, Playback, and About.
  - Standardized on 520 × 490 pt fixed dimensions with zero vertical scrollbars and native macOS form controls.
  - Embedded official high-resolution vector brand emblem and full Apple Silicon / Intel architecture information.
  - Replaced all non-standard configuration switches with fully automated system defaults.
- **Policy & Architecture Narrative Alignment**:
  - Removed obsolete absolute claims across codebase and documentation, standardizing on: "Native, lightweight, and minimal design with zero built-in ads and no redundant background processes."

### Fixed
- **HUD Narrow Window Volume Control Overlap (ISSUE-019)**:
  - Hid the inline bottom volume slider in `.minimal` layout tier (`< 480 pt` narrow/portrait windows) while keeping a mute/unmute toggle inside the overflow menu, eliminating overlap with the Next button.
- **Top Menu Bar Duplicate Window Menu & Fit-to-Video Cleanup (ISSUE-020)**:
  - Replaced the duplicate `Window` `CommandMenu` with `CommandGroup(before: .windowList)` so Media Inspector, Playlist, and Float on Top integrate into the standard macOS Window menu, and removed the redundant `Fit to Video (100% / 200%)` menu item.

---

## [1.5.1] - 2026-11-08

### Fixed
- **AV1 Video Decoding Support via libdav1d**:
  - Integrated high-performance `libdav1d` library into FFmpeg multimedia decoding pipeline across both Apple Silicon (`arm64`) and Intel (`x86_64`) architectures.
  - Resolved issue where playing MKV, MP4, or WebM media containing AV1 video streams resulted in audio playback with a black video display due to lack of hardware accelerated AV1 decoding on macOS.

---

## [1.5.0] - 2026-11-07

### Added
- **Universal Binary Distribution**: Native dual-slice images containing arm64 and x86_64 architectures, executing natively on both Apple Silicon (M1-M4) and Intel Macs without Rosetta 2 translation.
- **Interactive Volume Slider & Pre-play Audio Ramp**:
  - Upgraded HUD volume icon to dynamic state button; hovering smoothly reveals high-precision slider for fine-grained adjustments (Proposal 015).
  - Implemented pre-play smooth audio ramp transition algorithm to eliminate transient pop noises during initial playback and seek jumps.
- **Global Natural Semantic Sorting for Episodes**:
  - Recursive multi-folder scanning with flat media extraction (Proposal 016).
  - Built-in natural semantic sorting recognizing episode tags (S01E01, EP02) to preserve natural sequence across batch imports.

### Optimized
- **4K Video Memory & Demuxer Overhead Reduction**:
  - Bound frame caching to 3 frames during continuous playback, slashing resident memory footprint for 4K 10-bit media (Proposal 017).
  - Replaced busy-waiting with `NSCondition` synchronization in demuxing pipeline, eliminating idle CPU waste.
  - Automatic pause of bloom rendering during idle/pause states to prevent wasteful redraws.
- **Pure Audio Rendering Efficiency**:
  - Removed real-time Gaussian blur from vinyl artwork and ambient glow pipeline.
  - Throttled audio spectrum sampler and beat timer to 20Hz with dynamic threshold deadzone filtering.

### Fixed
- Fixed window state deadlock where double-clicking failed to enter fullscreen after toggling always-on-top or manual resizing (ISSUE-012).
- Fixed issue where pressing Esc in fill-maximized mode exited playback, accurately restoring normal window dimensions (ISSUE-013).
- Fixed window border jitter during manual window resizing in pure audio mode (ISSUE-011).

---

## [1.4.0] - 2026-10-31

### Added
- **Dual-Track Media Playlist**: Split queue into dedicated Video and Audio categories with automatic routing, isolated position tracking, and distinct playback state machines (Proposal 006).
- **Fallback Document Icons & Branding**: Added custom document icons and fallback branding artwork for non-native media preview formats (Proposal 011).

### Fixed
- **4K External Storage Seek Synchronization**: Fixed out-of-sync playback and hunger re-anchor failure on 4K 10-bit HEVC files stored on external USB/SMB drives (ISSUE-009).
- **Packaging Dynamic Library Path Leak**: Enforced zero-leak `@rpath` assertions in `package_app.sh`, resolving launch crashes on Intel Macs (ISSUE-010).
- **Window Interaction Audit Resolutions**: Resolved scroll wheel event interception in `PlayerHUDView`, unified always-on-top state source, corrected top-bar double-click bounding box, and prevented canvas drag in bottom control regions.

---

## [1.3.0] - 2026-10-24

### Added
- **Default Player & Format Associations**: Built-in format association manager in Settings, allowing one-click registration as default handler for common video/audio extensions via LaunchServices (Proposal 002).

### Fixed
- **Audio Scrubber Seek Clock Offset**: Fixed hardware sample accumulation clock offset during paused-state scrub operations in `SilkAudioEngine` (ISSUE-007).
- **macOS Dock Icon Contrast**: Enhanced edge contrast and ambient highlight curve for application Dock icon (ISSUE-008).

---

## [1.2.0] - 2026-10-20

### Fixed
- **Audio Playback Speed**: Fixed playback rate parameter application in `SilkAudioEngine` with pitch-preserved time-domain stretching (ISSUE-001).
- **Shuffle Playback History Memory**: Implemented memory-based sampling queue preventing rapid repeat of recently played tracks (ISSUE-002).
- **Pure Audio Layout Collisions**: Resolved window layout clipping and visual artifact collisions in pure audio mode (ISSUE-003).
- **Window Geometry & Interaction Topology**: Comprehensive overhaul of window constraint state machine, aspect-ratio preservation, and live-resize event flow (ISSUE-004).
- **Metal Occlusion Audio Streaming**: Guarded audio output clock from render stalling when video window is fully occluded (ISSUE-005).
- **SMB Streaming Buffer Starvation**: Optimized streaming buffer watermark and packet pre-fetch for network-attached shares (ISSUE-006).

---

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
