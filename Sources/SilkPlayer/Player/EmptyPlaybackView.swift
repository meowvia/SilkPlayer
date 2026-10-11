import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Empty Playback Canvas for SilkPlayer.
/// Features pure minimalist Apple aesthetics, iridescent Silk ambient backdrops,
/// and instant local / SMB drag-and-drop responsiveness.
@MainActor
public struct EmptyPlaybackView: View {
    var onOpenFile: () -> Void
    var onFileDropped: ((URL) -> Void)?
    var onFilesDropped: (([URL]) -> Void)?

    @State private var isDropTargeted: Bool = false
    @State private var isHoveringLogo: Bool = false

    public init(
        onOpenFile: @escaping () -> Void,
        onFileDropped: ((URL) -> Void)? = nil,
        onFilesDropped: (([URL]) -> Void)? = nil
    ) {
        self.onOpenFile = onOpenFile
        self.onFileDropped = onFileDropped
        self.onFilesDropped = onFilesDropped
    }

    public var body: some View {
        ZStack {
            // 1. Vibrancy Material Base
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)

            // 2. Ambient Gradient & Vignette
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.cyan.opacity(isHoveringLogo ? 0.16 : 0.08),
                    Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.45),
                    Color(red: 0.03, green: 0.04, blue: 0.07).opacity(0.88)
                ]),
                center: .center,
                startRadius: 40,
                endRadius: 540
            )
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.35), value: isHoveringLogo)

            // 3. Top Specular Highlight Line
            VStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color.white.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                Spacer()
            }
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(false)

            // 3.5 Native Window Background Drag Canvas (padded by 12pt to preserve all 4 edge & 4 corner resize handles)
            WindowDragGestureView()
                .padding(12)
                .edgesIgnoringSafeArea(.all)

            // 4. Centered Interactive Logo (Pure Minimalist Entrypoint)
            Button(action: onOpenFile) {
                SilkBrandLogoView(size: 104, isInteractive: true)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .focusEffectDisabled()
            .onHover { hovering in
                isHoveringLogo = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .help(L10n.tr("Open Media File (⌘O)", "打开媒体文件 (⌘O)"))
            .accessibilityLabel(L10n.openFile)

            // 5. Drag & Drop Active Overlay
            if isDropTargeted {
                dragDropOverlay
            }
        }
        .frame(minWidth: 640, minHeight: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Native Drag and Drop handling
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            guard !providers.isEmpty else { return false }
            Task { @MainActor in
                var collectedURLs: [URL] = []
                for provider in providers {
                    let url: URL? = await withCheckedContinuation { continuation in
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            continuation.resume(returning: url)
                        }
                    }
                    if let url = url {
                        collectedURLs.append(url)
                    }
                }
                guard !collectedURLs.isEmpty else { return }
                if let onFilesDropped = self.onFilesDropped {
                    onFilesDropped(collectedURLs)
                } else if let onFileDropped = self.onFileDropped, let first = collectedURLs.first {
                    onFileDropped(first)
                }
            }
            return true
        }
        .onDisappear {
            if isHoveringLogo {
                NSCursor.pop()
                isHoveringLogo = false
            }
        }
    }

    // MARK: - Drag & Drop Active Overlay
    private var dragDropOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .edgesIgnoringSafeArea(.all)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.cyan,
                            Color.blue.opacity(0.8),
                            Color.cyan.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2.2, dash: [9, 5])
                )
                .shadow(color: Color.cyan.opacity(0.60), radius: 24, x: 0, y: 0)
                .padding(24)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.20))
                        .frame(width: 72, height: 72)
                        .blur(radius: 8)

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.cyan],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(spacing: 4) {
                    Text(L10n.dropToPlay)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    Text(L10n.dragVideoHerePrompt)
                        .font(.system(size: 12.5))
                        .foregroundColor(.white.opacity(0.70))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.30))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 8)
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .animation(.snappy(duration: 0.20), value: isDropTargeted)
    }
}

/// Transparent NSViewRepresentable allowing window dragging from anywhere in empty canvas.
public struct WindowDragGestureView: NSViewRepresentable {
    public init() {}
    public func makeNSView(context: Context) -> WindowDragCanvasView {
        WindowDragCanvasView()
    }
    public func updateNSView(_ nsView: WindowDragCanvasView, context: Context) {}
}

public final class WindowDragCanvasView: NSView {
    override public func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
