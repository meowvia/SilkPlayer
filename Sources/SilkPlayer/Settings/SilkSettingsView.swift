import SwiftUI
import AppKit
import SilkCoreKit

/// Native macOS Settings View for SilkPlayer.
/// 560 × 540 pt clean architecture organized into 4 tabs:
/// 1. 通用 (General) - Appearance, Language, Window Mode, Screenshots
/// 2. 播放 (Playback) - Auto-play, Continuous Playback, Dual Playlist, Resume, History, Gestures
/// 3. 局域网 (LAN) - Media Library Switches, Protocol Overview, Local Index Status
/// 4. 关于 (About) - Version Info, Slogan, License Activation & Purchase, Spec Overview, Action Links
public struct SilkSettingsView: View {
    @Bindable var settings = AppSettings.shared
    @Bindable var updateService = UpdateService.shared
    @ObservedObject var licenseEngine = SilkProLicenseEngine.shared
    @ObservedObject var libraryEngine = SilkMediaLibraryEngine.shared
    @ObservedObject var scraperService = SilkMetadataScraperService.shared
    @AppStorage(SilkLibraryTheme.userDefaultsKey) private var selectedThemeRaw: String = SilkLibraryTheme.shenghui.rawValue

    @State private var selectedTab: Int = 0
    @State private var didFinishInitialSizing: Bool = false
    @State private var showHistoryClearedAlert: Bool = false
    @State private var posterCacheBytes: Int64 = 0
    @State private var licenseKeyInput: String = ""
    @State private var showPurchasePendingAlert: Bool = false

    // Unified Settings Layout Constants
    private let sectionOuterSpacing: CGFloat = 12
    private let sectionHeaderSpacing: CGFloat = 5
    private let tabTopPadding: CGFloat = 10
    private let tabBottomPadding: CGFloat = 16
    private let tabHorizontalPadding: CGFloat = 24
    private let uniformPickerWidth: CGFloat = 156

    private var currentTheme: SilkLibraryTheme {
        SilkLibraryTheme(rawValue: selectedThemeRaw) ?? .shenghui
    }

    private var isProThemed: Bool {
        licenseEngine.isProActive
    }

    private var isIceBlue: Bool {
        isProThemed && currentTheme.isIceBlue
    }

    private var isLightPro: Bool {
        isProThemed && currentTheme.isLight
    }

    private var primaryTextColor: Color {
        isProThemed ? currentTheme.primaryText : .primary
    }

    private var secondaryTextColor: Color {
        isProThemed ? currentTheme.secondaryText : .secondary
    }

    private var dividerOpacity: Double {
        isProThemed ? (currentTheme.isLight ? 0.35 : 0.20) : 0.12
    }

    public init() {}

