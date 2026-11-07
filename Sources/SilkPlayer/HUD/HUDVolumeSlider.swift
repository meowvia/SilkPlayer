import SwiftUI
import AppKit

@MainActor
struct HUDVolumeSlider: View {
    @ObservedObject var player: PlayerCore
    @State private var isHovered = false
    @State private var isDragging = false

    private var isExpanded: Bool {
        isHovered || isDragging
    }

    var body: some View {
        HStack(spacing: isExpanded ? 6 : 0) {
            Button(action: { player.toggleMute() }) {
                Image(systemName: volumeIconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isHovered && !isExpanded ? 0.12 : 0.0))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio)
            .hudTooltip("\(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio) (M)", edge: .top)
            .help("\(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio) (M)")

            if isExpanded {
                sliderBody
                    .frame(width: 72, height: 18)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .leading).combined(with: .opacity),
                        removal: .scale(scale: 0.8, anchor: .leading).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, isExpanded ? 4 : 0)
        .padding(.vertical, 0)
        .frame(width: isExpanded ? nil : 28, height: 28)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(isExpanded ? 0.25 : 0.0))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.volumeSlider)
        .accessibilityValue("\(Int(player.isMuted ? 0 : player.volume))%")
    }

    private var sliderBody: some View {
        GeometryReader { geo in
            let maxLimit = AppSettings.shared.maxVolumeLimit
            let currentVol = player.isMuted ? 0.0 : player.volume
            let fraction = CGFloat(max(0.0, min(maxLimit, currentVol)) / maxLimit)
            let height: CGFloat = 4.0
            let knobSize: CGFloat = 10.0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.35))
                    .frame(height: height)

                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: height)

                Capsule()
                    .fill(trackGradient)
                    .frame(width: max(0, min(geo.size.width, geo.size.width * fraction)), height: height)

                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: max(0, min(geo.size.width - knobSize, geo.size.width * fraction - (knobSize / 2.0))))
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        if player.isMuted {
                            player.toggleMute()
                        }
                        let newFraction = max(0.0, min(1.0, value.location.x / geo.size.width))
                        player.setVolume(Double(newFraction * maxLimit), maxLimit: maxLimit)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }

    private var trackGradient: LinearGradient {
        if player.isMuted {
            return LinearGradient(
                colors: [Color.red.opacity(0.85), Color.red.opacity(0.65)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if player.volume > 100 {
            return LinearGradient(
                colors: [Color.cyan.opacity(0.85), Color.orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white, Color.cyan.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var volumeIconName: String {
        if player.isMuted || player.volume <= 0 {
            return "speaker.slash.fill"
        } else if player.volume < 40 {
            return "speaker.wave.1.fill"
        } else if player.volume <= 100 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private var iconColor: Color {
        if player.isMuted || player.volume <= 0 {
            return Color(nsColor: .systemRed)
        } else if player.volume > 100 {
            return Color.orange
        } else {
            return Color.white.opacity(0.92)
        }
    }
}
