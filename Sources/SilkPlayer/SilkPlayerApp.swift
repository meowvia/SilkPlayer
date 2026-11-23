import SwiftUI
import AppKit

@main
struct SilkPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private var settings = AppSettings.shared

    init() {
        Self.purgeSavedWindowFrameAutosave()
        let args = CommandLine.arguments.dropFirst()
        for arg in args where !arg.hasPrefix("-") {
            if FileManager.default.fileExists(atPath: arg) {
                let ext = (arg as NSString).pathExtension.lowercased()
                if MediaFileClassifier.videoExtensions.contains(ext) || MediaFileClassifier.audioExtensions.contains(ext) {
                    if !AppDelegate.pendingFiles.contains(arg) {
                        AppDelegate.pendingFiles.append(arg)
                    }
                }
            }
        }
        PlayerWindowManager.shared.openShortcutsCheatsheetAction = {
            ShortcutsCheatsheetManager.shared.show()
        }
    }

    var body: some Scene {
        // 1. 单窗口统一视口容器 (PlayerWindowRootView) - 默认主窗口
        WindowGroup("SilkPlayer", id: "playerWindow") {
            PlayerWindowRootView()
                .preferredColorScheme(settings.effectiveColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 540)
        .handlesExternalEvents(matching: [])
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
