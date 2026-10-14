import SwiftUI
import AppKit

@MainActor
public struct AppShellView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var player: PlayerCore
    @State private var navigationModel = AppNavigationModel.shared
    var playlistManager: PlaylistManager
    private var settings = AppSettings.shared
    public let sessionId: UUID
    @State private var lastPreviousClickTime: Date = .distantPast

    public init(
        player: PlayerCore,
        playlistManager: PlaylistManager = PlaylistManager.shared,
        sessionId: UUID = UUID()
    ) {
        self.player = player
        self.playlistManager = playlistManager
        self.sessionId = sessionId
    }

    @MainActor private static var didCenterInitialColdLaunchWindow = false

    private var appSpringAnimation: Animation {
        SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSpring)
    }

    private var isPlaying: Bool {
        if case .playing = navigationModel.state {
            return true
        }
        return player.isLoaded || player.playbackState == .loading
    }

    public var body: some View {
        GeometryReader { geometry in
            let drawerWidth = PlaylistDrawerDimensions.drawerWidth(for: geometry.size.width, isFullscreen: player.isFullscreen)

            ZStack {
                if isPlaying {
                    if !player.isAudioOnly {
                        Color.black
                            .edgesIgnoringSafeArea(.all)
                    }

                    PlayerContainerView(
                        player: player,
                        playlist: playlistManager,
                        onPlayNext: {
                            playNext()
                        },
                        onPlayPrevious: {
                            playPrevious()
                        },
                        onSelectPlaylistItem: { item in
                            playPlaylistItem(item)
                        },
                        onClosePlayback: {
                            stopPlayback()
                        }
                    )
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                } else {
                    VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                        .edgesIgnoringSafeArea(.all)

                    EmptyPlaybackView(
                        onOpenFile: {
                            openSingleFile()
                        },
                        onFilesDropped: { urls in
                            let paths = urls.map(\.path)
                            openExternalPaths(paths)
                        }
                    )
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)

                    // Right-Edge Floating Side Triangle Pull Tab (always accessible on right border)
                    PlaylistDrawerHandleTab(
                        isDrawerVisible: player.isPlaylistDrawerVisible,
                        drawerWidth: drawerWidth
                    ) {
                        withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                            player.togglePlaylistDrawer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .zIndex(18)

                    if player.isPlaylistDrawerVisible {
                        Color.black.opacity(0.001)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                    player.isPlaylistDrawerVisible = false
                                }
                            }
                            .zIndex(16)

                        HStack(spacing: 0) {
                            Spacer()
                            SilkPlaylistDrawerView(
                                player: player,
                                playlist: playlistManager,
                                drawerWidth: drawerWidth,
                                onSelectPlaylistItem: { item in
                                    playPlaylistItem(item)
                                },
                                onClose: {
                                    withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                        player.isPlaylistDrawerVisible = false
                                    }
                                }
                            )
                            .environment(\.colorScheme, .dark)
                            .transition(SilkAnimation.transition(reduceMotion: reduceMotion, standard: .move(edge: .trailing)))
                        }
                        .padding(.top, 36)
                        .padding(.bottom, 16)
                        .padding(.trailing, 8)
                        .edgesIgnoringSafeArea(.all)
                        .zIndex(17)
                    }
                }
            }
        }
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .id(settings.appLanguage)
        .frame(minWidth: 640, minHeight: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            WindowAccessor { window in
                handleWindowAcquired(window)
            }
        )
        .onChange(of: isPlaying) { _, playing in
            updateAppTrafficLights()
            if playing {
                player.hostWindow?.isMovableByWindowBackground = false
                player.hostWindow?.isOpaque = false
                player.hostWindow?.backgroundColor = .clear
                if !player.isFullscreen {
                    player.applyContentAspectRatioLock()
                }
            } else {
                player.hostWindow?.isMovableByWindowBackground = false
                player.hostWindow?.isOpaque = false
                player.hostWindow?.backgroundColor = .clear
                player.hostWindow?.contentAspectRatio = .zero
                player.hostWindow?.aspectRatio = .zero
                player.hostWindow?.resizeIncrements = NSSize(width: 1, height: 1)
                let emptyMin = NSSize(width: 640, height: 360)
                if let w = player.hostWindow {
                    w.minSize = emptyMin
                    w.contentMinSize = emptyMin
                }
            }
        }
        .onChange(of: navigationModel.isAlwaysOnTop) { _, newValue in
            player.hostWindow?.level = newValue ? .floating : .normal
        }
        .onAppear {
            registerSession()
            setupHooks()
            checkPendingFiles()
        }
        .onDisappear {
            if let currentPath = player.currentFilePath, player.currentTime > 0 {
                AppSettings.shared.savePosition(for: currentPath, position: player.currentTime, duration: player.duration)
            }
            playlistManager.saveToStorage()
            PlayerWindowManager.shared.closeSettings()
            unregisterSession()
        }
        .onOpenURL { url in
            openExternalURL(url)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard !providers.isEmpty else { return false }
            Task { @MainActor in
                var collectedURLs: [URL] = []
                for provider in providers {
                    let url: URL? = await withCheckedContinuation { continuation in
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            continuation.resume(returning: url)
                        }
                    }
                    if let url = url {
                        collectedURLs.append(url)
                    }
                }
                let paths = collectedURLs.map(\.path)
                guard !paths.isEmpty else { return }
                self.openExternalPaths(paths)
            }
            return true
        }
    }

    // MARK: - Playback Controls & Routing
    private func stopPlayback() {
        if let currentPath = player.currentFilePath, player.currentTime > 0 {
            AppSettings.shared.savePosition(for: currentPath, position: player.currentTime, duration: player.duration)
        }
        PlayerWindowManager.shared.closeSettings()
        player.isPlaylistDrawerVisible = false
        player.isInspectorVisible = false
        player.stop()
        withAnimation(appSpringAnimation) {
            navigationModel.state = .idle
        }
    }

    private func startPlayback(path: String, startTime: Double = 0.0, autoPlay: Bool? = nil) {
        let url = URL(fileURLWithPath: path)
        withAnimation(appSpringAnimation) {
            navigationModel.state = .playing(url: url)
        }
        player.loadMediaWithCrossfade(path: path, startTime: startTime, autoPlay: autoPlay)
    }

    private func playMediaItem(_ item: MediaItem, in contextItems: [MediaItem] = []) {
        let list = contextItems.isEmpty ? [item] : contextItems
        playlistManager.setPlaylist(items: list, startingAt: item)
        let resumeTime = AppSettings.shared.getSavedPosition(for: item.path)
        startPlayback(path: item.path, startTime: resumeTime)
    }

    private func playPlaylistItem(_ item: PlaylistItem, forceStartFromBeginning: Bool = false) {
        if let idx = playlistManager.items.firstIndex(where: { $0.id == item.id || $0.path == item.path }) {
            playlistManager.selectIndex(idx)
        }
        let resumeTime = forceStartFromBeginning ? 0.0 : AppSettings.shared.getSavedPosition(for: item.path)
        startPlayback(path: item.path, startTime: resumeTime)
    }

    private func playNext() {
        guard let nextItem = playlistManager.moveToNext() else { return }
        playPlaylistItem(nextItem)
    }

    private func playPrevious() {
        if let prevItem = playlistManager.moveToPrevious() {
            playPlaylistItem(prevItem)
        } else {
            player.seek(to: 0.0)
            player.play()
        }
    }

    private func handlePlaybackEndedNaturally() {
        guard settings.autoPlayNextItem else {
            stopPlayback()
            return
        }

        guard let nextItem = playlistManager.handleNaturalEOF() else {
            stopPlayback()
            return
        }
        playPlaylistItem(nextItem, forceStartFromBeginning: true)
    }

    // MARK: - Session & Player Hooks
    private func setupHooks() {
        player.onProgressUpdate = { path, current, duration in
            if AppSettings.shared.keepRecentHistory {
                UserDefaults.standard.set(path, forKey: "lastPlayedFilePath")
                UserDefaults.standard.set(current, forKey: "lastPlayedPosition")
                UserDefaults.standard.set(duration, forKey: "lastPlayedDuration")
                AppSettings.shared.savePosition(for: path, position: current, duration: duration)
            }
        }
        player.onEscapePressed = {
            stopPlayback()
        }
        player.onPlaybackEndedNaturally = {
            guard isPlaying else { return }
            handlePlaybackEndedNaturally()
        }
        player.onNextTrackRequested = {
            guard isPlaying else { return }
            guard playlistManager.hasNext else { return }
            playNext()
        }
        player.onPreviousTrackRequested = {
            guard isPlaying else { return }
            playPrevious()
        }
        player.onFileLoadedFromDrop = { [self] path in
            self.openExternalPaths([path])
        }
        player.onFilesDropped = { [self] paths in
            self.openExternalPaths(paths)
        }
        player.onPlayRequestedWhenIdle = { [self] in
            guard !self.playlistManager.isEmpty else { return }
            let item = self.playlistManager.currentItem ?? self.playlistManager.items[0]
            self.playPlaylistItem(item)
        }
    }

    public func openExternalURL(_ url: URL) {
        guard url.isFileURL else { return }
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        openExternalPath(url.path)
    }

    public func openExternalPath(_ path: String) {
        openExternalPaths([path])
    }

    public func openExternalPaths(_ paths: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let expanded = PlayerWindowManager.expandFilesAndDirectories(paths)
            guard !expanded.isEmpty else { return }

            var newItems: [PlaylistItem] = []
            for p in expanded {
                let url = URL(fileURLWithPath: p)
                let title = url.deletingPathExtension().lastPathComponent
                let size = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
                let item = MediaItem(path: p, title: title, fileSize: size)
                newItems.append(PlaylistItem(from: item))
            }

            guard !newItems.isEmpty else { return }

            Task { @MainActor in
                self.playlistManager.appendItems(newItems)
                if let first = newItems.first {
                    self.playPlaylistItem(first)
                }
            }
        }
    }

    public func appendPlaylistPaths(_ paths: [String]) {
        openExternalPaths(paths)
    }

    private func registerSession() {
        let session = PlayerWindowSession(
            id: sessionId,
            window: player.hostWindow,
            player: player,
            isLoadedProvider: { [weak player] in
                guard let player = player else { return false }
                return player.isLoaded || player.playbackState == .loading
            }
        )
        session.closePlaybackHandler = { [self] in
            self.stopPlayback()
        }
        session.openFilePickerHandler = { [self] in
            self.openSingleFile()
        }
        session.onKeyDownHandler = { [weak player] event in
            player?.handleKeyDown(event: event)
        }
        session.onFullScreenChangedHandler = { [weak player] isFS in
            player?.setFullscreenState(isFS)
            if isFS {
                player?.isPlaylistDrawerVisible = false
            }
        }
        session.openPathHandler = { [self] path in
            self.openExternalPath(path)
        }
        session.appendPlaylistHandler = { [self] paths in
            self.appendPlaylistPaths(paths)
        }
        PlayerWindowManager.shared.registerSession(session)
    }

    private func unregisterSession() {
        PlayerWindowManager.shared.unregisterSession(id: sessionId)
        player.destroy()
        navigationModel.state = .idle
    }

    private func handleWindowAcquired(_ window: NSWindow) {
        if AppSettings.shared.windowMode == .singleWindow {
            // Check if another window session already exists with an attached window
            if let existing = PlayerWindowManager.shared.sessions.first(where: { $0.id != sessionId && $0.window != nil }) {
                // Duplicate window detected in single window mode: close immediately!
                DispatchQueue.main.async {
                    window.close()
                    existing.window?.makeKeyAndOrderFront(nil)
                    NSApp?.activate(ignoringOtherApps: true)
                }
                return
            }
        }

        if let session = PlayerWindowManager.shared.session(for: sessionId) {
            session.window = window
            if session.windowDelegate == nil {
                let delegate = PlayerWindowDelegate(session: session, player: player)
                session.windowDelegate = delegate
                window.delegate = delegate
            } else if window.delegate == nil {
                window.delegate = session.windowDelegate
            }
        }
        player.hostWindow = window
        window.toolbar = nil
        window.titlebarSeparatorStyle = .none
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        window.isOpaque = false
        window.backgroundColor = .clear
        if isPlaying {
            if !player.isFullscreen {
                player.applyContentAspectRatioLock()
            }
        } else {
            let emptyMin = NSSize(width: 640, height: 360)
            let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            window.minSize = emptyMin
            window.contentMinSize = emptyMin
            window.maxSize = screenFrame.size
            window.contentMaxSize = screenFrame.size
            window.contentAspectRatio = .zero
            window.aspectRatio = .zero
            window.resizeIncrements = NSSize(width: 1, height: 1)

            if !Self.didCenterInitialColdLaunchWindow {
                Self.didCenterInitialColdLaunchWindow = true
                let defaultW: CGFloat = 960
                let defaultH: CGFloat = 540
                let centerX = round(screenFrame.minX + (screenFrame.width - defaultW) / 2)
                let centerY = round(screenFrame.minY + (screenFrame.height - defaultH) / 2)
                let defaultFrame = NSRect(x: centerX, y: centerY, width: defaultW, height: defaultH)
                window.setFrame(defaultFrame, display: true, animate: false)
            }
        }
        player.updateTrafficLightsVisibility(animated: false)
    }

    private func updateAppTrafficLights() {
        if isPlaying {
            player.updateTrafficLightsVisibility()
        } else {
            showAllTrafficLights()
        }
    }

    private func showAllTrafficLights() {
        guard let window = player.hostWindow else { return }
        if window.styleMask.contains(.fullScreen) { return }
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for btnType in buttons {
            window.standardWindowButton(btnType)?.animator().alphaValue = 1.0
        }
    }

    private func checkPendingFiles() {
        let pending = PlayerWindowManager.shared.dequeuePendingFiles()
        if !pending.isEmpty {
            openExternalPaths(pending)
            return
        }

        if !AppDelegate.pendingFiles.isEmpty {
            let files = AppDelegate.pendingFiles
            AppDelegate.pendingFiles.removeAll()
            openExternalPaths(files)
            return
        }

        // On cold launch with no pending files, ensure playlist is restored if empty
        if playlistManager.isEmpty {
            playlistManager.restoreFromStorage()
        }

        // Only auto-resume playback on initial launch of the first window
        if PlayerWindowManager.shared.sessions.count <= 1 && settings.autoResumeOnLaunch {
            let targetItem = playlistManager.currentItem ?? playlistManager.items.first
            if let current = targetItem,
               FileManager.default.fileExists(atPath: current.path) {
                let lastPos = AppSettings.shared.getSavedPosition(for: current.path)
                startPlayback(path: current.path, startTime: lastPos, autoPlay: false)
            } else if playlistManager.isEmpty,
                      let lastPath = UserDefaults.standard.string(forKey: "lastPlayedFilePath"),
                      FileManager.default.fileExists(atPath: lastPath) {
                let lastPos = UserDefaults.standard.double(forKey: "lastPlayedPosition")
                playlistManager.setSingleItem(path: lastPath)
                startPlayback(path: lastPath, startTime: lastPos, autoPlay: false)
            }
        }
    }

    private func openSingleFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = L10n.chooseVideoDialog
        panel.prompt = L10n.open
        if panel.runModal() == .OK {
            let paths = panel.urls.map(\.path)
            openExternalPaths(paths)
        }
    }
}
