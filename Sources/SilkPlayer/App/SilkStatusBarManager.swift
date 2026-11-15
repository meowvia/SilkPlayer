import AppKit
import SwiftUI

/// Status bar manager enabling background playback with zero Dock footprint (`NSApplication.ActivationPolicy.accessory`).
@MainActor
public final class SilkStatusBarManager: NSObject, NSMenuDelegate {
    public static let shared = SilkStatusBarManager()

    /// Flag indicating whether SilkPlayer is currently minimized to the status bar in background playback mode.
    public private(set) var isBackgroundPlaybackActive = false

    private var statusItem: NSStatusItem?
    private weak var hiddenWindow: NSWindow?
    private var boundSessionId: UUID?

    private override init() {
        super.init()
    }

    // MARK: - Public Entrypoints

    /// Minimizes the player to the macOS status bar and completely removes the Dock icon.
    public func enterBackgroundMode(window: NSWindow? = nil) {
        let targetWindow = window
            ?? PlayerWindowManager.shared.activeSession(preferKey: true)?.window
            ?? NSApp.keyWindow
            ?? NSApp.windows.first(where: { $0.isVisible && !$0.className.contains("NSStatusBarWindow") })

        isBackgroundPlaybackActive = true
        hiddenWindow = targetWindow

        if let active = PlayerWindowManager.shared.activeSession(preferKey: true) {
            boundSessionId = active.id
        } else if let matched = PlayerWindowManager.shared.sessions.first(where: { $0.window === targetWindow }) {
            boundSessionId = matched.id
        }

        installStatusItemIfNeeded()

        // 1. Order out active window
        targetWindow?.orderOut(nil)

        // 2. Erase Dock icon and Cmd+Tab entry
        if !isUnitTestEnvironment {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// Restores the player window to the foreground and brings back the standard Dock icon.
    public func exitBackgroundMode() {
        // 1. Restore standard application activation policy with Dock presence
        if !isUnitTestEnvironment {
            NSApp.setActivationPolicy(.regular)
        }

        // 2. Bring window to front
        let targetWindow = hiddenWindow
            ?? PlayerWindowManager.shared.activeSession(preferKey: true)?.window
            ?? PlayerWindowManager.shared.sessions.first(where: { $0.window != nil })?.window

        if let win = targetWindow {
            win.makeKeyAndOrderFront(nil)
        } else {
            PlayerWindowManager.shared.openNewWindow()
        }

        if !isUnitTestEnvironment {
            NSApp.activate(ignoringOtherApps: true)
        }

        // 3. Tear down status bar item
        removeStatusItem()

        isBackgroundPlaybackActive = false
        hiddenWindow = nil
        boundSessionId = nil
    }

    private var isUnitTestEnvironment: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
    }

    // MARK: - Status Item Lifecycle

    private func installStatusItemIfNeeded() {
        guard statusItem == nil, !isUnitTestEnvironment else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .regular)
            let img = NSImage(systemSymbolName: "music.note", accessibilityDescription: "SilkPlayer")?.withSymbolConfiguration(symbolConfig)
            img?.isTemplate = true
            button.image = img
            button.toolTip = "SilkPlayer"
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu

        statusItem = item
    }

    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - Dynamic Menu Construction

    public func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        let session = currentSession()
        let player = session?.player
        let rawTitle = player?.mediaTitle ?? ""
        let isPlaying = player?.isPlaying ?? false

        // 1. Media Info Header (Read-only)
        let displayTitle = rawTitle.isEmpty
            ? (isPlaying ? L10n.tr("Playing Audio", "正在播放") : "SilkPlayer")
            : rawTitle

        let headerItem = NSMenuItem(title: displayTitle, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Transport Controls: Previous, Play/Pause, Next
        let prevItem = NSMenuItem(
            title: L10n.tr("Previous Track", "上一首"),
            action: #selector(handlePreviousTrack),
            keyEquivalent: ""
        )
        prevItem.target = self
        prevItem.isEnabled = session?.playPreviousHandler != nil
        menu.addItem(prevItem)

        let playPauseTitle = isPlaying
            ? L10n.tr("Pause", "暂停")
            : L10n.tr("Play", "播放")
        let playPauseItem = NSMenuItem(
            title: playPauseTitle,
            action: #selector(handleTogglePlayPause),
            keyEquivalent: ""
        )
        playPauseItem.target = self
        playPauseItem.isEnabled = player != nil
        menu.addItem(playPauseItem)

        let nextItem = NSMenuItem(
            title: L10n.tr("Next Track", "下一首"),
            action: #selector(handleNextTrack),
            keyEquivalent: ""
        )
        nextItem.target = self
        nextItem.isEnabled = session?.playNextHandler != nil
        menu.addItem(nextItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Open Player & Quit
        let openItem = NSMenuItem(
            title: L10n.tr("Open Player", "打开播放器"),
            action: #selector(handleOpenPlayer),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let quitItem = NSMenuItem(
            title: L10n.tr("Quit SilkPlayer", "退出 SilkPlayer"),
            action: #selector(handleQuitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func handlePreviousTrack() {
        currentSession()?.playPreviousHandler?()
    }

    @objc private func handleTogglePlayPause() {
        currentSession()?.player?.togglePlayPause()
    }

    @objc private func handleNextTrack() {
        currentSession()?.playNextHandler?()
    }

    @objc private func handleOpenPlayer() {
        exitBackgroundMode()
    }

    @objc private func handleQuitApp() {
        NSApp.terminate(nil)
    }

    private func currentSession() -> PlayerWindowSession? {
        if let id = boundSessionId, let matched = PlayerWindowManager.shared.session(for: id) {
            return matched
        }
        return PlayerWindowManager.shared.activeSession(preferKey: true)
            ?? PlayerWindowManager.shared.sessions.first
    }
}
