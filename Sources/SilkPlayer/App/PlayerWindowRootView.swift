import SwiftUI

/// Root view for each SilkPlayer window instance, managing its isolated PlayerCore and PlaylistManager lifecycle.
@MainActor
public struct PlayerWindowRootView: View {
    @State private var player = PlayerCore()
    @State private var playlistManager = PlaylistManager(isPersistenceEnabled: true, autoRestore: true)
    @State private var sessionId = UUID()
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some View {
        AppShellView(
            player: player,
            playlistManager: playlistManager,
            sessionId: sessionId
        )
        .onAppear {
            PlayerWindowManager.shared.openWindowAction = { [openWindow] in
                openWindow(id: "playerWindow")
            }
        }
    }
}
