import SwiftUI
import AppKit

@main
struct SilkPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private var settings = AppSettings.shared

    init() {
        Self.purgeSavedWindowFrameAutosave()
        PlayerWindowManager.shared.openShortcutsCheatsheetAction = {
            ShortcutsCheatsheetManager.shared.show()
        }
    }

    var body: some Scene {
        // 1. 单窗口统一视口容器 (PlayerWindowRootView) - 默认主窗口
        WindowGroup("SilkPlayer", id: "playerWindow") {
            PlayerWindowRootView()
                .preferredColorScheme(settings.effectiveColorScheme)
                .handlesExternalEvents(preferring: Set(arrayLiteral: "*"), allowing: Set(arrayLiteral: "*"))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 540)
        .commands {
            PlayerCommands()
        }
    }

    static func purgeSavedWindowFrameAutosave() {
        NSWindow.removeFrame(usingName: "playerWindow-AppWindow-1")
        let defaults = UserDefaults.standard
        let framePrefix = "NSWindow Frame "
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("\(framePrefix)playerWindow-") {
            let autosaveName = String(key.dropFirst(framePrefix.count))
            NSWindow.removeFrame(usingName: autosaveName)
            defaults.removeObject(forKey: key)
        }
    }
}
