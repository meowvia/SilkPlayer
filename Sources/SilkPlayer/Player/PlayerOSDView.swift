import SwiftUI
import AppKit

/// On-Screen Display (OSD) overlay for volume, seek, and playback status.
@MainActor
public struct PlayerOSDView: View {
    public let notification: OSDNotification

    public init(notification: OSDNotification) {
        self.notification = notification
    }

    public var body: some View {
        Group {
            switch notification {
            case .volume:
                // Volume is now exclusively and elegantly displayed on the right-side vertical HUD
                EmptyView()
            case .seek(let target, let offset, let duration):
                seekHUD(target: target, offset: offset, duration: duration)
            case .playPause(let isPlaying):
                playPauseHUD(isPlaying: isPlaying)
            case .track(let type, let title):
                trackHUD(type: type, title: title)
            case .pictureAdjustment(let name, let value):
                pictureAdjustmentHUD(name: name, value: value)
            case .screenshot(let filename):
                screenshotHUD(filename: filename)
            }
        }
        .allowsHitTesting(false)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.90).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }


    private func screenshotHUD(filename: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("✓ 截图已保存")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)

                Text(filename)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 240, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(Color.black.opacity(0.25))
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.40), radius: 20, x: 0, y: 8)
    }

    // MARK: - Seek OSD HUD
    private func seekHUD(target: Double, offset: Double, duration: Double) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: offset >= 0 ? "forward.fill" : "backward.fill")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(.cyan)

            if abs(offset) > 0.05 {
                Text(String(format: "%@%.1fs", offset >= 0 ? "+" : "", offset))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.18), in: Capsule())

                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.25))
            } else if abs(offset) > 0.0001 {
                Text(offset >= 0 ? L10n.tr("+1 Frame", "+1 帧") : L10n.tr("-1 Frame", "-1 帧"))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.18), in: Capsule())

                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.25))
            }

            Text("\(formatPlaybackTime(target)) / \(formatPlaybackTime(duration))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(Color.black.opacity(0.20))
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.40), radius: 20, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.20), radius: 4, x: 0, y: 1)
    }

    // MARK: - Play / Pause OSD HUD
    private func playPauseHUD(isPlaying: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isPlaying ? "play.fill" : "pause.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18)

            Text(isPlaying ? L10n.play : L10n.pause)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(Color.black.opacity(0.20))
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.40), radius: 20, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.20), radius: 4, x: 0, y: 1)
    }


    // MARK: - Track Selection OSD HUD
    private func trackHUD(type: String, title: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: type == "sub" ? "captions.bubble.fill" : "waveform")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)

            Text(type == "sub" ? L10n.subtitleTrack : L10n.audioTrack)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.16), in: Capsule())

            Divider()
                .frame(height: 14)
                .background(Color.white.opacity(0.25))

            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(Color.black.opacity(0.20))
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.40), radius: 20, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.20), radius: 4, x: 0, y: 1)
    }

    // MARK: - Picture Adjustment OSD HUD
    private func pictureAdjustmentHUD(name: String, value: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)

            Text(name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.white.opacity(0.92))

            Divider()
                .frame(height: 14)
                .background(Color.white.opacity(0.25))

            Text(value)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.16), in: Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(Color.black.opacity(0.20))
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.40), radius: 20, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.20), radius: 4, x: 0, y: 1)
    }
}
