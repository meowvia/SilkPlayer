import AppKit
import SwiftUI

/// Formatter that calculates live dimensions and human-readable aspect ratio.
public struct WindowDimensionFormatter: Sendable {
    public static func format(
        size: CGSize,
        videoWidth: Int = 0,
        videoHeight: Int = 0,
        isAudioOnly: Bool = false
    ) -> (dimensions: String, ratio: String) {
        let w = Int(round(size.width))
        let h = Int(round(size.height))
        let dimStr = "\(w) × \(h)"

        if isAudioOnly {
            return (dimStr, "1:1")
        }

        guard w > 0 && h > 0 else {
            return (dimStr, "")
        }

        let r = Double(w) / Double(h)
        var ratioLabel: String

        // Precision matching against common cinematographic and display aspect ratios:
        if abs(r - (16.0 / 9.0)) <= 0.045 {
            ratioLabel = "16:9"
        } else if abs(r - (16.0 / 10.0)) <= 0.035 {
            ratioLabel = "16:10"
        } else if abs(r - (4.0 / 3.0)) <= 0.035 {
            ratioLabel = "4:3"
        } else if abs(r - 2.39) <= 0.05 || abs(r - 2.35) <= 0.05 {
            ratioLabel = "2.39:1"
        } else if abs(r - (21.0 / 9.0)) <= 0.05 {
            ratioLabel = "21:9"
        } else if abs(r - 1.0) <= 0.03 {
            ratioLabel = "1:1"
        } else if abs(r - (9.0 / 16.0)) <= 0.035 {
            ratioLabel = "9:16"
        } else {
            ratioLabel = String(format: "%.2f:1", r)
        }

        // 100% Native Resolution Pixel-to-Pixel Alignment:
        if videoWidth > 0 && videoHeight > 0 && abs(w - videoWidth) <= 1 && abs(h - videoHeight) <= 1 {
            ratioLabel += " · 100%"
        }

        return (dimStr, ratioLabel)
    }
}

/// AppKit native centered bezel HUD showing live window dimensions and aspect ratio during manual drag resizing.
/// Synchronously drawn in `NSEventTrackingRunLoopMode` on every frame without runloop lag.
@MainActor
public final class WindowResizeHUDView: NSView {
    private let visualEffectView = NSVisualEffectView()
    private let stackView = NSStackView()
    private let dimensionLabel = NSTextField(labelWithString: "")
    private let dividerView = NSView()
    private let ratioLabel = NSTextField(labelWithString: "")
    private let nativeBadge = NSView()
    private let nativeLabel = NSTextField(labelWithString: "100%")

    private var dismissTimer: Timer?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        return nil // Mouse transparent: never intercepts clicks or window drags
    }

    private func setupUI() {
        wantsLayer = true
        layer?.zPosition = 9999
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.40
        layer?.shadowRadius = 14
        layer?.shadowOffset = CGSize(width: 0, height: -3)

        // Frosted glass bezel container
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 12
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.0
        visualEffectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        addSubview(visualEffectView)

        // Stack View
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 9
        stackView.edgeInsets = NSEdgeInsets(top: 7, left: 14, bottom: 7, right: 14)
        visualEffectView.addSubview(stackView)

        // Dimension Label (e.g. "1920 × 1080")
        dimensionLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14.5, weight: .semibold)
        dimensionLabel.textColor = .white
        dimensionLabel.isBezeled = false
        dimensionLabel.drawsBackground = false
        dimensionLabel.isEditable = false
        dimensionLabel.isSelectable = false
        dimensionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        stackView.addArrangedSubview(dimensionLabel)

        // Subtle hairline separator
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.wantsLayer = true
        dividerView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.22).cgColor
        dividerView.widthAnchor.constraint(equalToConstant: 1.0).isActive = true
        dividerView.heightAnchor.constraint(equalToConstant: 13.0).isActive = true
        stackView.addArrangedSubview(dividerView)

        // Aspect Ratio Label (e.g. "16:9")
        ratioLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        ratioLabel.textColor = NSColor(white: 1.0, alpha: 0.85)
        ratioLabel.isBezeled = false
        ratioLabel.drawsBackground = false
        ratioLabel.isEditable = false
        ratioLabel.isSelectable = false
        ratioLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        stackView.addArrangedSubview(ratioLabel)

        // Native 100% Badge
        setupNativeBadge()
        stackView.addArrangedSubview(nativeBadge)
        nativeBadge.isHidden = true

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
        ])
    }

    private func setupNativeBadge() {
        nativeBadge.translatesAutoresizingMaskIntoConstraints = false
        nativeBadge.wantsLayer = true
        nativeBadge.layer?.cornerRadius = 4.0
        nativeBadge.layer?.masksToBounds = true
        nativeBadge.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.22).cgColor
        nativeBadge.layer?.borderWidth = 1.0
        nativeBadge.layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.45).cgColor

        nativeLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeLabel.stringValue = "100%"
        nativeLabel.font = NSFont.systemFont(ofSize: 10, weight: .bold)
        nativeLabel.textColor = NSColor.systemGreen
        nativeLabel.isBezeled = false
        nativeLabel.drawsBackground = false
        nativeLabel.isEditable = false
        nativeLabel.isSelectable = false

        nativeBadge.addSubview(nativeLabel)
        NSLayoutConstraint.activate([
            nativeLabel.leadingAnchor.constraint(equalTo: nativeBadge.leadingAnchor, constant: 5),
            nativeLabel.trailingAnchor.constraint(equalTo: nativeBadge.trailingAnchor, constant: -5),
            nativeLabel.topAnchor.constraint(equalTo: nativeBadge.topAnchor, constant: 1.5),
            nativeLabel.bottomAnchor.constraint(equalTo: nativeBadge.bottomAnchor, constant: -1.5),
        ])
    }

    public func update(size: CGSize, videoWidth: Int, videoHeight: Int, isAudioOnly: Bool) {
        let formatted = WindowDimensionFormatter.format(
            size: size,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            isAudioOnly: isAudioOnly
        )

        dimensionLabel.stringValue = formatted.dimensions

        if formatted.ratio.contains("· 100%") {
            let cleanRatio = formatted.ratio.replacingOccurrences(of: " · 100%", with: "")
            ratioLabel.stringValue = cleanRatio
            nativeBadge.isHidden = false
        } else {
            ratioLabel.stringValue = formatted.ratio
            nativeBadge.isHidden = true
        }

        dividerView.isHidden = formatted.ratio.isEmpty
        layoutSubtreeIfNeeded()
    }

    public func show(size: CGSize, videoWidth: Int, videoHeight: Int, isAudioOnly: Bool) {
        dismissTimer?.invalidate()
        dismissTimer = nil

        update(size: size, videoWidth: videoWidth, videoHeight: videoHeight, isAudioOnly: isAudioOnly)

        // Ensure brought to front
        if let superview = self.superview {
            superview.addSubview(self, positioned: .above, relativeTo: nil)
        }

        isHidden = false
        if alphaValue < 1.0 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.1
                self.animator().alphaValue = 1.0
            }
        }
    }

    public func dismiss(afterDelay delay: TimeInterval = 0.35, duration: TimeInterval = 0.25) {
        dismissTimer?.invalidate()
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = duration
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    self.animator().alphaValue = 0.0
                }, completionHandler: {
                    MainActor.assumeIsolated {
                        if self.alphaValue <= 0.01 {
                            self.isHidden = true
                        }
                    }
                })
            }
        }
        self.dismissTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    public func hideImmediately() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        alphaValue = 0.0
        isHidden = true
    }
}
