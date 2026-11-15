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
    @AppStorage(SilkLibraryTheme.userDefaultsKey) private var selectedThemeRaw: String = SilkLibraryTheme.shenghui.rawValue

    @State private var selectedTab: Int = 0
    @State private var showHistoryClearedAlert: Bool = false
    @State private var licenseKeyInput: String = ""
    @State private var showPurchasePendingAlert: Bool = false

    private var currentTheme: SilkLibraryTheme {
        SilkLibraryTheme(rawValue: selectedThemeRaw) ?? .shenghui
    }

    private var isProThemed: Bool {
        licenseEngine.isProActive
    }

    private var isWarmWhitePro: Bool {
        isProThemed
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

    public var body: some View {
        ZStack {
            if isWarmWhitePro {
                currentTheme.backgroundBase
                    .edgesIgnoringSafeArea(.all)
            } else {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                    .edgesIgnoringSafeArea(.all)
            }

            VStack(spacing: 0) {
                // Centered macOS Segmented Toolbar Header
                topTabBar
                    .frame(width: 452)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()
                    .opacity(isProThemed ? (currentTheme.isLight ? 0.35 : 0.20) : 0.25)

                // Tab Content Body (Anchored to top, never encroaches header)
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 520, height: 490)
        .tint(isWarmWhitePro ? currentTheme.accentColor : nil)
        .preferredColorScheme(settings.effectiveColorScheme)
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
        HStack(spacing: 0) {
            tabButton(title: L10n.tr("General", "通用"), icon: "gearshape", tag: 0)
            tabButton(title: L10n.playback, icon: "play.circle", tag: 1)
            tabButton(title: L10n.tr("LAN", "局域网"), icon: "network", tag: 2)
            tabButton(
                title: L10n.tr("About", "关于"),
                icon: "info.circle",
                tag: 3,
                showRedDot: updateService.hasPendingUpdate
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isWarmWhitePro ? currentTheme.pillSurface : Color.primary.opacity(0.06))
        )
        .overlay(
            isWarmWhitePro
                ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(currentTheme.borderColor, lineWidth: 0.6)
                : nil
        )
    }

    private func tabButton(title: String, icon: String, tag: Int, showRedDot: Bool = false) -> some View {
        Button {
            selectedTab = tag
        } label: {
            HStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: selectedTab == tag ? .semibold : .regular))

                    if showRedDot {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .stroke(isProThemed ? currentTheme.cardSurface : Color(nsColor: .windowBackgroundColor), lineWidth: 1.2)
                            )
                            .offset(x: 4, y: -2)
                    }
                }

                Text(title)
                    .font(.system(size: 12.5, weight: selectedTab == tag ? .medium : .regular))
            }
            .foregroundColor(selectedTab == tag
                ? (isWarmWhitePro ? currentTheme.accentColor : .primary)
                : (isWarmWhitePro ? currentTheme.secondaryText : .secondary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if selectedTab == tag {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isWarmWhitePro ? currentTheme.cardSurface : Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(isWarmWhitePro ? 0.05 : 0.12), radius: 2, x: 0, y: 1)
                    } else {
                        Color.clear
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(2)
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
    private func sectionTitle(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(isWarmWhitePro ? currentTheme.secondaryText : .secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 1. General Tab (通用)
    private var generalSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Group 1: 界面外观与个性化
                VStack(spacing: 5) {
                    sectionTitle(L10n.tr("Appearance & Theme", "外观与主题"))
                    settingsFormCard {
                        if licenseEngine.isProActive {
                            // Pro 版由“界面主题”直接驱动外观（暖白联动浅色 Aqua，深灰联动深色 DarkAqua）
                            proThemeRow
                        } else {
                            // 免费版仅保留 macOS 原生“外观模式”（跟随系统/浅色/深色），主题锁定深灰带 PRO 徽标
                            freeAppearanceRow
                            Divider().opacity(dividerOpacity).padding(.vertical, 3)
                            freeLockedThemeRow
                        }

                        Divider().opacity(dividerOpacity).padding(.vertical, 3)

                        // App Language
                        languageRow
                    }
                }

                // Group 2: 视窗与存储管理
                VStack(spacing: 5) {
                    sectionTitle(L10n.tr("Window & Storage", "视窗与存储管理"))
                    settingsFormCard {
                        // Window Mode
                        HStack {
                            Text(L10n.tr("Startup Window", "启动视窗行为"))
                                .font(.system(size: 13))
                                .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                            Spacer()
                            Picker("", selection: $settings.windowMode) {
                                Text(L10n.tr("Remember Last Position", "记忆上次位置")).tag(WindowMode.singleWindow)
                                Text(L10n.tr("Center on Screen", "屏幕居中打开")).tag(WindowMode.multipleWindows)
                            }
                            .frame(width: 170)
                        }
                        .frame(height: 32)

                        Divider().opacity(dividerOpacity).padding(.vertical, 3)

                        // Screenshots Directory
                        HStack {
                            Text(L10n.tr("Screenshots Directory", "截图保存目录"))
                                .font(.system(size: 13))
                                .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                            Spacer()
                            HStack(spacing: 8) {
                                Text(settings.screenshotDirectory)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(isProThemed ? currentTheme.secondaryText : .secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: 180, alignment: .trailing)

                                Button(L10n.tr("Change…", "更改…")) {
                                    selectFolder()
                                }
                                .font(.system(size: 11.5))
                                .controlSize(.small)
                            }
                        }
                        .frame(height: 32)

                        Divider().opacity(dividerOpacity).padding(.vertical, 3)

                        // Screenshot Format
                        HStack {
                            Text(L10n.tr("Screenshot Format", "截图保存格式"))
                                .font(.system(size: 13))
                                .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                            Spacer()
                            Picker("", selection: $settings.screenshotFormat) {
                                Text(L10n.tr("PNG (Lossless)", "PNG (无损原画)")).tag("png")
                                Text(L10n.tr("JPEG (Compact)", "JPEG (紧凑压缩)")).tag("jpeg")
                            }
                            .frame(width: 170)
                        }
                        .frame(height: 32)
                    }
                }

                // Group 3: 隐私与诊断
                VStack(spacing: 5) {
                    sectionTitle(L10n.tr("Privacy & Diagnostics", "隐私与诊断"))
                    settingsFormCard {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.tr("Anonymous Crash & Diagnostics", "发送匿名崩溃与诊断数据"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(primaryTextColor)
                                Text(L10n.tr(
                                    "Automatically sends anonymous error and performance diagnostics to improve playback stability.",
                                    "自动发送匿名错误与性能数据，用于持续优化播放稳定性与兼容性。"
                                ))
                                .font(.system(size: 10))
                                .foregroundColor(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Toggle("", isOn: $settings.anonymousUsageAnalyticsEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Appearance & Theme Rows (Free vs Pro Separation)
    private var freeAppearanceRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("Appearance", "外观模式"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text(L10n.tr("System baseline light or dark styling", "系统标准浅色与深色基础外观"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Picker("", selection: $settings.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
        }
        .frame(height: 34)
    }

    private var freeLockedThemeRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(L10n.tr("Interface Theme", "界面主题"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    proThemeBadge(isUnlocked: false)
                }

                Text(L10n.tr("Pro exclusive styling · Unlock in About tab", "Pro 专属定制质感 · 激活解锁暖白等个性化主题"))
                    .font(.system(size: 10))
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
                .pickerStyle(.segmented)
                .frame(width: 150)
                .disabled(true)
            }
            .opacity(0.60)
            .help(L10n.tr("Activate SilkPlayer Pro in About to unlock themes", "请在「设置 → 关于」激活 SilkPlayer Pro 解锁主题功能"))
        }
        .frame(minHeight: 36)
    }

    private var proThemeRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(L10n.tr("Interface Theme", "界面主题"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)

                    proThemeBadge(isUnlocked: true)
                }

                Text(L10n.tr("Synchronizes app appearance, media library, and music mode", "联动全局外观、媒体库与音乐模式配色"))
                    .font(.system(size: 10))
                    .foregroundColor(isProThemed ? currentTheme.secondaryText : .secondary)
            }

            Spacer()

            Picker("", selection: $selectedThemeRaw) {
                ForEach(SilkLibraryTheme.allCases) { th in
                    Text(th.displayName).tag(th.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .tint(currentTheme.accentColor)
            .frame(minWidth: 175)
        }
        .frame(minHeight: 36)
    }

    private var languageRow: some View {
        HStack {
            Text(L10n.tr("Language", "界面语言"))
                .font(.system(size: 13))
                .foregroundColor(isWarmWhitePro ? currentTheme.primaryText : .primary)
            Spacer()
            Picker("", selection: $settings.appLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .frame(width: 170)
        }
        .frame(height: 32)
    }

    // MARK: - 2. Playback Tab (播放)
    private var playbackSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Group 1: 播放与连续性
                VStack(spacing: 5) {
                    sectionTitle(L10n.tr("Playback & Continuity", "播放与连续性"))
                    settingsFormCard {
                        // Auto Play on Load
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Auto Play", "自动播放"))
                                    .font(.system(size: 13))
                                    .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                                Text(L10n.tr("Automatically start playback when opening media", "载入视频时自动开始播放"))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(isProThemed ? currentTheme.secondaryText : .secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.autoPlayOnLoad)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        .frame(height: 32)

                        Divider().opacity(dividerOpacity).padding(.vertical, 2)

                        // Continuous Playback
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Continuous Playback", "连续播放"))
                                    .font(.system(size: 13))
                                    .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                                Text(L10n.tr("Automatically play next item in playlist", "播放结束时自动连播下一集"))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(isProThemed ? currentTheme.secondaryText : .secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.autoPlayNextItem)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        .frame(height: 32)

                        Divider().opacity(dividerOpacity).padding(.vertical, 2)

                        // Dual Playlist Mode
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Dual Playlist Mode", "双列表模式"))
                                    .font(.system(size: 13))
                                    .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                                Text(L10n.tr("Separates video and music queues in drawer", "在侧边抽屉中分列管理视频与音乐"))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(isProThemed ? currentTheme.secondaryText : .secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.dualPlaylistMode)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        .frame(height: 32)

                        Divider().opacity(dividerOpacity).padding(.vertical, 2)

                        // Resume Playback Progress
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Resume Playback", "记住播放进度"))
                                    .font(.system(size: 13))
                                    .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                                Text(L10n.tr("Resume playback from last saved position", "再次打开同一视频从上次断点恢复"))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(isProThemed ? currentTheme.secondaryText : .secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.resumePlayback)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        .frame(height: 32)

                        Divider().opacity(dividerOpacity).padding(.vertical, 2)

                        // Playback History
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Playback History", "媒体播放历史"))
                                    .font(.system(size: 13))
                                    .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                                Text(L10n.tr("Remembers progress and breakpoint memories", "记住播放历史记录与断点数据"))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(isProThemed ? currentTheme.secondaryText : .secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.keepRecentHistory)
                                .toggleStyle(.switch)
                                .controlSize(.small)

                            Button(role: .destructive) {
                                settings.clearAllHistory()
                                showHistoryClearedAlert = true
                            } label: {
                                Text(L10n.tr("Clear…", "清除…"))
                                    .font(.system(size: 11.5))
                            }
                            .controlSize(.small)
                        }
                        .frame(height: 32)
                    }
                }

                // Group 2: 操控交互与全屏显示
                VStack(spacing: 5) {
                    sectionTitle(L10n.tr("Controls & On-Screen Display", "操控交互与全屏显示"))
                    settingsFormCard {
                        // Fullscreen Clock
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Show Clock in Fullscreen", "全屏右上角显示时钟"))
                                    .font(.system(size: 13))
                                    .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                                Text(L10n.tr("Displays system clock HUD during fullscreen playback", "全屏播放时在右上角常驻显示系统时钟"))
                                    .font(.system(size: 10.5))
                                    .foregroundColor(isProThemed ? currentTheme.secondaryText : .secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $settings.showLocalTimeInFullscreen)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        .frame(height: 32)

                        Divider().opacity(dividerOpacity).padding(.vertical, 2)

                        // Seek Step Duration
                        HStack {
                            Text(L10n.tr("Seek Step Duration", "进度快进步长"))
                                .font(.system(size: 13))
                                .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                            Spacer()
                            Picker("", selection: $settings.shortSeekStep) {
                                Text("5 " + L10n.tr("Seconds", "秒")).tag(5.0)
                                Text("10 " + L10n.tr("Seconds", "秒")).tag(10.0)
                                Text("15 " + L10n.tr("Seconds", "秒")).tag(15.0)
                                Text("30 " + L10n.tr("Seconds", "秒")).tag(30.0)
                            }
                            .frame(width: 170)
                        }
                        .frame(height: 30)

                        Divider().opacity(dividerOpacity).padding(.vertical, 2)

                        // Scroll Wheel Action
                        HStack {
                            Text(L10n.tr("Scroll Wheel Action", "滚轮滚动操作"))
                                .font(.system(size: 13))
                                .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                            Spacer()
                            Picker("", selection: $settings.scrollWheelAction) {
                                ForEach(ScrollWheelAction.allCases) { action in
                                    Text(action.displayName).tag(action)
                                }
                            }
                            .frame(width: 170)
                        }
                        .frame(height: 30)

                        Divider().opacity(dividerOpacity).padding(.vertical, 2)

                        // Double Click Action
                        HStack {
                            Text(L10n.tr("Double-Click Action", "双击画面操作"))
                                .font(.system(size: 13))
                                .foregroundColor(isProThemed ? currentTheme.primaryText : .primary)
                            Spacer()
                            Picker("", selection: $settings.doubleClickAction) {
                                ForEach(DoubleClickAction.allCases) { action in
                                    Text(action.displayName).tag(action)
                                }
                            }
                            .frame(width: 170)
                        }
                        .frame(height: 30)
                    }
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 3. LAN Tab (局域网)
    private var lanSettingsSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                Spacer().frame(height: 2)

                // Group 1: Media Library Behavior Switches
                VStack(spacing: 6) {
                    sectionTitle(L10n.tr("LAN Media Library", "局域网媒体库"))
                    settingsFormCard {
                        lanToggleRow(
                            title: L10n.tr("Enable LAN Media Library", "启用局域网媒体库"),
                            subtitle: L10n.tr(
                                "Turn off to use the standard minimal playback home screen. Configured sources and playback history are preserved.",
                                "关闭后切回标准极简播放主页；已接入的局域网目录和播放记录保留不删。"
                            ),
                            isOn: $settings.proLibraryHomeEnabled
                        )
                        Divider().opacity(dividerOpacity).padding(.vertical, 4)
                        lanToggleRow(
                            title: L10n.tr("Auto-Scan Sources on Launch", "启动时自动更新媒体源"),
                            subtitle: L10n.tr(
                                "Incrementally scan enabled SMB 2/3, NFS, and local folders in the background at startup.",
                                "应用启动后在后台扫描已启用自动更新的 SMB 2/3、NFS 与本地目录变更。"
                            ),
                            isOn: $settings.proAutoScanOnLaunch
                        )

                        if !licenseEngine.isProActive {
                            Divider().opacity(dividerOpacity).padding(.vertical, 4)
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(L10n.tr(
                                    "Activate LAN features in Settings → About to enable media library.",
                                    "请在「设置 → 关于」完成激活后使用局域网与媒体库功能。"
                                ))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                Spacer()
                                Button(L10n.tr("Go to About", "前往激活")) {
                                    selectedTab = 3
                                }
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .disabled(!licenseEngine.isProActive)
                .opacity(licenseEngine.isProActive ? 1.0 : 0.72)

                // Group 2: Protocols & Index Summary
                VStack(spacing: 6) {
                    sectionTitle(L10n.tr("Protocols & Index Status", "协议支持与索引状态"))
                    settingsFormCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(L10n.tr("Supported Protocols", "支持协议"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("SMB 2/3 · NFS · Local Folders")
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary)
                            }

                            Divider().opacity(dividerOpacity)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.tr(
                                        "\(libraryEngine.sources.count) sources · \(libraryEngine.items.count) items indexed",
                                        "已接入 \(libraryEngine.sources.count) 个目录源 · 共 \(libraryEngine.items.count) 条索引"
                                    ))
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(.primary)

                                    Text(libraryEngine.isScanning
                                         ? L10n.tr("Scanning \(libraryEngine.scanningSourceName ?? "")...", "正在扫描 \(libraryEngine.scanningSourceName ?? "")…")
                                         : L10n.tr("Local SQLite index. Cached metadata remains available when NAS is offline.", "采用本地 SQLite 索引，局域网设备离线时保留已缓存记录。"))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(L10n.tr("Scan Now", "立即扫描")) {
                                    Task {
                                        await libraryEngine.rescanAll()
                                    }
                                }
                                .controlSize(.small)
                                .disabled(libraryEngine.sources.isEmpty || libraryEngine.isScanning || !licenseEngine.isProActive)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func lanToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
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
                                .foregroundColor(.primary)
                        }

                        Text(L10n.tr("Version \(appVersionLabel)", "版本 \(appVersionLabel)"))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)

                        if let receipt = licenseEngine.activeReceipt {
                            Button {
                                Task {
                                    UserDefaults.standard.set(receipt.rawToken, forKey: "silk.pro.lastActiveReceipt")
                                    await licenseEngine.deactivate()
                                    SilkProIconManager.syncApplicationIcon(isProActive: false)
                                }
                            } label: {
                                Text(L10n.tr("Deactivate / Experience Free Edition", "停用授权 / 体验免费版"))
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.link)
                            .padding(.top, 1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "key.horizontal")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Activate Pro Features", "激活 Pro 功能"))
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(L10n.tr("Version \(appVersionLabel)", "版本 \(appVersionLabel)"))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Text(L10n.tr(
                                    "Enter an activation key for SMB 2/3, NFS, and LAN media library.",
                                    "激活后可使用 SMB 2/3、NFS 共享挂载与局域网媒体库。"
                                ))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)

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
                            .buttonStyle(.borderedProminent)
                            .disabled(licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || licenseEngine.isProcessing)

                            Button(L10n.tr("Buy", "购买")) {
                                if let url = licenseEngine.purchaseURL {
                                    NSWorkspace.shared.open(url)
                                } else {
                                    showPurchasePendingAlert = true
                                }
                            }
                            .buttonStyle(.bordered)
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
                Divider().opacity(dividerOpacity).padding(.vertical, 3)
                aboutInfoRow(
                    icon: "cpu",
                    title: L10n.tr("Decode Core", "解码核心"),
                    value: "SilkCoreKit · VideoToolbox HW · FFmpeg (LGPL)"
                )
                Divider().opacity(dividerOpacity).padding(.vertical, 3)
                aboutInfoRow(
                    icon: "checkmark.seal",
                    title: L10n.tr("Application Shell", "应用框架"),
                    value: "GNU LGPL v3.0"
                )
                Divider().opacity(dividerOpacity).padding(.vertical, 3)
                aboutInfoRow(
                    icon: "lock.shield",
                    title: L10n.tr("Core Engine", "核心引擎"),
                    value: "SilkCoreKit Proprietary"
                )
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 8)

            // Action Links & Updates (pushed cleanly toward lower third)
            HStack(spacing: 14) {
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
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                }

                Button {
                    if let url = URL(string: "https://github.com/meowvia/SilkPlayer") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "safari")
                            .font(.system(size: 11.5))
                        Text(L10n.tr("Project Website", "产品官网"))
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                }

                Button {
                    openLicensesNotice()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11.5))
                        Text(L10n.tr("Licenses & Notices", "开源与第三方许可"))
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                }
            }

            Spacer().frame(height: 8)

            Text("Copyright © 2026 SilkPlayer. All rights reserved.")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func aboutInfoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(width: 125, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary.opacity(0.9))

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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isWarmWhitePro ? currentTheme.cardSurface : Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isWarmWhitePro ? currentTheme.borderColor : Color.primary.opacity(0.07), lineWidth: isWarmWhitePro ? 0.75 : 0.5)
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
