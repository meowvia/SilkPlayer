import Observation
import SwiftUI
import Combine
import AppKit

public enum AppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return L10n.tr("System", "跟随系统")
        case .light: return L10n.tr("Light", "浅色")
        case .dark: return L10n.tr("Dark", "深色")
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case zhHans = "zh-Hans"
    case en = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}

public enum DoubleClickAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case toggleFullscreen = "fullscreen"
    case playPause = "playPause"
    case openFile = "openFile"
    case none = "none"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .toggleFullscreen: return L10n.tr("Toggle Fullscreen", "切换全屏")
        case .playPause: return L10n.tr("Play / Pause", "播放 / 暂停")
        case .openFile: return L10n.tr("Open File...", "打开文件…")
        case .none: return L10n.tr("None", "无动作")
        }
    }
}

public enum ScrollWheelAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case volume = "volume"
    case seek = "seek"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .volume: return L10n.tr("Adjust Volume", "调节音量")
        case .seek: return L10n.tr("Seek Forward / Backward", "快进 / 快退")
        }
    }
}

// Subtitle size scale presets
public enum SubtitleSizePreset: Double, CaseIterable, Identifiable, Codable, Sendable {
    case small = 0.8
    case standard = 1.0
    case large = 1.25
    case extraLarge = 1.5

    public var id: Double { rawValue }

    public var displayName: String {
        switch self {
        case .small: return L10n.tr("Small (80%)", "小 (80%)")
        case .standard: return L10n.tr("Standard (100%)", "标准 (100%)")
        case .large: return L10n.tr("Large (125%)", "大 (125%)")
        case .extraLarge: return L10n.tr("Extra Large (150%)", "特大 (150%)")
        }
    }
}

public enum WindowMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case singleWindow = "SingleWindow"
    case multipleWindows = "MultipleWindows"

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .singleWindow: return L10n.tr("Single Window", "单窗口")
        case .multipleWindows: return L10n.tr("Multiple Windows", "多窗口")
        }
    }
    public var description: String {
        switch self {
        case .singleWindow: return L10n.tr("Always play in a single unified window", "始终使用单一播放窗口")
        case .multipleWindows: return L10n.tr("Allow opening multiple independent windows", "允许打开多个独立播放窗口")
        }
    }
}

@MainActor
@Observable public final class AppSettings {
    public static let shared = AppSettings()

