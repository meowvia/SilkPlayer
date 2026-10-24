import Foundation
import AppKit
import UniformTypeIdentifiers
import CoreServices

/// Service managing on-demand default video player prompt on first file open.
/// Principles:
/// 1. Only prompts for video formats; strictly never prompts for audio formats.
/// 2. Prompts at most once per file format (extension).
/// 3. Options are strictly "Yes" or "No".
/// 4. If "Yes", associates ONLY this single format.
/// 5. If "No", never prompts again for this format, leaving existing associations untouched.
@MainActor
public final class DefaultPlayerPromptService {
    public static let shared = DefaultPlayerPromptService()

    private let storageKey = "promptedDefaultPlayerFormats"

    private init() {}

    /// Set of lowercase file extensions that have already been prompted
    public var promptedFormats: Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return Set(arr)
    }

    /// Marks a format as having been prompted so the user is never asked again
    public func markPrompted(for format: String) {
        var set = promptedFormats
        set.insert(format.lowercased())
        UserDefaults.standard.set(Array(set), forKey: storageKey)
    }

    /// Resets prompted formats (useful for testing)
    public func resetPromptedFormats() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Checks if SilkPlayer is already the default handler for the given format
    public func isAlreadyDefault(for format: String) -> Bool {
        guard let uti = UTType(filenameExtension: format) else { return false }
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: uti) else { return false }
        let currentID = Bundle(url: appURL)?.bundleIdentifier ?? ""
        let targetID = Bundle.main.bundleIdentifier ?? "com.silkplayer.SilkPlayer"
        return currentID.lowercased() == targetID.lowercased()
    }

    /// Evaluates if the opened file should prompt for default player assignment
    public func checkAndPromptIfNeeded(for fileURL: URL, in window: NSWindow?) {
        guard fileURL.isFileURL else { return }

        // 1. Strict constraint: only video files (never audio)
        guard MediaFileClassifier.classify(url: fileURL) == .video else { return }

        let ext = fileURL.pathExtension.lowercased()
        guard !ext.isEmpty else { return }

        // 2. If already prompted for this format, never ask again
        if promptedFormats.contains(ext) {
            return
        }

        // 3. If SilkPlayer is already default for this format, mark and return
        if isAlreadyDefault(for: ext) {
            markPrompted(for: ext)
            return
        }

        // 4. Mark prompted immediately to prevent re-triggering during subsequent loads
        markPrompted(for: ext)

        // 5. Present native prompt
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.tr(
            "Set SilkPlayer as Default Player?",
            "是否将 SilkPlayer 设置为默认播放器？"
        )
        alert.informativeText = L10n.tr(
            "Would you like SilkPlayer to automatically open all .\(ext.uppercased()) video files?",
            "是否默认使用 SilkPlayer 打开所有 .\(ext.uppercased()) 视频文件？"
        )
        alert.addButton(withTitle: L10n.tr("Yes", "是"))
        alert.addButton(withTitle: L10n.tr("No", "否"))

        let associate = { [weak self] in
            self?.associateSingleFormat(ext)
        }

        let targetWindow = window ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible })
        if let targetWindow = targetWindow {
            alert.beginSheetModal(for: targetWindow) { response in
                if response == .alertFirstButtonReturn {
                    associate()
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                associate()
            }
        }
    }

    /// Associates ONLY this single format with SilkPlayer
    public func associateSingleFormat(_ format: String) {
        guard let uti = UTType(filenameExtension: format)?.identifier else { return }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.silkplayer.SilkPlayer"
        _ = LSSetDefaultRoleHandlerForContentType(uti as CFString, .viewer, bundleID as CFString)
        _ = LSSetDefaultRoleHandlerForContentType(uti as CFString, .all, bundleID as CFString)
    }
}