    @ViewBuilder
    private var settingsBackgroundLayer: some View {
        if isLightPro {
            currentTheme.backgroundBase
                .edgesIgnoringSafeArea(.all)
        } else if isIceBlue {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.12, blue: 0.22).opacity(0.48),
                    Color(red: 0.02, green: 0.05, blue: 0.10).opacity(0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            RadialGradient(
                colors: [
                    Color(red: 0.05, green: 0.85, blue: 1.0).opacity(0.14),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 480
            )
            .edgesIgnoringSafeArea(.all)
        } else {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
        }
    }

    private var settingsMainStack: some View {
        VStack(spacing: 0) {
            // Centered macOS Segmented Toolbar Header
            topTabBar
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()
                .opacity(isProThemed ? (currentTheme.isLight ? 0.35 : 0.20) : 0.25)

            // Tab Content Body (Deterministic non-scrolling height, anchored to top)
            tabContent
                .frame(width: 520, alignment: .top)
        }
        .frame(width: 520, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: SettingsContentHeightKey.self, value: geo.size.height)
            }
        )
    }

    private var settingsCoreContainer: some View {
        ZStack(alignment: .top) {
            settingsBackgroundLayer
            settingsMainStack
        }
        .frame(width: 520)
        .frame(maxHeight: .infinity, alignment: .top)
        .onPreferenceChange(SettingsContentHeightKey.self) { height in
            guard height > 100 else { return }
            PlayerWindowManager.shared.updateSettingsWindowHeight(height, animated: didFinishInitialSizing)
            if !didFinishInitialSizing {
                DispatchQueue.main.async {
                    didFinishInitialSizing = true
                }
            }
        }
        .tint(isProThemed ? currentTheme.accentColor : nil)
        .preferredColorScheme(settings.effectiveColorScheme)
        .focusEffectDisabled()
        .silkSuppressSheetFocusRing()
        .background(
            SettingsWindowAppearanceSync(
                appearance: settings.effectiveNSAppearance
            )
        )
        .id(settings.appLanguage)
        .onAppear {
            consumeRequestedTab()
            settings.applyAppearance()
        }
        .onChange(of: settings.requestedSettingsTab) { _, _ in
            consumeRequestedTab()
        }
        .onChange(of: selectedThemeRaw) { _, newThemeRaw in
            if let theme = SilkLibraryTheme(rawValue: newThemeRaw) {
                settings.proLibraryTheme = theme
            }
        }
        .onChange(of: licenseEngine.isProActive) { _, _ in
            settings.applyAppearance()
        }
    }

    public var body: some View {
        settingsCoreContainer
            .alert(L10n.tr("Playback History Cleared", "播放历史已清除"), isPresented: $showHistoryClearedAlert) {
                Button(L10n.tr("OK", "好"), role: .cancel) {}
            } message: {
                Text(L10n.tr("All media playback positions and history have been cleared.", "所有媒体的历史进度与断点记忆已被清除。"))
            }
            .alert(
                L10n.tr(
                    "New version \(updateService.latestVersion ?? "") is available. Update now?",
                    "发现新版本 \(updateService.latestVersion ?? "")，是否立即更新？"
                ),
                isPresented: $updateService.isShowingUpdateAlert
            ) {
                Button(L10n.tr("Yes", "是")) {
                    updateService.userAcceptedUpdate()
                }
                Button(L10n.tr("No", "否"), role: .cancel) {
                    updateService.userDeclinedUpdate()
                }
            }
            .alert(
                L10n.tr("You're up to date", "当前已是最新版本"),
                isPresented: $updateService.isShowingUpToDateAlert
            ) {
                Button(L10n.tr("OK", "好"), role: .cancel) {}
            } message: {
                Text(L10n.tr(
                    "SilkPlayer \(updateService.currentAppVersion) is currently the latest version.",
                    "SilkPlayer \(updateService.currentAppVersion) 当前已是最新版本。"
                ))
            }
            .alert(
                L10n.tr("Purchase Page Pending", "购买页面尚未配置"),
                isPresented: $showPurchasePendingAlert
            ) {
                Button(L10n.tr("OK", "好"), role: .cancel) {}
            } message: {
                Text(L10n.tr(
                    "The purchase link has not been configured yet. If you already have an activation key, enter it above to activate.",
                    "购买跳转链接暂未配置。如您已获取激活码，可直接在上方输入框完成激活。"
                ))
            }
    }

    private func consumeRequestedTab() {
        if let requested = settings.requestedSettingsTab, (0...3).contains(requested) {
            selectedTab = requested
            settings.requestedSettingsTab = nil
        }
    }

    // MARK: - Top Tab Bar (4 Standard Tabs + Red Dot)
    private var topTabBar: some View {
        HStack(spacing: 2) {
            SettingsTabButton(
                title: L10n.tr("General", "通用"),
                icon: "gearshape",
                tag: 0,
                isSelected: selectedTab == 0,
                showRedDot: false,
                isLightPro: isLightPro,
                isIceBlue: isIceBlue,
                isProThemed: isProThemed,
                theme: currentTheme,
                action: { selectedTab = 0 }
            )
            SettingsTabButton(
                title: L10n.playback,
                icon: "play.circle",
                tag: 1,
                isSelected: selectedTab == 1,
                showRedDot: false,
                isLightPro: isLightPro,
                isIceBlue: isIceBlue,
                isProThemed: isProThemed,
                theme: currentTheme,
                action: { selectedTab = 1 }
            )
            SettingsTabButton(
                title: L10n.tr("LAN", "局域网"),
                icon: "network",
                tag: 2,
                isSelected: selectedTab == 2,
                showRedDot: false,
                isLightPro: isLightPro,
                isIceBlue: isIceBlue,
                isProThemed: isProThemed,
                theme: currentTheme,
                action: { selectedTab = 2 }
            )
            SettingsTabButton(
                title: L10n.tr("About", "关于"),
                icon: "info.circle",
                tag: 3,
                isSelected: selectedTab == 3,
                showRedDot: updateService.hasPendingUpdate,
                isLightPro: isLightPro,
                isIceBlue: isIceBlue,
                isProThemed: isProThemed,
                theme: currentTheme,
                action: { selectedTab = 3 }
            )
        }
        .padding(2)
        .frame(width: 352, height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isLightPro ? currentTheme.pillSurface : (isIceBlue ? Color.white.opacity(0.08) : Color.primary.opacity(0.06)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isLightPro
                        ? currentTheme.borderColor
                        : (isIceBlue ? Color.white.opacity(0.20) : Color.clear),
                    lineWidth: 0.65
                )
        )
    }

    // MARK: - Tab Content Switcher
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            generalSection
        case 1:
            playbackSection
        case 2:
            lanSettingsSection
        case 3:
            aboutSection
        default:
            generalSection
        }
    }

    // MARK: - Section Header Title
    private func sectionTitle(_ text: String, showProBadge: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(isProThemed ? currentTheme.secondaryText : .secondary)
            if showProBadge {
                proSuperscriptBadge
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var cardRowDivider: some View {
        Divider()
            .opacity(dividerOpacity)
            .padding(.vertical, 4.5)
    }

    // MARK: - 1. General Tab (通用)
    private var generalSection: some View {
        VStack(spacing: sectionOuterSpacing) {
            // Group 1: 界面外观与个性化
            VStack(spacing: sectionHeaderSpacing) {
                sectionTitle(L10n.tr("Appearance & Theme", "外观与主题"))
                settingsFormCard {
                    if licenseEngine.isProActive {
                        proThemeRow
                    } else {
                        freeAppearanceRow
                        cardRowDivider
                        freeLockedThemeRow
                    }

                    cardRowDivider

                    languageRow
                }
            }

            // Group 2: 视窗与存储管理
            VStack(spacing: sectionHeaderSpacing) {
                sectionTitle(L10n.tr("Window & Storage", "视窗与存储管理"))
                settingsFormCard {
                    settingsToggleRow(
                        title: L10n.tr("Dual Playback Windows", "双播放窗口模式"),
                        subtitle: L10n.tr(
                            "Open a second window when main window is already playing",
                            "主窗口正在播放时，外部视频在第二个独立窗口打开"
                        ),
                        isOn: $settings.dualWindowPlaybackEnabled
                    )

                    cardRowDivider

                    // Screenshots Directory
                    HStack {
                        Text(L10n.tr("Screenshots Directory", "截图保存目录"))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        HStack(spacing: 8) {
                            Text(settings.screenshotDirectory)
                                .font(.system(size: 11))
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 185, alignment: .trailing)

                            lanPillButton(
                                title: L10n.tr("Change…", "更改…"),
                                disabled: false
                            ) {
                                selectFolder()
                            }
                        }
                    }
                    .frame(height: 28)

                    cardRowDivider

                    // Screenshot Format
                    HStack {
                        Text(L10n.tr("Screenshot Format", "截图保存格式"))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Picker("", selection: $settings.screenshotFormat) {
                            Text(L10n.tr("PNG (Lossless)", "PNG (无损原画)")).tag("png")
                            Text(L10n.tr("JPEG (Compact)", "JPEG (紧凑压缩)")).tag("jpeg")
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: uniformPickerWidth)
                    }
                    .frame(height: 28)
                }
            }

            // Group 3: 隐私与诊断
            VStack(spacing: sectionHeaderSpacing) {
                sectionTitle(L10n.tr("Privacy & Diagnostics", "隐私与诊断"))
                settingsFormCard {
                    settingsToggleRow(
                        title: L10n.tr("Anonymous Crash & Diagnostics", "发送匿名崩溃与诊断数据"),
                        subtitle: L10n.tr(
                            "Automatically sends anonymous error and performance diagnostics to improve playback stability.",
                            "自动发送匿名错误与性能数据，用于持续优化播放稳定性与兼容性。"
                        ),
                        isOn: $settings.anonymousUsageAnalyticsEnabled
                    )
                }
            }
        }
        .padding(.horizontal, tabHorizontalPadding)
        .padding(.top, tabTopPadding)
        .padding(.bottom, tabBottomPadding)
    }

    // MARK: - Appearance & Theme Rows (Free vs Pro Separation)
    private var freeAppearanceRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2.5) {
                Text(L10n.tr("Appearance", "外观模式"))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                Text(L10n.tr("System baseline light or dark styling", "系统标准浅色与深色基础外观"))
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Picker("", selection: $settings.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 196)
        }
        .frame(minHeight: 34)
    }

    private var freeLockedThemeRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 5) {
                    Text(L10n.tr("Interface Theme", "界面主题"))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.primary)

                    proThemeBadge(isUnlocked: false)
                }

                Text(L10n.tr("Pro exclusive styling · Unlock in About tab", "Pro 专属定制质感 · 激活解锁暖白等个性化主题"))
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Picker("", selection: .constant(SilkLibraryTheme.shenghui.rawValue)) {
                    ForEach(SilkLibraryTheme.allCases) { th in
                        Text(th.displayName).tag(th.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 156)
                .disabled(true)
            }
            .opacity(0.60)
            .help(L10n.tr("Activate SilkPlayer Pro in About to unlock themes", "请在「设置 → 关于」激活 SilkPlayer Pro 解锁主题功能"))
        }
        .frame(minHeight: 34)
    }

    private var proThemeRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 5) {
                    Text(L10n.tr("Interface Theme", "界面主题"))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(primaryTextColor)

                    proThemeBadge(isUnlocked: true)
                }

                Text(L10n.tr("Synchronizes app appearance, media library, and music mode", "联动全局外观、媒体库与音乐模式配色"))
                    .font(.system(size: 10.5))
                    .foregroundColor(secondaryTextColor)
            }

            Spacer()

            Picker("", selection: $selectedThemeRaw) {
                ForEach(SilkLibraryTheme.allCases) { th in
                    Text(th.displayName).tag(th.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .tint(currentTheme.accentColor)
            .frame(minWidth: 176)
        }
        .frame(minHeight: 34)
    }

    private var languageRow: some View {
        HStack {
            Text(L10n.tr("Language", "界面语言"))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(primaryTextColor)
            Spacer()
            Picker("", selection: $settings.appLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: uniformPickerWidth)
        }
        .frame(height: 28)
    }

    // MARK: - 2. Playback Tab (播放)
    private var playbackSection: some View {
        VStack(spacing: sectionOuterSpacing) {
            // Group 1: 播放与连续性
            VStack(spacing: sectionHeaderSpacing) {
                sectionTitle(L10n.tr("Playback & Continuity", "播放与连续性"))
                settingsFormCard {
                    settingsToggleRow(
                        title: L10n.tr("Auto Play", "自动播放"),
                        subtitle: L10n.tr("Automatically start playback when opening media", "载入视频时自动开始播放"),
                        isOn: $settings.autoPlayOnLoad
                    )

                    cardRowDivider

                    settingsToggleRow(
                        title: L10n.tr("Continuous Playback", "连续播放"),
                        subtitle: L10n.tr("Automatically play next item in playlist", "播放结束时自动连播下一集"),
                        isOn: $settings.autoPlayNextItem
                    )

                    cardRowDivider

                    settingsToggleRow(
                        title: L10n.tr("Dual Playlist Mode", "双列表模式"),
                        subtitle: L10n.tr("Separates video and music queues in drawer", "在侧边抽屉中分列管理视频与音乐"),
                        isOn: $settings.dualPlaylistMode
                    )

                    cardRowDivider

                    settingsToggleRow(
                        title: L10n.tr("Resume Playback", "记住播放进度"),
                        subtitle: L10n.tr("Resume playback from last saved position", "再次打开同一视频从上次断点恢复"),
                        isOn: $settings.resumePlayback
                    )

                    cardRowDivider

                    // Playback History
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text(L10n.tr("Playback History", "媒体播放历史"))
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(primaryTextColor)
                            Text(L10n.tr("Remembers progress and breakpoint memories", "记住播放历史记录与断点数据"))
                                .font(.system(size: 10.5))
                                .foregroundColor(secondaryTextColor)
                        }
                        Spacer(minLength: 8)
                        HStack(spacing: 8) {
                            Toggle("", isOn: $settings.keepRecentHistory)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)

                            lanPillButton(
                                title: L10n.tr("Clear…", "清除…"),
                                isDestructive: true,
                                disabled: false
                            ) {
                                settings.clearAllHistory()
                                showHistoryClearedAlert = true
                            }
                        }
                    }
                    .frame(minHeight: 34)
                }
            }

            // Group 2: 操控交互与全屏显示
            VStack(spacing: sectionHeaderSpacing) {
                sectionTitle(L10n.tr("Controls & On-Screen Display", "操控交互与全屏显示"))
                settingsFormCard {
                    settingsToggleRow(
                        title: L10n.tr("Show Clock in Fullscreen", "全屏右上角显示时钟"),
                        subtitle: L10n.tr("Displays system clock HUD during fullscreen playback", "全屏播放时在右上角常驻显示系统时钟"),
                        isOn: $settings.showLocalTimeInFullscreen
                    )

                    cardRowDivider

                    // Seek Step Duration
                    HStack {
                        Text(L10n.tr("Seek Step Duration", "进度快进步长"))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Picker("", selection: $settings.shortSeekStep) {
                            Text("5 " + L10n.tr("Seconds", "秒")).tag(5.0)
                            Text("10 " + L10n.tr("Seconds", "秒")).tag(10.0)
                            Text("15 " + L10n.tr("Seconds", "秒")).tag(15.0)
                            Text("30 " + L10n.tr("Seconds", "秒")).tag(30.0)
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: uniformPickerWidth)
                    }
                    .frame(height: 28)

                    cardRowDivider

                    // Scroll Wheel Action
                    HStack {
                        Text(L10n.tr("Scroll Wheel Action", "滚轮滚动操作"))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Picker("", selection: $settings.scrollWheelAction) {
                            ForEach(ScrollWheelAction.allCases) { action in
                                Text(action.displayName).tag(action)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: uniformPickerWidth)
                    }
                    .frame(height: 28)

                    cardRowDivider

                    // Double Click Action
                    HStack {
                        Text(L10n.tr("Double-Click Action", "双击画面操作"))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(primaryTextColor)
                        Spacer()
                        Picker("", selection: $settings.doubleClickAction) {
                            ForEach(DoubleClickAction.allCases) { action in
                                Text(action.displayName).tag(action)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: uniformPickerWidth)
                    }
                    .frame(height: 28)
                }
            }
        }
        .padding(.horizontal, tabHorizontalPadding)
        .padding(.top, tabTopPadding)
        .padding(.bottom, tabBottomPadding)
    }

    // MARK: - 3. LAN Tab (局域网)
    private var missingPosterRecords: [SilkMediaLibraryRecord] {
        libraryEngine.items.filter { record in
            record.kind != .audio && !record.hasValidLocalPoster
        }
    }

    private var formattedPosterCacheSize: String {
        if posterCacheBytes <= 0 {
            return "0 KB"
        }
        return ByteCountFormatter.string(fromByteCount: posterCacheBytes, countStyle: .file)
    }

    nonisolated private static func computePosterCacheBytes() -> Int64 {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return 0
        }
        let posterDir = caches.appendingPathComponent("SilkPlayer/Posters", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: posterDir,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for fileURL in files {
            if let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               vals.isRegularFile == true,
               let sz = vals.fileSize {
                total += Int64(sz)
            }
        }
        return total
    }

    private func refreshPosterCacheSize() {
        Task.detached(priority: .utility) {
            let computed = Self.computePosterCacheBytes()
            await MainActor.run {
                self.posterCacheBytes = computed
            }
        }
    }

    private func clearLocalPosterCache() {
        Task { @MainActor in
            await SilkMediaLibraryEngine.shared.clearPosterCache()
            self.posterCacheBytes = 0
        }
    }

    private var lanSettingsSection: some View {
        VStack(spacing: sectionOuterSpacing) {
            // Group 1: LAN Media Library Switches
            VStack(spacing: sectionHeaderSpacing) {
                sectionTitle(L10n.tr("LAN Media Library", "局域网媒体库"), showProBadge: !licenseEngine.isProActive)
                settingsFormCard {
                    Group {
                        settingsToggleRow(
                            title: L10n.tr("Enable LAN Media Library", "启用局域网媒体库"),
                            subtitle: L10n.tr(
                                "Turn off to use the standard playback view. Sources and history are preserved.",
                                "关闭后切回标准播放视图，已添加的目录源与播放记录保留。"
                            ),
                            isOn: $settings.proLibraryHomeEnabled
                        )

                        cardRowDivider

                        settingsToggleRow(
                            title: L10n.tr("Auto-Scan Sources on Launch", "启动时自动更新媒体源"),
                            subtitle: L10n.tr(
                                "Incrementally scan enabled media folders in the background at startup.",
                                "应用启动后自动在后台增量扫描目录变更。"
                            ),
                            isOn: $settings.proAutoScanOnLaunch
                        )

                        cardRowDivider

                        settingsToggleRow(
                            title: L10n.tr("Auto-Match Missing Posters", "扫描后自动匹配缺失海报"),
                            subtitle: L10n.tr(
                                "Automatically fetch missing posters and metadata online after scanning.",
                                "目录扫描完成后自动联网补全缺失的影视海报与简介。"
                            ),
                            isOn: $settings.proAutoScrapeAfterScan
                        )

                        cardRowDivider

                        settingsToggleRow(
                            title: L10n.tr("iCloud Playback Sync", "iCloud 跨设备播放同步"),
                            subtitle: L10n.tr(
                                "Sync playback progress across Macs signed into the same Apple Account.",
                                "通过个人 iCloud 云盘在同账号 Mac 间同步播放进度。"
                            ),
                            isOn: $settings.enableCloudPlaybackSync
                        )
                    }
                    .disabled(!licenseEngine.isProActive)
                    .opacity(licenseEngine.isProActive ? 1.0 : 0.72)
                }
            }

            // Group 2: Index & Metadata
            VStack(spacing: sectionHeaderSpacing) {
                sectionTitle(L10n.tr("Index & Metadata", "索引与元数据"), showProBadge: !licenseEngine.isProActive)
                settingsFormCard {
                    // Row 1: Media Library Index
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text(L10n.tr("Media Library Index", "媒体库索引"))
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(primaryTextColor)

                            Text(libraryEngine.isScanning
                                 ? L10n.tr("Scanning \(libraryEngine.scanningSourceName ?? "")...", "正在扫描 \(libraryEngine.scanningSourceName ?? "")…")
                                 : L10n.tr(
                                     "\(libraryEngine.sources.count) sources · \(libraryEngine.items.count) items indexed",
                                     "已接入 \(libraryEngine.sources.count) 个目录源 · 共 \(libraryEngine.items.count) 条记录"
                                 ))
                                .font(.system(size: 10.5))
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        lanPillButton(
                            title: libraryEngine.isScanning
                                ? L10n.tr("Scanning…", "扫描中…")
                                : L10n.tr("Scan Now", "立即扫描"),
                            disabled: libraryEngine.sources.isEmpty || libraryEngine.isScanning || !licenseEngine.isProActive
                        ) {
                            Task {
                                await libraryEngine.rescanAll()
                                refreshPosterCacheSize()
                            }
                        }
                    }
                    .frame(minHeight: 34)

                    cardRowDivider

                    // Row 2: Small Video Sample Filter
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text(L10n.tr("Small Video Filter", "小体积视频过滤"))
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(primaryTextColor)

                            Text(L10n.tr(
                                "Skip trailer and sample clips below threshold",
                                "扫描时自动跳过小于指定体积的预告片或样本"
                            ))
                            .font(.system(size: 10.5))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Picker("", selection: $settings.proMinVideoFileSizeMB) {
                            Text(L10n.tr("Off", "不过滤")).tag(0)
                            Text(L10n.tr("Under 50 MB", "小于 50 MB")).tag(50)
                            Text(L10n.tr("Under 100 MB", "小于 100 MB")).tag(100)
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 124)
                    }
                    .frame(minHeight: 34)

                    cardRowDivider

                    // Row 3: Poster Scraping & Cache
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text(L10n.tr("Poster & Metadata Cache", "海报刮削与缓存"))
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(primaryTextColor)

                            Text(scraperService.isScraping
                                 ? L10n.tr(
                                     "Matching metadata (\(scraperService.scrapedCount)/\(max(1, scraperService.totalCount)))...",
                                     "正在匹配海报元数据 (\(scraperService.scrapedCount)/\(max(1, scraperService.totalCount)))…"
                                 )
                                 : L10n.tr(
                                     "Cache \(formattedPosterCacheSize) · \(missingPosterRecords.count) unscraped",
                                     "缓存占用 \(formattedPosterCacheSize) · 待补全 \(missingPosterRecords.count) 项"
                                 ))
                                .font(.system(size: 10.5))
                                .foregroundColor(secondaryTextColor)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 6) {
                            lanPillButton(
                                title: scraperService.isScraping
                                    ? L10n.tr("Matching…", "刮削中…")
                                    : L10n.tr("Match Missing", "补全刮削"),
                                disabled: missingPosterRecords.isEmpty || scraperService.isScraping || !licenseEngine.isProActive
                            ) {
                                let targets = missingPosterRecords
                                Task {
                                    await scraperService.scrapeBatch(records: targets, forceAll: false)
                                    refreshPosterCacheSize()
                                }
                            }

                            lanPillButton(
                                title: L10n.tr("Clear Cache", "清理缓存"),
                                disabled: posterCacheBytes <= 0 || scraperService.isScraping || !licenseEngine.isProActive
                            ) {
                                clearLocalPosterCache()
                            }
                        }
                    }
                    .frame(minHeight: 34)
                }
            }
            .disabled(!licenseEngine.isProActive)
            .opacity(licenseEngine.isProActive ? 1.0 : 0.72)
        }
        .padding(.horizontal, tabHorizontalPadding)
        .padding(.top, tabTopPadding)
        .padding(.bottom, tabBottomPadding)
        .onAppear {
            refreshPosterCacheSize()
        }
        .onChange(of: scraperService.isScraping) { _, scraping in
            if !scraping {
                refreshPosterCacheSize()
            }
        }
    }

    private func settingsToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2.5) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(primaryTextColor)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(minHeight: 34)
    }

    private func lanPillButton(
        title: String,
        isDestructive: Bool = false,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let fgColor: Color = {
            if isDestructive {
                return Color.red.opacity(isLightPro ? 0.85 : 0.90)
            }
            return isProThemed ? currentTheme.primaryText : .primary
        }()
        return Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(fgColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isProThemed ? currentTheme.pillSurface : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(isProThemed ? currentTheme.borderColor : Color(nsColor: .separatorColor), lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .focusEffectDisabled()
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1.0)
    }

    private func triggerActivation() {
        let key = licenseKeyInput
        Task {
            let result = await licenseEngine.activate(licenseKey: key)
            if case .success = result {
                licenseKeyInput = ""
                SilkProIconManager.syncApplicationIcon(isProActive: true)
            }
        }
    }

    // MARK: - 4. About Tab (关于)
    private var appVersionLabel: String {
        let full = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
        return full.replacingOccurrences(of: "-pro", with: "").replacingOccurrences(of: "-dev", with: "")
    }

    private var proSuperscriptBadge: some View {
        Text("PRO")
            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.88, blue: 0.65),
                        Color(red: 0.95, green: 0.65, blue: 0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(Color(red: 0.22, green: 0.16, blue: 0.12).opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.65, blue: 0.25).opacity(0.8),
                                Color(red: 0.65, green: 0.35, blue: 0.15).opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: Color(red: 0.85, green: 0.45, blue: 0.15).opacity(0.25), radius: 2.5, x: 0, y: 1)
            .fixedSize()
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 10)

            // Header: App Icon + Title with Pro Badge + Slogan
            VStack(spacing: 6) {
                if let appIcon = SilkProIconManager.currentDisplayIcon(isProActive: licenseEngine.isProActive) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(licenseEngine.isProActive ? Color(red: 0.85, green: 0.55, blue: 0.25).opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                        )
                }

                HStack(alignment: .top, spacing: 5) {
                    if licenseEngine.isProActive {
                        // Invisible symmetrical placeholder to guarantee SilkPlayer stays 100% centered with Logo
                        proSuperscriptBadge
                            .hidden()
                    }

                    Text("SilkPlayer")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.primary)

                    if licenseEngine.isProActive {
                        proSuperscriptBadge
                            .offset(y: -4)
                    }
                }

                Text(L10n.tr(
                    "Native · Minimal · Ultra-light · Effortless",
                    "原生 · 极简 · 极轻 · 易用"
                ))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.secondary.opacity(0.9))
            }

            Spacer().frame(height: 10)

            // License Activation & Purchase
            settingsFormCard {
                if licenseEngine.isProActive {
                    VStack(spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Color.green)

                            Text(L10n.tr("Pro · Activated", "Pro · 已激活"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(primaryTextColor)
                        }

                        Text(L10n.tr("Version \(appVersionLabel)", "版本 \(appVersionLabel)"))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "key.horizontal")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(isProThemed ? currentTheme.accentColor : Color.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Activate Pro Features", "激活 Pro 功能"))
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(primaryTextColor)

                                Text(L10n.tr("Version \(appVersionLabel)", "版本 \(appVersionLabel)"))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(secondaryTextColor)

                                Text(L10n.tr(
                                    "Enter an activation key for SMB 2/3, NFS, and LAN media library.",
                                    "激活后可使用 SMB 2/3、NFS 共享挂载与局域网媒体库。"
                                ))
                                .font(.system(size: 10.5))
                                .foregroundColor(secondaryTextColor)

                                if let cached = UserDefaults.standard.string(forKey: "silk.pro.lastActiveReceipt"), !cached.isEmpty {
                                    Button {
                                        Task {
                                            _ = await licenseEngine.activate(licenseKey: cached)
                                            SilkProIconManager.syncApplicationIcon(isProActive: true)
                                        }
                                    } label: {
                                        Text(L10n.tr("Restore Pro Activation", "恢复 Pro 授权"))
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.link)
                                    .padding(.top, 2)
                                }
                            }

                            Spacer()
                        }

                        HStack(spacing: 8) {
                            TextField(
                                L10n.tr("Enter activation key...", "输入激活码…"),
                                text: $licenseKeyInput
                            )
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .onSubmit {
                                triggerActivation()
                            }

                            Button {
                                triggerActivation()
                            } label: {
                                if licenseEngine.isProcessing {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 44)
                                } else {
                                    Text(L10n.tr("Activate", "激活"))
                                        .font(.system(size: 12, weight: .medium))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4.5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || licenseEngine.isProcessing ? (isProThemed ? currentTheme.accentColor.opacity(0.35) : Color.accentColor.opacity(0.35)) : (isProThemed ? currentTheme.accentColor : Color.accentColor))
                            )
                            .buttonStyle(.plain)
                            .disabled(licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || licenseEngine.isProcessing)

                            Button {
                                if let url = licenseEngine.purchaseURL {
                                    NSWorkspace.shared.open(url)
                                } else if let websiteURL = URL(string: "https://silkplayer.com") {
                                    NSWorkspace.shared.open(websiteURL)
                                } else {
                                    showPurchasePendingAlert = true
                                }
                            } label: {
                                Text(L10n.tr("Buy", "购买"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(primaryTextColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(isProThemed ? currentTheme.pillSurface : Color.secondary.opacity(0.12))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(isProThemed ? currentTheme.borderColor : Color.secondary.opacity(0.24), lineWidth: 0.75)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        if let err = licenseEngine.lastErrorMessage, !err.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Text(err)
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.orange)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 10)

            // Core Specs Inset Card
            settingsFormCard {
                aboutInfoRow(
                    icon: "sparkles.tv",
                    title: L10n.tr("Rendering Pipeline", "渲染管线"),
                    value: "Apple Silicon Metal Direct (Zero-Copy)"
                )
                cardRowDivider
                aboutInfoRow(
                    icon: "cpu",
                    title: L10n.tr("Decode Core", "解码核心"),
                    value: "SilkCoreKit · VideoToolbox HW · FFmpeg (LGPL)"
                )
                cardRowDivider
                aboutInfoRow(
                    icon: "checkmark.seal",
                    title: L10n.tr("Application Shell", "应用框架"),
                    value: "GNU LGPL v3.0"
                )
                cardRowDivider
                aboutInfoRow(
                    icon: "lock.shield",
                    title: L10n.tr("Core Engine", "核心引擎"),
                    value: "SilkCoreKit Proprietary"
                )
            }
            .padding(.horizontal, tabHorizontalPadding)

            Spacer().frame(height: 14)

            // Action Links & Updates
            HStack(spacing: 12) {
                Button {
                    updateService.checkManually()
                } label: {
                    HStack(spacing: 5) {
                        if updateService.isChecking {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11.5))
                        }
                        Text(L10n.tr("Check for Updates", "检查更新"))
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isProThemed ? currentTheme.pillSurface : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isProThemed ? currentTheme.borderColor : Color(nsColor: .separatorColor), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()

                Button {
                    if let url = URL(string: "https://silkplayer.com") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                            .font(.system(size: 11.5))
                        Text(L10n.tr("Project Website", "产品官网"))
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isProThemed ? currentTheme.pillSurface : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isProThemed ? currentTheme.borderColor : Color(nsColor: .separatorColor), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()

                Button {
                    openLicensesNotice()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11.5))
                        Text(L10n.tr("Licenses & Notices", "开源与第三方许可"))
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isProThemed ? currentTheme.pillSurface : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(isProThemed ? currentTheme.borderColor : Color(nsColor: .separatorColor), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
            }

            Spacer().frame(height: 8)

            Text("Copyright © 2026 SilkPlayer. All rights reserved.")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, tabBottomPadding)
        }
        .frame(maxWidth: .infinity)
    }

    private func openLicensesNotice() {
        if let bundlePath = Bundle.main.resourcePath {
            let licensesPath = (bundlePath as NSString).appendingPathComponent("Licenses/THIRD_PARTY_LICENSES.txt")
            let fileURL = URL(fileURLWithPath: licensesPath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                NSWorkspace.shared.open(fileURL)
                return
            }
        }
        if let url = URL(string: "https://github.com/meowvia/SilkPlayer/blob/main/Documentation/THIRD_PARTY.md") {
            NSWorkspace.shared.open(url)
        }
    }

    private func aboutInfoRow(icon: String, title: String, value: String, url: URL? = nil) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(secondaryTextColor)
            }
            .frame(width: 148, alignment: .leading)

            if let url {
                Link(value, destination: url)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isProThemed ? currentTheme.accentColor : .accentColor)
            } else {
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(primaryTextColor.opacity(0.9))
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .frame(height: 24)
    }

    // MARK: - Reusable Card Form Component
    private func settingsFormCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                if isLightPro {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(currentTheme.cardSurface)
                } else if isIceBlue {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.65)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color(red: 0.06, green: 0.14, blue: 0.24).opacity(0.38)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isIceBlue
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.50),
                                    Color(red: 0.05, green: 0.85, blue: 1.0).opacity(0.28),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : (isLightPro ? AnyShapeStyle(currentTheme.borderColor) : AnyShapeStyle(Color.primary.opacity(0.07))),
                    lineWidth: isIceBlue ? 0.95 : (isLightPro ? 0.75 : 0.5)
                )
        )
    }

    private func proThemeBadge(isUnlocked: Bool) -> some View {
        HStack(spacing: 3) {
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 7.5))
            }
            Text("PRO")
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.88, blue: 0.65),
                    Color(red: 0.90, green: 0.68, blue: 0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(red: 0.35, green: 0.25, blue: 0.12).opacity(isUnlocked ? 0.35 : 0.60))
        )
        .overlay(
            Capsule()
                .stroke(Color(red: 0.90, green: 0.68, blue: 0.38).opacity(isUnlocked ? 0.45 : 0.70), lineWidth: 0.6)
        )
        .help(isUnlocked
            ? L10n.tr("SilkPlayer Pro active: Slate & Warm White unlocked", "SilkPlayer Pro 已激活：深灰与暖白专属主题已解锁")
            : L10n.tr("Upgrade to SilkPlayer Pro in About to unlock custom themes", "激活 SilkPlayer Pro 即可解锁深灰与暖白专属主题"))
    }

    private func selectFolder() {
        NSCursor.unhide()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.appearance = settings.effectiveNSAppearance
        panel.prompt = L10n.tr("Select", "选择")
        if panel.runModal() == .OK, let url = panel.url {
            settings.screenshotDirectory = url.path
        }
        NSCursor.unhide()
    }
}

