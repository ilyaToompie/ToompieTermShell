import AppKit
import SwiftUI

/// Animated, procedurally-drawn background styles. Distinct from the particle
/// `WeatherEffect` overlays: these *are* the base layer and animate continuously.
/// Everything here is macOS-14 friendly (Canvas + TimelineView, no MeshGradient).
enum LiveBackground: String, CaseIterable, Identifiable {
    case aurora
    case nebula
    case plasma
    case lavalamp
    case mesh
    case starfield
    case waves
    case gradientFlow

    var id: String { rawValue }
    var labelKey: String { "live.\(rawValue)" }

    var icon: String {
        switch self {
        case .aurora: return "sun.haze.fill"
        case .nebula: return "smoke.fill"
        case .plasma: return "atom"
        case .lavalamp: return "drop.degreesign.fill"
        case .mesh: return "circle.hexagongrid.fill"
        case .starfield: return "sparkles"
        case .waves: return "water.waves"
        case .gradientFlow: return "drop.fill"
        }
    }
}

private struct BlobSpec {
    let color: Color
    let x: Double      // 0...1 anchor
    let y: Double      // 0...1 anchor
    let scale: Double  // radius multiplier
}

/// Stable pseudo-random in 0...1 from an integer seed (deterministic across frames).
private func hash01(_ n: Int) -> Double {
    let x = sin(Double(n) * 12.9898 + 78.233) * 43758.5453
    return x - floor(x)
}

private func drawBlobs(_ ctx: inout GraphicsContext, size: CGSize, t: Double,
                       blobs: [BlobSpec], blur: CGFloat, additive: Bool, drift: Double) {
    ctx.addFilter(.blur(radius: blur))
    if additive { ctx.blendMode = .plusLighter }
    for (idx, b) in blobs.enumerated() {
        let phase = Double(idx) * 1.7
        let cx = (b.x + drift * sin(t * 0.30 + phase)) * size.width
        let cy = (b.y + drift * cos(t * 0.27 + phase * 1.3)) * size.height
        let r = size.width * 0.42 * b.scale
        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [b.color, b.color.opacity(0)]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0,
                endRadius: r
            )
        )
    }
}

