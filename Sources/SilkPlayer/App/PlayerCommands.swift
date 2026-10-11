import SwiftUI
import AppKit

/// Centralized macOS Menu Bar Commands architecture for SilkPlayer.
/// Fully conforms to macOS Human Interface Guidelines (Apple HIG) with standard
/// Playback, Audio, Subtitle, Video, Window, and Help menus, comprehensive keyboard shortcuts,
/// dynamic command validation gates, and multi-window session routing.
@MainActor
public struct PlayerCommands: Commands {
    private var windowManager = PlayerWindowManager.shared
    private var settings = AppSettings.shared

    public init() {}

    private var activePlayer: (any PlayerControllable)? {
        windowManager.activePlayer
    }

    private var isLoaded: Bool {
        activePlayer?.isLoaded == true
    }

    public var body: some Commands {
        // MARK: - Native Preferences Command
        CommandGroup(replacing: .appSettings) {
            Button(L10n.settings + "...") {
                windowManager.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        // MARK: - File Menu Enhancements (Strictly Single Window)
        CommandGroup(replacing: .newItem) {
            Button(L10n.openFile + "...") {
                windowManager.openFilePicker()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            if isLoaded {
                Button(L10n.tr("Close Media", "关闭当前媒体")) {
                    windowManager.closePlaybackOrReturnToEmpty()
                }
                .keyboardShortcut("w", modifiers: .command)
            } else {
                Button(L10n.tr("Close Window", "关闭窗口")) {
                    windowManager.closeActiveWindow()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }

        // MARK: - Playback Menu
        CommandMenu(L10n.menuPlayback) {
            Button(activePlayer?.isPlaying == true ? L10n.pause : L10n.play) {
                activePlayer?.togglePlayPause()
            }
            .keyboardShortcut(.space, modifiers: [])

            Divider()

            Button(L10n.tr("Step Forward", "快进")) {
                activePlayer?.step(seconds: settings.shortSeekStep)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(!isLoaded)

            Button(L10n.tr("Step Backward", "快退")) {
                activePlayer?.step(seconds: -settings.shortSeekStep)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(!isLoaded)

            Button(L10n.tr("Long Step Forward", "大步快进")) {
                activePlayer?.step(seconds: settings.longSeekStep)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.option])
            .disabled(!isLoaded)

            Button(L10n.tr("Long Step Backward", "大步快退")) {
                activePlayer?.step(seconds: -settings.longSeekStep)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.option])
            .disabled(!isLoaded)

            Divider()

            // Frame Step Micro-adjustments
            Button(L10n.frameStepForward) {
                activePlayer?.stepFrame(forward: true)
            }
            .keyboardShortcut("]", modifiers: [])
            .disabled(!isLoaded)

            Button(L10n.frameStepBackward) {
                activePlayer?.stepFrame(forward: false)
            }
            .keyboardShortcut("[", modifiers: [])
            .disabled(!isLoaded)

            Divider()

            Button(L10n.nextTrack) {
                activePlayer?.onNextTrackRequested?()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled(!isLoaded)

            Button(L10n.previousTrack) {
                activePlayer?.onPreviousTrackRequested?()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(!isLoaded)

            Divider()

            // Playback Speed Hierarchy
            Menu(L10n.playbackSpeed) {
                let currentSpeed = activePlayer?.speed ?? 1.0
                Button("0.25x" + (abs(currentSpeed - 0.25) < 0.05 ? " ✓" : "")) {
                    activePlayer?.setSpeed(0.25)
                }
                Button("0.5x" + (abs(currentSpeed - 0.5) < 0.05 ? " ✓" : "")) {
                    activePlayer?.setSpeed(0.5)
                }
                Button("0.75x" + (abs(currentSpeed - 0.75) < 0.05 ? " ✓" : "")) {
                    activePlayer?.setSpeed(0.75)
                }
                Button(L10n.speedNormal + (abs(currentSpeed - 1.0) < 0.05 ? " ✓" : "")) {
                    activePlayer?.setSpeed(1.0)
                }
                Button("1.25x" + (abs(currentSpeed - 1.25) < 0.05 ? " ✓" : "")) {
                    activePlayer?.setSpeed(1.25)
                }
                Button("1.5x" + (abs(currentSpeed - 1.5) < 0.05 ? " ✓" : "")) {
                    activePlayer?.setSpeed(1.5)
                }
                Button("2.0x" + (abs(currentSpeed - 2.0) < 0.05 ? " ✓" : "")) {
                    activePlayer?.setSpeed(2.0)
                }

                Divider()

                Button(L10n.speedIncrease) {
                    activePlayer?.setSpeed(currentSpeed + 0.25)
                }
                .keyboardShortcut("]", modifiers: [.command])

                Button(L10n.speedDecrease) {
                    activePlayer?.setSpeed(max(0.25, currentSpeed - 0.25))
                }
                .keyboardShortcut("[", modifiers: [.command])

                Button(L10n.speedReset) {
                    activePlayer?.setSpeed(1.0)
                }
            }
            .disabled(!isLoaded)

            Divider()

            Button(L10n.tr("Stop Playback", "停止播放")) {
                windowManager.closePlaybackOrReturnToEmpty()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(!isLoaded)
        }

        // MARK: - Audio Menu
        CommandMenu(L10n.menuAudio) {
            Button(L10n.tr("Volume Up (+10%)", "增加音量 (+10%)")) {
                activePlayer?.adjustVolume(by: 10.0)
            }
            .keyboardShortcut(.upArrow, modifiers: [])

            Button(L10n.tr("Volume Down (-10%)", "减小音量 (-10%)")) {
                activePlayer?.adjustVolume(by: -10.0)
            }
            .keyboardShortcut(.downArrow, modifiers: [])

            Button(activePlayer?.isMuted == true ? L10n.unmuteAudio : L10n.muteAudio) {
                activePlayer?.toggleMute()
            }
            .keyboardShortcut("m", modifiers: [])

            Divider()

            Button(L10n.cycleAudioTrack) {
                activePlayer?.cycleAudioTrack()
            }
            .keyboardShortcut("a", modifiers: [])
            .disabled(!isLoaded)

            if let player = activePlayer, !player.audioTracks.isEmpty {
                Divider()
                ForEach(player.audioTracks) { track in
                    Button(track.displayName + (track.isSelected ? " ✓" : "")) {
                        player.setAudioTrack(id: track.id, notifyOSD: true)
                    }
                }
            }

            Divider()

            // Audio Delay Adjustments
            Menu(L10n.audioDelay) {
                Button(L10n.increaseAudioDelay) {
                    activePlayer?.adjustAudioDelay(by: 0.1)
                }
                Button(L10n.decreaseAudioDelay) {
                    activePlayer?.adjustAudioDelay(by: -0.1)
                }
                Divider()
                Button(L10n.resetAudioDelay) {
                    activePlayer?.resetAudioDelay()
                }
            }
            .disabled(!isLoaded)
        }

        // MARK: - Subtitle Menu
        CommandMenu(L10n.menuSubtitle) {
            Button(L10n.cycleSubtitleTrack) {
                activePlayer?.cycleSubtitleTrack()
            }
            .keyboardShortcut("s", modifiers: [])

            Button(L10n.disableSubtitles) {
                activePlayer?.setSubtitleTrack(id: 0, notifyOSD: true)
            }
            .disabled(!isLoaded)

            Divider()

            Button(L10n.loadExternalSubtitle) {
                activePlayer?.openSubtitleDialog()
            }
            .disabled(!isLoaded)

            if let player = activePlayer, !player.subtitleTracks.isEmpty {
                Divider()
                ForEach(player.subtitleTracks) { track in
                    Button(track.displayName + (track.isSelected ? " ✓" : "")) {
                        player.setSubtitleTrack(id: track.id, notifyOSD: true)
                    }
                }
            }

            Divider()

            // Subtitle Delay Adjustments
            Menu(L10n.subtitleDelay) {
                Button(L10n.increaseSubtitleDelay) {
                    activePlayer?.adjustSubtitleDelay(by: 0.1)
                }
                Button(L10n.decreaseSubtitleDelay) {
                    activePlayer?.adjustSubtitleDelay(by: -0.1)
                }
                Divider()
                Button(L10n.resetSubtitleDelay) {
                    activePlayer?.resetSubtitleDelay()
                }
            }
            .disabled(!isLoaded)

            // Subtitle Size Adjustments
            Menu(L10n.subtitleScale) {
                Button(L10n.increaseSubtitleScale) {
                    activePlayer?.adjustSubtitleScale(by: 0.1)
                }
                Button(L10n.decreaseSubtitleScale) {
                    activePlayer?.adjustSubtitleScale(by: -0.1)
                }
                Divider()
                Button(L10n.resetSubtitleScale) {
                    activePlayer?.resetSubtitleScale()
                }
            }
            .disabled(!isLoaded)
        }

        // MARK: - Video Menu
        CommandMenu(L10n.menuVideo) {
            Button(activePlayer?.isFullscreen == true ? L10n.exitFullscreen : L10n.enterFullscreen) {
                activePlayer?.toggleFullscreen()
            }
            .keyboardShortcut("f", modifiers: [.command])

            Button(L10n.tr("Capture Screenshot", "截取画面")) {
                activePlayer?.takeScreenshot()
            }
            .keyboardShortcut("s", modifiers: [.command])

            Divider()

            // Aspect Ratio Submenu with Selection Checkmarks
            Menu(L10n.aspectRatio) {
                let currentRatio = activePlayer?.videoAspectRatio ?? "auto"
                Button(L10n.aspectRatioDefault + (currentRatio == "auto" ? " ✓" : "")) {
                    activePlayer?.setAspectRatio("auto")
                }
                Button(L10n.aspectRatio16_9 + (currentRatio == "16:9" ? " ✓" : "")) {
                    activePlayer?.setAspectRatio("16:9")
                }
                Button(L10n.aspectRatio4_3 + (currentRatio == "4:3" ? " ✓" : "")) {
                    activePlayer?.setAspectRatio("4:3")
                }
                Button(L10n.aspectRatio235_1 + (currentRatio == "2.35:1" ? " ✓" : "")) {
                    activePlayer?.setAspectRatio("2.35:1")
                }
            }
            .disabled(!isLoaded)

            Divider()

            Menu(L10n.tr("Rotation & Flip", "画面旋转与翻转")) {
                let rot = activePlayer?.transform.effectiveRotation ?? 0
                let flipH = activePlayer?.transform.flipH ?? false
                let flipV = activePlayer?.transform.flipV ?? false

                Button(L10n.tr("Rotate 90° Clockwise", "顺时针旋转 90°")) {
                    activePlayer?.rotateVideo(clockwise: true)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button(L10n.tr("Rotate 90° Counterclockwise", "逆时针旋转 90°")) {
                    activePlayer?.rotateVideo(clockwise: false)
                }
                .keyboardShortcut("r", modifiers: [.shift, .command])

                Button(L10n.tr("Reset Orientation", "复位")) {
                    activePlayer?.resetVideoRotation()
                }
                .keyboardShortcut("r", modifiers: [.option, .command])

                Divider()

                Button(L10n.tr("Flip Horizontal", "水平翻转") + (flipH ? " ✓" : "")) {
                    activePlayer?.toggleFlipHorizontal()
                }
                .keyboardShortcut("m", modifiers: [.shift, .command])

                Button(L10n.tr("Flip Vertical", "垂直翻转") + (flipV ? " ✓" : "")) {
                    activePlayer?.toggleFlipVertical()
                }

                Divider()

                Button("0°" + (rot == 0 ? " ✓" : "")) {
                    activePlayer?.setExactRotation(0)
                }
                Button("90°" + (rot == 90 ? " ✓" : "")) {
                    activePlayer?.setExactRotation(90)
                }
                Button("180°" + (rot == 180 ? " ✓" : "")) {
                    activePlayer?.setExactRotation(180)
                }
                Button("270°" + (rot == 270 ? " ✓" : "")) {
                    activePlayer?.setExactRotation(270)
                }
            }
            .disabled(!isLoaded)

            Divider()

            Button(L10n.toggleDeband + (activePlayer?.isDebandEnabled == true ? " ✓" : "")) {
                activePlayer?.toggleDeband()
            }
            .keyboardShortcut("d", modifiers: [])
            .disabled(!isLoaded)

            // Picture Adjustments
            Menu(L10n.pictureAdjustments) {
                Button(L10n.increaseSharpen) {
                    activePlayer?.adjustSharpen(by: 0.1)
                }
                Button(L10n.decreaseSharpen) {
                    activePlayer?.adjustSharpen(by: -0.1)
                }
                Divider()
                Button(L10n.increaseContrast) {
                    activePlayer?.adjustContrast(by: 5.0)
                }
                Button(L10n.decreaseContrast) {
                    activePlayer?.adjustContrast(by: -5.0)
                }
                Divider()
                Button(L10n.increaseBrightness) {
                    activePlayer?.adjustBrightness(by: 5.0)
                }
                Button(L10n.decreaseBrightness) {
                    activePlayer?.adjustBrightness(by: -5.0)
                }
                Divider()
                Button(L10n.resetPictureAdjustments) {
                    activePlayer?.resetPictureAdjustments()
                }
            }
            .disabled(!isLoaded)
        }

        // MARK: - Window Menu
        CommandMenu(L10n.menuWindow) {
            Button(L10n.mediaInspectorTitle + (activePlayer?.isInspectorVisible == true ? " ✓" : "")) {
                activePlayer?.toggleInspector()
            }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(!isLoaded)

            Button(L10n.playlist + (activePlayer?.isPlaylistDrawerVisible == true ? " ✓" : "")) {
                activePlayer?.togglePlaylistDrawer()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(activePlayer == nil)

            Divider()

            Button(L10n.floatOnTop + (windowManager.isAlwaysOnTop ? " ✓" : "")) {
                windowManager.toggleAlwaysOnTop()
            }

            Divider()

            Menu(L10n.fitToVideo) {
                Button(L10n.fitToVideo100) {
                    windowManager.fitActiveWindow(scale: 1.0)
                }
                Button(L10n.fitToVideo200) {
                    windowManager.fitActiveWindow(scale: 2.0)
                }
            }
            .disabled(!isLoaded)
        }

        // MARK: - Help Menu
        CommandGroup(replacing: .help) {
            Button(L10n.keyboardShortcuts + "...") {
                windowManager.openShortcutsCheatsheet()
            }
            .keyboardShortcut("/", modifiers: .command)

            Divider()

            Button(L10n.aboutSilkPlayer) {
                NSApp.orderFrontStandardAboutPanel(nil)
            }
        }
    }
}
