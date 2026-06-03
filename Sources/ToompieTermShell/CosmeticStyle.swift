import SwiftUI

struct HoverScale: ViewModifier {
    @State private var hovering = false
    var scale: CGFloat = 1.03
    var lift: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1.0)
            .brightness(hovering ? 0.05 : 0)
            .shadow(color: .black.opacity(hovering && lift ? 0.25 : 0), radius: hovering && lift ? 10 : 0, y: hovering && lift ? 5 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverScale(_ scale: CGFloat = 1.03, lift: Bool = false) -> some View {
        modifier(HoverScale(scale: scale, lift: lift))
    }

    func softShadow() -> some View {
        shadow(color: .black.opacity(0.22), radius: 9, x: 0, y: 4)
    }
}

struct PulsingDot: View {
    let color: Color
    let active: Bool
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(active ? color : Color.gray)
            .frame(width: 7, height: 7)
            .scaleEffect(active && pulse ? 1.4 : 1.0)
            .shadow(color: active ? color.opacity(0.9) : .clear, radius: active ? 4 : 0)
            .animation(active ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)
            .onAppear { pulse = true }
    }
}

struct DecorBlobs: View {
    let accent: Color
    var parallax: CGSize = .zero

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                blob(accent, t: t, phase: 0, radius: 260, depth: 1.0)
                blob(.blue, t: t, phase: 2.1, radius: 220, depth: 1.6)
                blob(.purple, t: t, phase: 4.2, radius: 240, depth: 0.7)
                blob(.teal, t: t, phase: 1.1, radius: 180, depth: 2.0)
            }
            .blur(radius: 70)
            .opacity(0.30)
        }
        .allowsHitTesting(false)
    }

    private func blob(_ color: Color, t: Double, phase: Double, radius: CGFloat, depth: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: radius, height: radius)
            .offset(
                x: CGFloat(cos(t * 0.18 + phase)) * 150 + parallax.width * depth,
                y: CGFloat(sin(t * 0.23 + phase)) * 130 + parallax.height * depth
            )
    }
}

struct CRTOverlay: View {
    var body: some View {
        ZStack {
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height {
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1.0)), with: .color(.black.opacity(0.18)))
                    y += 3
                }
            }
            .blendMode(.multiply)
            RadialGradient(colors: [.clear, .black.opacity(0.05), .black.opacity(0.45)], center: .center, startRadius: 60, endRadius: 700)
        }
        .allowsHitTesting(false)
    }
}

struct AnimatedBorder: ViewModifier {
    let active: Bool
    let cornerRadius: CGFloat
    let color: Color

    func body(content: Content) -> some View {
        content.overlay {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            if active {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                    let angle = Angle.degrees((ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3) * 360)
                    shape.strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [color, color.opacity(0.2), color.opacity(0.7), color.opacity(0.2), color]),
                            center: .center,
                            angle: angle
                        ),
                        lineWidth: 2
                    )
                }
            } else {
                shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
        }
    }
}

extension View {
    func animatedBorder(active: Bool, cornerRadius: CGFloat = 12, color: Color = .accentColor) -> some View {
        modifier(AnimatedBorder(active: active, cornerRadius: cornerRadius, color: color))
    }
}

struct SectionTitle: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    LinearGradient(colors: [tint, tint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .softShadow()
            Text(title).font(.headline)
            Spacer(minLength: 0)
        }
    }
}

struct ShimmerAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(
                    LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .hoverScale(1.12)
    }
}