struct LiveBackgroundView: View {
    let style: LiveBackground
    var top: Color
    var bottom: Color
    var accent: Color
    var speed: Double      // 0.1 ... 3
    var intensity: Double  // 0 ... 1
    var parallax: CGSize = .zero
    @ObservedObject private var motion = MotionController.shared
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        Group {
            if motion.animate && !prefs.reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    frame(t: context.date.timeIntervalSinceReferenceDate * max(0.05, speed))
                }
            } else {
                frame(t: 0)
            }
        }
        .allowsHitTesting(false)
    }

    private func frame(t: Double) -> some View {
        ZStack {
            LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            // Only the animated layer tracks the cursor — the base gradient stays
            // put so the parallax shift never exposes a window edge.
            content(t: t)
                .offset(x: parallax.width * 0.6, y: parallax.height * 0.6)
        }
    }

    @ViewBuilder
    private func content(t: Double) -> some View {
        switch style {
        case .aurora:        aurora(t: t)
        case .nebula:        nebula(t: t)
        case .plasma:        plasma(t: t)
        case .lavalamp:      lavalamp(t: t)
        case .mesh:          mesh(t: t)
        case .starfield:     starfield(t: t)
        case .waves:         waves(t: t)
        case .gradientFlow:  gradientFlow(t: t)
        }
    }

    // MARK: - Styles

    private func aurora(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.addFilter(.blur(radius: 48))
            ctx.blendMode = .plusLighter
            let bandColors = [accent, top, accent.opacity(0.8), bottom]
            let amp = size.height * (0.10 + 0.14 * intensity)
            for i in 0..<4 {
                var path = Path()
                let yBase = size.height * (0.18 + 0.18 * Double(i))
                path.move(to: CGPoint(x: 0, y: yBase))
                var x = 0.0
                while x <= size.width {
                    let y = yBase
                        + sin(x / 150 + t * 0.6 + Double(i)) * amp
                        + cos(x / 90 - t * 0.4 + Double(i) * 0.5) * amp * 0.5
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 14
                }
                path.addLine(to: CGPoint(x: size.width, y: -40))
                path.addLine(to: CGPoint(x: 0, y: -40))
                path.closeSubpath()
                ctx.fill(path, with: .color(bandColors[i % bandColors.count].opacity(0.22)))
            }
        }
        .opacity(0.9)
    }

    private func nebula(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            let blobs = [
                BlobSpec(color: accent.opacity(0.55), x: 0.25, y: 0.30, scale: 1.3),
                BlobSpec(color: top.opacity(0.55),    x: 0.75, y: 0.35, scale: 1.5),
                BlobSpec(color: bottom.opacity(0.6),  x: 0.50, y: 0.75, scale: 1.4),
                BlobSpec(color: accent.opacity(0.4),  x: 0.85, y: 0.80, scale: 1.0),
            ]
            drawBlobs(&ctx, size: size, t: t, blobs: blobs, blur: 70, additive: true,
                      drift: 0.06 + 0.05 * intensity)
        }
        .opacity(0.85)
    }

    private func plasma(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            var blobs: [BlobSpec] = []
            let palette = [accent, top, bottom, accent.opacity(0.85)]
            for i in 0..<7 {
                blobs.append(BlobSpec(
                    color: palette[i % palette.count].opacity(0.5),
                    x: 0.15 + hash01(i * 3) * 0.7,
                    y: 0.15 + hash01(i * 3 + 1) * 0.7,
                    scale: 0.6 + hash01(i * 3 + 2) * 0.6
                ))
            }
            drawBlobs(&ctx, size: size, t: t * 1.6, blobs: blobs, blur: 44, additive: true,
                      drift: 0.10 + 0.10 * intensity)
        }
        .opacity(0.9)
    }

    private func lavalamp(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.addFilter(.blur(radius: 46))
            ctx.blendMode = .plusLighter
            let warm: [Color] = [
                accent,
                Color(red: 1.0, green: 0.45, blue: 0.15),
                Color(red: 1.0, green: 0.30, blue: 0.45),
                accent.opacity(0.9),
                Color(red: 1.0, green: 0.6, blue: 0.2),
            ]
            for i in 0..<6 {
                let phase = Double(i) * 1.3
                let cx = (0.18 + 0.64 * hash01(i * 5)) * size.width
                    + sin(t * 0.25 + phase) * size.width * 0.05
                // Slow vertical bob spanning most of the lamp height.
                let bob = sin(t * (0.18 + 0.06 * hash01(i + 2)) + phase) * 0.5 + 0.5
                let cy = (0.12 + 0.76 * bob) * size.height
                let baseR = size.width * (0.10 + 0.07 * hash01(i + 9))
                // Squash/stretch a touch as it moves for a gooey, molten feel.
                let stretch = 1.0 + 0.25 * sin(t * 0.5 + phase)
                let rw = baseR
                let rh = baseR * stretch * (1.0 + 0.4 * intensity)
                let rect = CGRect(x: cx - rw, y: cy - rh, width: rw * 2, height: rh * 2)
                let color = warm[i % warm.count]
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [color.opacity(0.85), color.opacity(0)]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: max(rw, rh)
                    )
                )
            }
        }
        .opacity(0.92)
    }

    private func mesh(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            let blobs = [
                BlobSpec(color: top,                 x: 0.20, y: 0.25, scale: 1.1),
                BlobSpec(color: accent,              x: 0.80, y: 0.22, scale: 1.0),
                BlobSpec(color: bottom,              x: 0.30, y: 0.80, scale: 1.2),
                BlobSpec(color: accent.opacity(0.8), x: 0.78, y: 0.78, scale: 0.9),
                BlobSpec(color: top.opacity(0.9),    x: 0.50, y: 0.50, scale: 1.0),
            ]
            // Normal blend so colors mix like a mesh gradient.
            drawBlobs(&ctx, size: size, t: t, blobs: blobs, blur: 64, additive: false,
                      drift: 0.07 + 0.06 * intensity)
        }
    }

    private func starfield(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.blendMode = .plusLighter
            let count = 160
            let driftSpeed = 18.0 + 50.0 * intensity
            for i in 0..<count {
                let sx = hash01(i) * size.width
                let layer = 0.3 + hash01(i + 7) * 0.9
                let yStart = hash01(i + 13) * size.height
                let y = (yStart + t * driftSpeed * layer)
                    .truncatingRemainder(dividingBy: size.height)
                let twinkle = 0.45 + 0.55 * abs(sin(t * (0.8 + layer) + Double(i)))
                let r = (0.6 + layer * 1.6)
                let rect = CGRect(x: sx, y: y, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(twinkle)))
                if layer > 1.0 {
                    let glow = rect.insetBy(dx: -r, dy: -r)
                    ctx.fill(Path(ellipseIn: glow), with: .color(accent.opacity(twinkle * 0.25)))
                }
            }
        }
    }

    private func waves(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.blendMode = .plusLighter
            let layerColors = [bottom, accent, top]
            let amp = size.height * (0.05 + 0.08 * intensity)
            for i in 0..<3 {
                var path = Path()
                let yBase = size.height * (0.55 + 0.16 * Double(i))
                path.move(to: CGPoint(x: 0, y: size.height))
                var x = 0.0
                while x <= size.width {
                    let y = yBase
                        + sin(x / 120 + t * (0.9 + Double(i) * 0.3)) * amp
                        + sin(x / 47 - t * 1.4) * amp * 0.35
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 10
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                ctx.fill(path, with: .color(layerColors[i % layerColors.count].opacity(0.35)))
            }
        }
    }

    private func gradientFlow(t: Double) -> some View {
        let angle = t * 0.25
        let start = UnitPoint(x: 0.5 + 0.5 * cos(angle), y: 0.5 + 0.5 * sin(angle))
        let end = UnitPoint(x: 0.5 - 0.5 * cos(angle), y: 0.5 - 0.5 * sin(angle))
        return LinearGradient(
            colors: [top, accent, bottom, accent, top],
            startPoint: start,
            endPoint: end
        )
        .hueRotation(.degrees(t * (8 + 22 * intensity)))
        .opacity(0.95)
    }
}

