import SwiftUI
import AppKit

/// Native macOS Settings View for SilkPlayer.
/// Conforms 100% to macOS Human Interface Guidelines (HIG).
/// Organized into 4 categories:
/// 1. 通用 (General) - Appearance & Language unified card, Window Strategy, Screenshots, Privacy & History
/// 2. 播放 (Playback) - Auto-play, Window Auto-fit, Seeking, Gestures
/// 3. 音视频与字幕 (Audio & Subtitles) - Hardware Decode, Dialogue Boost, Volume Memory, Subtitle Sizing & Sync
/// 4. 关于 (About SilkPlayer) - Brand Emblem, Engine Architecture, Privacy Manifesto
public struct SilkSettingsView: View {
    @Bindable var settings = AppSettings.shared
    @State private var selectedTab: Int = 0
    @State private var showHistoryClearedAlert: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // 1. Vibrancy Material Base
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            // Ambient Iridescent Tint
            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.cyan.opacity(0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Top Segmented Header
                topTabBar
                    .padding(.horizontal, 20)
                    .padding(.top, 26)
                    .padding(.bottom, 12)

                Divider()
                    .opacity(0.25)

                // Tab Content Container
                tabContainer
            }
        }
        .frame(width: 540, height: 680)
        .preferredColorScheme(settings.appearanceMode.colorScheme)
        .alert(L10n.tr("Playback History Cleared", "播放历史已清除"), isPresented: $showHistoryClearedAlert) {
            Button(L10n.tr("OK", "好"), role: .cancel) { }
        } message: {
            Text(L10n.tr("All media playback positions and history have been cleared.", "所有媒体的历史进度与断点记忆已被清除。"))
        }
    }

    // MARK: - Top Tab Bar
    private var topTabBar: some View {
        Picker("", selection: $selectedTab) {
            Label(L10n.tr("General", "通用"), systemImage: "gearshape.fill").tag(0)
            Label(L10n.playback, systemImage: "play.circle.fill").tag(1)
            Label(L10n.tr("Audio & Subtitles", "音视频与字幕"), systemImage: "speaker.wave.2.fill").tag(2)
            Label(L10n.tr("Shortcuts", "快捷键"), systemImage: "command").tag(3)
            Label(L10n.aboutSilkPlayer, systemImage: "info.circle.fill").tag(4)
        }
        .pickerStyle(.segmented)
        .animation(.snappy(duration: 0.15), value: selectedTab)
    }

    // MARK: - Tab Content Container
    // General Tab presents fully in one view without scrolling; others use standard ScrollView
    private var tabContainer: some View {
        Group {
            if selectedTab == 0 {
                generalSection
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    Group {
                        switch selectedTab {
                        case 1:
                            playbackSection
                        case 2:
                            audioSubtitleSection
                        case 3:
                            shortcutsSection
                        case 4:
                            aboutSection
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                }
            }
        }
        .frame(width: 540, height: 585)
    }

    // MARK: - 1. General Tab (通用)
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Merged Appearance & Language Card
            SettingsCard(title: L10n.tr("Appearance & Language", "外观与语言"), icon: "paintbrush.fill") {
                VStack(spacing: 10) {
                    HStack {
                        Text(L10n.tr("Appearance Mode", "外观模式"))
                            .font(.body)
                        Spacer()
                        Picker("", selection: $settings.appearanceMode) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }

                    Divider().opacity(0.2)

                    HStack {
                        Text(L10n.tr("Interface Language", "界面语言"))
                            .font(.body)
                        Spacer()
                        Picker("", selection: $settings.appLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                    }
                }
            }

            // Window Strategy Card
            SettingsCard(title: L10n.tr("Window Strategy", "窗口模式"), icon: "macwindow.on.rectangle") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L10n.tr("Single Window Mode (Reuse window for new media)", "单窗口模式 (打开新媒体时复用当前窗口)"), isOn: $settings.singleWindowMode)
                    Text(L10n.tr("When enabled, always plays media inside a single window; when disabled, opens a new window for each media.", "开启后始终在单一窗口中流畅换片；关闭则每次打开新媒体创建独立窗口。"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Screenshots Card
            SettingsCard(title: L10n.tr("Screenshots", "截屏"), icon: "camera.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.tr("Image Format", "图片格式"))
                            .font(.body)
                        Spacer()
                        Picker("", selection: $settings.screenshotFormat) {
                            Text(L10n.tr("PNG (Lossless)", "PNG (无损原画)")).tag("png")
                            Text(L10n.tr("JPEG (Compact)", "JPEG (紧凑压缩)")).tag("jpeg")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 145)
                    }

                    Divider().opacity(0.2)

                    Text(L10n.tr("Save Location", "存储位置"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(settings.screenshotDirectory)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                        )

                    HStack {
                        Spacer()
                        Button(L10n.showInFinder) {
                            let url = URL(fileURLWithPath: settings.screenshotDirectory)
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        .controlSize(.small)

                        Button(L10n.tr("Choose...", "选取…")) {
                            selectFolder()
                        }
                        .controlSize(.small)
                    }
                }
            }

            // History & Privacy Card
            SettingsCard(title: L10n.tr("Playback History", "播放历史"), icon: "clock.arrow.circlepath") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("Clear Playback History", "清除播放历史"))
                            .font(.body)
                        Text(L10n.tr("Clear all saved positions and progress for local media.", "清除所有本地媒体的历史进度与断点记忆。"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(L10n.tr("Clear History...", "清除历史…")) {
                        settings.clearAllHistory()
                        showHistoryClearedAlert = true
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - 2. Playback Tab (播放)
    private var playbackSection: some View {
        VStack(spacing: 14) {
            // Playback Flow Card
            SettingsCard(title: L10n.tr("Playback Controls", "播放控制"), icon: "play.circle.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.tr("Resume playback on launch", "启动时恢复上次播放"), isOn: $settings.autoResumeOnLaunch)
                    Text(L10n.tr("Automatically loads the last played file when opening SilkPlayer (paused by default to protect privacy).", "打开 SilkPlayer 时自动载入上次播放的文件（默认保持暂停以保护隐私）。"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider().opacity(0.2)

                    Toggle(L10n.tr("Auto-play on load", "打开文件时自动播放"), isOn: $settings.autoPlayOnLoad)
                    Text(L10n.tr("Starts playback immediately when opening or dropping media; otherwise pauses at the first frame.", "打开或拖入媒体文件时立即开始播放；关闭则载入首帧并暂停等待。"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider().opacity(0.2)

                    Toggle(L10n.tr("Remember playback progress", "记住播放进度"), isOn: $settings.resumePlayback)
                    Text(L10n.tr("Remembers playback position for each file and resumes seamlessly on reopen.", "为每个媒体记住上次播放位置，再次载入时自动无缝续播。"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider().opacity(0.2)

                    Toggle(L10n.tr("Auto-play next media in playlist", "自动播放下一个项目"), isOn: $settings.autoPlayNextItem)
                    Text(L10n.tr("Advances to the next item in the folder or playlist when playback completes.", "当前媒体播放完毕后，自动衔接同目录或播放列表中的下一个项目。"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Window Behavior Card
            SettingsCard(title: L10n.tr("Video & Window", "画面与窗口"), icon: "arrow.up.left.and.arrow.down.right") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.tr("Auto-match video aspect ratio", "自动匹配视频原始比例"), isOn: $settings.autoResizeWindow)
                    Text(L10n.tr("Automatically resizes window to fit native video dimensions without black bars.", "打开媒体时自动调整窗口大小以贴合视频原生宽高比，消除黑边。"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider().opacity(0.2)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Double-click Action", "双击画面动作"))
                                .font(.body)
                            Text(L10n.tr("Action triggered when double-clicking on the canvas.", "在视频画面任意区域双击鼠标主键时的操作。"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.doubleClickAction) {
                            ForEach(DoubleClickAction.allCases) { action in
                                Text(action.displayName).tag(action)
                            }
                        }
                        .frame(width: 155)
                    }
                }
            }

            // Gestures & Seeking Card
            SettingsCard(title: L10n.tr("Seeking & Gestures", "快进与手势"), icon: "hand.tap.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    // Fast Forward Callout
                    HStack(spacing: 8) {
                        Image(systemName: "forward.fill")
                            .foregroundColor(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Hold Right Arrow for 2.0x Fast Forward", "长按右箭头键 2 倍速快进"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(L10n.tr("Press and hold the Right Arrow key for 2.0x playback; release to restore instantly.", "按住右方向键以 2.0x 极速快进，松开立即平滑恢复原速。"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cyan.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Divider().opacity(0.2)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Seek Step Interval", "步进跳转时间"))
                                .font(.body)
                            Text(L10n.tr("Seek duration when pressing ← / → arrow keys.", "单击方向键 ← / → 时的跳跃步长。"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.shortSeekStep) {
                            Text(L10n.tr("3s", "3 秒")).tag(3.0)
                            Text(L10n.tr("5s (Default)", "5 秒 (默认)")).tag(5.0)
                            Text(L10n.tr("10s", "10 秒")).tag(10.0)
                            Text(L10n.tr("15s", "15 秒")).tag(15.0)
                        }
                        .frame(width: 140)
                    }

                    Divider().opacity(0.2)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Scroll Wheel Action", "滚轮动作"))
                                .font(.body)
                            Text(L10n.tr("Behavior when scrolling vertically on the video canvas.", "在播放画面中垂直滚动鼠标滚轮时的行为。"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.scrollWheelAction) {
                            ForEach(ScrollWheelAction.allCases) { action in
                                Text(action.displayName).tag(action)
                            }
                        }
                        .frame(width: 140)
                    }
                }
            }
        }
    }

    // MARK: - 3. Audio & Subtitles Tab (音视频与字幕)
    private var audioSubtitleSection: some View {
        VStack(spacing: 14) {
            // Hardware Decoding & Audio Card
            SettingsCard(title: L10n.tr("Decoding & Audio", "解码与音频"), icon: "bolt.badge.automatic.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Hardware Accelerated Direct Rendering", "硬件加速渲染"))
                                .font(.body)
                            Text(L10n.tr("VideoToolbox hardware decoding + Metal zero-copy direct display.", "VideoToolbox 硬件解码 + Metal 零拷贝 GPU 直显。"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Metal Direct")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }

                    Divider().opacity(0.2)

                    Toggle(L10n.tr("Remember Volume", "记住音量设置"), isOn: $settings.rememberVolume)
                    Text(L10n.tr("Retains volume level across app restarts.", "退出并重新启动播放器后，保留上次设置的音量值。"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Subtitle Presentation Card
            SettingsCard(title: L10n.tr("Subtitle Settings", "字幕设置"), icon: "captions.bubble.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Preferred Subtitle Language", "默认字幕语言"))
                                .font(.body)
                            Text(L10n.tr("Language prioritized in embedded or multi-track subtitles.", "内嵌或多音轨字幕中优先激活的语言。"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.preferredSubtitleLang) {
                            Text(L10n.tr("Chinese (Simplified / Traditional)", "中文 (简体 / 繁体)")).tag("zh,chi,zho,zh-Hans,zh-Hant,chs,cht")
                            Text(L10n.tr("English", "英文")).tag("eng")
                            Text(L10n.tr("Media Default", "媒体默认")).tag("auto")
                        }
                        .frame(width: 155)
                    }

                    Divider().opacity(0.2)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Default Font Size", "默认字体大小"))
                                .font(.body)
                            Text(L10n.tr("Initial subtitle size preset when opening videos.", "打开视频时的初始字号预设。"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.subtitleSizePreset) {
                            ForEach(SubtitleSizePreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .frame(width: 155)
                    }

                    Divider().opacity(0.2)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("Auto-load Matching Subtitles", "自动载入同名字幕"))
                                .font(.body)
                            Text(L10n.tr("Automatically loads companion .srt / .ass / .vtt files in the same folder.", "自动识别并加载同目录同名的 .srt / .ass / .vtt 外挂字幕。"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(L10n.tr("Auto-load", "自动载入"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.cyan)
                    }

                    Divider().opacity(0.2)

                    HStack(spacing: 6) {
                        Image(systemName: "command")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(L10n.tr("Press Z / X during playback to fine-tune subtitle sync (±0.5s).", "播放时按快捷键 Z / X 可微调字幕同步时间轴（±0.5s）。"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 4. Shortcuts Tab (快捷键)
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Card 1: 常用播控
            SettingsCard(title: L10n.tr("Playback Shortcuts", "播控操作"), icon: "play.circle.fill") {
                VStack(spacing: 6) {
                    shortcutRow(title: L10n.tr("Play / Pause", "播放 / 暂停"), keys: ["␣ Space"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Seek ±5 Seconds", "快退 / 快进 5 秒"), keys: ["←", "→"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Seek ±30 Seconds", "快退 / 快进 30 秒"), keys: ["⌥", "←", "/", "→"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Step Previous / Next Frame", "上一帧 / 下一帧逐帧微调"), keys: ["[", "]"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Previous / Next Item", "上一个 / 下一个媒体项目"), keys: ["⌘", "←", "/", "→"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Playback Speed (Down / Up)", "减速 / 加速播放倍速"), keys: ["⌘", "[", "/", "]"])
                }
            }

            // Card 2: 声音与画面
            SettingsCard(title: L10n.tr("Audio & Video Shortcuts", "声音与画面"), icon: "speaker.wave.2.fill") {
                VStack(spacing: 6) {
                    shortcutRow(title: L10n.tr("Volume Up / Down (±10%)", "调大 / 调小音量 (±10%)"), keys: ["↑", "↓"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Mute / Unmute", "静音 / 取消静音"), keys: ["M"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Cycle Audio Tracks", "切换音频轨道"), keys: ["A"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Cycle Subtitles", "切换字幕轨道"), keys: ["S"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Toggle Fullscreen", "进入 / 退出全屏"), keys: ["F", "/", "⌘", "F"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("HDR Tone Mapping", "HDR / 杜比色调映射开关"), keys: ["H"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Rotate Video (90°)", "画面顺时针旋转 90°"), keys: ["R"])
                }
            }

            // Card 3: 窗口与管理
            SettingsCard(title: L10n.tr("Window & Controls", "窗口与快捷管理"), icon: "macwindow") {
                VStack(spacing: 6) {
                    shortcutRow(title: L10n.tr("Open File", "打开媒体文件"), keys: ["⌘", "O"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Toggle Playlist Drawer", "展开 / 收起播放列表"), keys: ["⌘", "P"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Toggle Media Properties", "展开 / 收起媒体属性"), keys: ["⌘", "I"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Take Screenshot", "截取当前画面"), keys: ["⌘", "S"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Close Window / Dialog", "关闭当前窗口 / 面板"), keys: ["Esc", "/", "⌘", "W"])
                    Divider().opacity(0.15)
                    shortcutRow(title: L10n.tr("Preferences", "打开偏好设置"), keys: ["⌘", ","])
                }
            }

            // Bottom Floating Cheatsheet Entry Button
            HStack {
                Spacer()
                Button(action: {
                    ShortcutsCheatsheetManager.shared.show()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "command")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.tr("Open Full Shortcuts Window (Cmd+/)", "在独立窗口中打开完整速查表 (⌘ /)"))
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    private func shortcutRow(title: String, keys: [String]) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { k in
                    Text(k)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.85))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(.vertical, 1.5)
    }

    // MARK: - 5. About Tab (关于 SilkPlayer)
    private var aboutSection: some View {
        VStack(spacing: 16) {
            // Brand Logo & Typography
            VStack(spacing: 12) {
                SilkBrandLogoView(size: 68, isInteractive: false)

                VStack(spacing: 4) {
                    Text("SilkPlayer")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
                    Text(L10n.tr("Version \(appVersion) (SilkCoreKit · Apple Silicon)", "版本 \(appVersion) (SilkCoreKit · Apple Silicon)"))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)

            // High-Visibility GitHub Repository Update Prompt (更新高亮提示)
            Button(action: {
                if let url = URL(string: "https://github.com/meowvia/SilkPlayer/releases") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.85), Color.blue.opacity(0.70)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(L10n.tr("Check for Updates", "检查更新"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)

                            Text("GitHub")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor))
                        }

                        Text(L10n.tr("Visit GitHub repository for latest releases and changelogs", "前往 GitHub 仓库获取最新版本发布与更新日志"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text(L10n.tr("Open", "前往"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.60))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.40), lineWidth: 1.2)
                        )
                )
                .shadow(color: Color.accentColor.opacity(0.10), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Architecture Pillars Card
            SettingsCard(title: L10n.tr("Architecture & Specifications", "技术规格与系统架构"), icon: "cpu") {
                VStack(alignment: .leading, spacing: 10) {
                    aboutPillarRow(
                        icon: "bolt.fill",
                        color: .yellow,
                        title: L10n.tr("SilkPlayback Engine · VideoToolbox & Audio", "SilkPlayback Engine 回放引擎"),
                        desc: L10n.tr("Hardware-accelerated decoding via Apple Silicon media engine with synchronized master clock and zero-latency audio playback.", "基于 Apple Silicon 硬件加速硬解与原生低延迟音频时钟同步管线，提供丝滑流畅的音画回放体验。")
                    )
                    Divider().opacity(0.2)
                    aboutPillarRow(
                        icon: "sun.max.fill",
                        color: .orange,
                        title: L10n.tr("SilkRender Pipeline · Metal 3 & Profile 5", "SilkRender Pipeline 渲染管线"),
                        desc: L10n.tr("Direct IOSurface zero-copy Metal texture presentation with proprietary Dolby Vision Profile 5 RPU dynamic reshaping.", "基于 IOSurface 零拷贝 Metal 3 纹理直出与专有杜比视界 Profile 5 RPU 动态重塑算法，拒绝偏色偏灰。")
                    )
                    Divider().opacity(0.2)
                    aboutPillarRow(
                        icon: "sparkles",
                        color: .cyan,
                        title: L10n.tr("SilkThumb Engine · Keyframe Scrubbing", "SilkThumb Engine 抽帧引擎"),
                        desc: L10n.tr("Independent high-speed keyframe extraction and adaptive memory LRU caching for instantaneous timeline hover previews.", "独立高速关键帧解析与自适应内存两级 LRU 缓存，实现鼠标进度条悬停毫秒级无卡顿预览。")
                    )
                    Divider().opacity(0.2)
                    aboutPillarRow(
                        icon: "lock.shield.fill",
                        color: .green,
                        title: L10n.tr("Native Architecture & Privacy Protection", "原生架构与隐私保护"),
                        desc: L10n.tr("Lightweight proprietary core (SilkCoreKit) + LGPL-3.0 dynamic library baseline, offline execution without telemetry.", "专有核心架构 (SilkCoreKit) 结合 LGPL-3.0 动态链接合规基线，完全单机离线运行，无任何网络遥测。")
                    )
                }
            }

            // Open Source Credits & Acknowledgements Card
            SettingsCard(title: L10n.tr("Architecture & Acknowledgements", "底层架构与技术致谢"), icon: "cube.box") {
                VStack(spacing: 8) {
                    aboutCreditRow(name: "Apple VideoToolbox & Metal 3", license: "Hardware Acceleration")
                    Divider().opacity(0.2)
                    aboutCreditRow(name: "Apple AudioToolbox (AudioQueue)", license: "Native Audio Subsystem")
                    Divider().opacity(0.2)
                    aboutCreditRow(name: "FFmpeg (Core Libraries)", license: "LGPL-3.0 Dynamic")
                }
            }

            Text(L10n.tr("Released under LGPL-3.0 · Powered by SilkCoreKit", "遵循 LGPL-3.0 动态链接合规标准 · 搭载 SilkCoreKit 核心驱动"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.70))
                .padding(.bottom, 4)
        }
    }

    private func aboutCreditRow(name: String, license: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 4) {
                Text(L10n.tr("License:", "许可证:"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.75))
                Text(license)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(.vertical, 2)
    }

    private func aboutPillarRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
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

// MARK: - Reusable Settings Card
public struct SettingsCard<Content: View>: View {
    public let title: String
    public let icon: String
    public let content: Content

    public init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.cyan)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
