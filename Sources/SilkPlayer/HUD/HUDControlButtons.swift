import SwiftUI
import AppKit

@MainActor
struct HUDTransportButton: View {
    let icon: String
    var size: CGFloat = 14
    var weight: Font.Weight = .regular
    var color: Color = .white
    var disabled: Bool = false
    var helpText: String = ""
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
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : (isHovered ? 1.0 : 0.88))
        .scaleEffect(isHovered && !disabled ? 1.08 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
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
        .help("更多控制")
    }
}

@MainActor
struct HUDSpeedMenuButton: View {
    @ObservedObject var player: PlayerCore
    @State private var isHovered = false

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
                .foregroundColor(player.speed != 1.0 ? .cyan : .white.opacity(0.88))
                .frame(minWidth: 32)
                .frame(height: 26)
                .padding(.horizontal, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(isHovered ? 0.14 : (player.speed != 1.0 ? 0.12 : 0.06)))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(player.speed != 1.0 ? Color.cyan.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 0.6)
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
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(helpText)
    }
}
