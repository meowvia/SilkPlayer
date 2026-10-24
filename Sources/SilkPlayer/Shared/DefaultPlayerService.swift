import Foundation
import CoreServices
import UniformTypeIdentifiers
import Observation

/// Service managing system default video player role and video format associations.
/// Adheres strictly to the user privacy and experience principles:
/// - Only manages video formats (modern and legacy).
/// - Never touches or hijacks audio formats (.mp3, .flac, .wav, .m4a, etc.).
/// - Uses pure LaunchServices C-API (LSSetDefaultRoleHandlerForContentType) to associate
///   formats silently without triggering intrusive system confirmation dialogs.
/// - Never runs automatically on install or cold start; operates solely on explicit user toggle.
@MainActor
@Observable public final class DefaultPlayerService {
    public static let shared = DefaultPlayerService()

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
        "public.video",
        "public.mpeg-4",
        "com.apple.quicktime-movie",
        "com.apple.m4v-video",
        "public.avi",
        "org.matroska.mkv",
        "org.webmproject.webm",
        "public.mpeg-2-transport-stream",
        "public.avchd-mpeg-2-transport-stream",
        "com.microsoft.windows-media-wmv",
        "com.microsoft.advanced-systems-format",
        "com.adobe.flash.video",
        "com.real.realmedia",
        "com.real.realmedia-vbr",
        "public.mpeg",
        "public.mpeg-2-video",
        "public.3gpp",
        "public.3gpp2",
        "org.xiph.ogv"
    ]

    public private(set) var isOperating: Bool = false

    private init() {}

    private var targetBundleID: String {
        Bundle.main.bundleIdentifier ?? "com.silkplayer.SilkPlayer"
    }

    /// Verifies if SilkPlayer is set as the default viewer for core video formats.
    public func checkStatus() async {
        let bundleID = targetBundleID
        let isDefault = await Task.detached(priority: .userInitiated) {
            let checkUTIs = ["public.mpeg-4", "com.apple.quicktime-movie", "public.movie"]
            var matchCount = 0
            for u in checkUTIs {
                if let handler = LSCopyDefaultRoleHandlerForContentType(u as CFString, .viewer)?.takeRetainedValue() as String?,
                   handler.lowercased() == bundleID.lowercased() {
                    matchCount += 1
                }
            }
            return matchCount >= 2
        }.value

        AppSettings.shared.isDefaultVideoPlayer = isDefault
    }

    /// Associates all video formats with SilkPlayer silently without modal confirmation popups.
    /// Strictly ignores any audio formats.
    public func setAsDefaultVideoPlayer() async {
        guard !isOperating else { return }
        isOperating = true
        defer { isOperating = false }

        let bundleID = targetBundleID
        let exts = Self.videoExtensions
        let canonicals = Self.canonicalVideoUTIs

        await Task.detached(priority: .userInitiated) {
            // 1. Register canonical video UTIs
            for uti in canonicals {
                _ = LSSetDefaultRoleHandlerForContentType(uti as CFString, .viewer, bundleID as CFString)
                _ = LSSetDefaultRoleHandlerForContentType(uti as CFString, .all, bundleID as CFString)
            }

            // 2. Register file extension UTTypes
            for ext in exts {
                if let uti = UTType(filenameExtension: ext)?.identifier {
                    _ = LSSetDefaultRoleHandlerForContentType(uti as CFString, .viewer, bundleID as CFString)
                    _ = LSSetDefaultRoleHandlerForContentType(uti as CFString, .all, bundleID as CFString)
                }
            }
        }.value

        AppSettings.shared.isDefaultVideoPlayer = true
    }

    /// Native Apple video formats that QuickTime Player supports natively.
    private static let appleNativeUTIs: [String] = [
        "public.movie",
        "public.video",
        "public.mpeg-4",
        "com.apple.quicktime-movie",
        "com.apple.m4v-video",
        "public.3gpp"
    ]

    /// Restores system default media player (QuickTime Player for Apple formats,
    /// and prior third-party player for MKV/WebM/AVI) by removing SilkPlayer overrides.
    public func restoreSystemDefaultPlayer() async {
        guard !isOperating else { return }
        isOperating = true
        defer { isOperating = false }

        let qtBundleID = "com.apple.QuickTimePlayerX"
        let appleUTIs = Self.appleNativeUTIs

        await Task.detached(priority: .userInitiated) {
            // 1. Revert Apple native formats to QuickTime
            for uti in appleUTIs {
                _ = LSSetDefaultRoleHandlerForContentType(uti as CFString, .viewer, qtBundleID as CFString)
                _ = LSSetDefaultRoleHandlerForContentType(uti as CFString, .all, qtBundleID as CFString)
            }

            // 2. Clean SilkPlayer entries from LaunchServices secure plist so non-Apple formats
            // naturally fall back to the user's prior third-party player (e.g. Movist, IINA)
            let path = ("~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist" as NSString).expandingTildeInPath
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               var plist = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: Any],
               let handlers = plist["LSHandlers"] as? [[String: Any]] {
                let filtered = handlers.filter { dict in
                    let s = "\(dict)".lowercased()
                    return !s.contains("silkplayer")
                }
                plist["LSHandlers"] = filtered
                if let outData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) {
                    try? outData.write(to: URL(fileURLWithPath: path))
                }
            }
        }.value

        AppSettings.shared.isDefaultVideoPlayer = false
    }
}
