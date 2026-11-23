import SwiftUI
import AppKit
import SilkCoreKit

@MainActor
public struct AppShellView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var player: PlayerCore
    @ObservedObject private var licenseEngine = SilkProLicenseEngine.shared
    @ObservedObject private var libraryEngine = SilkMediaLibraryEngine.shared
    var navigationModel: AppNavigationModel
    var playlistManager: PlaylistManager
    private var settings = AppSettings.shared
    public let sessionId: UUID
    public let isSecondaryWindow: Bool
    @State private var isDiscardedDuplicateWindow: Bool = false
    @State private var lastPreviousClickTime: Date = .distantPast
    @State private var prePlaybackLibraryFrame: NSRect? = nil
    @State private var isLeftSourceDrawerVisible: Bool = false
    @State private var playRequestGeneration: UInt64 = 0
    @State private var inFlightResolveTask: Task<Void, Never>? = nil
    @State private var resolvingTargetPath: String? = nil
    @State private var libraryPlaybackErrorMessage: String? = nil
    @State private var isLibraryDetailActive: Bool = false
    @State private var activeLibraryRecordPath: String? = nil
    @State private var interruptedLibraryDetailPath: String? = nil
    @State private var isPlayingEphemeralExternalMedia: Bool = false
    @AppStorage(SilkLibraryTheme.userDefaultsKey) private var proLibraryThemeRaw: String = SilkLibraryTheme.shenghui.rawValue

    public init(
        player: PlayerCore,
        playlistManager: PlaylistManager = PlaylistManager.shared,
        navigationModel: AppNavigationModel = .shared,
        sessionId: UUID = UUID(),
        isSecondaryWindow: Bool = false
    ) {
        self.player = player
        self.playlistManager = playlistManager
        self.navigationModel = navigationModel
        self.sessionId = sessionId
        self.isSecondaryWindow = isSecondaryWindow
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

    private var canUseLANFeatures: Bool {
        !isSecondaryWindow && licenseEngine.isProActive && settings.proLibraryHomeEnabled
    }

    private var isProLibraryActive: Bool {
        !isSecondaryWindow && canUseLANFeatures && !libraryEngine.sources.isEmpty
    }

    private var shouldHidePlaylistDrawerForPro: Bool {
        !isSecondaryWindow && ((!isPlaying && licenseEngine.isProActive) || isProLibraryActive)
    }

    private var useWarmLightEdgeHandle: Bool {
        !isPlaying && isProLibraryActive && (SilkLibraryTheme(rawValue: proLibraryThemeRaw)?.isLight == true)
    }

    private var isLibraryPlaybackErrorPresented: Binding<Bool> {
        Binding(
            get: { self.libraryPlaybackErrorMessage != nil },
            set: { if !$0 { self.libraryPlaybackErrorMessage = nil } }
        )
    }

    private var rootMinWidth: CGFloat {
        if player.isProMusicModeActive {
            let screenW = (player.hostWindow?.screen ?? NSScreen.main)?.visibleFrame.width ?? 1920
            return MusicModeGeometry.lockedWidth(forScreenWidth: screenW)
        } else if isPlaying || player.isLoaded {
            return 200
        } else if isProLibraryActive {
            return 720
        } else {
            return 200
        }
    }

    private var rootMinHeight: CGFloat {
        if player.isProMusicModeActive {
            // Keep well below collapsed height minus titlebar safe-area inset (~28-32pt) so AppKit window.minSize governs cleanly
            return 140.0
        } else if isPlaying || player.isLoaded {
            return 200
        } else if isProLibraryActive {
            return 460
        } else {
            return 200
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            let drawerWidth = PlaylistDrawerDimensions.drawerWidth(for: geometry.size.width, isFullscreen: player.isFullscreen)

            ZStack {
                if isPlaying {
                    if !player.isAudioOnly || !SilkProLicenseEngine.shared.isProActive {
                        Color.black
                            .edgesIgnoringSafeArea(.all)
                            .allowsHitTesting(false)
                    }

                    PlayerContainerView(
                        player: player,
                        playlist: playlistManager,
                        navigationModel: navigationModel,
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
                    .zIndex(10)
                } else {
                    if isProLibraryActive {
                        SilkProLibraryView(
                            onPlayItem: { target, queue, forceFromBeginning in
                                playLibraryRecord(target, queue: queue, forceFromBeginning: forceFromBeginning)
                            },
                            onOpenFile: {
                                openSingleFile()
                            },
                            onFilesDropped: { urls in
                                let paths = urls.map(\.path)
                                openExternalPaths(paths)
                            },
                            onOpenSettings: { tab in
                                PlayerWindowManager.shared.openSettings(initialTab: tab)
                            },
                            onDetailVisibilityChanged: { isActive in
                                isLibraryDetailActive = isActive
                            }
                        )
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    } else {
                        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                            .edgesIgnoringSafeArea(.all)
                            .allowsHitTesting(false)

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
                        .environment(\.colorScheme, .dark)
                        .transition(.opacity)
                    }

                    // Right-Edge Floating Side Triangle Pull Tab (omitted in Music Mode or Pro Library Drawer-Hidden Mode)
                    if !shouldHidePlaylistDrawerForPro {
                        if !player.isPlaylistDrawerVisible {
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
                            .allowsHitTesting(true)
                            .zIndex(18)
                        }

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

                    // Left-Edge Floating LAN Sources Handle & Manual Frosted Sidebar (hidden when movie detail canvas is active)
                    if canUseLANFeatures && !isLibraryDetailActive {
                        if !isLeftSourceDrawerVisible {
                            LeftLANSourceHandleTab(
                                isDrawerVisible: isLeftSourceDrawerVisible,
                                drawerWidth: max(290, drawerWidth),
                                useWarmLightStyle: useWarmLightEdgeHandle
                            ) {
                                withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                    isLeftSourceDrawerVisible.toggle()
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                            .allowsHitTesting(true)
                            .zIndex(18)
                        }

                        if isLeftSourceDrawerVisible {
                            Color.black.opacity(0.001)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .edgesIgnoringSafeArea(.all)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                        isLeftSourceDrawerVisible = false
                                    }
                                }
                                .zIndex(19)

                            HStack(spacing: 0) {
                                SilkLANSourceDrawerView(
                                    drawerWidth: max(290, drawerWidth),
                                    isInMediaLibrary: isProLibraryActive,
                                    onCompletedConfiguration: {
                                        withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                            isLeftSourceDrawerVisible = false
                                        }
                                    },
                                    onClose: {
                                        withAnimation(SilkAnimation.adaptive(reduceMotion: reduceMotion, preferred: .silkSnappy)) {
                                            isLeftSourceDrawerVisible = false
                                        }
                                    }
                                )
                                .environment(\.colorScheme, (SilkLibraryTheme(rawValue: proLibraryThemeRaw)?.isLight == true) ? .light : .dark)
                                .transition(SilkAnimation.transition(reduceMotion: reduceMotion, standard: .move(edge: .leading)))
                                Spacer()
                            }
                            .padding(.top, 36)
                            .padding(.bottom, 16)
                            .padding(.leading, 8)
                            .edgesIgnoringSafeArea(.all)
                            .zIndex(20)
                        }
                    }
                }


            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .preferredColorScheme(settings.effectiveColorScheme)
        .onChange(of: proLibraryThemeRaw) { _, newRaw in
            if let theme = SilkLibraryTheme(rawValue: newRaw), settings.proLibraryTheme != theme {
                settings.proLibraryTheme = theme
            }
        }
        .id(settings.appLanguage)
        .frame(minWidth: rootMinWidth, minHeight: rootMinHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            WindowAccessor { window in
                handleWindowAcquired(window)
            }
        )
        .onChange(of: isPlaying) { wasPlaying, isNowPlaying in
            handlePlaybackStateChange(wasPlaying: wasPlaying, isNowPlaying: isNowPlaying)
        }
        .onChange(of: settings.keepWindowOnTop) { _, newValue in
            PlayerWindowManager.shared.applyAlwaysOnTop(newValue)
        }
        .onChange(of: canUseLANFeatures) { _, enabled in
            if !enabled {
                isLeftSourceDrawerVisible = false
            }
        }
        .alert(
            L10n.tr("Unable to Open Media", "无法打开媒体文件"),
            isPresented: isLibraryPlaybackErrorPresented
        ) {
            Button(L10n.tr("OK", "确定"), role: .cancel) {
                libraryPlaybackErrorMessage = nil
            }
        } message: {
            Text(libraryPlaybackErrorMessage ?? "")
        }
        .onChange(of: licenseEngine.isProActive) { _, isActive in
            SilkProIconManager.syncApplicationIcon(isProActive: isActive)
            guard isActive, !isSecondaryWindow else { return }
            Task { @MainActor in
                if settings.proAutoScanOnLaunch {
                    await SilkMediaLibraryEngine.shared.rescanAutoSourcesOnLaunch()
                } else {
                    await SilkMediaLibraryEngine.shared.loadFromDatabase()
                }
            }
        }
        .onAppear {
            SilkProIconManager.syncApplicationIcon(isProActive: licenseEngine.isProActive)
            registerSession()
            setupHooks()
            if case .playing(let url) = navigationModel.state, player.currentFilePath == nil {
                startPlayback(path: url.path, startTime: AppSettings.shared.getSavedPosition(for: url.path), autoPlay: true)
            } else {
                checkPendingFiles()
            }
            if !isSecondaryWindow && licenseEngine.isProActive {
                Task { @MainActor in
                    if settings.proAutoScanOnLaunch {
                        await SilkMediaLibraryEngine.shared.rescanAutoSourcesOnLaunch()
                    } else {
                        await SilkMediaLibraryEngine.shared.loadFromDatabase()
                    }
                }
            }
        }
        .onDisappear {
            if isDiscardedDuplicateWindow {
                PlayerWindowManager.shared.unregisterSession(id: sessionId)
                player.destroy()
                return
            }
            if let currentPath = player.currentFilePath, player.currentTime > 0 {
                AppSettings.shared.savePosition(for: currentPath, position: player.currentTime, duration: player.duration)
            }
            if !isSecondaryWindow && !isPlayingEphemeralExternalMedia {
                playlistManager.saveToStorage()
            }
            if PlayerWindowManager.shared.sessions.count <= 1 {
                PlayerWindowManager.shared.closeSettings()
            }
            unregisterSession()
        }
        .onOpenURL { url in
            guard url.isFileURL else { return }
            PlayerWindowManager.shared.handleSystemOpenFiles([url.path])
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
        .alert(
            L10n.tr(
                "New version \(UpdateService.shared.latestVersion ?? "") is available. Update now?",
                "发现新版本 \(UpdateService.shared.latestVersion ?? "")，是否立即更新？"
            ),
            isPresented: Binding(
                get: { UpdateService.shared.isShowingUpdateAlert && !isSecondaryWindow && !isPlaying },
                set: { UpdateService.shared.isShowingUpdateAlert = $0 }
            )
        ) {
            Button(L10n.tr("Yes", "是")) {
                UpdateService.shared.userAcceptedUpdate()
            }
            Button(L10n.tr("No", "否"), role: .cancel) {
                UpdateService.shared.userDeclinedUpdate()
            }
        }
    }

    // MARK: - Playback Controls & Routing
    private func stopPlayback() {
        if player.isFullscreen, let w = player.hostWindow, w.styleMask.contains(.fullScreen) {
            player.toggleFullscreen()
        }
        inFlightResolveTask?.cancel()
        inFlightResolveTask = nil
        resolvingTargetPath = nil
        playRequestGeneration &+= 1
        if let currentPath = player.currentFilePath, player.currentTime > 0 {
            AppSettings.shared.recordPlaybackProgress(
                path: currentPath,
                current: player.currentTime,
                duration: player.duration,
                isPlaying: false,
                force: true
            )
        }
        player.isPlaylistDrawerVisible = false
        player.isInspectorVisible = false

        // Secondary window acts as a dedicated temporary player: closing playback closes the secondary window cleanly.
        if isSecondaryWindow {
            player.stop()
            playlistManager.clear()
            navigationModel.state = .idle
            player.hostWindow?.close()
            return
        }

        PlayerWindowManager.shared.closeSettings()
        player.stop()
        let wasEphemeralExternal = isPlayingEphemeralExternalMedia
        let restoreDetailPath = wasEphemeralExternal ? interruptedLibraryDetailPath : nil
        isPlayingEphemeralExternalMedia = false
        interruptedLibraryDetailPath = nil
        activeLibraryRecordPath = nil

        if isProLibraryActive {
            playlistManager.clear()
            playlistManager.isPersistenceEnabled = true
            if wasEphemeralExternal {
                playlistManager.saveToStorage()
                if let restoreDetailPath {
                    libraryEngine.activeDetailPath = restoreDetailPath
                }
            }
        } else {
            playlistManager.isPersistenceEnabled = true
            playlistManager.saveToStorage()
        }

        Task { @MainActor in
            await SilkMediaLibraryEngine.shared.reclaimMemory()
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            navigationModel.state = .idle
        }
    }

    private func startPlayback(path: String, startTime: Double = 0.0, autoPlay: Bool? = nil) {
        if !isPlaying,
           prePlaybackLibraryFrame == nil,
           let w = player.hostWindow,
           !w.styleMask.contains(.fullScreen) {
            prePlaybackLibraryFrame = w.frame
        }
        let url = URL(fileURLWithPath: path)
        let cat = PlaylistManager.category(for: url)
        playlistManager.applyPlaybackCategory(cat)
        if !isPlaying {
            navigationModel.state = .playing(url: url)
        } else {
            withAnimation(appSpringAnimation) {
                navigationModel.state = .playing(url: url)
            }
        }
        player.loadMediaWithCrossfade(path: path, startTime: startTime, autoPlay: autoPlay)
    }

    private func handlePlaybackStateChange(wasPlaying: Bool, isNowPlaying: Bool) {
        updateAppTrafficLights()
        if isNowPlaying {
            isLeftSourceDrawerVisible = false
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
            player.hostWindow?.contentResizeIncrements = NSSize(width: 1, height: 1)
            let emptyMin = isProLibraryActive ? NSSize(width: 720, height: 460) : NSSize(width: 640, height: 360)
            if let w = player.hostWindow, !w.styleMask.contains(.fullScreen), !player.isFullscreen {
                (w.delegate as? PlayerWindowDelegate)?.resetInteractiveModeToNormal()
                player.restoreStandardWindowChrome(on: w)
                let screen = w.screen ?? NSScreen.main
                let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

                let defaultIdleSize = NSSize(width: 960, height: 540)
                let targetFrame: NSRect
                if let savedLibraryFrame = prePlaybackLibraryFrame, (isProLibraryActive || savedLibraryFrame.width >= savedLibraryFrame.height) {
                    prePlaybackLibraryFrame = nil
                    let targetW = max(emptyMin.width, min(screenFrame.width, savedLibraryFrame.width))
                    let targetH = max(emptyMin.height, min(screenFrame.height, savedLibraryFrame.height))
                    let targetX = max(screenFrame.minX, min(screenFrame.maxX - targetW, savedLibraryFrame.origin.x))
                    let targetY = max(screenFrame.minY, min(screenFrame.maxY - targetH, savedLibraryFrame.origin.y))
                    targetFrame = NSRect(x: targetX, y: targetY, width: targetW, height: targetH)
                } else {
                    prePlaybackLibraryFrame = nil
                    let currentFrame = w.frame
                    let targetW: CGFloat
                    let targetH: CGFloat
                    let targetX: CGFloat
                    let targetY: CGFloat

                    // ISSUE-022: If closing after playing a portrait/vertical video (width < height)
                    // or unusually narrow window, reset back to standard 960x540 landscape frame.
                    if currentFrame.width < currentFrame.height || currentFrame.width < 720 {
                        targetW = min(defaultIdleSize.width, screenFrame.width)
                        targetH = min(defaultIdleSize.height, screenFrame.height)
                        let centerX = currentFrame.midX
                        let centerY = currentFrame.midY
                        let candidateX = centerX - (targetW / 2)
                        let candidateY = centerY - (targetH / 2)
                        targetX = max(screenFrame.minX, min(screenFrame.maxX - targetW, candidateX))
                        targetY = max(screenFrame.minY, min(screenFrame.maxY - targetH, candidateY))
                    } else {
                        targetW = max(currentFrame.width, emptyMin.width)
                        targetH = max(currentFrame.height, emptyMin.height)
                        let rawY = currentFrame.origin.y - (targetH - currentFrame.height)
                        let rawX = currentFrame.origin.x
                        targetX = max(screenFrame.minX, min(screenFrame.maxX - targetW, rawX))
                        targetY = max(screenFrame.minY, min(screenFrame.maxY - targetH, rawY))
                    }
                    targetFrame = NSRect(x: targetX, y: targetY, width: targetW, height: targetH)
                }

                w.minSize = NSSize(width: 100, height: 100)
                w.contentMinSize = w.minSize
                w.setFrame(targetFrame, display: true, animate: false)
                w.minSize = emptyMin
                w.contentMinSize = emptyMin
                w.maxSize = screenFrame.size
                w.contentMaxSize = screenFrame.size
                if let cv = w.contentView {
                    cv.autoresizingMask = [.width, .height]
                    if let superview = cv.superview {
                        cv.frame = superview.bounds
                    }
                    cv.needsLayout = true
                }
                w.layoutIfNeeded()
                DispatchQueue.main.async { [weak w] in
                    guard let w = w, let cv = w.contentView else { return }
                    cv.autoresizingMask = [.width, .height]
                    if let superview = cv.superview {
                        cv.frame = superview.bounds
                    }
                    cv.needsLayout = true
                    w.layoutIfNeeded()
                }
            }
        }
    }

    private func playLibraryRecord(_ target: SilkMediaLibraryRecord, queue: [SilkMediaLibraryRecord], forceFromBeginning: Bool) {
        // Ignore duplicate rapid double-click on the exact same item while it is still resolving/mounting
        if inFlightResolveTask != nil && resolvingTargetPath == target.path {
            return
        }

        inFlightResolveTask?.cancel()
        playRequestGeneration &+= 1
        let requestGen = playRequestGeneration
        resolvingTargetPath = target.path
        isPlayingEphemeralExternalMedia = false
        interruptedLibraryDetailPath = nil
        activeLibraryRecordPath = target.path
        if !isSecondaryWindow {
            playlistManager.isPersistenceEnabled = true
        }

        if !isPlaying,
           prePlaybackLibraryFrame == nil,
           let w = player.hostWindow,
           !w.styleMask.contains(.fullScreen) {
            prePlaybackLibraryFrame = w.frame
        }

        let orderedQueue = queue.isEmpty ? [target] : queue

        inFlightResolveTask = Task { @MainActor in
            defer {
                if requestGen == playRequestGeneration {
                    inFlightResolveTask = nil
                    resolvingTargetPath = nil
                }
            }

            let resolvedURL = await SilkMediaLibraryEngine.shared.resolvePlayableURL(for: target.path)
            guard !Task.isCancelled, requestGen == playRequestGeneration else { return }

            guard let resolvedURL else {
                if !isPlaying {
                    prePlaybackLibraryFrame = nil
                }
                libraryPlaybackErrorMessage = L10n.tr(
                    "The media file could not be accessed. Please verify the shared drive connection or folder permissions.\n\n\(target.title)",
                    "当前无法访问该媒体文件，请检查共享挂载连接或目录权限。\n\n\(target.title)"
                )
                return
            }

            let effectivePath = resolvedURL.path
            let playlistItems = Self.remappedPlaylistItems(
                from: orderedQueue,
                originalTargetPath: target.path,
                resolvedTargetPath: effectivePath
            )
            let startIndex = playlistItems.firstIndex(where: { $0.path == effectivePath })
                ?? orderedQueue.firstIndex(where: { $0.path == target.path })
                ?? 0

            playlistManager.setPlaylist(playlistItems: playlistItems, startingIndex: startIndex)

            let resumeTime: Double
            if forceFromBeginning || target.kind == .audio {
                resumeTime = 0.0
                if forceFromBeginning {
                    AppSettings.shared.savePosition(for: effectivePath, position: 0.0, duration: 0)
                }
            } else if target.watchState == .inProgress && target.positionSeconds >= 1.0 {
                resumeTime = target.positionSeconds
            } else {
                resumeTime = AppSettings.shared.getSavedPosition(for: effectivePath)
            }
            startPlayback(path: effectivePath, startTime: resumeTime, autoPlay: true)
        }
    }

    private static func remappedPlaylistItems(
        from queue: [SilkMediaLibraryRecord],
        originalTargetPath: String,
        resolvedTargetPath: String
    ) -> [PlaylistItem] {
        guard originalTargetPath != resolvedTargetPath else {
            return queue.map { PlaylistItem(path: $0.path, title: $0.title, duration: $0.durationSeconds) }
        }
        let origParts = originalTargetPath.split(separator: "/", omittingEmptySubsequences: false)
        let resParts = resolvedTargetPath.split(separator: "/", omittingEmptySubsequences: false)
        var commonTailCount = 0
        while commonTailCount < origParts.count && commonTailCount < resParts.count {
            let o = origParts[origParts.count - 1 - commonTailCount]
            let r = resParts[resParts.count - 1 - commonTailCount]
            if o != r { break }
            commonTailCount += 1
        }
        guard commonTailCount > 0 else {
            return queue.map { record in
                let p = (record.path == originalTargetPath) ? resolvedTargetPath : record.path
                return PlaylistItem(path: p, title: record.title, duration: record.durationSeconds)
            }
        }
        let oldPrefixParts = origParts.dropLast(commonTailCount)
        let newPrefixParts = resParts.dropLast(commonTailCount)
        let oldPrefix = oldPrefixParts.joined(separator: "/")
        let newPrefix = newPrefixParts.joined(separator: "/")
        guard !oldPrefix.isEmpty, oldPrefix != newPrefix else {
            return queue.map { PlaylistItem(path: $0.path, title: $0.title, duration: $0.durationSeconds) }
        }
        return queue.map { record in
            let remappedPath: String
            if record.path == originalTargetPath {
                remappedPath = resolvedTargetPath
            } else if record.path.hasPrefix(oldPrefix + "/") {
                remappedPath = newPrefix + String(record.path.dropFirst(oldPrefix.count))
            } else {
                remappedPath = record.path
            }
            return PlaylistItem(path: remappedPath, title: record.title, duration: record.durationSeconds)
        }
    }

    private func playMediaItem(_ item: MediaItem, in contextItems: [MediaItem] = []) {
        let list = contextItems.isEmpty ? [item] : contextItems
        playlistManager.setPlaylist(items: list, startingAt: item)
        let resumeTime = AppSettings.shared.getSavedPosition(for: item.path)
        startPlayback(path: item.path, startTime: resumeTime)
    }

    private func playPlaylistItem(_ item: PlaylistItem, forceStartFromBeginning: Bool = false) {
        playlistManager.selectItem(item)
        let resumeTime = forceStartFromBeginning ? 0.0 : AppSettings.shared.getSavedPosition(for: item.path)
        startPlayback(path: item.path, startTime: resumeTime, autoPlay: true)
    }

    private func playNext() {
        guard let nextItem = playlistManager.moveToNext() else { return }
        playPlaylistItem(nextItem)
    }

    private func playPrevious() {
        let (action, targetItem) = playlistManager.determinePreviousAction(currentTime: player.currentTime)
        if action == "rewind" {
            player.seek(to: 0.0)
            player.play()
        } else if let prevItem = targetItem {
            playPlaylistItem(prevItem)
        } else {
            player.seek(to: 0.0)
            player.play()
        }
    }

    private func handlePlaybackEndedNaturally() {
        guard settings.autoPlayNextItem else {
            player.pause()
            return
        }

        guard let nextItem = playlistManager.handleNaturalEOF() else {
            player.pause()
            return
        }
        playPlaylistItem(nextItem, forceStartFromBeginning: true)
    }

    // MARK: - Session & Player Hooks
    private func setupHooks() {
        player.onProgressUpdate = { [weak player] path, current, duration in
            AppSettings.shared.recordPlaybackProgress(
                path: path,
                current: current,
                duration: duration,
                isPlaying: player?.isPlaying ?? false
            )
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

        self.inFlightResolveTask?.cancel()
        self.inFlightResolveTask = nil
        self.resolvingTargetPath = nil
        self.playRequestGeneration &+= 1

        let isExternalNonLibrary = !self.isSecondaryWindow
            && self.isProLibraryActive
            && !expanded.allSatisfy { p in self.libraryEngine.items.contains(where: { $0.path == p }) }

        if isExternalNonLibrary {
            if self.isPlaying, let currentPath = self.player.currentFilePath, self.player.currentTime > 0 {
                AppSettings.shared.recordPlaybackProgress(
                    path: currentPath,
                    current: self.player.currentTime,
                    duration: self.player.duration,
                    isPlaying: false,
                    force: true
                )
            }
            if !self.isPlayingEphemeralExternalMedia {
                self.interruptedLibraryDetailPath = self.libraryEngine.activeDetailPath ?? self.activeLibraryRecordPath
            }
            self.isPlayingEphemeralExternalMedia = true
            self.libraryEngine.activeDetailPath = nil
            self.playlistManager.isPersistenceEnabled = false
            self.playlistManager.setPlaylist(playlistItems: newItems, startingIndex: 0)
            if let target = newItems.first {
                self.playPlaylistItem(target)
            }
        } else {
            if !self.isSecondaryWindow {
                self.playlistManager.isPersistenceEnabled = true
            }
            let wasEmpty = self.playlistManager.isEmpty
            self.playlistManager.appendItems(newItems)
            let itemToPlay = (wasEmpty && self.playlistManager.playbackMode == .shuffle)
                ? (self.playlistManager.currentItem ?? newItems.first)
                : newItems.first
            if let target = itemToPlay {
                self.playPlaylistItem(target)
            }
        }
    }

    public func appendPlaylistPaths(_ paths: [String]) {
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
            }
        }
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
        session.isSecondaryWindow = isSecondaryWindow
        session.closePlaybackHandler = { [self] in
            self.stopPlayback()
        }
        session.playPreviousHandler = { [self] in
            self.playPrevious()
        }
        session.playNextHandler = { [self] in
            self.playNext()
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
        session.isSecondaryWindow = isSecondaryWindow
        session.playlist = playlistManager
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
                isDiscardedDuplicateWindow = true
                var orphanedFiles = PlayerWindowManager.shared.dequeuePendingFiles()
                if !AppDelegate.pendingFiles.isEmpty {
                    orphanedFiles.append(contentsOf: AppDelegate.pendingFiles)
                    AppDelegate.pendingFiles.removeAll()
                }
                window.orderOut(nil)
                PlayerWindowManager.shared.unregisterSession(id: sessionId)
                DispatchQueue.main.async {
                    window.close()
                    if !orphanedFiles.isEmpty {
                        existing.openPath(orphanedFiles[0])
                        if orphanedFiles.count > 1 {
                            existing.appendPlaylistPaths(Array(orphanedFiles.dropFirst()))
                        }
                    }
                    if !PlayerWindowManager.isRunningTests {
                        existing.window?.makeKeyAndOrderFront(nil)
                        NSApp?.activate(ignoringOtherApps: true)
                    }
                }
                return
            }
        } else {
            // Enforce strict maxConcurrentWindows (2) cap in Dual-Window mode
            let attachedOthers = PlayerWindowManager.shared.sessions.filter { $0.id != sessionId && $0.window != nil }
            let hasPendingTask = PlayerWindowManager.shared.hasPendingFiles || !AppDelegate.pendingFiles.isEmpty
            let isPrimaryPlaying = attachedOthers.first?.isLoaded == true
            // If another window already exists, secondary window is ONLY allowed if there are pending files or primary window is actively playing
            if attachedOthers.count >= PlayerWindowManager.maxConcurrentWindows || (attachedOthers.count >= 1 && !hasPendingTask && !isPrimaryPlaying) {
                isDiscardedDuplicateWindow = true
                var orphanedFiles = PlayerWindowManager.shared.dequeuePendingFiles()
                if !AppDelegate.pendingFiles.isEmpty {
                    orphanedFiles.append(contentsOf: AppDelegate.pendingFiles)
                    AppDelegate.pendingFiles.removeAll()
                }
                window.orderOut(nil)
                PlayerWindowManager.shared.unregisterSession(id: sessionId)
                let reuseTarget = attachedOthers.first
                DispatchQueue.main.async {
                    window.close()
                    if !orphanedFiles.isEmpty, let target = reuseTarget {
                        target.openPath(orphanedFiles[0])
                        if orphanedFiles.count > 1 {
                            target.appendPlaylistPaths(Array(orphanedFiles.dropFirst()))
                        }
                    }
                    if !PlayerWindowManager.isRunningTests {
                        reuseTarget?.window?.makeKeyAndOrderFront(nil)
                        NSApp?.activate(ignoringOtherApps: true)
                    }
                }
                return
            }
        }

        if let session = PlayerWindowManager.shared.session(for: sessionId) {
            session.window = window
            if session.windowDelegate == nil {
                let delegate = PlayerWindowDelegate(session: session, player: player)
                delegate.isMediaLibraryActiveProvider = { [self] in
                    !self.isPlaying && self.isProLibraryActive
                }
                session.windowDelegate = delegate
                window.delegate = delegate
            } else if window.delegate == nil {
                window.delegate = session.windowDelegate
            }
            (window.delegate as? PlayerWindowDelegate)?.isMediaLibraryActiveProvider = { [self] in
                !self.isPlaying && self.isProLibraryActive
            }
            if let zoomBtn = window.standardWindowButton(.zoomButton),
               let delegate = window.delegate as? PlayerWindowDelegate {
                zoomBtn.target = delegate
                zoomBtn.action = #selector(PlayerWindowDelegate.handleZoomButtonClick(_:))
            }
            _ = (window.delegate as? PlayerWindowDelegate)?.ensureHUDAttached(to: window)
        }
        player.hostWindow = window
        // Never allow SwiftUI's automatic NSWindow autosave/tilingState to override cold-launch sizing.
        window.isRestorable = false
        if !window.frameAutosaveName.isEmpty {
            let autosaveName = window.frameAutosaveName
            window.setFrameAutosaveName("")
            NSWindow.removeFrame(usingName: autosaveName)
        }
        SilkPlayerApp.purgeSavedWindowFrameAutosave()
        window.toolbar = nil
        window.titlebarSeparatorStyle = .none
        window.acceptsMouseMovedEvents = true
        if player.isAudioOnly {
            player.configureMusicModeChrome(on: window)
        } else {
            player.restoreStandardWindowChrome(on: window)
        }
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert([.resizable, .fullSizeContentView])
        window.isMovableByWindowBackground = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = AppSettings.shared.keepWindowOnTop ? .floating : .normal
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = player.isFullscreen ? 0.0 : 10.0
        window.contentView?.layer?.masksToBounds = true
        if isPlaying {
            if !player.isFullscreen {
                player.applyContentAspectRatioLock()
                if player.isAudioOnly {
                    player.applyAudioWindowGeometry(animated: false)
                } else if AppSettings.shared.autoResizeWindow {
                    player.applyAdaptiveWindowGeometry(animated: false)
                }
            }
        } else {
            let emptyMin = isProLibraryActive ? NSSize(width: 720, height: 460) : NSSize(width: 640, height: 360)
            let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            window.minSize = emptyMin
            window.contentMinSize = emptyMin
            window.maxSize = screenFrame.size
            window.contentMaxSize = screenFrame.size
            window.contentAspectRatio = .zero
            window.aspectRatio = .zero
            window.resizeIncrements = NSSize(width: 1, height: 1)
            window.contentResizeIncrements = NSSize(width: 1, height: 1)

            if !Self.didCenterInitialColdLaunchWindow {
                Self.didCenterInitialColdLaunchWindow = true
                let defaultW: CGFloat = 960
                let defaultH: CGFloat = 540
                let centerX = round(screenFrame.minX + (screenFrame.width - defaultW) / 2)
                let centerY = round(screenFrame.minY + (screenFrame.height - defaultH) / 2)
                let defaultFrame = NSRect(x: centerX, y: centerY, width: defaultW, height: defaultH)
                window.setFrame(defaultFrame, display: true, animate: false)
                // Re-apply after initial SwiftUI window presentation settles in case WindowGroup applies a cached frame/tile late.
                DispatchQueue.main.async { [weak window] in
                    guard let window = window,
                          !self.isPlaying,
                          !self.player.isAudioOnly,
                          !window.styleMask.contains(.fullScreen) else { return }
                    if abs(window.frame.width - defaultW) > 1.0 || abs(window.frame.height - defaultH) > 1.0 {
                        window.setFrame(defaultFrame, display: true, animate: false)
                    }
                }
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

        if isSecondaryWindow {
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

/// Thin left-edge trigger handle preserving open-source `SilkDrawerHandleRepresentable` mouse tracking.
@MainActor
public struct LeftLANSourceHandleTab: View {
    public let isDrawerVisible: Bool
    public let drawerWidth: CGFloat
    public var useWarmLightStyle: Bool = false
    public var onHoverChange: ((Bool) -> Void)? = nil
    public let action: () -> Void

    public init(
        isDrawerVisible: Bool,
        drawerWidth: CGFloat,
        useWarmLightStyle: Bool = false,
        onHoverChange: ((Bool) -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.isDrawerVisible = isDrawerVisible
        self.drawerWidth = drawerWidth
        self.useWarmLightStyle = useWarmLightStyle
        self.onHoverChange = onHoverChange
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 0) {
            let isLight = useWarmLightStyle
            SilkDrawerHandleRepresentable(
                isDrawerVisible: isDrawerVisible,
                isLeadingEdge: true,
                customHandleWidth: isLight ? 8.0 : nil,
                customFillColor: isLight
                    ? NSColor(calibratedRed: 0.941, green: 0.902, blue: 0.839, alpha: 0.96)
                    : nil,
                customStrokeColor: isLight
                    ? NSColor(calibratedRed: 0.784, green: 0.408, blue: 0.180, alpha: 0.85)
                    : nil,
                customArrowColor: isLight
                    ? NSColor(calibratedRed: 0.784, green: 0.408, blue: 0.180, alpha: 0.95)
                    : nil,
                onHoverChange: onHoverChange,
                action: action
            )
            .frame(width: 28, height: 128)
            .help(L10n.tr("LAN & Media Sources", "局域网与媒体源"))
            .opacity(isDrawerVisible ? 0.0 : 1.0)
            .allowsHitTesting(!isDrawerVisible)

            Spacer()
                .allowsHitTesting(false)
        }
    }
}
