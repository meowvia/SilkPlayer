import Observation
import SwiftUI
import AppKit
import Combine

extension Notification.Name {
    public static let openExternalFileNotification = Notification.Name("com.silkplayer.openExternalFile")
}

/// Session representing an active SilkPlayer window and its isolated playback engine.
@MainActor
@Observable public final class PlayerWindowSession: Identifiable {
    public let id: UUID
    public weak var window: NSWindow?
    public weak var player: (any PlayerControllable)?
    private let isLoadedProvider: (@MainActor () -> Bool)?
    public var testIsKey: Bool?

    public var openPathHandler: (@MainActor (String) -> Void)?
    public var appendPlaylistHandler: (@MainActor ([String]) -> Void)?
    public var openFilePickerHandler: (@MainActor () -> Void)?
    public var onKeyDownHandler: (@MainActor (NSEvent) -> NSEvent?)?
    public var onFullScreenChangedHandler: (@MainActor (Bool) -> Void)?
    public var closePlaybackHandler: (@MainActor () -> Void)?
    public var windowDelegate: PlayerWindowDelegate?

    public init(
        id: UUID = UUID(),
        window: NSWindow? = nil,
        player: (any PlayerControllable)? = nil,
        isLoadedProvider: (@MainActor () -> Bool)? = nil
    ) {
        self.id = id
        self.window = window
        self.player = player
        self.isLoadedProvider = isLoadedProvider
    }

    public var isLoaded: Bool {
        isLoadedProvider?() ?? (player?.isLoaded ?? false)
    }

    public var isKey: Bool {
        testIsKey ?? (window?.isKeyWindow ?? false)
    }

    public func openPath(_ path: String) {
        openPathHandler?(path)
    }

    public func appendPlaylistPaths(_ paths: [String]) {
        appendPlaylistHandler?(paths)
    }

    public var isAlwaysOnTop: Bool {
        get { PlayerWindowManager.shared.isAlwaysOnTop }
        set { PlayerWindowManager.shared.isAlwaysOnTop = newValue }
    }

    public func toggleAlwaysOnTop() {
        PlayerWindowManager.shared.toggleAlwaysOnTop()
    }

    public func closePlaybackOrReturnToEmpty() {
        if let handler = closePlaybackHandler {
            handler()
        } else if let player = player {
            player.stopAndReturnToLibrary()
        } else {
            window?.close()
        }
    }

    public func stopAndReturnToLibrary() {
        closePlaybackOrReturnToEmpty()
    }
}

/// Centralized coordinator for window lifecycle, single-window reuse, and multi-window scheduling.
@MainActor
@Observable public final class PlayerWindowManager {
    public static let shared = PlayerWindowManager()

    public private(set) var sessions: [PlayerWindowSession] = []

    /// Queue for pending files to be consumed by newly spawned windows
    private var pendingQueue: [String] = []

    /// Registered action from SwiftUI environment to trigger opening a new WindowGroup
    public var openWindowAction: (@MainActor () -> Void)?

    private var keyEventMonitor: Any?
    private var keyUpEventMonitor: Any?
    private var rightArrowDownTime: TimeInterval = 0.0
    private var windowObservers: [NSObjectProtocol] = []

    public init() {
        setupGlobalNotifications()
        setupGlobalKeyMonitor()
    }

