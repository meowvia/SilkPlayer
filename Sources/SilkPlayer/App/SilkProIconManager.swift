import AppKit

@MainActor
public enum SilkProIconManager {
    /// Cached Pro Icon Image (Amber/Black Gold Style from Website)
    private static let proIconImage: NSImage? = {
        if let proIconURL = Bundle.main.url(forResource: "AppIcon_Pro", withExtension: "icns") ??
                            Bundle.main.url(forResource: "AppIcon_Pro_1024", withExtension: "png") {
            return NSImage(contentsOf: proIconURL)
        }
        return nil
    }()

    /// Cached Standard Icon Image
    private static let standardIconImage: NSImage? = {
        if let stdIconURL = Bundle.main.url(forResource: "AppIcon_Standard", withExtension: "icns") ??
                            Bundle.main.url(forResource: "AppIcon", withExtension: "icns") ??
                            Bundle.main.url(forResource: "AppIcon_1024", withExtension: "png") {
            return NSImage(contentsOf: stdIconURL)
        }
        return nil
    }()

    /// Returns the appropriate icon for display inside UI components (e.g. Settings About page)
    public static func currentDisplayIcon(isProActive: Bool) -> NSImage? {
        if isProActive, let proIcon = proIconImage {
            return proIcon
        }
        return standardIconImage
    }

    /// Synchronizes the macOS application Dock icon with the Pro activation state
    public static func syncApplicationIcon(isProActive: Bool) {
        if isProActive, let proIcon = proIconImage {
            NSApp?.applicationIconImage = proIcon
        } else if let stdIcon = standardIconImage {
            NSApp?.applicationIconImage = stdIcon
        } else {
            NSApp?.applicationIconImage = nil
        }
    }
}
