import SwiftUI
import AppKit

@MainActor
struct HUDVolumeSlider: View {
    @ObservedObject var player: PlayerCore
    @State private var isHovered = false
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: { player.toggleMute() }) {
                Image(systemName: volumeIconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(player.isMuted ? Color(nsColor: .systemRed) : .white.opacity(0.92))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(isHovered ? 0.12 : 0.0))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio)
            .help("\(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio) (M)")

            GeometryReader { geo in
                let maxLimit = AppSettings.shared.maxVolumeLimit
                let currentVol = player.isMuted ? 0.0 : player.volume
                let fraction = CGFloat(max(0.0, min(maxLimit, currentVol)) / maxLimit)
                let isExpanded = isHovered || isDragging
                let height: CGFloat = isExpanded ? 6.0 : 4.0
                let knobSize: CGFloat = isExpanded ? 11.0 : 8.0

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.35))
                        .frame(height: height)

                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: height)

                    Capsule()
                        .fill(
                            player.isMuted
                                ? LinearGradient(colors: [Color.red.opacity(0.85), Color.red.opacity(0.65)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.white, Color.cyan.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * fraction)), height: height)

                    if isExpanded {
                        Circle()
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                            .frame(width: knobSize, height: knobSize)
                            .offset(x: max(0, min(geo.size.width - knobSize, geo.size.width * fraction - (knobSize / 2.0))))
                            .transition(.scale.combined(with: .opacity))
                    }
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
            .frame(width: 72, height: 18)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isHovered)
            .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isDragging)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.volumeSlider)
        .accessibilityValue("\(Int(player.isMuted ? 0 : player.volume))%")
    }

    private var volumeIconName: String {
        if player.isMuted || player.volume <= 0 {
            return "speaker.slash.fill"
        } else if player.volume < 40 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
}
