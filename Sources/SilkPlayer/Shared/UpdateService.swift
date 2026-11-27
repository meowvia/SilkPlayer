import Foundation
import AppKit

/// Centralized Update Service for SilkPlayer (Proposal 020).
/// Prioritizes official Cloudflare Edge endpoints (`silkplayer.com`) for reliable
/// Mainland China connectivity, with automatic fallback to GitHub Releases.
@MainActor
@Observable
public final class UpdateService {
    public static let shared = UpdateService()

    public nonisolated static let officialVersionEndpoint = "https://silkplayer.com/api/version"
    public nonisolated static let officialDownloadEndpoint = "https://silkplayer.com/api/download?arch=universal"
    public nonisolated static let githubLatestAPIEndpoint = "https://api.github.com/repos/meowvia/SilkPlayer/releases/latest"

    public private(set) var isChecking: Bool = false
    public private(set) var isDownloading: Bool = false
    public private(set) var downloadProgress: Double = 0.0
    public var latestVersion: String? = nil
    public var latestDownloadURL: String? = nil
    public var latestReleaseNotes: String? = nil

    public var isShowingUpdateAlert: Bool = false
    public var isShowingUpToDateAlert: Bool = false
    public var alertErrorMessage: String? = nil

    private let userDefaultsLatestVersionKey = "SilkPlayer.Update.LatestVersion"
    private let userDefaultsLatestDownloadURLKey = "SilkPlayer.Update.LatestDownloadURL"
    private let userDefaultsLatestReleaseNotesKey = "SilkPlayer.Update.LatestReleaseNotes"
    private let userDefaultsHasPendingUpdateKey = "SilkPlayer.Update.HasPendingUpdate"
    private let userDefaultsLastColdStartReminderKey = "SilkPlayer.Update.LastColdStartReminderDate"

    public var hasPendingUpdate: Bool {
        get {
            UserDefaults.standard.bool(forKey: userDefaultsHasPendingUpdateKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userDefaultsHasPendingUpdateKey)
        }
    }

