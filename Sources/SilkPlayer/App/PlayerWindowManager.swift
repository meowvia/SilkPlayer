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
        get { (window?.level == .floating) }
        set { window?.level = newValue ? .floating : .normal }
    }

    public func toggleAlwaysOnTop() {
        guard let window = window else { return }
        window.level = (window.level == .floating) ? .normal : .floating
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
            if flags.isEmpty && event.keyCode == 124 && event.isARepeat {
                let targetWindow = event.window ?? NSApp?.keyWindow
                if let targetWindow = targetWindow, targetWindow === self.settingsWindow {
                    return event
                }
                if let session = (targetWindow != nil ? self.sessions.first(where: { $0.window === targetWindow }) : nil) ?? self.activeSession(preferKey: true) {
                    if let player = session.player {
                        player.startFastForward2x()
                        return nil
                    }
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
                if let settings = self?.settingsWindow, (event.window === settings || (settings.isKeyWindow && event.window == nil)) {
                    return event
                }
                if event.keyCode == 124 {
                    if let player = self?.activeSession(preferKey: true)?.player, player.isFastForwarding2x {
                        player.stopFastForward2x()
                        return nil
                    }
                }
                return event
            }
        }
    }

    // MARK: - Session Registration
    public func registerSession(_ session: PlayerWindowSession) {
        if !sessions.contains(where: { $0.id == session.id }) {
            sessions.append(session)
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
        activeSession(preferKey: true)?.isAlwaysOnTop ?? false
    }

    public func toggleAlwaysOnTop() {
        activeSession(preferKey: true)?.toggleAlwaysOnTop()
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
    // MARK: - Open External Files Scheduling (Strictly Single Window)
    public func openExternalFiles(_ files: [String]) {
        let expanded = Self.expandFilesAndDirectories(files)
        guard !expanded.isEmpty else { return }

        if let session = activeSession(preferKey: true) ?? sessions.first(where: { $0.window != nil }) {
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

    // MARK: - Window Spawning & Request (Strictly Single Window)
    public func requestNewWindow() {
        if let session = activeSession(preferKey: true) ?? sessions.first(where: { $0.window != nil }) {
            session.window?.makeKeyAndOrderFront(nil)
            NSApp?.activate(ignoringOtherApps: true)
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

    public init(session: PlayerWindowSession? = nil, player: (any PlayerControllable)? = nil) {
        self.session = session
        self.player = player
        super.init()
    }

    /// Checks whether the target frameSize matches macOS native window tiling / split-screen geometry
    /// (e.g. left/right half screen in macOS 15 Sequoia, quarter screen, top/bottom half)
    private func isTilingOrSnapSize(_ size: NSSize, screenFrame: NSRect) -> Bool {
        let tolerance: CGFloat = 40.0
        // 1. Full height vertical split (e.g. Left half, Right half, 1/3, 2/3 column tiles)
        if abs(size.height - screenFrame.height) <= tolerance {
            return true
        }
        // 2. Full width horizontal split (e.g. Top half, Bottom half)
        if abs(size.width - screenFrame.width) <= tolerance {
            return true
        }
        // 3. Quarter-screen grid tiling (Half width & Half height)
        if abs(size.width - screenFrame.width * 0.5) <= tolerance &&
           abs(size.height - screenFrame.height * 0.5) <= tolerance {
            return true
        }
        return false
    }

    public func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
        let minW: CGFloat = 640
        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let maxSize = screenFrame.size

        // In fullscreen mode or during zoom to screen size, allow unconstrained filling
        if window.styleMask.contains(.fullScreen) || frameSize == screenFrame.size {
            return frameSize
        }

        // Allow Shift-key freeform resizing without aspect ratio constraints
        if NSEvent.modifierFlags.contains(.shift) {
            let minSide: CGFloat = (player?.isAudioOnly == true) ? 380.0 : 360.0
            let minWidth: CGFloat = (player?.isAudioOnly == true) ? 380.0 : minW
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
                // Dragging top or bottom edge: scale by vertical delta
                targetSide = frameSize.height
            } else {
                // Dragging left or right edge, or corner: scale by horizontal delta
                targetSide = frameSize.width
            }

            // Clamp to [minAudioSize, maxAudioDimension] preserving strict 1:1 square
            targetSide = max(minAudioSize, min(maxAudioDimension, targetSide))
            return NSSize(width: round(targetSide), height: round(targetSide))
        }

        guard let player = self.player, (player.videoWidth > 0 || player.videoHeight > 0) else {
            // Idle window without loaded video:
            // Never trigger snap tiling during live manual dragging
            if !window.inLiveResize && isTilingOrSnapSize(frameSize, screenFrame: screenFrame) {
                return frameSize
            }
            return NSSize(
                width: max(minW, min(maxSize.width, frameSize.width)),
                height: max(360, min(maxSize.height, frameSize.height))
            )
        }

        let baseAspect = player.effectiveAspectRatio
        let minH = round(minW / max(0.001, baseAspect))

        // Video-Adaptive Split Screen Tiling ("播放自适应分屏"):
        // Only trigger when NOT in interactive live resize dragging
        if !window.inLiveResize && isTilingOrSnapSize(frameSize, screenFrame: screenFrame) {
            let tolerance: CGFloat = 40.0

            // 1. Full-height vertical split (e.g. Left half, Right half, 1/3, 2/3 column tiles)
            if abs(frameSize.height - screenFrame.height) <= tolerance {
                let targetW = frameSize.width
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
                let targetH = frameSize.height
                let adaptiveW = round(targetH * baseAspect)
                if adaptiveW <= screenFrame.width {
                    return NSSize(width: round(adaptiveW), height: round(targetH))
                } else {
                    let targetW = screenFrame.width
                    let targetH = min(frameSize.height, round(targetW / max(0.001, baseAspect)))
                    return NSSize(width: round(targetW), height: round(targetH))
                }
            }

            // 3. Quarter-screen grid tiling (Half width & Half height)
            let boxW = frameSize.width
            let boxH = frameSize.height
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
            // Primarily dragging top or bottom edge
            targetH = frameSize.height
            targetW = targetH * baseAspect
        } else {
            // Primarily dragging left/right edge or corner
            targetW = frameSize.width
            targetH = targetW / max(0.001, baseAspect)
        }

        // Clamp to minimum size while strictly preserving aspect ratio
        if targetW < minW {
            targetW = minW
            targetH = targetW / max(0.001, baseAspect)
        }
        if targetH < minH {
            targetH = minH
            targetW = targetH * baseAspect
        }

        // Clamp to screen maximum visible bounds while strictly preserving aspect ratio
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

        return NSSize(width: round(targetW), height: round(targetH))
    }

    public func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              !window.styleMask.contains(.fullScreen),
              !window.isZoomed,
              let player = self.player else { return }

        // Perform boundary safety adjustment once user finishes dragging
        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        var curFrame = window.frame
        var adjusted = false

        // 1. Strict dock invasion defense: ensure bottom of window never sinks below screenFrame.minY
        if curFrame.minY < screenFrame.minY {
            curFrame.origin.y = screenFrame.minY
            adjusted = true
        }

        // 2. Strict menu bar invasion defense: ensure top of window never exceeds screenFrame.maxY
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

        let contentSize = window.contentRect(forFrameRect: window.frame).size
        if player.videoWidth > 0 || player.videoHeight > 0 {
            player.updateRememberedWindowSize(contentSize)
        }
    }

    public func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              !window.styleMask.contains(.fullScreen) else { return }

        // If the window is in interactive live resize by user mouse dragging,
        // do not mutate frame or fight with AppKit's live tracking loop.
        if window.inLiveResize {
            return
        }

        let screen = window.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        var curFrame = window.frame
        var adjusted = false

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

    public func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        return true
    }

    public func windowWillEnterFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.contentAspectRatio = .zero
            window.aspectRatio = .zero
        }
    }

    public func windowDidEnterFullScreen(_ notification: Notification) {
        player?.setFullscreenState(true)
    }

    public func windowDidExitFullScreen(_ notification: Notification) {
        player?.setFullscreenState(false)
        player?.applyContentAspectRatioLock()
    }

    public func windowWillClose(_ notification: Notification) {
        player?.stop()
    }
}
