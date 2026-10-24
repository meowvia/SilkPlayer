import Foundation
import AppKit
import UniformTypeIdentifiers
import CoreServices
import Observation

/// Service managing system default video player role and video format associations.
/// Adheres strictly to the user privacy principle:
/// - Only manages video formats (modern and legacy).
/// - Never touches or hijacks audio formats (.mp3, .flac, .wav, .m4a, etc.).
/// - Never prompts user on launch; operates only on explicit user request in Settings.
@MainActor
@Observable public final class DefaultPlayerService {
    public static let shared = DefaultPlayerService()

    public enum Status: Equatable, Sendable {
        case unknown
        case checking
        case allDefault
        case partiallyDefault(matched: Int, total: Int)
        case notDefault
    }

    /// All target video file extensions to associate (strictly video only, zero audio formats).
    public static let videoExtensions: [String] = [
        "mp4", "m4v", "mov", "mkv", "webm", "avi",
        "ts", "m2ts", "mts", "wmv", "asf", "flv",
        "f4v", "rmvb", "rm", "vob", "mpg", "mpeg",
        "m2v", "3gp", "3g2", "ogv", "divx"
    ]

    /// Canonical system video UTIs.
    public static let canonicalVideoUTIs: [String] = [
        "public.movie",
        "public.video"
    ]

    public private(set) var status: Status = .unknown
    public private(set) var isSetting: Bool = false

    private init() {}

    /// Target application bundle URL
    private var targetAppURL: URL {
        if Bundle.main.bundleURL.pathExtension == "app" {
            return Bundle.main.bundleURL
        }
        let installedURL = URL(fileURLWithPath: "/Applications/SilkPlayer.app")
        if FileManager.default.fileExists(atPath: installedURL.path) {
            return installedURL
        }
        return Bundle.main.bundleURL
    }

    private var targetBundleID: String {
        Bundle.main.bundleIdentifier ?? "com.silkplayer.SilkPlayer"
    }

    /// Checks current default player status across all video formats.
    public func checkStatus() async {
        status = .checking

        let exts = Self.videoExtensions
        let bundleID = targetBundleID

        // Run check off main thread to prevent any UI hitch
        let (matched, total) = await Task.detached(priority: .userInitiated) {
            var m = 0
            var t = 0
            for ext in exts {
                guard let uti = UTType(filenameExtension: ext) else { continue }
                t += 1
                if let handlerURL = NSWorkspace.shared.urlForApplication(toOpen: uti) {
                    let id = Bundle(url: handlerURL)?.bundleIdentifier
                    if id == bundleID || handlerURL.lastPathComponent.contains("SilkPlayer") {
                        m += 1
                    }
                }
            }
            return (m, t)
        }.value

        if total > 0 && matched == total {
            status = .allDefault
        } else if matched > 0 {
            status = .partiallyDefault(matched: matched, total: total)
        } else {
            status = .notDefault
        }
    }

    /// Associates all video formats with SilkPlayer.
    /// Strictly ignores any audio formats.
    @discardableResult
    public func setAsDefaultVideoPlayer() async -> Bool {
        guard !isSetting else { return false }
        isSetting = true
        defer { isSetting = false }

        let appURL = targetAppURL
        let bundleID = targetBundleID
        let exts = Self.videoExtensions
        let canonicals = Self.canonicalVideoUTIs

        await withTaskGroup(of: Void.self) { group in
            // 1. Register file extension UTTypes
            for ext in exts {
                guard let uti = UTType(filenameExtension: ext) else { continue }
                group.addTask {
                    await withCheckedContinuation { continuation in
                        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: uti) { _ in
                            continuation.resume()
                        }
                    }
                    LSSetDefaultRoleHandlerForContentType(uti.identifier as CFString, .viewer, bundleID as CFString)
                }
            }

            // 2. Register canonical video UTIs
            for canonical in canonicals {
                group.addTask {
                    if let uti = UTType(canonical) {
                        await withCheckedContinuation { continuation in
                            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: uti) { _ in
                                continuation.resume()
                            }
                        }
                    }
                    LSSetDefaultRoleHandlerForContentType(canonical as CFString, .viewer, bundleID as CFString)
                }
            }
        }

        await checkStatus()
        return status == .allDefault
    }

    /// User-facing status string
    public var statusDescription: String {
        switch status {
        case .unknown, .checking:
            return L10n.tr("Checking default player status...", "正在检测默认播放器状态…")
        case .allDefault:
            return L10n.tr("SilkPlayer is the default video player", "SilkPlayer 已作为系统默认视频播放器")
        case .partiallyDefault(let matched, let total):
            return L10n.tr("Partially associated (\(matched)/\(total) formats)", "已关联部分视频格式 (\(matched)/\(total))")
        case .notDefault:
            return L10n.tr("Not set as default video player", "尚未设为系统默认视频播放器")
        }
    }
}