    public var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
    }

    public init() {
        if let savedLatest = UserDefaults.standard.string(forKey: userDefaultsLatestVersionKey) {
            self.latestVersion = savedLatest
        }
        if let savedURL = UserDefaults.standard.string(forKey: userDefaultsLatestDownloadURLKey) {
            self.latestDownloadURL = savedURL
        }
        if let savedNotes = UserDefaults.standard.string(forKey: userDefaultsLatestReleaseNotesKey) {
            self.latestReleaseNotes = savedNotes
        }
    }

    // MARK: - Semantic Version Comparison
    public static func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let clean1 = v1.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let clean2 = v2.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

        let parts1 = clean1.split(separator: ".").compactMap { Int($0) }
        let parts2 = clean2.split(separator: ".").compactMap { Int($0) }

        let maxCount = max(parts1.count, parts2.count)
        for i in 0..<maxCount {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 < p2 { return .orderedAscending }
            if p1 > p2 { return .orderedDescending }
        }
        return .orderedSame
    }

    // MARK: - Cold Start Quiet Check
    public func performColdStartCheckIfNeeded() {
        guard !PlayerWindowManager.isRunningTests else { return }

        let lastReminderTime = UserDefaults.standard.double(forKey: userDefaultsLastColdStartReminderKey)
        let now = Date().timeIntervalSince1970
        let sevenDays: TimeInterval = 7 * 24 * 3600

        // If user clicked "No" within the past 7 days, enforce strict quiet period
        if lastReminderTime > 0 && (now - lastReminderTime) < sevenDays {
            checkForUpdates(silent: true) { _, _ in }
            return
        }

        checkForUpdates(silent: true) { [weak self] hasUpdate, version in
            guard let self = self, hasUpdate, let version = version else { return }
            self.latestVersion = version

            // 规则：播放中绝不弹窗打扰，仅在冷启动、静态待机时弹出
            let isAnyPlaying = PlayerWindowManager.shared.sessions.contains { $0.player?.isPlaying == true }
            guard !isAnyPlaying else { return }

            self.isShowingUpdateAlert = true
            self.presentColdStartAlertModalIfNeeded(version: version)
        }
    }

    /// Presents a native modal/sheet alert on the active playback window during cold start
    /// when the Settings window is not currently open.
    public func presentColdStartAlertModalIfNeeded(version: String) {
        guard !PlayerWindowManager.isRunningTests else { return }

        let isAnyPlaying = PlayerWindowManager.shared.sessions.contains { $0.player?.isPlaying == true }
        guard !isAnyPlaying else { return }

        // If Settings window is already visible and bound to SwiftUI alert, avoid duplicate presentation
        if let settingsWin = NSApp.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("偏好设置") }), settingsWin.isVisible {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.tr(
            "New version \(version) is available. Update now?",
            "发现新版本 \(version)，是否立即更新？"
        )
        alert.informativeText = formattedAlertMessage(for: version)
        alert.addButton(withTitle: L10n.tr("Yes", "是"))
        alert.addButton(withTitle: L10n.tr("No", "否"))

        let targetWindow = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && !($0 is NSPanel) })
        if let targetWindow = targetWindow {
            alert.beginSheetModal(for: targetWindow) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    self?.userAcceptedUpdate()
                } else {
                    self?.userDeclinedUpdate()
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.userAcceptedUpdate()
            } else {
                self.userDeclinedUpdate()
            }
        }
    }

    // MARK: - Manual Check
    public func checkManually() {
        isChecking = true
        checkForUpdates(silent: false) { [weak self] hasUpdate, version in
            guard let self = self else { return }
            self.isChecking = false
            if hasUpdate, let version = version {
                self.latestVersion = version
                self.isShowingUpdateAlert = true
            } else {
                self.isShowingUpToDateAlert = true
            }
        }
    }

    // MARK: - Edge-First + GitHub Fallback Network Check
    public func checkForUpdates(
        silent: Bool,
        completion: @escaping @MainActor (Bool, String?) -> Void
    ) {
        let appVer = currentAppVersion

        Task(priority: .utility) { [weak self] in
            if let edgeResult = await Self.fetchFromOfficialEdge(appVersion: appVer) {
                self?.applyRemoteVersionResult(
                    remoteVersion: edgeResult.version,
                    resolvedDownloadURL: edgeResult.downloadURL,
                    releaseNotes: edgeResult.notes,
                    completion: completion
                )
                return
            }

            if let ghResult = await Self.fetchFromGitHubFallback(appVersion: appVer) {
                self?.applyRemoteVersionResult(
                    remoteVersion: ghResult.version,
                    resolvedDownloadURL: ghResult.downloadURL,
                    releaseNotes: ghResult.notes,
                    completion: completion
                )
                return
            }

            completion(false, nil)
        }
    }

    /// Formats concise release notes + download guidance shown in both NSAlert and SwiftUI update dialogs.
    public func formattedAlertMessage(for version: String) -> String {
        let notesText = resolvedNotesText(for: version)
        let actionNote = L10n.tr(
            "Click \"Yes\" to download and install automatically in the background.",
            "点击「是」即可在端内静默下载并无损替换升级。"
        )
        if notesText.isEmpty {
            return actionNote
        }
        return "\(notesText)\n\n\(actionNote)"
    }

    private func resolvedNotesText(for version: String) -> String {
        if let raw = latestReleaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return raw
        }
        let cleanVer = version.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        if cleanVer == "2.2.0" {
            return L10n.tr(
                """
                What's New in 2.2.0:
                • Media Library now scans local folders, external drives & NAS shares
                • Added optional Pro Ambient Letterbox Fill in Settings → Playback
                • Direct FFmpeg header probe for Dolby Vision & Dolby Atmos specs
                • Fullscreen right-edge hover opens Playlist; 8s network watchdog
                """,
                """
                2.2.0 更新亮点：
                • 「媒体库」全面支持本地文件夹、外置硬盘与 NAS 目录海报墙
                • 新增 Pro「黑边环境光柔化」，可在 设置 → 播放 中按需开启
                • 详情页直接探测 Dolby Vision / Dolby Atmos 等音视频规格
                • 全屏右侧悬停展开播放列表，新增网络断流 8 秒超时保护
                """
            )
        }
        return ""
    }

    private func applyRemoteVersionResult(
        remoteVersion: String,
        resolvedDownloadURL: String,
        releaseNotes: String?,
        completion: @escaping @MainActor (Bool, String?) -> Void
    ) {
        let comparison = Self.compareVersions(remoteVersion, currentAppVersion)
        if comparison == .orderedDescending {
            latestVersion = remoteVersion
            latestDownloadURL = resolvedDownloadURL
            let trimmedNotes = releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
            latestReleaseNotes = (trimmedNotes?.isEmpty == false) ? trimmedNotes : nil
            hasPendingUpdate = true
            UserDefaults.standard.set(remoteVersion, forKey: userDefaultsLatestVersionKey)
            UserDefaults.standard.set(resolvedDownloadURL, forKey: userDefaultsLatestDownloadURLKey)
            if let notes = latestReleaseNotes {
                UserDefaults.standard.set(notes, forKey: userDefaultsLatestReleaseNotesKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userDefaultsLatestReleaseNotesKey)
            }
            completion(true, remoteVersion)
        } else {
            latestDownloadURL = nil
            latestReleaseNotes = nil
            hasPendingUpdate = false
            UserDefaults.standard.removeObject(forKey: userDefaultsLatestVersionKey)
            UserDefaults.standard.removeObject(forKey: userDefaultsLatestDownloadURLKey)
            UserDefaults.standard.removeObject(forKey: userDefaultsLatestReleaseNotesKey)
            completion(false, nil)
        }
    }

    private nonisolated static func selectLocalizedNotes(from json: [String: Any]) -> String? {
        let isChinese = Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
        let candidates: [String?] = isChinese
            ? [json["notes_zh"] as? String, json["notes"] as? String, json["notes_en"] as? String]
            : [json["notes_en"] as? String, json["notes"] as? String, json["notes_zh"] as? String]
        for candidate in candidates {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private nonisolated static func compactGitHubReleaseNotes(_ rawBody: String?) -> String? {
        guard let rawBody else { return nil }
        let lines = rawBody
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                !line.isEmpty
                    && !line.hasPrefix("#")
                    && !line.hasPrefix("```")
                    && !line.hasPrefix(">")
                    && (line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• "))
            }
            .prefix(4)
            .map { line -> String in
                if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    return "• " + line.dropFirst(2)
                }
                return line
            }
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }

    private nonisolated static func fetchFromOfficialEdge(
        appVersion: String
    ) async -> (version: String, downloadURL: String, notes: String?)? {
        guard let url = URL(string: officialVersionEndpoint) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.setValue("SilkPlayer/\(appVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            let rawVer = (json["version"] as? String) ?? (json["tag"] as? String)
            guard let rawVer else { return nil }
            let cleanVer = rawVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            guard !cleanVer.isEmpty else { return nil }
            let notes = selectLocalizedNotes(from: json)
            return (cleanVer, officialDownloadEndpoint, notes)
        } catch {
            return nil
        }
    }

    private nonisolated static func fetchFromGitHubFallback(
        appVersion: String
    ) async -> (version: String, downloadURL: String, notes: String?)? {
        guard let url = URL(string: githubLatestAPIEndpoint) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue("SilkPlayer/\(appVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawTagName = json["tag_name"] as? String else {
                return nil
            }
            let cleanVer = rawTagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            guard !cleanVer.isEmpty else { return nil }
            let assets = json["assets"] as? [[String: Any]]
            let ghURL = resolveDownloadURLString(version: cleanVer, assets: assets)
            // Prefer official Cloudflare Edge download mirror so Mainland China users don't stall on GitHub CDN
            _ = ghURL
            let notes = compactGitHubReleaseNotes(json["body"] as? String)
            return (cleanVer, officialDownloadEndpoint, notes)
        } catch {
            return nil
        }
    }

    public nonisolated static func resolveDownloadURLString(
        version: String,
        assets: [[String: Any]]? = nil,
        preferredArch: String? = nil
    ) -> String {
        let resolvedArch: String = {
            if let preferredArch { return preferredArch }
            #if arch(arm64)
            return "arm64"
            #else
            return "x86_64"
            #endif
        }()

        let candidateNames = [
            "SilkPlayer-\(version)-universal.dmg",
            "SilkPlayer-\(version).dmg",
            "SilkPlayer-\(version)-\(resolvedArch).dmg"
        ]

        if let assets {
            for candidate in candidateNames {
                if let match = assets.first(where: { ($0["name"] as? String) == candidate }),
                   let downloadURL = match["browser_download_url"] as? String,
                   !downloadURL.isEmpty {
                    return downloadURL
                }
            }
            if let universalDMG = assets.first(where: {
                guard let name = $0["name"] as? String else { return false }
                return name.hasSuffix(".dmg") && name.localizedCaseInsensitiveContains("universal")
            }), let downloadURL = universalDMG["browser_download_url"] as? String, !downloadURL.isEmpty {
                return downloadURL
            }
        }

        return "https://github.com/meowvia/SilkPlayer/releases/download/\(version)/SilkPlayer-\(version)-universal.dmg"
    }

    // MARK: - User Decisions
    public func userDeclinedUpdate() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: userDefaultsLastColdStartReminderKey)
        isShowingUpdateAlert = false
    }

    public func userAcceptedUpdate() {
        isShowingUpdateAlert = false
        guard let version = latestVersion else { return }
        downloadAndInstall(version: version)
    }

    // MARK: - In-Place Lossless Overwrite Installer (Edge-First + GitHub Fallback)
    public func downloadAndInstall(version: String) {
        isDownloading = true
        downloadProgress = 0.05

        let primaryURLString: String
        if let cachedURL = latestDownloadURL,
           !cachedURL.isEmpty,
           latestVersion == version {
            primaryURLString = cachedURL
        } else {
            primaryURLString = Self.officialDownloadEndpoint
        }
        let fallbackGitHubURLString = Self.resolveDownloadURLString(version: version)

        var candidateURLs: [URL] = []
        if let primaryURL = URL(string: primaryURLString) {
            candidateURLs.append(primaryURL)
        }
        if fallbackGitHubURLString != primaryURLString, let fallbackURL = URL(string: fallbackGitHubURLString) {
            candidateURLs.append(fallbackURL)
        }

        guard !candidateURLs.isEmpty else {
            isDownloading = false
            alertErrorMessage = L10n.tr("Invalid download URL", "下载地址无效")
            return
        }

        let targetDMG = FileManager.default.temporaryDirectory
            .appendingPathComponent("SilkPlayer-\(version)-universal.dmg")

        Task(priority: .userInitiated) { [weak self] in
            var lastError: Error? = nil

            for candidateURL in candidateURLs {
                do {
                    let (tempLocalURL, response) = try await URLSession.shared.download(from: candidateURL)
                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        throw URLError(.badServerResponse)
                    }
                    try? FileManager.default.removeItem(at: targetDMG)
                    try FileManager.default.moveItem(at: tempLocalURL, to: targetDMG)

                    guard let self = self else { return }
                    self.downloadProgress = 1.0
                    self.launchInPlaceUpdateScript(dmgPath: targetDMG.path)
                    return
                } catch {
                    lastError = error
                }
            }

            guard let self = self else { return }
            self.isDownloading = false
            let message = lastError?.localizedDescription ?? "Unknown error"
            self.alertErrorMessage = L10n.tr("Download failed: ", "下载失败: ") + message
        }
    }

    /// Spawns a background shell script to replace /Applications/SilkPlayer.app cleanly
    /// and relaunch, completely preserving all user Library data and preferences.
    private func launchInPlaceUpdateScript(dmgPath: String) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let scriptPath = "/tmp/silkplayer_inplace_updater.sh"
        let script = """
        #!/bin/bash
        set -e
        PID=\(pid)
        DMG="\(dmgPath)"
        APP_PATH="/Applications/SilkPlayer.app"

        # Wait for host process to quit cleanly
        while kill -0 $PID 2>/dev/null; do
            sleep 0.2
        done

        MOUNT_DIR=$(mktemp -d /tmp/silkplayer_mount_XXXXXX)
        hdiutil attach "$DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

        if [ -d "$MOUNT_DIR/SilkPlayer.app" ]; then
            rm -rf "$APP_PATH"
            cp -R "$MOUNT_DIR/SilkPlayer.app" "$APP_PATH"
            xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true
        fi

        hdiutil detach "$MOUNT_DIR" -quiet || true
        rm -rf "$MOUNT_DIR"
        rm -f "$DMG"

        open "$APP_PATH"
        rm -f "$0"
        """

        try? script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        _ = try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptPath]
        try? task.run()

        NSApp?.terminate(nil)
    }
}
