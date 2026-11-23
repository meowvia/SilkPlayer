import SwiftUI
import AppKit

/// Root view for each SilkPlayer window instance, managing its isolated PlayerCore and PlaylistManager lifecycle.
@MainActor
public struct PlayerWindowRootView: View {
    @State private var player = PlayerCore()
    @State private var navigationModel: AppNavigationModel
    @State private var isSecondaryWindow: Bool
    @State private var isUnwantedDuplicate: Bool
    @State private var playlistManager: PlaylistManager
    @State private var sessionId = UUID()
    @Environment(\.openWindow) private var openWindow

    public init() {
        let existingSessions = PlayerWindowManager.shared.sessions.filter { $0.window != nil }
        let hasExisting = !existingSessions.isEmpty
        let isSingleMode = AppSettings.shared.windowMode == .singleWindow
        let hasPendingTask = PlayerWindowManager.shared.hasPendingFiles || !AppDelegate.pendingFiles.isEmpty
        let isPrimaryPlaying = existingSessions.first?.isLoaded == true

        let shouldDiscard: Bool
        if isSingleMode {
            shouldDiscard = hasExisting
        } else {
            shouldDiscard = existingSessions.count >= PlayerWindowManager.maxConcurrentWindows ||
                (hasExisting && !hasPendingTask && !isPrimaryPlaying)
        }

        self._isUnwantedDuplicate = State(initialValue: shouldDiscard)
        self._isSecondaryWindow = State(initialValue: hasExisting)

        var initialPending = PlayerWindowManager.shared.dequeuePendingFiles()
        if initialPending.isEmpty && !AppDelegate.pendingFiles.isEmpty {
            initialPending = AppDelegate.pendingFiles
            AppDelegate.pendingFiles.removeAll()
        }

        let initialPlaylist = PlaylistManager(
            isPersistenceEnabled: !hasExisting && initialPending.isEmpty,
            autoRestore: !hasExisting && initialPending.isEmpty
        )

        let navModel: AppNavigationModel
        if let first = initialPending.first {
            let url = URL(fileURLWithPath: first)
            let title = url.deletingPathExtension().lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: first)[.size] as? Int64) ?? 0
            let item = PlaylistItem(from: MediaItem(path: first, title: title, fileSize: size))
            var allItems = [item]
            if initialPending.count > 1 {
                for p in initialPending.dropFirst() {
                    let u = URL(fileURLWithPath: p)
                    let t = u.deletingPathExtension().lastPathComponent
                    let s = (try? FileManager.default.attributesOfItem(atPath: p)[.size] as? Int64) ?? 0
                    allItems.append(PlaylistItem(from: MediaItem(path: p, title: t, fileSize: s)))
                }
            }
            initialPlaylist.setPlaylist(playlistItems: allItems, startingIndex: 0)
            navModel = AppNavigationModel(initialState: .playing(url: url))
        } else {
            navModel = AppNavigationModel()
        }

        self._playlistManager = State(initialValue: initialPlaylist)
        self._navigationModel = State(initialValue: navModel)
    }

    public var body: some View {
        if isUnwantedDuplicate {
            Color.clear
                .frame(width: 1, height: 1)
                .background(
                    WindowAccessor { window in
                        window.orderOut(nil)
                        DispatchQueue.main.async {
                            window.close()
                        }
                    }
                )
        } else {
            AppShellView(
                player: player,
                playlistManager: playlistManager,
                navigationModel: navigationModel,
                sessionId: sessionId,
                isSecondaryWindow: isSecondaryWindow
            )
            .onAppear {
                PlayerWindowManager.shared.openWindowAction = { [openWindow] in
                    openWindow(id: "playerWindow")
                }
            }
        }
    }
}