    private func setupGlobalNotifications() {
        let obs1 = NotificationCenter.default.addObserver(
            forName: .openExternalFileNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let path = notification.object as? String
            MainActor.assumeIsolated {
                if let path = path {
                    self?.openExternalFiles([path])
                }
            }
        }
        let obs2 = NotificationCenter.default.addObserver(
            forName: NSWindow.didEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let notifWindow = notification.object as? NSWindow
            MainActor.assumeIsolated {
                guard let self = self, let notifWindow = notifWindow else { return }
                for s in self.sessions where s.window === notifWindow {
                    s.onFullScreenChangedHandler?(true)
                }
                if let settings = self.settingsWindow {
                    settings.level = .floating
                }
            }
        }
        let obs3 = NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let notifWindow = notification.object as? NSWindow
            MainActor.assumeIsolated {
                guard let self = self, let notifWindow = notifWindow else { return }
                for s in self.sessions where s.window === notifWindow {
                    s.onFullScreenChangedHandler?(false)
                }
                if let settings = self.settingsWindow {
                    settings.level = .floating
                }
            }
        }
        let obs4 = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let notifWindow = notification.object as? NSWindow
            MainActor.assumeIsolated {
                guard let self = self, let notifWindow = notifWindow else { return }
                // Only insert .fullScreenPrimary into actual player session windows, never settingsWindow
                if notifWindow !== self.settingsWindow && self.sessions.contains(where: { $0.window === notifWindow }) {
                    notifWindow.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
                }
            }
        }
        windowObservers = [obs1, obs2, obs3, obs4]
    }

    private func setupGlobalKeyMonitor() {
        guard keyEventMonitor == nil else { return }
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let flags = event.modifierFlags.intersection([.deviceIndependentFlagsMask])

            // 1. Settings Window Key Event Isolation:
            // If the key event is directed to settingsWindow or settingsWindow is currently Key:
            if let settings = self.settingsWindow, (event.window === settings || (settings.isKeyWindow && event.window == nil)) {
                // Command + W: Close settings window cleanly, never terminate playback!
                if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "w" {
                    self.closeSettings()
                    return nil
                }

                // Esc (keyCode 53): Close settings window cleanly, never leak to player!
                if flags.isEmpty && event.keyCode == 53 {
                    self.closeSettings()
                    return nil
                }

                // Command + ,: Toggle/close settings window cleanly
                if flags.contains(.command) && event.charactersIgnoringModifiers == "," {
                    self.closeSettings()
                    return nil
                }

                // All other keys inside settings window (Space, Arrows, F, M, S, etc.)
                // MUST proceed normally through the responder chain of settingsWindow
                // and MUST NEVER be leaked or routed to background playback!
                return event
            }

            if let responder = event.window?.firstResponder, responder is NSTextView {
                if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "w" {
                    self.closePlaybackOrReturnToEmpty()
                    return nil
                }
                return event
            }

            // Command + , (Preferences)
            if flags.contains(.command) && event.charactersIgnoringModifiers == "," {
                self.openSettings()
                return nil
            }

            // Command + / or Command + ? (Shortcuts Cheatsheet)
            if flags.contains(.command) && (event.charactersIgnoringModifiers == "/" || event.charactersIgnoringModifiers == "?") {
                self.openShortcutsCheatsheet()
                return nil
            }

            // Command + O (Open File)
            if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "o" {
                self.openFilePicker()
                return nil
            }

            // Command + N (New Window)
            if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "n" {
                self.requestNewWindow()
                return nil
            }

            // Command + W (Close Playback / Close Window)
            if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "w" {
                self.closePlaybackOrReturnToEmpty()
                return nil
            }

            // Command + S (Take Screenshot)
            if flags == .command && event.charactersIgnoringModifiers?.lowercased() == "s" {
                let targetWindow = event.window ?? NSApp?.keyWindow
                if let targetWindow = targetWindow, targetWindow === self.settingsWindow {
                    return event
                }
                if let session = (targetWindow != nil ? self.sessions.first(where: { $0.window === targetWindow }) : nil) ?? self.activeSession(preferKey: true) {
                    session.player?.takeScreenshot()
                    return nil
                }
            }

            // Spacebar (Play / Pause)
            if flags.isEmpty && event.keyCode == 49 {
                let targetWindow = event.window ?? NSApp?.keyWindow
                if let targetWindow = targetWindow, targetWindow === self.settingsWindow {
                    return event
                }
                if let session = (targetWindow != nil ? self.sessions.first(where: { $0.window === targetWindow }) : nil) ?? self.activeSession(preferKey: true) {
                    session.player?.togglePlayPause()
                    return nil
                }
            }

            // Right Arrow Long-Press Repeat for 2.0x Fast Forward
            if flags.isEmpty && event.keyCode == 124 {
                let targetWindow = event.window ?? NSApp?.keyWindow
                if let targetWindow = targetWindow, targetWindow === self.settingsWindow {
                    return event
                }
                if event.isARepeat {
                    if let session = (targetWindow != nil ? self.sessions.first(where: { $0.window === targetWindow }) : nil) ?? self.activeSession(preferKey: true) {
                        session.player?.startFastForward2x()
                    }
                    return nil
                } else {
                    self.rightArrowDownTime = ProcessInfo.processInfo.systemUptime
                    return nil
                }
            }

            let targetWindow = event.window ?? NSApp?.keyWindow
            if let targetWindow = targetWindow, targetWindow === self.settingsWindow {
                return event
            }
            if let session = (targetWindow != nil ? self.sessions.first(where: { $0.window === targetWindow }) : nil) ?? self.activeSession(preferKey: true) {
                if let handler = session.onKeyDownHandler {
                    return handler(event)
                }
            }
            return event
        }

        if keyUpEventMonitor == nil {
            keyUpEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
                guard let self = self else { return event }
                if let settings = self.settingsWindow, (event.window === settings || (settings.isKeyWindow && event.window == nil)) {
                    return event
                }
                if event.keyCode == 124 {
                    let targetWindow = event.window ?? NSApp?.keyWindow
                    let session = (targetWindow != nil ? self.sessions.first(where: { $0.window === targetWindow }) : nil) ?? self.activeSession(preferKey: true)
                    if let player = session?.player {
                        if player.isFastForwarding2x {
                            player.stopFastForward2x()
                            self.rightArrowDownTime = 0.0
                            return nil
                        } else if self.rightArrowDownTime > 0.0 {
                            self.rightArrowDownTime = 0.0
                            let stepSec = AppSettings.shared.shortSeekStep
                            player.step(seconds: stepSec)
                            return nil
                        }
                    }
                    self.rightArrowDownTime = 0.0
                }
                return event
            }
        }
    }

    // MARK: - Session Registration
    public func registerSession(_ session: PlayerWindowSession) {
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.append(session)
            session.window?.level = isAlwaysOnTop ? .floating : .normal
        }
    }

    public func unregisterSession(id: UUID) {
        sessions.removeAll(where: { $0.id == id })
        if sessions.isEmpty {
            closeSettings()
        }
    }

    public func session(for id: UUID) -> PlayerWindowSession? {
        sessions.first(where: { $0.id == id })
    }

    // MARK: - Window Lookup
    public var activePlayer: (any PlayerControllable)? {
        activeSession(preferKey: true)?.player
    }

    public func activeSession(preferKey: Bool = true) -> PlayerWindowSession? {
        if preferKey {
            if let keyWindow = NSApp?.keyWindow,
               let session = sessions.first(where: { $0.window === keyWindow }) {
                return session
            }
            if let key = sessions.first(where: { $0.isKey }) {
                return key
            }
        }
        return sessions.first
    }

    public var isAlwaysOnTop: Bool {
        get { AppSettings.shared.keepWindowOnTop }
        set {
            AppSettings.shared.keepWindowOnTop = newValue
            applyAlwaysOnTop(newValue)
        }
    }

    public func toggleAlwaysOnTop() {
        isAlwaysOnTop = !isAlwaysOnTop
    }

    public func toggleMaximize(window: NSWindow? = nil) {
        let win = window ?? activeSession(preferKey: true)?.window ?? NSApp?.keyWindow
        guard let win = win else { return }
        if let delegate = win.delegate as? PlayerWindowDelegate {
            delegate.toggleMaximize(window: win)
        } else {
            win.zoom(nil)
        }
    }

    public func fitActiveWindow(scale: Double) {
        activeSession(preferKey: true)?.player?.fitWindow(scale: scale)
    }

    public func closePlaybackOrReturnToEmpty() {
        guard let session = activeSession(preferKey: true) ?? sessions.first else {
            NSApp?.keyWindow?.performClose(nil)
            return
        }
        if session.isLoaded {
            session.closePlaybackOrReturnToEmpty()
        } else {
            closeActiveWindow()
        }
    }

    public func closeActiveWindow() {
        if let window = activeSession(preferKey: true)?.window ?? NSApp?.keyWindow {
            window.performClose(nil)
        }
    }

    public func stopAndReturnToLibrary() {
        closePlaybackOrReturnToEmpty()
    }

    public var openShortcutsCheatsheetAction: (@MainActor () -> Void)?

    public func openShortcutsCheatsheet() {
        openShortcutsCheatsheetAction?()
    }

    public func openFilePicker() {
        if let handler = activeSession(preferKey: true)?.openFilePickerHandler {
            handler()
        } else {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = true
            panel.message = L10n.chooseVideoDialog
            panel.prompt = L10n.open
            if panel.runModal() == .OK {
                let paths = panel.urls.map(\.path)
                openExternalFiles(paths)
            }
        }
    }


    public weak var settingsWindow: NSWindow?

    public func closeSettings() {
        guard let window = settingsWindow else { return }
        window.close()
        self.settingsWindow = nil
    }

    public func openSettings() {
        // Strictly NEVER pause active playback when opening preferences:
        // Allows the user to preview subtitle size, HDR tone mapping, and audio levels in real time.

        if let existing = settingsWindow {
            if existing.isKeyWindow {
                closeSettings()
                return
            }
            existing.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
            existing.level = .floating
            existing.makeKeyAndOrderFront(nil)
            NSApp?.activate(ignoringOtherApps: true)
            return
        }

        let contentRect = NSRect(x: 0, y: 0, width: 540, height: 680)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = L10n.tr("Settings", "偏好设置")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        // Fullscreen auxiliary space support strictly prevents macOS Space jump
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        window.level = .floating
        window.minSize = NSSize(width: 520, height: 560)
        window.maxSize = NSSize(width: 520, height: 560)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.settingsWindow = nil
            }
        }

        let hostingView = NSHostingView(rootView: SilkSettingsView())
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp?.activate(ignoringOtherApps: true)
    }

    /// Recursively expands folders and external disk volumes into contained video/audio paths
    nonisolated public static func expandFilesAndDirectories(_ paths: [String]) -> [String] {
        var results: [String] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                let videos = MediaFileClassifier.findVideos(in: url)
                results.append(contentsOf: videos.map(\.path))
            } else {
                results.append(path)
            }
        }
        return results
    }

    // MARK: - Pending Files Queue
    public func enqueuePendingFiles(_ files: [String]) {
        pendingQueue.append(contentsOf: files)
    }

    public func dequeuePendingFiles() -> [String] {
        let files = pendingQueue
        pendingQueue.removeAll()
        return files
    }

    public func dequeuePendingFile() -> String? {
        guard !pendingQueue.isEmpty else { return nil }
        return pendingQueue.removeFirst()
    }

    // MARK: - Open External Files Scheduling
    public func openExternalFiles(_ files: [String]) {
        let expanded = Self.expandFilesAndDirectories(files)
        guard !expanded.isEmpty else { return }

        let singleWindow = AppSettings.shared.singleWindowMode
        if singleWindow, let session = activeSession(preferKey: true) ?? sessions.first(where: { $0.window != nil }) {
            session.openPath(expanded[0])
            if expanded.count > 1 {
                session.appendPlaylistPaths(Array(expanded.dropFirst()))
            }
            session.window?.makeKeyAndOrderFront(nil)
            NSApp?.activate(ignoringOtherApps: true)
        } else if !singleWindow && !sessions.isEmpty {
            enqueuePendingFiles(expanded)
            openWindowAction?()
        } else if let session = activeSession(preferKey: true) ?? sessions.first(where: { $0.window != nil }) {
            session.openPath(expanded[0])
            if expanded.count > 1 {
                session.appendPlaylistPaths(Array(expanded.dropFirst()))
            }
            session.window?.makeKeyAndOrderFront(nil)
            NSApp?.activate(ignoringOtherApps: true)
        } else {
            enqueuePendingFiles(expanded)
            openWindowAction?()
        }
    }

    // MARK: - Window Spawning & Request
    public func requestNewWindow() {
        if AppSettings.shared.singleWindowMode {
            if let session = activeSession(preferKey: true) ?? sessions.first(where: { $0.window != nil }) {
                session.window?.makeKeyAndOrderFront(nil)
                NSApp?.activate(ignoringOtherApps: true)
            } else {
                openNewWindow()
            }
        } else {
            openNewWindow()
        }
    }

    public func applyAlwaysOnTop(_ onTop: Bool) {
        for s in sessions {
            s.window?.level = onTop ? .floating : .normal
        }
    }

    public func applyAutoEnhanceQuality(_ enhance: Bool) {
        for s in sessions {
            if let p = s.player {
                if enhance && !p.isDebandEnabled {
                    p.toggleDeband()
                } else if !enhance && p.isDebandEnabled {
                    p.toggleDeband()
                }
            }
        }
    }

    public func applyHDRToneMapping(_ enabled: Bool) {
        for s in sessions {
            s.player?.setHDREnabled(enabled)
        }
    }

    public func applySubtitleScale(_ scale: Double) {
        for s in sessions {
            s.player?.setSubtitleScale(scale)
        }
    }

    public func applyNightMode(_ enabled: Bool) {
        for s in sessions {
            s.player?.setNightModeEnabled(enabled)
        }
    }

    public func openNewWindow() {
        if let action = openWindowAction {
            action()
        }
    }

    // MARK: - Test Maintenance Helper
    public func resetForTesting() {
        sessions.removeAll()
        pendingQueue.removeAll()
        openWindowAction = nil
        openShortcutsCheatsheetAction = nil
    }
}

