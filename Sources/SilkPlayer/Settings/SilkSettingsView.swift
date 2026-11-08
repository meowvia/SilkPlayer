import SwiftUI
import AppKit

/// Native macOS Settings View for SilkPlayer (Proposal 018 & 020).
/// Strictly conforms to macOS Human Interface Guidelines (HIG).
/// Fixed 520 × 400 pt zero-scroll architecture organized into 3 standard tabs:
/// 1. 通用 (General) - Appearance, Language, Window Mode, Screenshots, History
/// 2. 播放 (Playback) - Auto-play, Continuous Playback, Window Fit, Fullscreen, Gestures, Step Duration
/// 3. 关于 (About) - Official AppIcon, Version Info, Check for Updates, Architecture Manifesto
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
                // Standard macOS Segmented Toolbar Header
                topTabBar
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 14)

                Divider()
                    .opacity(0.3)

                // Tab Content Body (Zero Scrollbar)
                tabContent
                    .frame(width: 520, height: 320)
            }
        }
        .frame(width: 520, height: 400)
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
        .padding(.horizontal, 40)
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
        .padding(2)
    }

    // MARK: - Tab Content Switcher
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 0:
                generalSection
            case 1:
                playbackSection
            case 2:
                aboutSection
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    // MARK: - 1. General Tab (通用)
    private var generalSection: some View {
        VStack(spacing: 12) {
            settingsFormCard {
                VStack(spacing: 10) {
                    // Appearance Mode
                    HStack {
                        Text(L10n.tr("Appearance", "外观模式"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $settings.appearanceMode) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    Divider().opacity(0.2)

                    // Language
                    HStack {
                        Text(L10n.tr("Language", "界面语言"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $settings.appLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    Divider().opacity(0.2)

                    // Window Mode
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Window Mode", "窗口模式"))
                                .font(.system(size: 13))
                            Text(L10n.tr("Open media files in a single window", "在单个窗口中播放视频"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.singleWindowMode)
                            .toggleStyle(.switch)
                    }
                }
            }

            settingsFormCard {
                VStack(spacing: 10) {
                    // Screenshots Format & Folder
                    HStack {
                        Text(L10n.tr("Screenshots", "截屏"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $settings.screenshotFormat) {
                            Text("PNG").tag("png")
                            Text("JPEG").tag("jpeg")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)

                        Button(L10n.tr("Choose...", "选取...")) {
                            selectFolder()
                        }
                        .font(.system(size: 12))
                    }

                    Divider().opacity(0.2)

                    // History Progress & Clear
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Playback History", "播放历史"))
                                .font(.system(size: 13))
                            Text(L10n.tr("Remember last played position", "记住播放进度"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.autoResumePlayback)
                            .toggleStyle(.switch)

                        Button(L10n.tr("Clear...", "清除…")) {
                            settings.clearAllHistory()
                            showHistoryClearedAlert = true
                        }
                        .font(.system(size: 12))
                    }
                }
            }
        }
    }

    // MARK: - 2. Playback Tab (播放)
    private var playbackSection: some View {
        VStack(spacing: 12) {
            settingsFormCard {
                VStack(spacing: 10) {
                    // Auto Play
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Auto Play", "自动播放"))
                                .font(.system(size: 13))
                            Text(L10n.tr("Automatically play after opening files", "打开文件后自动播放"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.autoPlayOnLoad)
                            .toggleStyle(.switch)
                    }

                    Divider().opacity(0.2)

                    // Continuous Playback
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Continuous Playback", "连续播放"))
                                .font(.system(size: 13))
                            Text(L10n.tr("Automatically play next file when finished", "播放完成后自动播放下一个文件"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.autoPlayNextItem)
                            .toggleStyle(.switch)
                    }

                    Divider().opacity(0.2)

                    // Auto Resize Window
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Window Sizing", "窗口适配"))
                                .font(.system(size: 13))
                            Text(L10n.tr("Automatically resize window to fit video dimensions", "自动调整窗口大小以适应视频尺寸"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.autoResizeWindow)
                            .toggleStyle(.switch)
                    }
                }
            }

            settingsFormCard {
                VStack(spacing: 10) {
                    // Fullscreen Clock
                    HStack {
                        Text(L10n.tr("Show Clock in Fullscreen", "全屏时显示时钟"))
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: $settings.showLocalTimeInFullscreen)
                            .toggleStyle(.switch)
                    }

                    Divider().opacity(0.2)

                    // Double Click Action
                    HStack {
                        Text(L10n.tr("Double-Click Action", "双击操作"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $settings.doubleClickAction) {
                            ForEach(DoubleClickAction.allCases) { action in
                                Text(action.displayName).tag(action)
                            }
                        }
                        .frame(width: 170)
                    }

                    Divider().opacity(0.2)

                    // Step Duration
                    HStack {
                        Text(L10n.tr("Seek Step Duration", "步进时间"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $settings.shortSeekStep) {
                            Text("5 " + L10n.tr("Seconds", "秒")).tag(5.0)
                            Text("10 " + L10n.tr("Seconds", "秒")).tag(10.0)
                            Text("15 " + L10n.tr("Seconds", "秒")).tag(15.0)
                            Text("30 " + L10n.tr("Seconds", "秒")).tag(30.0)
                        }
                        .frame(width: 170)
                    }
                }
            }
        }
    }

    // MARK: - 3. About Tab (关于)
    private var aboutSection: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 4)

            // Real AppIcon / Vector Brand Emblem
            AboutAppIconView()

            VStack(spacing: 4) {
                Text("SilkPlayer")
                    .font(.system(size: 17, weight: .bold))

                Text("1.6.0 (Build 2026.11) · Universal Binary")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Text(L10n.tr(
                "Native, lightweight, and minimal design with zero built-in ads and no redundant background processes.",
                "原生轻量与极简设计，无内置广告与冗余后台常驻进程。"
            ))
            .font(.system(size: 11.5))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            // Standard Action Buttons
            HStack(spacing: 14) {
                Button {
                    updateService.checkManually()
                } label: {
                    HStack(spacing: 4) {
                        if updateService.isChecking {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                        }
                        Text(L10n.tr("Check for Updates", "检查更新"))
                            .font(.system(size: 11.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }

                Button {
                    if let url = URL(string: "https://github.com/meowvia/SilkPlayer") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "safari")
                            .font(.system(size: 11))
                        Text(L10n.tr("Project Homepage", "项目主页"))
                            .font(.system(size: 11.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }

                Button {
                    if let url = URL(string: "https://github.com/meowvia/SilkPlayer/blob/main/LICENSE") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11))
                        Text("LGPL-3.0")
                            .font(.system(size: 11.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }

            Spacer().frame(height: 2)

            Text("Copyright © 2026 meowvia. All rights reserved.")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Reusable Card Form Component
    private func settingsFormCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
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

// MARK: - Native AppIcon Component
struct AboutAppIconView: View {
    var body: some View {
        if let appIcon = NSApp?.applicationIconImage, appIcon.isValid, appIcon.size.width > 0 {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        } else {
            SilkBrandLogoView(size: 64)
        }
    }
}
