import SwiftUI
import AppKit
import SilkCoreKit

// MARK: - Instant Responsive Micro-Tooltip Modifier
@MainActor
public struct HUDMicroTooltipModifier: ViewModifier {
    let text: String
    var edge: VerticalEdge = .top
    var horizontalAlignment: HorizontalAlignment = .center

    @State private var isHovered: Bool = false
    @State private var isVisible: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil

    private var resolvedAlignment: Alignment {
        switch (edge, horizontalAlignment) {
        case (.top, .leading): return .topLeading
        case (.top, .trailing): return .topTrailing
        case (.top, _): return .top
        case (.bottom, .leading): return .bottomLeading
        case (.bottom, .trailing): return .bottomTrailing
        case (.bottom, _): return .bottom
        }
    }

    public func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovered = hovering
                timerTask?.cancel()
                if hovering && !text.isEmpty {
                    timerTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.20s natural debounce
                        guard !Task.isCancelled, isHovered else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            isVisible = true
                        }
                    }
                } else {
                    timerTask?.cancel()
                    if isVisible {
                        withAnimation(.easeIn(duration: 0.10)) {
                            isVisible = false
                        }
                    }
                }
            }
            .overlay(alignment: resolvedAlignment) {
                if isVisible && !text.isEmpty {
                    Text(text)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 7.5)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.black.opacity(0.72))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.6)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)
                        .offset(y: edge == .top ? -32 : 34)
                        .allowsHitTesting(false)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                        .zIndex(9999)
                }
            }
    }
}

extension View {
    @MainActor
    public func hudTooltip(
        _ text: String,
        edge: VerticalEdge = .top,
        horizontalAlignment: HorizontalAlignment = .center
    ) -> some View {
        self.modifier(
            HUDMicroTooltipModifier(
                text: text,
                edge: edge,
                horizontalAlignment: horizontalAlignment
            )
        )
    }
}

@MainActor
public struct SilkFluidSpringButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.94
    var pressedOpacity: CGFloat = 0.88

    public init(pressedScale: CGFloat = 0.94, pressedOpacity: CGFloat = 0.88) {
        self.pressedScale = pressedScale
        self.pressedOpacity = pressedOpacity
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

@MainActor
struct HUDTransportButton: View {
    let icon: String
    var size: CGFloat = 14
    var weight: Font.Weight = .regular
    var color: Color = .white
    var disabled: Bool = false
    var helpText: String = ""
    var tooltipHorizontalAlignment: HorizontalAlignment = .center
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: weight))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.12 : 0.0))
                )
                .contentShape(Circle())
        }
        .buttonStyle(SilkFluidSpringButtonStyle(pressedScale: 0.93, pressedOpacity: 0.86))
        .frame(width: 28, height: 28)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : (isHovered ? 1.0 : 0.88))
        .scaleEffect(isHovered && !disabled ? 1.08 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .hudTooltip(helpText, edge: .top, horizontalAlignment: tooltipHorizontalAlignment)
        .help(helpText)
    }
}

@MainActor
struct HUDMenuButton<Content: View>: View {
    let icon: String
    var size: CGFloat = 14
    var weight: Font.Weight = .medium
    var color: Color = .white
    var isActive: Bool = false
    var helpText: String = ""
    var tooltipHorizontalAlignment: HorizontalAlignment = .center
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size, weight: weight))
                .foregroundColor(isActive ? .cyan : color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.14 : (isActive ? 0.10 : 0.0)))
                )
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .fixedSize()
        .opacity(isHovered || isActive ? 1.0 : 0.88)
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .hudTooltip(helpText, edge: .top, horizontalAlignment: tooltipHorizontalAlignment)
        .help(helpText)
    }
}

@MainActor
struct HUDMoreMenuButton<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.90))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(isHovered ? 0.14 : 0.0))
                )
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .fixedSize()
        .opacity(isHovered ? 1.0 : 0.88)
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .hudTooltip(L10n.tr("More Controls", "更多控制"), edge: .top)
        .help("更多控制")
    }
}

