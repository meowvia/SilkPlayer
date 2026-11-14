import SwiftUI
import AppKit

/// Native macOS Settings View for SilkPlayer (Proposal 018 & 020).
/// Strictly conforms to macOS Human Interface Guidelines (HIG) and Professional Design System.
/// Generous 520 × 490 pt zero-scroll architecture organized into 3 standard tabs:
/// 1. 通用 (General) - Appearance, Language, Window Mode, Screenshots (Directory & Format)
/// 2. 播放 (Playback) - Auto-play, Continuous Playback, Dual Playlist, Resume Playback, History, Step Duration, Scroll Wheel, Gestures, Clock
/// 3. 关于 (About) - Native AppIcon, Version Info, Spec Overview, Action Links, Legal Copyright
public struct SilkSettingsView: View {
    @Bindable var settings = AppSettings.shared
    @Bindable var updateService = UpdateService.shared

    @State private var selectedTab: Int = 0
    @State private var showHistoryClearedAlert: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Centered macOS Segmented Toolbar Header
                topTabBar
                    .frame(width: 320)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .opacity(0.25)

                // Tab Content Body (Zero Scrollbar, Fixed 520 × 422 pt)
                tabContent
                    .frame(width: 520, height: 422)
            }
        }
        .frame(width: 520, height: 490)
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .id(settings.appLanguage)
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
    }

    // MARK: - Top Tab Bar (3 Standard Tabs + Red Dot)
    private var topTabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: L10n.tr("General", "通用"), icon: "gearshape", tag: 0)
            tabButton(title: L10n.playback, icon: "play.circle", tag: 1)
            tabButton(
                title: L10n.tr("About", "关于"),
                icon: "info.circle",
                tag: 2,
                showRedDot: updateService.hasPendingUpdate
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
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
                            .offset(x: 4, y: -2)
                    }
                }

                Text(title)
                    .font(.system(size: 12.5, weight: selectedTab == tag ? .medium : .regular))
            }
            .foregroundColor(selectedTab == tag ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Group {
                    if selectedTab == tag {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
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
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 1. General Tab (通用)
    private var generalSection: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 2)

            // Group 1: 界面外观与语言
            VStack(spacing: 6) {
                sectionTitle(L10n.tr("Appearance & Language", "外观与语言"))
                settingsFormCard {
                    // Appearance Mode
                    HStack {
                        Text(L10n.tr("Appearance", "外观模式"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Picker("", selection: $settings.appearanceMode) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }
                    .frame(height: 32)

                    Divider().opacity(0.12).padding(.vertical, 3)

                    // App Language
                    HStack {
                        Text(L10n.tr("Language", "界面语言"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
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
            }

            // Group 2: 视窗与存储管理
            VStack(spacing: 6) {
                sectionTitle(L10n.tr("Window & Storage", "视窗与存储管理"))
                settingsFormCard {
                    // Window Mode
                    HStack {
                        Text(L10n.tr("Startup Window", "启动视窗行为"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Picker("", selection: $settings.windowMode) {
                            Text(L10n.tr("Remember Last Position", "记忆上次位置")).tag(WindowMode.singleWindow)
                            Text(L10n.tr("Center on Screen", "屏幕居中打开")).tag(WindowMode.multipleWindows)
                        }
                        .frame(width: 170)
                    }
                    .frame(height: 32)

                    Divider().opacity(0.12).padding(.vertical, 3)

                    // Fullscreen Clock
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Show Clock in Fullscreen", "全屏右上角显示时钟"))
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            Text(L10n.tr("Displays system clock HUD during fullscreen playback", "全屏播放时在右上角常驻显示系统时钟"))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.showLocalTimeInFullscreen)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .frame(height: 32)

                    Divider().opacity(0.12).padding(.vertical, 3)

                    // Screenshots Directory
                    HStack {
                        Text(L10n.tr("Screenshots Directory", "截图保存目录"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        HStack(spacing: 8) {
                            Text(settings.screenshotDirectory)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
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

                    Divider().opacity(0.12).padding(.vertical, 3)

                    // Screenshot Format
                    HStack {
                        Text(L10n.tr("Screenshot Format", "截图保存格式"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    // MARK: - 2. Playback Tab (播放)
    private var playbackSection: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 2)

            // Group 1: 播放与连续性
            VStack(spacing: 6) {
                sectionTitle(L10n.tr("Playback & Continuity", "播放与连续性"))
                settingsFormCard {
                    // Auto Play on Load
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Auto Play", "自动播放"))
                                .font(.system(size: 13))
                            Text(L10n.tr("Automatically start playback when opening media", "载入视频时自动开始播放"))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.autoPlayOnLoad)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .frame(height: 34)

                    Divider().opacity(0.12).padding(.vertical, 2)

                    // Continuous Playback
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Continuous Playback", "连续播放"))
                                .font(.system(size: 13))
                            Text(L10n.tr("Automatically play next item in playlist", "播放结束时自动连播下一集"))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.autoPlayNextItem)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .frame(height: 34)

                    Divider().opacity(0.12).padding(.vertical, 2)

                    // Dual Playlist Mode
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Dual Playlist Mode", "双列表模式"))
                                .font(.system(size: 13))
                            Text(L10n.tr("Separates video and music queues in drawer", "在侧边抽屉中分列管理视频与音乐"))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.dualPlaylistMode)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .frame(height: 34)

                    Divider().opacity(0.12).padding(.vertical, 2)

                    // Resume Playback Progress
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Resume Playback", "记住播放进度"))
                                .font(.system(size: 13))
                            Text(L10n.tr("Resume playback from last saved position", "再次打开同一视频从上次断点恢复"))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.resumePlayback)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .frame(height: 34)

                    Divider().opacity(0.12).padding(.vertical, 2)

                    // Playback History
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Playback History", "媒体播放历史"))
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            Text(L10n.tr("Remembers progress and breakpoint memories", "记住播放历史记录与断点数据"))
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
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
                    .frame(height: 34)
                }
            }

            // Group 2: 操控交互与导航
            VStack(spacing: 6) {
                sectionTitle(L10n.tr("Controls & Navigation", "操控交互与导航"))
                settingsFormCard {
                    // Seek Step Duration
                    HStack {
                        Text(L10n.tr("Seek Step Duration", "进度快进步长"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
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

                    Divider().opacity(0.12).padding(.vertical, 2)

                    // Scroll Wheel Action
                    HStack {
                        Text(L10n.tr("Scroll Wheel Action", "滚轮滚动操作"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Picker("", selection: $settings.scrollWheelAction) {
                            ForEach(ScrollWheelAction.allCases) { action in
                                Text(action.displayName).tag(action)
                            }
                        }
                        .frame(width: 170)
                    }
                    .frame(height: 30)

                    Divider().opacity(0.12).padding(.vertical, 2)

                    // Double Click Action
                    HStack {
                        Text(L10n.tr("Double-Click Action", "双击画面操作"))
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    // MARK: - 3. About Tab (关于) - Commercial Grade Native Presentation
    private var aboutSection: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 14)

            // Header: Vector Brand Logo + Title + Version Badge + Slogan
            VStack(spacing: 8) {
                SilkBrandLogoView(size: 76, isInteractive: false)

                VStack(spacing: 5) {
                    Text("SilkPlayer")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Text("1.6.0 (Build 2026.11)")
                        Text("·")
                        Text(L10n.tr("Universal Binary", "双架构通用二进制"))
                    }
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )

                    Text(L10n.tr(
                        "Native · Minimal · Ultra-light · Effortless",
                        "原生 · 极简 · 极轻 · 易用"
                    ))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.9))
                    .padding(.top, 2)
                }
            }

            Spacer().frame(height: 16)

            // Core Specs Inset Card
            settingsFormCard {
                aboutInfoRow(
                    icon: "sparkles.tv",
                    title: L10n.tr("Rendering Pipeline", "渲染管线"),
                    value: "Apple Silicon Metal Direct (Zero-Copy)"
                )
                Divider().opacity(0.12).padding(.vertical, 3)
                aboutInfoRow(
                    icon: "cpu",
                    title: L10n.tr("Decode Core", "解码核心"),
                    value: "SilkCoreKit · VideoToolbox HW"
                )
                Divider().opacity(0.12).padding(.vertical, 3)
                aboutInfoRow(
                    icon: "checkmark.seal",
                    title: L10n.tr("License", "开源协议"),
                    value: "GNU LGPL v3.0"
                )
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 18)

            // Action Links & Updates
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
                    if let resourceURL = Bundle.main.url(forResource: "THIRD_PARTY_LICENSES", withExtension: "txt") {
                        NSWorkspace.shared.open(resourceURL)
                    } else if let url = URL(string: "https://github.com/meowvia/SilkPlayer/blob/main/Documentation/THIRD_PARTY.md") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11.5))
                        Text(L10n.tr("Licenses & Notices", "开源许可与致谢"))
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                }
            }

            Spacer().frame(height: 18)

            Text("Copyright © 2026 SilkPlayer. All rights reserved.")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary.opacity(0.6))

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        )
    }

    private func selectFolder() {
        NSCursor.unhide()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.tr("Select", "选择")
        if panel.runModal() == .OK, let url = panel.url {
            settings.screenshotDirectory = url.path
        }
        NSCursor.unhide()
    }
}
