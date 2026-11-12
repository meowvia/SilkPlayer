import SwiftUI
import AppKit

@MainActor
struct HUDVolumeSlider: View {
    @ObservedObject var player: PlayerCore
    var expandVertically: Bool = false

    @State private var isButtonHovered = false
    @State private var isOverlayHovered = false
    @State private var isDragging = false
    @State private var isHoverExpanded = false
    @State private var collapseTask: Task<Void, Never>? = nil

    private var isExpanded: Bool {
        isHoverExpanded || isDragging
    }

    var body: some View {
        Group {
            if expandVertically {
                muteButton
                    .frame(width: 28, height: 28)
                    .onHover { hovering in
                        isButtonHovered = hovering
                        syncHoverExpansion()
                    }
                    .overlay(alignment: .bottom) {
                        if isExpanded {
                            verticalSliderPopover
                                .padding(.bottom, 28)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.85, anchor: .bottom).combined(with: .opacity),
                                    removal: .scale(scale: 0.85, anchor: .bottom).combined(with: .opacity)
                                ))
                        }
                    }
                    .zIndex(isExpanded ? 50 : 0)
            } else {
                HStack(spacing: isExpanded ? 6 : 0) {
                    muteButton

                    if isExpanded {
                        horizontalSliderBody
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
                        isButtonHovered = hovering
                        isHoverExpanded = hovering
                    }
                }
            }
        }
        .onDisappear {
            collapseTask?.cancel()
            collapseTask = nil
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.volumeSlider)
        .accessibilityValue("\(Int(player.isMuted ? 0 : player.volume))%")
    }

    @ViewBuilder
    private var muteButton: some View {
        let base = Button(action: { player.toggleMute() }) {
            Image(systemName: volumeIconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity((isButtonHovered && !isExpanded) ? 0.12 : 0.0))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio)
        .help("\(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio) (M)")

        if expandVertically {
            base
        } else {
            base.hudTooltip("\(player.isMuted ? L10n.unmuteAudio : L10n.muteAudio) (M)", edge: .top)
        }
    }

    private var verticalSliderPopover: some View {
        VStack(spacing: 4) {
            verticalSliderBody
                .frame(width: 20, height: 76)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(width: 32, height: 92)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.68))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
        .contentShape(Capsule())
        .onHover { hovering in
            isOverlayHovered = hovering
            syncHoverExpansion()
        }
    }

    private func syncHoverExpansion() {
        collapseTask?.cancel()
        collapseTask = nil

        if isButtonHovered || isOverlayHovered {
            if !isHoverExpanded {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                    isHoverExpanded = true
                }
            }
            return
        }

        // Brief grace period avoids collapsing when the cursor crosses from speaker icon into the vertical popup.
        collapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }
            if !isButtonHovered && !isOverlayHovered {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                    isHoverExpanded = false
                }
            }
        }
    }

    private func updateVolume(fraction rawFraction: CGFloat) {
        isDragging = true
        if player.isMuted {
            player.toggleMute()
        }
        let maxLimit = AppSettings.shared.maxVolumeLimit
        let clamped = max(0.0, min(1.0, rawFraction))
        player.setVolume(Double(clamped * maxLimit), maxLimit: maxLimit)
    }

    private var currentVolumeFraction: CGFloat {
        let maxLimit = AppSettings.shared.maxVolumeLimit
        let currentVol = player.isMuted ? 0.0 : player.volume
        return CGFloat(max(0.0, min(maxLimit, currentVol)) / maxLimit)
    }

    private var horizontalSliderBody: some View {
        GeometryReader { geo in
            let fraction = currentVolumeFraction
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
                    .fill(trackGradient(startPoint: .leading, endPoint: .trailing))
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
                        updateVolume(fraction: value.location.x / max(1.0, geo.size.width))
                    }
                    .onEnded { _ in
                        isDragging = false
                        if expandVertically { syncHoverExpansion() }
                    }
            )
        }
    }

    private var verticalSliderBody: some View {
        GeometryReader { geo in
            let fraction = currentVolumeFraction
            let width: CGFloat = 4.0
            let knobSize: CGFloat = 10.0

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: width)

                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: width)

                Capsule()
                    .fill(trackGradient(startPoint: .bottom, endPoint: .top))
                    .frame(width: width, height: max(0, min(geo.size.height, geo.size.height * fraction)))

                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .offset(y: -max(0, min(geo.size.height - knobSize, (geo.size.height - knobSize) * fraction)))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateVolume(fraction: 1.0 - (value.location.y / max(1.0, geo.size.height)))
                    }
                    .onEnded { _ in
                        isDragging = false
                        syncHoverExpansion()
                    }
            )
        }
    }

    private func trackGradient(startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
        if player.isMuted {
            return LinearGradient(
                colors: [Color.red.opacity(0.85), Color.red.opacity(0.65)],
                startPoint: startPoint,
                endPoint: endPoint
            )
        } else if player.volume > 100 {
            return LinearGradient(
                colors: [Color.cyan.opacity(0.85), Color.orange],
                startPoint: startPoint,
                endPoint: endPoint
            )
        } else {
            return LinearGradient(
                colors: [Color.white, Color.cyan.opacity(0.85)],
                startPoint: startPoint,
                endPoint: endPoint
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
