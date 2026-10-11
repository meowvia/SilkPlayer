import SwiftUI

/// Centralized Apple HIG Animation curves and Accessibility Reduce Motion adaptors for SilkPlayer.
public enum SilkAnimation {
    /// Apple standard natural spring response (0.32s response, 0.82 damping fraction)
    public static let spring: Animation = .spring(response: 0.32, dampingFraction: 0.82)

    /// Snappy spring curve for drawers, sheets, and overlay transitions
    public static let snappy: Animation = .spring(response: 0.28, dampingFraction: 0.85)

    /// Gentle ease for subtle fades and opacity blends
    public static let subtleEase: Animation = .easeInOut(duration: 0.18)

    /// Adaptive spring: resolves to gentle fade when accessibility Reduce Motion is active
    public static func adaptive(reduceMotion: Bool, preferred: Animation = SilkAnimation.spring) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : preferred
    }

    /// Adaptive transition: resolves to simple opacity crossfade when Reduce Motion is active
    public static func transition(reduceMotion: Bool, standard: AnyTransition) -> AnyTransition {
        reduceMotion ? .opacity : standard
    }
}

public extension Animation {
    static var silkSpring: Animation { SilkAnimation.spring }
    static var silkSnappy: Animation { SilkAnimation.snappy }
    static var silkSubtleEase: Animation { SilkAnimation.subtleEase }
}