@MainActor
struct HUDSpeedMenuButton: View {
    @ObservedObject var player: PlayerCore
    @State private var isHovered = false
    @AppStorage(SilkLibraryTheme.userDefaultsKey) private var selectedThemeRaw: String = SilkLibraryTheme.shenghui.rawValue

    private var isWarmWhiteMusic: Bool {
        player.isAudioOnly && selectedThemeRaw == SilkLibraryTheme.nuanbai.rawValue
    }

    var body: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                Button(abs(player.speed - rate) < 0.04 ? "✓ \(String(format: "%.2fx", rate))\(rate == 1.0 ? " (" + L10n.speedNormal + ")" : "")" : "\(String(format: "%.2fx", rate))\(rate == 1.0 ? " (" + L10n.speedNormal + ")" : "")") {
                    player.setSpeed(rate)
                }
            }
        } label: {
            Text(speedPillText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(
                    player.speed != 1.0
                        ? (isWarmWhiteMusic ? SilkLibraryTheme.nuanbai.accentColor : .cyan)
                        : (isWarmWhiteMusic ? SilkLibraryTheme.nuanbai.primaryText : .white.opacity(0.88))
                )
                .frame(minWidth: 32)
                .frame(height: 26)
                .padding(.horizontal, 4)
                .background(
                    Capsule()
                        .fill(
                            isWarmWhiteMusic
                                ? (player.speed != 1.0 ? SilkLibraryTheme.nuanbai.accentColor.opacity(0.15) : (isHovered ? SilkLibraryTheme.nuanbai.pillSurface : Color.clear))
                                : Color.white.opacity(isHovered ? 0.14 : (player.speed != 1.0 ? 0.12 : 0.06))
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isWarmWhiteMusic
                                ? (player.speed != 1.0 ? SilkLibraryTheme.nuanbai.accentColor.opacity(0.4) : SilkLibraryTheme.nuanbai.borderColor)
                                : (player.speed != 1.0 ? Color.cyan.opacity(0.4) : Color.white.opacity(0.15)),
                            lineWidth: 0.6
                        )
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .scaleEffect(isHovered ? 1.06 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .hudTooltip(L10n.tr("Playback Speed (Click to choose)", "倍速播放 (点击选择常规倍速)"), edge: .top)
        .help(L10n.tr("Playback Speed: \(String(format: "%.2fx", player.speed)) (Click to choose)", "倍速播放: \(String(format: "%.2fx", player.speed)) (点击选择常规倍速)"))
    }

    private var speedPillText: String {
        if player.speed == 1.0 {
            return "1.0x"
        } else if player.speed.truncatingRemainder(dividingBy: 0.1) < 0.01 {
            return String(format: "%.1fx", player.speed)
        } else {
            return String(format: "%.2fx", player.speed)
        }
    }
}

@MainActor
struct HUDCircleButton: View {
    let icon: String
    var isActive: Bool = false
    var helpText: String = ""
    var tooltipHorizontalAlignment: HorizontalAlignment = .center
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isActive ? .cyan : .white.opacity(0.92))
                .frame(width: 30, height: 30)
                .background(
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                        if isActive {
                            Circle()
                                .fill(Color.cyan.opacity(0.25))
                        } else {
                            Circle()
                                .fill(Color.black.opacity(0.20))
                        }
                    }
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isActive
                                ? Color.cyan.opacity(0.65)
                                : Color.white.opacity(isHovered ? 0.35 : 0.18),
                            lineWidth: 0.75
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                .scaleEffect(isHovered ? 1.06 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isHovered)
        }
        .buttonStyle(SilkFluidSpringButtonStyle(pressedScale: 0.93, pressedOpacity: 0.88))
        .onHover { hovering in
            isHovered = hovering
        }
        .hudTooltip(helpText, edge: .bottom, horizontalAlignment: tooltipHorizontalAlignment)
        .help(helpText)
    }
}
