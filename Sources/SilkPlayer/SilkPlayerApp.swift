import SwiftUI
import AppKit

@main
struct SilkPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private var settings = AppSettings.shared

    init() {
        PlayerWindowManager.shared.openShortcutsCheatsheetAction = {
            ShortcutsCheatsheetManager.shared.show()
        }
    }

    var body: some Scene {
        // 1. 单窗口统一视口容器 (PlayerWindowRootView) - 默认主窗口
        WindowGroup("SilkPlayer", id: "playerWindow") {
            PlayerWindowRootView()
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 540)
        .commands {
            PlayerCommands()
        }
    }
}