// MARK: - Settings Window Dynamic Appearance Synchronizer
private struct SettingsWindowAppearanceSync: NSViewRepresentable {
    let appearance: NSAppearance?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            apply(view: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            apply(view: nsView)
        }
    }

    private func apply(view: NSView) {
        if view.window?.appearance != appearance {
            view.window?.appearance = appearance
        }
        if view.window?.contentView?.appearance != appearance {
            view.window?.contentView?.appearance = appearance
        }
    }
}

private struct SettingsContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Fully Responsive Compact Settings Tab Button
private struct SettingsTabButton: View {
    let title: String
    let icon: String
    let tag: Int
    let isSelected: Bool
    let showRedDot: Bool
    let isLightPro: Bool
    let isIceBlue: Bool
    let isProThemed: Bool
    let theme: SilkLibraryTheme
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5.5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))

                    if showRedDot {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .stroke(isProThemed ? theme.cardSurface : Color(nsColor: .windowBackgroundColor), lineWidth: 1.2)
                            )
                            .offset(x: 4, y: -2)
                    }
                }

                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
            }
            .foregroundColor(isSelected
                ? (isProThemed ? theme.accentColor : .primary)
                : (isProThemed ? theme.secondaryText : .secondary))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Group {
                    if isSelected {
                        if isIceBlue {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(0.28), lineWidth: 0.75)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isLightPro ? theme.cardSurface : Color(nsColor: .controlBackgroundColor))
                                .shadow(color: Color.black.opacity(isLightPro ? 0.05 : 0.12), radius: 2, x: 0, y: 1)
                        }
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .frame(height: 30)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