/// Helper NSViewRepresentable to acquire the hosting NSWindow for SwiftUI views once.
public struct WindowAccessor: NSViewRepresentable {
    public let onWindow: (NSWindow) -> Void

    public init(onWindow: @escaping (NSWindow) -> Void) {
        self.onWindow = onWindow
    }

    public func makeNSView(context: Context) -> NSView {
        return WindowObserverView(onWindow: onWindow)
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        // Strictly empty! Never re-acquire window on SwiftUI view update cycles!
    }
}

private final class WindowObserverView: NSView {
    private let onWindow: (NSWindow) -> Void
    private weak var lastKnownWindow: NSWindow?

    init(onWindow: @escaping (NSWindow) -> Void) {
        self.onWindow = onWindow
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window, window !== lastKnownWindow {
            lastKnownWindow = window
            DispatchQueue.main.async { [weak self, weak window] in
                guard let window = window, self?.lastKnownWindow === window else { return }
                self?.onWindow(window)
            }
        }
    }
}

/// Dedicated Window Delegate enforcing macOS media player standards:
/// 1. Mathematical aspect ratio preservation during live edge and corner window resizing
/// 2. Strict minimum dimensions (640x360) and maximum screen visible frame clamp
/// 3. Seamless fullscreen lifecycle notification routing
@MainActor
public final class PlayerWindowDelegate: NSObject, NSWindowDelegate {
    public weak var session: PlayerWindowSession?
    public weak var player: (any PlayerControllable)?
    public private(set) var isMaximizingOrRestoring: Bool = false
    private var isAdjustingWindowFrame: Bool = false
    private var isFullscreenTransitioning: Bool = false
    private var savedPreZoomFrame: NSRect? = nil
    private var savedPreFullScreenFrame: NSRect? = nil
    private var lastToggleMaximizeTime: TimeInterval = 0

