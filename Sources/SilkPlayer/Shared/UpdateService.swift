import Foundation
import AppKit

/// Centralized Update Service for SilkPlayer (Proposal 020).
/// Provides smart silent update checks, 7-day weekly quiet cadence,
/// persistent "About" red dot indicator, and lossless in-place overwrite upgrades.
@MainActor
@Observable
public final class UpdateService {
    public static let shared = UpdateService()

    public private(set) var isChecking: Bool = false
    public private(set) var isDownloading: Bool = false
    public private(set) var downloadProgress: Double = 0.0
    public var latestVersion: String? = nil

    public var isShowingUpdateAlert: Bool = false
    public var isShowingUpToDateAlert: Bool = false
    public var alertErrorMessage: String? = nil

    private let userDefaultsLatestVersionKey = "SilkPlayer.Update.LatestVersion"
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
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6.0"
    }

    public init() {
        if let savedLatest = UserDefaults.standard.string(forKey: userDefaultsLatestVersionKey) {
            self.latestVersion = savedLatest
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
            // Still perform lightweight quiet check in background to refresh red dot status
            checkForUpdates(silent: true) { _, _ in }
            return
        }

        checkForUpdates(silent: true) { [weak self] hasUpdate, version in
            guard let self = self, hasUpdate, let version = version else { return }
            self.latestVersion = version
            self.isShowingUpdateAlert = true
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

    // MARK: - GitHub Releases Network Check
    public func checkForUpdates(
        silent: Bool,
        completion: @escaping @MainActor (Bool, String?) -> Void
    ) {
        guard let url = URL(string: "https://api.github.com/repos/meowvia/SilkPlayer/releases/latest") else {
            completion(false, nil)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue("SilkPlayer/\(currentAppVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        Task.detached(priority: .utility) { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    await MainActor.run { completion(false, nil) }
                    return
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let rawTagName = json["tag_name"] as? String else {
                    await MainActor.run { completion(false, nil) }
                    return
                }

                let remoteVersion = rawTagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

                await MainActor.run {
                    guard let self = self else { return }
                    let current = self.currentAppVersion
                    let comparison = Self.compareVersions(remoteVersion, current)

                    if comparison == .orderedDescending {
                        self.latestVersion = remoteVersion
                        self.hasPendingUpdate = true
                        UserDefaults.standard.set(remoteVersion, forKey: self.userDefaultsLatestVersionKey)
                        completion(true, remoteVersion)
                    } else {
                        self.hasPendingUpdate = false
                        UserDefaults.standard.removeObject(forKey: self.userDefaultsLatestVersionKey)
                        completion(false, nil)
                    }
                }
            } catch {
                await MainActor.run { completion(false, nil) }
            }
        }
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

    // MARK: - In-Place Lossless Overwrite Installer
    public func downloadAndInstall(version: String) {
        isDownloading = true
        downloadProgress = 0.05

        #if arch(arm64)
        let dmgName = "SilkPlayer-\(version)-arm64.dmg"
        #else
        let dmgName = "SilkPlayer-\(version)-x86_64.dmg"
        #endif

        let downloadURLString = "https://github.com/meowvia/SilkPlayer/releases/download/\(version)/\(dmgName)"
        guard let downloadURL = URL(string: downloadURLString) else {
            isDownloading = false
            alertErrorMessage = L10n.tr("Invalid download URL", "下载地址无效")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let targetDMG = tempDir.appendingPathComponent(dmgName)

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let (tempLocalURL, _) = try await URLSession.shared.download(from: downloadURL)
                try? FileManager.default.removeItem(at: targetDMG)
                try FileManager.default.moveItem(at: tempLocalURL, to: targetDMG)

                await MainActor.run {
                    self?.downloadProgress = 1.0
                    self?.launchInPlaceUpdateScript(dmgPath: targetDMG.path)
                }
            } catch {
                await MainActor.run {
                    self?.isDownloading = false
                    self?.alertErrorMessage = L10n.tr("Download failed: ", "下载失败: ") + error.localizedDescription
                }
            }
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
