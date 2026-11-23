import Observation
import SwiftUI
import Combine
import AppKit
import SilkCoreKit

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

    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
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
        case .multipleWindows: return L10n.tr("Dual Windows", "双窗口")
        }
    }
    public var description: String {
        switch self {
        case .singleWindow: return L10n.tr("Always play in a single unified window", "始终使用单一播放窗口")
        case .multipleWindows: return L10n.tr("Open a second window when main player is already playing", "主窗口正在播放时，允许打开第二个独立播放窗口")
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

    /// Pro edition theme selection. Backed by `SilkLibraryTheme.userDefaultsKey`.
    public var proLibraryTheme: SilkLibraryTheme {
        didSet {
            UserDefaults.standard.set(proLibraryTheme.rawValue, forKey: SilkLibraryTheme.userDefaultsKey)
            applyAppearance()
        }
    }

    /// Unified effective color scheme:
    /// In Pro edition, directly driven by `proLibraryTheme` (nuanbai -> .light, shenghui -> .dark).
    /// In Free edition, governed by native macOS `appearanceMode`.
    public var effectiveColorScheme: ColorScheme? {
        if SilkProLicenseEngine.shared.isProActive {
            return proLibraryTheme.isLight ? .light : .dark
        }
        return appearanceMode.colorScheme
    }

    /// Unified effective NSAppearance:
    /// In Pro edition, directly driven by `proLibraryTheme` (nuanbai -> aqua, shenghui -> darkAqua).
    /// In Free edition, governed by native macOS `appearanceMode`.
    public var effectiveNSAppearance: NSAppearance? {
        if SilkProLicenseEngine.shared.isProActive {
            return proLibraryTheme.isLight ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
        }
        return appearanceMode.nsAppearance
    }
    public var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
            L10n.invalidateLanguageCache()
            NotificationCenter.default.post(name: .silkLanguageDidChange, object: nil)
        }
    }
    /// Anonymous launch measurement used to compare first-seen and returning installations.
    /// Enabled by default; users can disable it in General settings.
    public var anonymousUsageAnalyticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(anonymousUsageAnalyticsEnabled, forKey: "anonymousUsageAnalyticsEnabled")
            Task { @MainActor in
                await SilkUsageAnalytics.shared.setEnabled(anonymousUsageAnalyticsEnabled)
            }
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
    public var showLocalTimeInFullscreen: Bool {
        didSet {
            UserDefaults.standard.set(showLocalTimeInFullscreen, forKey: "showLocalTimeInFullscreen")
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

    // Window management strategy (Single-window vs Dual-window capped at 2)
    public var windowMode: WindowMode {
        get { singleWindowMode ? .singleWindow : .multipleWindows }
        set { singleWindowMode = (newValue == .singleWindow) }
    }
    public var dualWindowPlaybackEnabled: Bool {
        get { !singleWindowMode }
        set { singleWindowMode = !newValue }
    }
    public var singleWindowMode: Bool {
        didSet {
            UserDefaults.standard.set(singleWindowMode, forKey: "singleWindowMode")
            PlayerWindowManager.shared.syncCommandState()
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
    public var autoSkipIntro: Bool {
        didSet {
            UserDefaults.standard.set(autoSkipIntro, forKey: "autoSkipIntro")
        }
    }
    public var dualPlaylistMode: Bool {
        didSet {
            UserDefaults.standard.set(dualPlaylistMode, forKey: "dualPlaylistMode")
            let sessionPlaylists = PlayerWindowManager.shared.sessions.compactMap(\.playlist)
            if sessionPlaylists.isEmpty {
                PlaylistManager.shared.applyDualPlaylistMode(dualPlaylistMode)
            } else {
                for playlist in sessionPlaylists {
                    playlist.applyDualPlaylistMode(dualPlaylistMode)
                }
            }
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

    public var isMusicQueueCollapsed: Bool = UserDefaults.standard.bool(forKey: "musicModeQueueCollapsed") {
        didSet {
            guard isMusicQueueCollapsed != oldValue else { return }
            UserDefaults.standard.set(isMusicQueueCollapsed, forKey: "musicModeQueueCollapsed")
        }
    }

    @ObservationIgnored private var lastPersistedProgressTime: CFAbsoluteTime = 0
    @ObservationIgnored private var lastPersistedProgressPath: String = ""
    @ObservationIgnored private var lastPersistedProgressPosition: Double = -1
    @ObservationIgnored private var lastPersistedProgressPlaying: Bool = false

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

    // MARK: - 5. Pro & Unified Library (Pro 与片库)
    /// Enables replacing the idle startup dropzone with the unified Pro Media Library.
    public var proLibraryHomeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(proLibraryHomeEnabled, forKey: "proLibraryHomeEnabled")
        }
    }
    /// Automatically suppresses the legacy right-side playlist drawer while Pro Library Mode is active.
    public var proHideLegacyPlaylistDrawer: Bool {
        didSet {
            UserDefaults.standard.set(proHideLegacyPlaylistDrawer, forKey: "proHideLegacyPlaylistDrawer")
        }
    }
    /// Separates audio extensions cleanly into the dedicated Audio / Album Library tab.
    public var proDedicatedAudioLibrary: Bool {
        didSet {
            UserDefaults.standard.set(proDedicatedAudioLibrary, forKey: "proDedicatedAudioLibrary")
        }
    }
    /// Runs Stat-Only incremental indexing on auto-scan sources on startup when Pro is active.
    public var proAutoScanOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(proAutoScanOnLaunch, forKey: "proAutoScanOnLaunch")
        }
    }
    /// Automatically fetches missing posters and metadata online after directory scans complete.
    public var proAutoScrapeAfterScan: Bool {
        didSet {
            UserDefaults.standard.set(proAutoScrapeAfterScan, forKey: "proAutoScrapeAfterScan")
        }
    }
    /// Skips video files smaller than this threshold (in MB) during directory scans; 0 means no size filtering.
    public var proMinVideoFileSizeMB: Int {
        didSet {
            UserDefaults.standard.set(proMinVideoFileSizeMB, forKey: "proMinVideoFileSizeMB")
            if proMinVideoFileSizeMB != oldValue,
               SilkProLicenseEngine.shared.isProActive,
               !SilkMediaLibraryEngine.shared.sources.isEmpty {
                SilkMediaLibraryEngine.shared.enqueueBackgroundRescan(
                    sourceIds: SilkMediaLibraryEngine.shared.sources.map(\.id)
                )
            }
        }
    }
    /// Synchronizes playback progress and watch state across Macs via personal iCloud Drive container.
    public var enableCloudPlaybackSync: Bool {
        didSet {
            UserDefaults.standard.set(enableCloudPlaybackSync, forKey: "enableCloudPlaybackSync")
        }
    }
    /// Transient navigation signal allowing Pro UI actions to open a specific Settings tab.
    @ObservationIgnored public var requestedSettingsTab: Int? = nil

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
        self.anonymousUsageAnalyticsEnabled = UserDefaults.standard.object(forKey: "anonymousUsageAnalyticsEnabled") as? Bool ?? true
        self.keepWindowOnTop = UserDefaults.standard.bool(forKey: "keepWindowOnTop")
        self.autoResizeWindow = UserDefaults.standard.object(forKey: "autoResizeWindow") as? Bool ?? true
        self.showLocalTimeInFullscreen = UserDefaults.standard.object(forKey: "showLocalTimeInFullscreen") as? Bool ?? true
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
        self.autoSkipIntro = UserDefaults.standard.object(forKey: "autoSkipIntro") as? Bool ?? true
        self.dualPlaylistMode = UserDefaults.standard.object(forKey: "dualPlaylistMode") as? Bool ?? true
        self.shortSeekStep = UserDefaults.standard.object(forKey: "shortSeekStep") as? Double ?? 5.0
        self.longSeekStep = UserDefaults.standard.object(forKey: "longSeekStep") as? Double ?? 30.0
        self.autoEnhanceQuality = UserDefaults.standard.object(forKey: "autoEnhanceQuality") as? Bool ?? false
        self.hdrToneMappingEnabled = UserDefaults.standard.object(forKey: "hdrToneMappingEnabled") as? Bool ?? true
        self.autoScanSubfolders = UserDefaults.standard.object(forKey: "autoScanSubfolders") as? Bool ?? true
        self.keepRecentHistory = UserDefaults.standard.object(forKey: "keepRecentHistory") as? Bool ?? true

        // 3. Audio & Subtitles
        let storedMaxVol = UserDefaults.standard.object(forKey: "maxVolumeLimit") as? Double ?? 200.0
        self.maxVolumeLimit = (storedMaxVol <= 150.0 && storedMaxVol > 0.0) ? 200.0 : storedMaxVol
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

        // 5. Pro & Unified Library
        self.proLibraryHomeEnabled = UserDefaults.standard.object(forKey: "proLibraryHomeEnabled") as? Bool ?? true
        self.proHideLegacyPlaylistDrawer = UserDefaults.standard.object(forKey: "proHideLegacyPlaylistDrawer") as? Bool ?? false
        self.proDedicatedAudioLibrary = UserDefaults.standard.object(forKey: "proDedicatedAudioLibrary") as? Bool ?? true
        self.proAutoScanOnLaunch = UserDefaults.standard.object(forKey: "proAutoScanOnLaunch") as? Bool ?? true
        self.proAutoScrapeAfterScan = UserDefaults.standard.object(forKey: "proAutoScrapeAfterScan") as? Bool ?? true
        self.proMinVideoFileSizeMB = UserDefaults.standard.object(forKey: "proMinVideoFileSizeMB") as? Int ?? 0
        self.enableCloudPlaybackSync = UserDefaults.standard.object(forKey: "enableCloudPlaybackSync") as? Bool ?? true
        let rawTheme = UserDefaults.standard.string(forKey: SilkLibraryTheme.userDefaultsKey) ?? SilkLibraryTheme.shenghui.rawValue
        self.proLibraryTheme = SilkLibraryTheme(rawValue: rawTheme) ?? .shenghui

        // Load progress history dictionary
        if let dict = UserDefaults.standard.dictionary(forKey: "playbackProgressHistory") as? [String: Double] {
            self.progressHistory = dict
        }

        try? FileManager.default.createDirectory(atPath: self.screenshotDirectory, withIntermediateDirectories: true)
        applyAppearance()
    }

    public func applyAppearance() {
        let appearance = effectiveNSAppearance
        NSApp?.appearance = appearance
        if let settingsWin = PlayerWindowManager.shared.settingsWindow {
            settingsWin.appearance = appearance
        }
        for session in PlayerWindowManager.shared.sessions {
            if let win = session.window {
                if session.player?.isPlaying != true || session.player?.isAudioOnly == true {
                    win.appearance = appearance
                }
            }
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
        lastPersistedProgressTime = CFAbsoluteTimeGetCurrent()
        lastPersistedProgressPath = path
        lastPersistedProgressPosition = position

        if SilkProLicenseEngine.shared.isProActive, !norm.isEmpty {
            let capturedDuration = duration
            let capturedPos = position
            Task { @MainActor in
                await SilkMediaLibraryEngine.shared.recordPlaybackProgress(
                    path: norm,
                    position: capturedPos,
                    duration: capturedDuration
                )
            }
        }
    }

    /// Persists continuous playback progress at a throttled cadence (~3s) while flushing immediately on track changes, seeks, pause, or explicit force.
    public func recordPlaybackProgress(path: String, current: Double, duration: Double, isPlaying: Bool, force: Bool = false) {
        guard keepRecentHistory, !path.isEmpty else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let pathChanged = (path != lastPersistedProgressPath)
        let pausedFromPlaying = (!isPlaying && lastPersistedProgressPlaying)
        let seekJumped = (lastPersistedProgressPosition >= 0 && abs(current - lastPersistedProgressPosition) >= 4.0 && (now - lastPersistedProgressTime) >= 0.5)
        let intervalElapsed = ((now - lastPersistedProgressTime) >= 3.0) && (abs(current - lastPersistedProgressPosition) >= 0.25 || pathChanged || isPlaying != lastPersistedProgressPlaying)

        guard force || pathChanged || pausedFromPlaying || seekJumped || intervalElapsed else {
            return
        }

        if pathChanged || force {
            UserDefaults.standard.set(path, forKey: "lastPlayedFilePath")
        }
        UserDefaults.standard.set(current, forKey: "lastPlayedPosition")
        UserDefaults.standard.set(duration, forKey: "lastPlayedDuration")
        savePosition(for: path, position: current, duration: duration)
        lastPersistedProgressTime = now
        lastPersistedProgressPath = path
        lastPersistedProgressPosition = current
        lastPersistedProgressPlaying = isPlaying
    }

    public func clearAllHistory() {
        progressHistory.removeAll()
        lastPersistedProgressTime = 0
        lastPersistedProgressPath = ""
        lastPersistedProgressPosition = -1
        lastPersistedProgressPlaying = false
        UserDefaults.standard.removeObject(forKey: "playbackProgressHistory")
        UserDefaults.standard.removeObject(forKey: "lastPlayedFilePath")
        UserDefaults.standard.removeObject(forKey: "lastPlayedPosition")
        UserDefaults.standard.removeObject(forKey: "lastPlayedDuration")
        if SilkProLicenseEngine.shared.isProActive {
            Task { @MainActor in
                await SilkMediaLibraryEngine.shared.clearAllWatchMemory()
            }
        }
    }
}