    public init(session: PlayerWindowSession? = nil, player: (any PlayerControllable)? = nil) {
        self.session = session
        self.player = player
        super.init()
    }

    public func capturePreFullScreenFrameIfNeeded(window: NSWindow) {
        guard !window.styleMask.contains(.fullScreen), !isFullscreenTransitioning else { return }
        let f = window.frame
        guard !f.origin.x.isNaN, !f.origin.y.isNaN, !f.width.isNaN, !f.height.isNaN,
              f.width >= 320, f.height >= 240 else { return }
        if let screen = window.screen ?? NSScreen.main {
            // 严禁把超出可用工作区尺寸（如物理全屏帧 2752x1152）保存为退出全屏恢复帧
            if f.height > screen.visibleFrame.height + 2.0 || f.width > screen.frame.width + 2.0 {
                return
            }
            if abs(f.width - screen.frame.width) <= 2.0 && abs(f.height - screen.frame.height) <= 2.0 {
                return
            }
        }
        savedPreFullScreenFrame = f
    }

    /// Checks whether the target frameSize matches macOS native window tiling / split-screen geometry
    /// (e.g. left/right half screen in macOS 15 Sequoia, quarter screen, top/bottom half)
    private func isTilingOrSnapSize(_ size: NSSize, screen: NSScreen?, screenFrame: NSRect) -> Bool {
        // 1. 严禁将物理全屏尺寸（screen.frame.size）误判为分屏！
        if let fullScreenSize = screen?.frame.size {
            if abs(size.width - fullScreenSize.width) <= 8.0 && abs(size.height - fullScreenSize.height) <= 8.0 {
                return false
            }
        }
        // 2. 严禁将整个可用工作区尺寸（最大化）误判为半屏/四分之一分屏！
        let tolerance: CGFloat = 40.0
        if abs(size.width - screenFrame.width) <= tolerance && abs(size.height - screenFrame.height) <= tolerance {
            return false
        }
        // 3. 任何高度超过可用工作区高度的尺寸（例如全屏过渡帧）绝不是分屏！
        if size.height > screenFrame.height + 2.0 || size.width > screenFrame.width + 2.0 {
            return false
        }

        // A. 左右分屏（高度等于可用区高度，宽度在 30% ~ 70% 之间）
        if abs(size.height - screenFrame.height) <= tolerance &&
           size.width >= screenFrame.width * 0.30 &&
           size.width <= screenFrame.width * 0.70 {
            return true
        }
        // B. 上下分屏（宽度等于可用区宽度，高度在 30% ~ 70% 之间）
        if abs(size.width - screenFrame.width) <= tolerance &&
           size.height >= screenFrame.height * 0.30 &&
           size.height <= screenFrame.height * 0.70 {
            return true
        }
        // C. 四分之一分屏（宽高均约为可用区的 50%）
        if abs(size.width - screenFrame.width * 0.5) <= tolerance &&
           abs(size.height - screenFrame.height * 0.5) <= tolerance {
            return true
        }
        return false
    }

