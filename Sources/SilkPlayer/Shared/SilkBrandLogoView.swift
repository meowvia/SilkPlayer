import SwiftUI

/// Pure vector brand emblem for SilkPlayer, designed to reflect the "Silk" (fluidity)
/// and "Metal" (native hardware acceleration) identity without any artificial AI clutter.
@MainActor
public struct SilkBrandLogoView: View {
    public var size: CGFloat = 84
    public var isInteractive: Bool = true
    
    @State private var isHovered: Bool = false
    @State private var subtleGlow: Bool = false
    
    public init(size: CGFloat = 84, isInteractive: Bool = true) {
        self.size = size
        self.isInteractive = isInteractive
    }
    
    public var body: some View {
        ZStack {
            // Ambient Sapphire Glow behind the squircle
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(isHovered ? 0.35 : (subtleGlow ? 0.25 : 0.15)),
                            Color.blue.opacity(isHovered ? 0.20 : 0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.3, height: size * 1.3)
                .blur(radius: size * 0.18)

            // Outer Apple Squircle Substrate (Midnight Obsidian)
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
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
                        colors: [
                            Color.white.opacity(isHovered ? 0.40 : 0.25),
                            Color.white.opacity(0.08),
                            Color.cyan.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.0, size * 0.015)
                )
                .frame(width: size, height: size)

            // Flowing Silk Arc Loop
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    LinearGradient(
                        colors: [
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
                        colors: [
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
                .shadow(color: Color.cyan.opacity(0.4), radius: size * 0.08, x: 0, y: 0)
                .shadow(color: Color.black.opacity(0.35), radius: size * 0.05, x: 0, y: size * 0.02)
        }
        .scaleEffect(isInteractive && isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                subtleGlow = true
            }
        }
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
