import SwiftUI

/// Root view for each SilkPlayer window instance, managing its isolated PlayerCore and PlaylistManager lifecycle.
@MainActor
public struct PlayerWindowRootView: View {
    @State private var player = PlayerCore()
    @State private var navigationModel = AppNavigationModel()
    @State private var isSecondaryWindow: Bool
    @State private var playlistManager: PlaylistManager
    @State private var sessionId = UUID()
    @Environment(\.openWindow) private var openWindow

    public init() {
        let isSecondary = !PlayerWindowManager.shared.sessions.isEmpty
        self._isSecondaryWindow = State(initialValue: isSecondary)
        self._playlistManager = State(
            initialValue: PlaylistManager(
                isPersistenceEnabled: !isSecondary,
                autoRestore: !isSecondary
            )
        )
    }

    public var body: some View {
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
