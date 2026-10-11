import SwiftUI
import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var pendingFiles: [String] = []

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp?.setActivationPolicy(.regular)
        NSApp?.activate(ignoringOtherApps: true)
        let args = CommandLine.arguments.dropFirst()
        var validFiles: [String] = []
        for arg in args where !arg.hasPrefix("-") {
            if FileManager.default.fileExists(atPath: arg) {
                let ext = (arg as NSString).pathExtension.lowercased()
                if MediaFileClassifier.videoExtensions.contains(ext) {
                    validFiles.append(arg)
                }
            }
        }
        if !validFiles.isEmpty {
            PlayerWindowManager.shared.openExternalFiles(validFiles)
        }
    }

    public func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for file in filenames {
            AppDelegate.pendingFiles.append(file)
        }
        PlayerWindowManager.shared.openExternalFiles(filenames)
    }

    public func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        AppDelegate.pendingFiles.append(filename)
        PlayerWindowManager.shared.openExternalFiles([filename])
        return true
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            PlayerWindowManager.shared.openNewWindow()
            return true
        }
        return true
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for session in PlayerWindowManager.shared.sessions {
            if let player = session.player as? PlayerCore {
                if let path = player.currentFilePath, player.currentTime > 0 {
                    AppSettings.shared.savePosition(for: path, position: player.currentTime, duration: player.duration)
                }
                player.stop()
            }
        }
        PlaylistManager.shared.saveToStorage()
        return .terminateNow
    }

    public func applicationWillTerminate(_ notification: Notification) {
        for session in PlayerWindowManager.shared.sessions {
            if let player = session.player as? PlayerCore {
                if let path = player.currentFilePath, player.currentTime > 0 {
                    AppSettings.shared.savePosition(for: path, position: player.currentTime, duration: player.duration)
                }
                player.stop()
            }
        }
        PlaylistManager.shared.saveToStorage()
    }
}