// MARK: - Post-processing overlays (apply to any background mode)

struct VignetteOverlay: View {
    var strength: Double
    var body: some View {
        GeometryReader { geo in
            let maxDim = max(geo.size.width, geo.size.height)
            RadialGradient(
                colors: [.clear, .black.opacity(min(max(strength, 0), 1))],
                center: .center,
                startRadius: maxDim * 0.24,
                endRadius: maxDim * 0.72
            )
        }
        .allowsHitTesting(false)
    }
}

struct ScanlinesOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1.0)),
                         with: .color(.black.opacity(0.22)))
                y += 3
            }
        }
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }
}

/// Cached static noise frames; cheap to build once, cycled for a filmic grain.
enum NoiseTexture {
    static let tiles: [NSImage] = (0..<4).map { _ in makeTile(dimension: 110) }

    private static func makeTile(dimension: Int) -> NSImage {
        let size = NSSize(width: dimension, height: dimension)
        let image = NSImage(size: size)
        image.lockFocus()
        for x in 0..<dimension {
            for y in 0..<dimension {
                let v = CGFloat.random(in: 0...1)
                NSColor(calibratedWhite: v, alpha: 1).setFill()
                NSRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1).fill()
            }
        }
        image.unlockFocus()
        return image
    }
}

struct GrainOverlay: View {
    var strength: Double
    @ObservedObject private var motion = MotionController.shared
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        Group {
            if motion.animate && !prefs.reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { context in
                    grain(frame: Int(context.date.timeIntervalSinceReferenceDate * 12)
                        % max(NoiseTexture.tiles.count, 1))
                }
            } else {
                grain(frame: 0)
            }
        }
        .allowsHitTesting(false)
    }

    private func grain(frame: Int) -> some View {
        Image(nsImage: NoiseTexture.tiles[frame])
            .resizable(resizingMode: .tile)
            .opacity(min(max(strength, 0), 1) * 0.5)
            .blendMode(.overlay)
    }
}
