import Foundation

/// Sends only a random installation identifier, app version, and a launch event.
/// No media paths, playback events, license data, or hardware identifiers are sent.
@MainActor
final class SilkUsageAnalytics {
    static let shared = SilkUsageAnalytics()

    // Deploy the companion Cloudflare Worker on this first-party hostname before release.
    private let endpoint = URL(string: "https://analytics.silkplayer.1999909.xyz/v1/events")!
    private let installationIDKey = "silk.analytics.installationID"
    private let defaults = UserDefaults.standard

    private init() {}

    func recordLaunchIfEnabled() async {
        guard defaults.object(forKey: "anonymousUsageAnalyticsEnabled") as? Bool ?? true else {
            await retryPendingDeletion()
            return
        }

        let installationID = getOrCreateInstallationID()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        guard let url = URL(string: "/v1/events", relativeTo: endpoint)?.absoluteURL else { return }

        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "install_id": installationID,
            "version": String(version.prefix(32)),
            "event": "launch"
        ])
        _ = await perform(request)
    }

    func setEnabled(_ enabled: Bool) async {
        guard !enabled else {
            return
        }
        await retryPendingDeletion()
    }

    private func getOrCreateInstallationID() -> String {
        if let existing = defaults.string(forKey: installationIDKey), UUID(uuidString: existing) != nil {
            return existing
        }
        let identifier = UUID().uuidString.lowercased()
        defaults.set(identifier, forKey: installationIDKey)
        return identifier
    }

    private func retryPendingDeletion() async {
        guard let identifier = defaults.string(forKey: installationIDKey),
              UUID(uuidString: identifier) != nil,
              let baseURL = URL(string: "https://analytics.silkplayer.1999909.xyz/v1/install/"),
              let url = URL(string: identifier, relativeTo: baseURL)?.absoluteURL else {
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "DELETE"
        if await perform(request) {
            defaults.removeObject(forKey: installationIDKey)
        }
    }

    @discardableResult
    private func perform(_ request: URLRequest) async -> Bool {
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(response.statusCode)
        } catch {
            return false
        }
    }
}
