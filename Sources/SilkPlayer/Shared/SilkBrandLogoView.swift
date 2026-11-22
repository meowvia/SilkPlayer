import SwiftUI
import SilkCoreKit

/// Pure vector brand emblem for SilkPlayer, designed to reflect the "Silk" (fluidity)
/// and "Metal" (native hardware acceleration) identity without any artificial AI clutter.
@MainActor
public struct SilkBrandLogoView: View {
    public var size: CGFloat = 84
    public var isInteractive: Bool = true
    public var forceProTheme: Bool? = nil
    
    @ObservedObject private var licenseEngine = SilkProLicenseEngine.shared
    @State private var isHovered: Bool = false
    
    public init(size: CGFloat = 84, isInteractive: Bool = true, forceProTheme: Bool? = nil) {
        self.size = size
        self.isInteractive = isInteractive
        self.forceProTheme = forceProTheme
    }

    private var isPro: Bool {
        forceProTheme ?? licenseEngine.isProActive
    }
    
    public var body: some View {
        ZStack {
            // Ambient Glow behind the squircle
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: isPro ? [
                            Color(red: 0.96, green: 0.62, blue: 0.15).opacity(isHovered ? 0.35 : 0.18),
                            Color(red: 0.85, green: 0.47, blue: 0.21).opacity(isHovered ? 0.20 : 0.08),
                            Color.clear
                        ] : [
                            Color.cyan.opacity(isHovered ? 0.35 : 0.15),
                            Color.blue.opacity(isHovered ? 0.20 : 0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.3, height: size * 1.3)
                .blur(radius: size * 0.18)
                .animation(.easeOut(duration: 0.25), value: isHovered)

            // Outer Apple Squircle Substrate
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isPro ? [
                            Color(red: 0.23, green: 0.19, blue: 0.16), // #3a3028 warm walnut
                            Color(red: 0.14, green: 0.11, blue: 0.09)  // #231c16 deep espresso
                        ] : [
                            Color(red: 0.11, green: 0.13, blue: 0.18),
                            Color(red: 0.05, green: 0.06, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.45), radius: size * 0.14, x: 0, y: size * 0.06)

            // Specular Chamfer Rim
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isPro ? [
                            Color(red: 0.85, green: 0.47, blue: 0.21).opacity(isHovered ? 0.65 : 0.45),
                            Color.white.opacity(isHovered ? 0.25 : 0.12),
                            Color(red: 0.76, green: 0.37, blue: 0.14).opacity(0.35)
                        ] : [
                            Color.cyan.opacity(isHovered ? 0.35 : 0.22),
                            Color.white.opacity(isHovered ? 0.12 : 0.05),
                            Color.blue.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
                .frame(width: size, height: size)

            // Flowing Silk Arc Loop
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    LinearGradient(
                        colors: isPro ? [
                            Color(red: 0.98, green: 0.75, blue: 0.25).opacity(0.95), // gold amber
                            Color(red: 0.85, green: 0.47, blue: 0.21).opacity(0.85), // terracotta
                            Color(red: 0.60, green: 0.20, blue: 0.07).opacity(0.20)  // deep burnt orange
                        ] : [
                            Color.cyan.opacity(0.85),
                            Color.blue.opacity(0.40),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round)
                )
                .frame(width: size * 0.58, height: size * 0.58)
                .rotationEffect(.degrees(isHovered ? 45 : 15))
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: isHovered)

            // Pure Minimalist Play Glyph (Silk Gradient Facet)
            PlayTriangleShape()
                .fill(
                    LinearGradient(
                        colors: isPro ? [
                            Color.white,
                            Color(red: 1.0, green: 0.97, blue: 0.93),
                            Color(red: 0.99, green: 0.84, blue: 0.67)
                        ] : [
                            Color.white,
                            Color(red: 0.85, green: 0.94, blue: 1.0),
                            Color.cyan.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.36, height: size * 0.38)
                .offset(x: size * 0.035) // Optical center offset
                .shadow(
                    color: isPro ? Color(red: 0.85, green: 0.47, blue: 0.21).opacity(0.4) : Color.cyan.opacity(0.4),
                    radius: size * 0.08,
                    x: 0,
                    y: 0
                )
                .shadow(color: Color.black.opacity(0.35), radius: size * 0.05, x: 0, y: size * 0.02)
        }
        .scaleEffect(isInteractive && isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
        .onHover { hovering in
            if isInteractive {
                isHovered = hovering
            }
        }
    }
}

/// Pure geometric rounded play triangle
private struct PlayTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = rect.width * 0.18
        
        // Vertices
        let pTip = CGPoint(x: rect.maxX, y: rect.midY)
        let pTop = CGPoint(x: rect.minX, y: rect.minY)
        let pBot = CGPoint(x: rect.minX, y: rect.maxY)
        
        // Rounded path
        path.move(to: CGPoint(x: pTop.x + radius, y: pTop.y))
        path.addArc(tangent1End: pTop, tangent2End: pBot, radius: radius)
        path.addArc(tangent1End: pBot, tangent2End: pTip, radius: radius)
        path.addArc(tangent1End: pTip, tangent2End: pTop, radius: radius)
        path.closeSubpath()
        return path
    }
}