    public func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
        let idleMinW: CGFloat = 640
        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let maxSize = screenFrame.size

        // Sanity guard against NaN or non-positive sizes
        if frameSize.width.isNaN || frameSize.height.isNaN || frameSize.width <= 0 || frameSize.height <= 0 {
            return window.frame.size
        }

        // 在全屏模式、全屏进出过渡期、等比最大化/还原期间、或缩放至屏幕可用工作区尺寸时，100% 原样放行！
        if window.styleMask.contains(.fullScreen) ||
           isFullscreenTransitioning ||
           player?.isFullscreen == true ||
           player?.isFullscreenTransitioning == true ||
           isMaximizingOrRestoring ||
           frameSize == screenFrame.size {
            return frameSize
        }

        // 如果非用户手动拖拽且传入的是整个物理屏幕尺寸（AppKit 全屏调用首帧），直接放行
        if !window.inLiveResize, let fullSz = screen?.frame.size,
           abs(frameSize.width - fullSz.width) <= 2.0 && abs(frameSize.height - fullSz.height) <= 2.0 {
            return frameSize
        }

        // Allow Shift-key freeform resizing without aspect ratio constraints during interactive dragging
        if window.inLiveResize && NSEvent.modifierFlags.contains(.shift) {
            let minSide: CGFloat = (player?.isAudioOnly == true) ? 380.0 : 360.0
            let minWidth: CGFloat = (player?.isAudioOnly == true) ? 380.0 : idleMinW
            return NSSize(
                width: max(minWidth, min(maxSize.width, frameSize.width)),
                height: max(minSide, min(maxSize.height, frameSize.height))
            )
        }

        // Dedicated pure-audio window resize branch: strictly maintain 1:1 proportional (等比) square resizing
        if player?.isAudioOnly == true {
            let minAudioSize: CGFloat = 380.0
            let maxAudioDimension = min(maxSize.width, maxSize.height)

            let curSize = window.frame.size
            let deltaW = abs(frameSize.width - curSize.width)
            let deltaH = abs(frameSize.height - curSize.height)

            var targetSide: CGFloat
            if deltaH > deltaW && deltaH > 1.0 {
                targetSide = frameSize.height
            } else {
                targetSide = frameSize.width
            }

            targetSide = max(minAudioSize, min(maxAudioDimension, targetSide))
            return NSSize(width: round(targetSide), height: round(targetSide))
        }

        guard let player = self.player, (player.videoWidth > 0 || player.videoHeight > 0) else {
            if !window.inLiveResize && isTilingOrSnapSize(frameSize, screen: screen, screenFrame: screenFrame) {
                return NSSize(
                    width: min(maxSize.width, frameSize.width),
                    height: min(maxSize.height, frameSize.height)
                )
            }
            return NSSize(
                width: max(idleMinW, min(maxSize.width, frameSize.width)),
                height: max(360, min(maxSize.height, frameSize.height))
            )
        }

        let baseAspect = player.effectiveAspectRatio
        let minContentSz = PlayerGeometry.minimumContentSize(for: baseAspect, screenVisibleHeight: screenFrame.height)
        let minW = minContentSz.width
        let minH = minContentSz.height