    // MARK: - 1. General (通用)
    public var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            applyAppearance()
        }
    }
    public var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
            NotificationCenter.default.post(name: .silkLanguageDidChange, object: nil)
        }
    }
    public var keepWindowOnTop: Bool {
        didSet {
            UserDefaults.standard.set(keepWindowOnTop, forKey: "keepWindowOnTop")
            PlayerWindowManager.shared.applyAlwaysOnTop(keepWindowOnTop)
        }
    }
    public var autoResizeWindow: Bool {
        didSet {
            UserDefaults.standard.set(autoResizeWindow, forKey: "autoResizeWindow")
        }
    }
    public var doubleClickAction: DoubleClickAction {
        didSet {
            UserDefaults.standard.set(doubleClickAction.rawValue, forKey: "doubleClickAction")
        }
    }
    public var screenshotDirectory: String {
        didSet {
            UserDefaults.standard.set(screenshotDirectory, forKey: "screenshotDirectory")
            try? FileManager.default.createDirectory(atPath: screenshotDirectory, withIntermediateDirectories: true)
        }
    }
    public var screenshotFormat: String {
        didSet {
            UserDefaults.standard.set(screenshotFormat, forKey: "screenshotFormat")
        }
    }

    // Window management strategy (Single-window vs Multi-window)
    public var windowMode: WindowMode {
        get { singleWindowMode ? .singleWindow : .multipleWindows }
        set { singleWindowMode = (newValue == .singleWindow) }
    }
    public var singleWindowMode: Bool {
        didSet {
            UserDefaults.standard.set(singleWindowMode, forKey: "singleWindowMode")
        }
    }

    // MARK: - 2. Playback (播放)
    public var autoPlayOnLoad: Bool {
        didSet {
            UserDefaults.standard.set(autoPlayOnLoad, forKey: "autoPlayOnLoad")
        }
    }
    public var resumePlayback: Bool {
        didSet {
            UserDefaults.standard.set(resumePlayback, forKey: "resumePlayback")
        }
    }
    public var autoResumeOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(autoResumeOnLaunch, forKey: "autoResumeOnLaunch")
        }
    }
    public var autoResumePlayback: Bool {
        get { autoResumeOnLaunch }
        set { autoResumeOnLaunch = newValue }
    }
    public var autoPlayNextItem: Bool {
        didSet {
            UserDefaults.standard.set(autoPlayNextItem, forKey: "autoPlayNextItem")
        }
    }
    public var shortSeekStep: Double {
        didSet {
            UserDefaults.standard.set(shortSeekStep, forKey: "shortSeekStep")
        }
    }
    public var longSeekStep: Double {
        didSet {
            UserDefaults.standard.set(longSeekStep, forKey: "longSeekStep")
        }
    }
    public var autoEnhanceQuality: Bool {
        didSet {
            UserDefaults.standard.set(autoEnhanceQuality, forKey: "autoEnhanceQuality")
            PlayerWindowManager.shared.applyAutoEnhanceQuality(autoEnhanceQuality)
        }
    }
    public var hdrToneMappingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hdrToneMappingEnabled, forKey: "hdrToneMappingEnabled")
            PlayerWindowManager.shared.applyHDRToneMapping(hdrToneMappingEnabled)
        }
    }
    public var autoScanSubfolders: Bool {
        didSet {
            UserDefaults.standard.set(autoScanSubfolders, forKey: "autoScanSubfolders")
        }
    }
    public var keepRecentHistory: Bool {
        didSet {
            UserDefaults.standard.set(keepRecentHistory, forKey: "keepRecentHistory")
        }
    }

    // MARK: - 3. Audio & Subtitles (音频与字幕)
    public var maxVolumeLimit: Double {
        didSet {
            UserDefaults.standard.set(maxVolumeLimit, forKey: "maxVolumeLimit")
        }
    }
    public var rememberVolume: Bool {
        didSet {
            UserDefaults.standard.set(rememberVolume, forKey: "rememberVolume")
        }
    }
    public var savedVolume: Double {
        didSet {
            UserDefaults.standard.set(savedVolume, forKey: "savedVolume")
        }
    }
    public var subAutoMode: String {
        didSet {
            UserDefaults.standard.set(subAutoMode, forKey: "subAutoMode")
        }
    }
    public var nightModeDialogueBoost: Bool {
        didSet {
            UserDefaults.standard.set(nightModeDialogueBoost, forKey: "nightModeDialogueBoost")
            PlayerWindowManager.shared.applyNightMode(nightModeDialogueBoost)
        }
    }
    public var subtitleSizePreset: SubtitleSizePreset {
        didSet {
            UserDefaults.standard.set(subtitleSizePreset.rawValue, forKey: "subtitleSizePreset")
            defaultSubtitleScale = subtitleSizePreset.rawValue
        }
    }
    public var defaultSubtitleScale: Double {
        didSet {
            UserDefaults.standard.set(defaultSubtitleScale, forKey: "defaultSubtitleScale")
            PlayerWindowManager.shared.applySubtitleScale(defaultSubtitleScale)
        }
    }
    public var preferredSubtitleLang: String {
        didSet {
            UserDefaults.standard.set(preferredSubtitleLang, forKey: "preferredSubtitleLang")
        }
    }

    // Compatibility shim for volumeBoost
    public var volumeBoost: Int {
        get { Int(maxVolumeLimit) }
        set { maxVolumeLimit = Double(newValue) }
    }

    // MARK: - 4. Shortcuts & Gestures (快捷键与手势)
    public var scrollWheelAction: ScrollWheelAction {
        didSet {
            UserDefaults.standard.set(scrollWheelAction.rawValue, forKey: "scrollWheelAction")
        }
    }

    // MARK: - Playback History Dictionary
    private var progressHistory: [String: Double] = [:]

    private init() {
        // 1. General
        let rawAppearance = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: rawAppearance) ?? .system
        let rawLang = UserDefaults.standard.string(forKey: "appLanguage")
        if let rawLang = rawLang, let lang = AppLanguage(rawValue: rawLang) {
            self.appLanguage = lang
        } else {
            let isZh = Locale.preferredLanguages.first?.hasPrefix("zh") ?? true
            self.appLanguage = isZh ? .zhHans : .en
        }
        self.keepWindowOnTop = UserDefaults.standard.bool(forKey: "keepWindowOnTop")
        self.autoResizeWindow = UserDefaults.standard.object(forKey: "autoResizeWindow") as? Bool ?? true
        let rawDoubleClick = UserDefaults.standard.string(forKey: "doubleClickAction") ?? DoubleClickAction.toggleFullscreen.rawValue
        self.doubleClickAction = DoubleClickAction(rawValue: rawDoubleClick) ?? .toggleFullscreen

        let defaultPicturesDir = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first?.appendingPathComponent("SilkPlayer").path ?? (NSHomeDirectory() + "/Pictures/SilkPlayer")
        self.screenshotDirectory = UserDefaults.standard.string(forKey: "screenshotDirectory") ?? defaultPicturesDir
        self.screenshotFormat = UserDefaults.standard.string(forKey: "screenshotFormat") ?? "png"

        self.singleWindowMode = UserDefaults.standard.object(forKey: "singleWindowMode") as? Bool ?? true

        // 2. Playback
        self.autoPlayOnLoad = UserDefaults.standard.object(forKey: "autoPlayOnLoad") as? Bool ?? true
        self.resumePlayback = UserDefaults.standard.object(forKey: "resumePlayback") as? Bool ?? true
        self.autoResumeOnLaunch = UserDefaults.standard.object(forKey: "autoResumeOnLaunch") as? Bool ?? false
        self.autoPlayNextItem = UserDefaults.standard.object(forKey: "autoPlayNextItem") as? Bool ?? true
        self.shortSeekStep = UserDefaults.standard.object(forKey: "shortSeekStep") as? Double ?? 5.0
        self.longSeekStep = UserDefaults.standard.object(forKey: "longSeekStep") as? Double ?? 30.0
        self.autoEnhanceQuality = UserDefaults.standard.object(forKey: "autoEnhanceQuality") as? Bool ?? false
        self.hdrToneMappingEnabled = UserDefaults.standard.object(forKey: "hdrToneMappingEnabled") as? Bool ?? true
        self.autoScanSubfolders = UserDefaults.standard.object(forKey: "autoScanSubfolders") as? Bool ?? true
        self.keepRecentHistory = UserDefaults.standard.object(forKey: "keepRecentHistory") as? Bool ?? true

        // 3. Audio & Subtitles
        self.maxVolumeLimit = UserDefaults.standard.object(forKey: "maxVolumeLimit") as? Double ?? 150.0
        self.rememberVolume = UserDefaults.standard.object(forKey: "rememberVolume") as? Bool ?? true
        self.savedVolume = UserDefaults.standard.object(forKey: "savedVolume") as? Double ?? 100.0
        self.subAutoMode = UserDefaults.standard.string(forKey: "subAutoMode") ?? "fuzzy"
        self.nightModeDialogueBoost = UserDefaults.standard.bool(forKey: "nightModeDialogueBoost")
        let rawSubPreset = UserDefaults.standard.double(forKey: "subtitleSizePreset")
        let subPreset = SubtitleSizePreset(rawValue: rawSubPreset) ?? .standard
        self.subtitleSizePreset = subPreset
        self.defaultSubtitleScale = subPreset.rawValue
        self.preferredSubtitleLang = UserDefaults.standard.string(forKey: "preferredSubtitleLang") ?? "zh,chi,zho,zh-Hans,zh-Hant,chs,cht"

        // 4. Shortcuts & Gestures
        let rawScroll = UserDefaults.standard.string(forKey: "scrollWheelAction") ?? ScrollWheelAction.volume.rawValue
        self.scrollWheelAction = ScrollWheelAction(rawValue: rawScroll) ?? .volume

        // Load progress history dictionary
        if let dict = UserDefaults.standard.dictionary(forKey: "playbackProgressHistory") as? [String: Double] {
            self.progressHistory = dict
        }

        try? FileManager.default.createDirectory(atPath: self.screenshotDirectory, withIntermediateDirectories: true)
        applyAppearance()
    }

    public func applyAppearance() {
        switch appearanceMode {
        case .system:
            NSApp?.appearance = nil
        case .light:
            NSApp?.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - History Progress Helpers
    private func normalizePath(_ path: String) -> String {
        if path.hasPrefix("file://") {
            return URL(string: path)?.path ?? path
        }
        return path
    }

    public func getSavedPosition(for path: String) -> Double {
        guard resumePlayback else { return 0.0 }
        let norm = normalizePath(path)
        return progressHistory[norm] ?? progressHistory[path] ?? 0.0
    }

    public func savePosition(for path: String, position: Double, duration: Double) {
        guard keepRecentHistory else { return }
        let norm = normalizePath(path)
        // If file is within 5 seconds of end or less than 1 second in, clear progress
        if position < 1.0 || (duration > 0 && position >= duration - 5.0) {
            progressHistory.removeValue(forKey: norm)
            progressHistory.removeValue(forKey: path)
        } else {
            progressHistory[norm] = position
        }
        UserDefaults.standard.set(progressHistory, forKey: "playbackProgressHistory")
    }

    public func clearAllHistory() {
        progressHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: "playbackProgressHistory")
        UserDefaults.standard.removeObject(forKey: "lastPlayedFilePath")
        UserDefaults.standard.removeObject(forKey: "lastPlayedPosition")
        UserDefaults.standard.removeObject(forKey: "lastPlayedDuration")
    }
}
