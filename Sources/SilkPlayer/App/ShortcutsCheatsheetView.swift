import SwiftUI
import AppKit

public struct ShortcutRowItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let keys: [String]
    public let category: ShortcutCategory

    public init(title: String, keys: [String], category: ShortcutCategory) {
        self.title = title
        self.keys = keys
        self.category = category
    }
}

public enum ShortcutCategory: String, CaseIterable, Identifiable {
    case all
    case playback
    case audio
    case subtitle
    case video
    case window

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return L10n.tr("All", "全部")
        case .playback: return L10n.playback
        case .audio: return L10n.audioTrack
        case .subtitle: return L10n.subtitles
        case .video: return L10n.menuVideo
        case .window: return L10n.menuWindow
        }
    }
}

public struct ShortcutsCheatsheetView: View {
    @State private var selectedCategory: ShortcutCategory = .all
    @State private var searchText: String = ""

    public init() {}

    private var allShortcuts: [ShortcutRowItem] {
        [
            // Playback
            ShortcutRowItem(title: L10n.tr("Play / Pause", "播放 / 暂停"), keys: ["␣ Space"], category: .playback),
            ShortcutRowItem(title: L10n.stepBackward5s, keys: ["←"], category: .playback),
            ShortcutRowItem(title: L10n.stepForward5s, keys: ["→"], category: .playback),
            ShortcutRowItem(title: L10n.jumpBackward30s, keys: ["⌥", "←"], category: .playback),
            ShortcutRowItem(title: L10n.jumpForward30s, keys: ["⌥", "→"], category: .playback),
            ShortcutRowItem(title: L10n.frameStepBackward, keys: ["["], category: .playback),
            ShortcutRowItem(title: L10n.frameStepForward, keys: ["]"], category: .playback),
            ShortcutRowItem(title: L10n.previousTrack, keys: ["⌘", "←"], category: .playback),
            ShortcutRowItem(title: L10n.nextTrack, keys: ["⌘", "→"], category: .playback),
            ShortcutRowItem(title: L10n.tr("Close Media", "关闭当前媒体"), keys: ["Esc", "/", "⌘", "W"], category: .playback),
            ShortcutRowItem(title: L10n.speedDecrease, keys: ["⌘", "["], category: .playback),
            ShortcutRowItem(title: L10n.speedIncrease, keys: ["⌘", "]"], category: .playback),

            // Audio
            ShortcutRowItem(title: L10n.tr("Volume Up (+10%)", "增加音量 (+10%)"), keys: ["↑"], category: .audio),
            ShortcutRowItem(title: L10n.tr("Volume Down (-10%)", "减小音量 (-10%)"), keys: ["↓"], category: .audio),
            ShortcutRowItem(title: L10n.muteUnmute, keys: ["M"], category: .audio),
            ShortcutRowItem(title: L10n.cycleAudioTrack, keys: ["A"], category: .audio),

            // Subtitle
            ShortcutRowItem(title: L10n.cycleSubtitleTrack, keys: ["S"], category: .subtitle),

            // Video
            ShortcutRowItem(title: L10n.tr("Toggle Fullscreen", "进入 / 退出全屏"), keys: ["F", "/", "⌘", "F"], category: .video),
            ShortcutRowItem(title: L10n.tr("HDR Tone Mapping", "HDR 色调映射"), keys: ["H"], category: .video),
            ShortcutRowItem(title: L10n.tr("Rotate Video (90°)", "画面旋转 (90°)"), keys: ["R"], category: .video),
            ShortcutRowItem(title: L10n.toggleDeband, keys: ["D"], category: .video),

            // Window & App
            ShortcutRowItem(title: L10n.mediaInspectorTitle, keys: ["⌘", "I"], category: .window),
            ShortcutRowItem(title: L10n.playlist, keys: ["⌘", "P"], category: .window),
            ShortcutRowItem(title: L10n.openFile, keys: ["⌘", "O"], category: .window),
            ShortcutRowItem(title: L10n.settings, keys: ["⌘", ","], category: .window),
            ShortcutRowItem(title: L10n.keyboardShortcuts, keys: ["⌘", "/"], category: .window)
        ]
    }

    private var filteredShortcuts: [ShortcutRowItem] {
        allShortcuts.filter { item in
            let matchesCategory = (selectedCategory == .all || item.category == selectedCategory)
            if searchText.isEmpty {
                return matchesCategory
            }
            let query = searchText.lowercased()
            return matchesCategory && (item.title.lowercased().contains(query) || item.keys.joined(separator: " ").lowercased().contains(query))
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Image(systemName: "command")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.keyboardShortcutsTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(L10n.tr("Master SilkPlayer playback and controls with native gestures", "使用原生 macOS 快捷键全面掌控 SilkPlayer 播放体验"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Compact Search Input
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 10))
                    TextField(L10n.tr("Search shortcuts...", "搜索快捷键..."), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .frame(width: 130)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Category Segment Capsule Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ShortcutCategory.allCases) { cat in
                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                selectedCategory = cat
                            }
                        }) {
                            Text(cat.title)
                                .font(.system(size: 11, weight: selectedCategory == cat ? .medium : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(selectedCategory == cat ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                                .foregroundColor(selectedCategory == cat ? .accentColor : .secondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedCategory == cat ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }

            Divider()
                .opacity(0.4)

            // Shortcuts List
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredShortcuts) { item in
                        HStack(spacing: 12) {
                            Text(item.title)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)

                            Spacer()

                            HStack(spacing: 4) {
                                ForEach(Array(item.keys.enumerated()), id: \.offset) { _, key in
                                    if key == "/" {
                                        Text("/")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(key)
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.primary.opacity(0.08))
                                            .foregroundColor(.primary.opacity(0.9))
                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 580, height: 440)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
    }
}

@MainActor
public final class ShortcutsCheatsheetManager {
    public static let shared = ShortcutsCheatsheetManager()
    private var windowController: NSWindowController?

    public init() {}

    public func show() {
        if let controller = windowController {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp?.activate(ignoringOtherApps: true)
            return
        }

        let cheatsheetView = ShortcutsCheatsheetView()
        let hostingView = NSHostingView(rootView: cheatsheetView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = L10n.keyboardShortcutsTitle
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentView = hostingView
        window.isReleasedWhenClosed = false

        let controller = NSWindowController(window: window)
        self.windowController = controller
        controller.showWindow(nil)
        NSApp?.activate(ignoringOtherApps: true)
    }
}