        // Video-Adaptive Split Screen Tiling ("播放自适应分屏"):
        // Only trigger when NOT in interactive live resize dragging
        if !window.inLiveResize && isTilingOrSnapSize(frameSize, screen: screen, screenFrame: screenFrame) {
            let tolerance: CGFloat = 40.0

            // 1. Full-height vertical split (e.g. Left half, Right half, 1/3, 2/3 column tiles)
            if abs(frameSize.height - screenFrame.height) <= tolerance {
                let targetW = min(maxSize.width, frameSize.width)
                let adaptiveH = round(targetW / max(0.001, baseAspect))
                if adaptiveH <= screenFrame.height {
                    return NSSize(width: round(targetW), height: round(adaptiveH))
                } else {
                    let targetH = screenFrame.height
                    let targetW = min(frameSize.width, round(targetH * baseAspect))
                    return NSSize(width: round(targetW), height: round(targetH))
                }
            }

            // 2. Full-width horizontal split (e.g. Top half, Bottom half)
            if abs(frameSize.width - screenFrame.width) <= tolerance {
                let targetH = min(maxSize.height, frameSize.height)
                let adaptiveW = round(targetH * baseAspect)
                if adaptiveW <= screenFrame.width {
                    return NSSize(width: round(adaptiveW), height: round(targetH))
                } else {
                    let targetW = screenFrame.width
                    let targetH = min(maxSize.height, round(targetW / max(0.001, baseAspect)))
                    return NSSize(width: round(targetW), height: round(targetH))
                }
            }

            // 3. Quarter-screen grid tiling (Half width & Half height)
            let boxW = min(maxSize.width, frameSize.width)
            let boxH = min(maxSize.height, frameSize.height)
            let boxAspect = boxW / max(1.0, boxH)
            if baseAspect >= boxAspect {
                let targetW = boxW
                let targetH = min(boxH, round(targetW / max(0.001, baseAspect)))
                return NSSize(width: round(targetW), height: round(targetH))
            } else {
                let targetH = boxH
                let targetW = min(boxW, round(targetH * baseAspect))
                return NSSize(width: round(targetW), height: round(targetH))
            }
        }

        let curSize = window.frame.size
        let deltaW = abs(frameSize.width - curSize.width)
        let deltaH = abs(frameSize.height - curSize.height)

        var targetW: CGFloat
        var targetH: CGFloat

        if deltaH > deltaW && deltaH > 1.0 {
            targetH = frameSize.height
            targetW = targetH * baseAspect
        } else {
            targetW = frameSize.width
            targetH = targetW / max(0.001, baseAspect)
        }

        if targetW < minW {
            targetW = minW
            targetH = targetW / max(0.001, baseAspect)
        }
        if targetH < minH {
            targetH = minH
            targetW = targetH * baseAspect
        }

        if targetW > maxSize.width {
            targetW = maxSize.width
            targetH = round(targetW / max(0.001, baseAspect))
        }
        if targetH > maxSize.height {
            targetH = maxSize.height
            targetW = round(targetH * baseAspect)
        }
        if targetW > maxSize.width {
            targetW = maxSize.width
            targetH = round(targetW / max(0.001, baseAspect))
        }
        targetW = min(targetW, maxSize.width)
        targetH = min(targetH, maxSize.height)

        if targetW.isNaN || targetH.isNaN || targetW <= 0 || targetH <= 0 {
            return frameSize
        }

        return NSSize(width: round(targetW), height: round(targetH))
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              !window.styleMask.contains(.fullScreen),
              !isFullscreenTransitioning,
              let player = self.player else { return }

        savedPreZoomFrame = nil

        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        var curFrame = window.frame
        var adjusted = false

        if curFrame.height > screenFrame.height {
            curFrame.size.height = screenFrame.height
            adjusted = true
        }
        if curFrame.minY < screenFrame.minY {
            curFrame.origin.y = screenFrame.minY
            adjusted = true
        }
        if curFrame.maxY > screenFrame.maxY {
            curFrame.origin.y = max(screenFrame.minY, screenFrame.maxY - curFrame.height)
            adjusted = true
        }
        if curFrame.minX < screenFrame.minX {
            curFrame.origin.x = screenFrame.minX
            adjusted = true
        }
        if curFrame.maxX > screenFrame.maxX {
            curFrame.origin.x = max(screenFrame.minX, screenFrame.maxX - curFrame.width)
            adjusted = true
        }

        if adjusted {
            isAdjustingWindowFrame = true
            window.setFrame(curFrame, display: true, animate: false)
            isAdjustingWindowFrame = false
        }

        capturePreFullScreenFrameIfNeeded(window: window)

