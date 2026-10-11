import SwiftUI
import AppKit

/// Sleek vertical hidden volume bar positioned at the right edge of the player canvas.
/// Matches the visual language and interaction precision of the playback scrubber.
@MainActor
public struct SilkVerticalVolumeBarView: View {
    @ObservedObject var player: PlayerCore
    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false

    private let maxLimit: Double = AppSettings.shared.maxVolumeLimit

    public init(player: PlayerCore) {
        self.player = player
    }

    public var body: some View {
        let isMuted = player.isMuted
        let currentVol = isMuted ? 0.0 : player.volume
        let isBoosted = currentVol > 100.0
        let fraction = CGFloat(max(0.0, min(maxLimit, currentVol)) / maxLimit)
        let isExpanded = isHovered || isDragging

        VStack(spacing: 8) {
            // 1. Dynamic Speaker Icon Button (Mute / Unmute Toggle)
            Button(action: {
                player.toggleMute()
                player.keepVolumeHUDAlive()
            }) {
                Image(systemName: speakerIconName(vol: currentVol, isMuted: isMuted))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isMuted ? Color(nsColor: .systemRed) : (isBoosted ? .orange : .white))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(Color.white.opacity(isHovered ? 0.12 : 0.0))
                    )
            }
            .buttonStyle(.plain)
            .help(isMuted ? L10n.unmuteAudio : L10n.muteAudio)

            // 2. Real-Time Volume Percentage Badge (Translucent & unobtrusive)
            Text(isMuted ? L10n.muteAudio : (isBoosted ? "\(Int(currentVol))%" : "\(Int(currentVol))%"))
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(isMuted ? Color(nsColor: .systemRed) : (isBoosted ? .orange : .white.opacity(0.90)))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color.black.opacity(0.18))
                )

            // 3. Vertical Interactive Volume Track (Matching PlayerScrubberView form factor)
            GeometryReader { geo in
                let trackWidth: CGFloat = isExpanded ? 7.0 : 4.5
                let totalHeight = geo.size.height
                let fillHeight = max(0, min(totalHeight, totalHeight * fraction))
                let knobSize: CGFloat = isExpanded ? 13.0 : 9.5

                ZStack(alignment: .bottom) {
                    // Base Inactive Track (Sheer glass transparency)
                    Capsule()
                        .fill(Color.black.opacity(0.20))
                        .frame(width: trackWidth, height: totalHeight)

                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: trackWidth, height: totalHeight)

                    // 100% Benchmark Mark Line (if maxLimit > 100)
                    if maxLimit > 100.0 {
                        let benchmarkY = totalHeight * (1.0 - CGFloat(100.0 / maxLimit))
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: trackWidth + 4, height: 1.0)
                            .position(x: geo.size.width / 2.0, y: benchmarkY)
                    }

                    // Active Filled Level Track (Bottom to Top)
                    Capsule()
                        .fill(
                            isMuted
                                ? LinearGradient(colors: [Color.red.opacity(0.85), Color.red.opacity(0.55)], startPoint: .bottom, endPoint: .top)
                                : (isBoosted
                                    ? LinearGradient(colors: [Color.orange.opacity(0.95), Color.yellow.opacity(0.90)], startPoint: .bottom, endPoint: .top)
                                    : LinearGradient(colors: [Color.cyan.opacity(0.95), Color.blue.opacity(0.75)], startPoint: .bottom, endPoint: .top))
                        )
                        .frame(width: trackWidth, height: fillHeight)

                    // Interactive Knob
                    Circle()
                        .fill(Color.white)
                        .overlay(
                            Circle()
                                .strokeBorder(isBoosted ? Color.orange : Color.cyan.opacity(0.85), lineWidth: isExpanded ? 1.0 : 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: isExpanded ? 4 : 2, x: 0, y: 1)
                        .frame(width: knobSize, height: knobSize)
                        .offset(y: -(fillHeight - (knobSize / 2.0)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            player.keepVolumeHUDAlive()
                            if player.isMuted {
                                player.isMuted = false
                            }
                            // Calculate fraction from bottom (Y = 0 is top, Y = totalHeight is bottom)
                            let touchYFromBottom = max(0.0, min(totalHeight, totalHeight - value.location.y))
                            let newFraction = Double(touchYFromBottom / totalHeight)
                            let newVol = round(newFraction * maxLimit)
                            player.setVolume(newVol, maxLimit: maxLimit, showOSD: false)
                        }
                        .onEnded { _ in
                            isDragging = false
                            player.scheduleVolumeHUDDismiss()
                        }
                )
            }
            .frame(width: 24, height: 130)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(width: 40)
        .background(
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color.black.opacity(0.14))
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 14, x: -2, y: 3)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                player.keepVolumeHUDAlive()
            } else if !isDragging {
                player.scheduleVolumeHUDDismiss()
            }
        }
    }

    private func speakerIconName(vol: Double, isMuted: Bool) -> String {
        if isMuted || vol <= 0 {
            return "speaker.slash.fill"
        } else if vol > 100 {
            return "speaker.wave.3.fill"
        } else if vol >= 40 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.1.fill"
        }
    }
}