        let contentSize = window.contentRect(forFrameRect: window.frame).size
        if player.videoWidth > 0 || player.videoHeight > 0 {
            player.updateRememberedWindowSize(contentSize)
        }
    }

    public func windowDidResize(_ notification: Notification) {
        guard !isFullscreenTransitioning,
              !isMaximizingOrRestoring,
              !isAdjustingWindowFrame,
              player?.isFullscreen != true,
              player?.isFullscreenTransitioning != true else { return }

        guard let window = notification.object as? NSWindow,
              !window.styleMask.contains(.fullScreen) else { return }

        if window.inLiveResize {
            return
        }

        isAdjustingWindowFrame = true
        defer { isAdjustingWindowFrame = false }

        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        var curFrame = window.frame
        var adjusted = false

        // 0. 高度防溢出保护：窗口高度绝不能超过可用工作区高度（防止侵入 Dock）
        if curFrame.height > screenFrame.height {
            curFrame.size.height = screenFrame.height
            if let player = self.player, !player.isAudioOnly, player.videoWidth > 0, player.videoHeight > 0 {
                curFrame.size.width = min(screenFrame.width, round(curFrame.size.height * player.effectiveAspectRatio))
            }
            adjusted = true
        }

        // 1. Strict dock invasion defense: bottom of window must never sink below screenFrame.minY
        if curFrame.minY < screenFrame.minY {
            curFrame.origin.y = screenFrame.minY
            adjusted = true
        }

        // 2. Strict menu bar invasion defense: top of window must never exceed screenFrame.maxY
        if curFrame.maxY > screenFrame.maxY {
            curFrame.origin.y = max(screenFrame.minY, screenFrame.maxY - curFrame.height)
            adjusted = true
        }

        // 3. Screen horizontal boundaries clamp
        if curFrame.minX < screenFrame.minX {
            curFrame.origin.x = screenFrame.minX
            adjusted = true
        }
        if curFrame.maxX > screenFrame.maxX {
            curFrame.origin.x = max(screenFrame.minX, screenFrame.maxX - curFrame.width)
            adjusted = true
        }

        if adjusted {
            window.setFrame(curFrame, display: true, animate: false)
        }

        // 4. Video-adaptive vertical centering on half-screen snap
        if let player = self.player, !player.isAudioOnly, player.videoWidth > 0, player.videoHeight > 0 {
            let isLeftDocked = abs(curFrame.minX - screenFrame.minX) <= 10.0
            let isRightDocked = abs(curFrame.maxX - screenFrame.maxX) <= 10.0
            let isHalfWidth = abs(curFrame.width - round(screenFrame.width * 0.5)) <= 40.0

            if (isLeftDocked || isRightDocked) && isHalfWidth && curFrame.height < screenFrame.height - 20.0 {
                let targetY = round(screenFrame.origin.y + (screenFrame.height - curFrame.height) * 0.5)
                if abs(curFrame.origin.y - targetY) > 2.0 {
                    window.setFrameOrigin(NSPoint(x: curFrame.origin.x, y: targetY))
                }
            }
        }
    }

    public func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame: NSRect) -> NSRect {
        guard let player = self.player else { return defaultFrame }

        if player.isAudioOnly {
            let sz: CGFloat = 520
            let cx = round(defaultFrame.minX + (defaultFrame.width - sz) / 2)
            let cy = round(defaultFrame.minY + (defaultFrame.height - sz) / 2)
            return NSRect(x: cx, y: cy, width: sz, height: sz)
        }

        return defaultFrame
    }

    public func toggleMaximize(window: NSWindow) {
        guard !window.styleMask.contains(.fullScreen), !isFullscreenTransitioning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastToggleMaximizeTime > 0.35 else { return }
        lastToggleMaximizeTime = now

        let screen = window.screen ?? NSScreen.main
        guard let screenFrame = screen?.visibleFrame else { return }

        isMaximizingOrRestoring = true
        isAdjustingWindowFrame = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.isAdjustingWindowFrame = false
            self?.isMaximizingOrRestoring = false
        }

        // A. 纯音频模式：固定 520x520 居中
        if player?.isAudioOnly == true {
            let sz: CGFloat = 520
            let cx = round(screenFrame.midX - sz / 2)
            let cy = round(screenFrame.midY - sz / 2)
            let targetFrame = NSRect(x: cx, y: cy, width: sz, height: sz)
            window.setFrame(targetFrame, display: true, animate: true)
            return
        }

        // B. 闲置窗口（未加载视频）：在 screenFrame 与 960x540 之间双向切换
        guard let player = self.player, player.videoWidth > 0, player.videoHeight > 0 else {
            let isCurrentlyMax = abs(window.frame.width - screenFrame.width) <= 16.0 &&
                                 abs(window.frame.height - screenFrame.height) <= 16.0
            if isCurrentlyMax {
                let restore = savedPreZoomFrame ?? NSRect(
                    x: round(screenFrame.midX - 480),
                    y: round(screenFrame.midY - 270),
                    width: 960,
                    height: 540
                )
                savedPreZoomFrame = nil
                window.setFrame(restore, display: true, animate: true)
            } else {
                savedPreZoomFrame = window.frame
                window.setFrame(screenFrame, display: true, animate: true)
            }
            return
        }

        // C. 视频播放态：计算当前屏幕可用区内的最大等比尺寸（100% 占满工作区长边，严格保持视频比例）
        let aspect = player.effectiveAspectRatio
        let maxContent = PlayerGeometry.maximizedContentSize(for: aspect, screenVisibleSize: screenFrame.size)
        let maxW = round(maxContent.width)
        let maxH = round(maxContent.height)

        let isCurrentlyAtMax = abs(window.frame.width - maxW) <= 16.0 &&
                               abs(window.frame.height - maxH) <= 16.0

        if isCurrentlyAtMax {
            let restoreFrame: NSRect
            if let saved = savedPreZoomFrame,
               (abs(saved.width - maxW) > 16.0 || abs(saved.height - maxH) > 16.0) {
                restoreFrame = saved
            } else {
                let stdW: CGFloat
                let stdH: CGFloat
                if player.isEffectiveVertical {
                    stdH = round(screenFrame.height * 0.60)
                    stdW = round(stdH * aspect)
                } else {
                    stdW = round(screenFrame.width * 0.55)
                    stdH = round(stdW / max(0.001, aspect))
                }
                let cx = round(screenFrame.midX - stdW / 2)
                let cy = round(screenFrame.midY - stdH / 2)
                restoreFrame = NSRect(x: cx, y: cy, width: stdW, height: stdH)
            }
            savedPreZoomFrame = nil
            savedPreFullScreenFrame = restoreFrame
            window.setFrame(restoreFrame, display: true, animate: true)
        } else {
            savedPreZoomFrame = window.frame
            let targetX = round(screenFrame.midX - maxW / 2)
            let targetY = round(screenFrame.midY - maxH / 2)
            let targetFrame = NSRect(x: targetX, y: targetY, width: maxW, height: maxH)
            savedPreFullScreenFrame = targetFrame
            window.setFrame(targetFrame, display: true, animate: true)
        }
    }

    public func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        toggleMaximize(window: window)
        return false
    }

    public func windowWillEnterFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            capturePreFullScreenFrameIfNeeded(window: window)
            window.contentAspectRatio = .zero
            window.aspectRatio = .zero
        }
        isFullscreenTransitioning = true
        player?.isFullscreenTransitioning = true
    }

    public func windowDidEnterFullScreen(_ notification: Notification) {
        isFullscreenTransitioning = false
        player?.isFullscreenTransitioning = false
        player?.setFullscreenState(true)
    }

    public func windowWillExitFullScreen(_ notification: Notification) {
        isFullscreenTransitioning = true
        player?.isFullscreenTransitioning = true
        if let window = notification.object as? NSWindow {
            window.contentAspectRatio = .zero
            window.aspectRatio = .zero
            let screen = window.screen ?? NSScreen.main
            let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

            var targetFrame: NSRect
            if let saved = savedPreFullScreenFrame {
                let clampedW = min(saved.width, screenFrame.width)
                let clampedH = min(saved.height, screenFrame.height)
                let clampedX = max(screenFrame.minX, min(screenFrame.maxX - clampedW, saved.origin.x))
                let clampedY = max(screenFrame.minY, min(screenFrame.maxY - clampedH, saved.origin.y))
                targetFrame = NSRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)
            } else {
                let aspect = player?.effectiveAspectRatio ?? (16.0 / 9.0)
                let stdW = round(screenFrame.width * 0.55)
                let stdH = round(stdW / max(0.001, aspect))
                let clampedW = min(stdW, screenFrame.width)
                let clampedH = min(stdH, screenFrame.height)
                let cx = round(screenFrame.midX - clampedW / 2)
                let cy = round(screenFrame.midY - clampedH / 2)
                targetFrame = NSRect(x: cx, y: cy, width: clampedW, height: clampedH)
            }

            if targetFrame.height > screenFrame.height {
                targetFrame.size.height = screenFrame.height
            }
            if targetFrame.origin.y < screenFrame.minY {
                targetFrame.origin.y = screenFrame.minY
            }
            if targetFrame.maxY > screenFrame.maxY {
                targetFrame.origin.y = max(screenFrame.minY, screenFrame.maxY - targetFrame.height)
            }

            // 预设桌面空间窗口恢复帧，使 AppKit 全屏退出转场动画直接平滑缩回该目标帧，避免从 (0,0) 左下角缩放跳跃
            isAdjustingWindowFrame = true
            window.setFrame(targetFrame, display: false, animate: false)
            isAdjustingWindowFrame = false
        }
    }

    public func windowDidExitFullScreen(_ notification: Notification) {
        isFullscreenTransitioning = false
        player?.isFullscreenTransitioning = false
        player?.setFullscreenState(false)

        if let window = notification.object as? NSWindow {
            let screen = window.screen ?? NSScreen.main
            let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

            var targetFrame: NSRect
            if let saved = savedPreFullScreenFrame {
                let clampedW = min(saved.width, screenFrame.width)
                let clampedH = min(saved.height, screenFrame.height)
                let clampedX = max(screenFrame.minX, min(screenFrame.maxX - clampedW, saved.origin.x))
                let clampedY = max(screenFrame.minY, min(screenFrame.maxY - clampedH, saved.origin.y))
                targetFrame = NSRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)
                savedPreFullScreenFrame = nil
            } else {
                let aspect = player?.effectiveAspectRatio ?? (16.0 / 9.0)
                let stdW = round(screenFrame.width * 0.55)
                let stdH = round(stdW / max(0.001, aspect))
                let clampedW = min(stdW, screenFrame.width)
                let clampedH = min(stdH, screenFrame.height)
                let cx = round(screenFrame.midX - clampedW / 2)
                let cy = round(screenFrame.midY - clampedH / 2)
                targetFrame = NSRect(x: cx, y: cy, width: clampedW, height: clampedH)
            }

            if targetFrame.height > screenFrame.height {
                targetFrame.size.height = screenFrame.height
            }
            if targetFrame.origin.y < screenFrame.minY {
                targetFrame.origin.y = screenFrame.minY
            }
            if targetFrame.maxY > screenFrame.maxY {
                targetFrame.origin.y = max(screenFrame.minY, screenFrame.maxY - targetFrame.height)
            }

            if abs(window.frame.width - targetFrame.width) > 2.0 ||
               abs(window.frame.height - targetFrame.height) > 2.0 ||
               abs(window.frame.origin.x - targetFrame.origin.x) > 2.0 ||
               abs(window.frame.origin.y - targetFrame.origin.y) > 2.0 {
                isAdjustingWindowFrame = true
                window.setFrame(targetFrame, display: true, animate: false)
                isAdjustingWindowFrame = false
            }
        }

        player?.applyContentAspectRatioLock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            if let player = self?.player, !player.isPlaying {
                player.renderCurrentFrameImmediately()
            }
        }
    }

    public func windowDidFailToEnterFullScreen(_ window: NSWindow) {
        isFullscreenTransitioning = false
        player?.isFullscreenTransitioning = false
    }

    public func windowDidFailToExitFullScreen(_ window: NSWindow) {
        isFullscreenTransitioning = false
        player?.isFullscreenTransitioning = false
    }

    public func windowWillClose(_ notification: Notification) {
        player?.stop()
    }
}
