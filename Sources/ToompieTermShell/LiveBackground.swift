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
    case rays
    case grid
    case silk
    case kaleidoscope
    case ripplePool
    case prism

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
        case .rays: return "sun.max.fill"
        case .grid: return "grid"
        case .silk: return "wind"
        case .kaleidoscope: return "snowflake"
        case .ripplePool: return "drop.circle.fill"
        case .prism: return "rainbow"
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
                // Frame cap is set by the graphics tier — Potato idles at 15 fps,
                // Ludicrous runs at 60. (High, the >8 GB default, keeps the old 30.)
                TimelineView(.animation(minimumInterval: 1.0 / prefs.graphicsQuality.backgroundFPS)) { context in
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
        case .rays:          rays(t: t)
        case .grid:          grid(t: t)
        case .silk:          silk(t: t)
        case .kaleidoscope:  kaleidoscope(t: t)
        case .ripplePool:    ripplePool(t: t)
        case .prism:         prism(t: t)
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
        let count = Int(160 * prefs.graphicsQuality.starCountScale)
        return Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.blendMode = .plusLighter
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

    // MARK: - Added styles

    /// Slow-rotating volumetric "god rays" fanning out from a source near the top.
    private func rays(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.addFilter(.blur(radius: 26))
            ctx.blendMode = .plusLighter
            let center = CGPoint(x: size.width * 0.5, y: -size.height * 0.15)
            let count = 14
            let maxR = hypot(size.width, size.height) * 1.5
            let palette = [accent, top, accent.opacity(0.75), bottom]
            for i in 0..<count {
                let base = Double(i) / Double(count) * .pi * 2
                let sweep = 0.05 + 0.035 * (0.5 + 0.5 * sin(t * 0.6 + Double(i)))
                let a = base + t * 0.08
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x + cos(a - sweep) * maxR,
                                         y: center.y + sin(a - sweep) * maxR))
                path.addLine(to: CGPoint(x: center.x + cos(a + sweep) * maxR,
                                         y: center.y + sin(a + sweep) * maxR))
                path.closeSubpath()
                let c = palette[i % palette.count]
                ctx.fill(path, with: .radialGradient(
                    Gradient(colors: [c.opacity(0.30 + 0.16 * intensity), c.opacity(0)]),
                    center: center, startRadius: 0, endRadius: maxR))
            }
        }
        .opacity(0.9)
    }

    /// Retro synthwave perspective grid scrolling toward the viewer.
    private func grid(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.blendMode = .plusLighter
            let horizon = size.height * 0.5
            let vp = CGPoint(x: size.width / 2, y: horizon)
            let line = accent
            // Sun glow sitting on the horizon.
            let sunR = size.width * 0.18
            ctx.fill(
                Path(ellipseIn: CGRect(x: vp.x - sunR, y: horizon - sunR, width: sunR * 2, height: sunR * 2)),
                with: .radialGradient(Gradient(colors: [top.opacity(0.5), top.opacity(0)]),
                                      center: vp, startRadius: 0, endRadius: sunR))
            // Vertical lines converging to the vanishing point.
            let cols = 14
            for i in -cols...cols {
                let xBottom = vp.x + CGFloat(i) * size.width / CGFloat(cols)
                var p = Path()
                p.move(to: CGPoint(x: xBottom, y: size.height))
                p.addLine(to: vp)
                ctx.stroke(p, with: .color(line.opacity(0.22)), lineWidth: 1)
            }
            // Horizontal lines bunching toward the horizon, scrolling outward.
            let rows = 16
            let scroll = (t * 0.3).truncatingRemainder(dividingBy: 1.0)
            for i in 0..<rows {
                let f = (Double(i) + scroll) / Double(rows)
                let y = horizon + pow(f, 2.2) * (size.height - horizon)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(line.opacity(0.12 + 0.45 * f)), lineWidth: 1 + f)
            }
        }
        .opacity(0.85)
    }

    /// Soft overlapping ribbons that warp like flowing silk.
    private func silk(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.addFilter(.blur(radius: 34))
            ctx.blendMode = .plusLighter
            let palette = [accent, top, bottom, accent.opacity(0.8)]
            let bands = 5
            let amp = size.height * (0.05 + 0.07 * intensity)
            for i in 0..<bands {
                func wave(_ x: Double, offset: Double) -> Double {
                    let yBase = size.height * (0.12 + 0.17 * Double(i)) + offset
                    return yBase
                        + sin(x / 220 + t * 0.7 + Double(i) * 0.9) * amp
                        + sin(x / 70 - t * 0.5 + Double(i)) * amp * 0.4
                }
                var path = Path()
                path.move(to: CGPoint(x: 0, y: wave(0, offset: 0)))
                var x = 0.0
                while x <= size.width { path.addLine(to: CGPoint(x: x, y: wave(x, offset: 0))); x += 14 }
                let thickness = size.height * 0.12
                x = size.width
                while x >= 0 { path.addLine(to: CGPoint(x: x, y: wave(x, offset: thickness))); x -= 14 }
                path.closeSubpath()
                ctx.fill(path, with: .color(palette[i % palette.count].opacity(0.26)))
            }
        }
        .opacity(0.9)
    }

    /// Mirror-symmetric drifting blobs — a slowly turning kaleidoscope.
    private func kaleidoscope(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.addFilter(.blur(radius: 20))
            ctx.blendMode = .plusLighter
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let segments = 8
            let palette = [accent, top, bottom]
            for s in 0..<segments {
                var slice = ctx
                slice.translateBy(x: center.x, y: center.y)
                slice.rotate(by: .radians(Double(s) / Double(segments) * .pi * 2 + t * 0.2))
                for i in 0..<3 {
                    let r = size.width * (0.10 + 0.05 * Double(i))
                    let dist = size.width * (0.10 + 0.09 * Double(i)) * (1 + 0.2 * sin(t * 0.6 + Double(i)))
                    let cx = cos(t * 0.4 + Double(i)) * dist * 0.5
                    let cy = sin(t * 0.5 + Double(i) * 1.3) * dist * 0.3 + dist
                    let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                    let c = palette[(s + i) % palette.count]
                    slice.fill(Path(ellipseIn: rect), with: .radialGradient(
                        Gradient(colors: [c.opacity(0.5), c.opacity(0)]),
                        center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r))
                }
            }
        }
        .opacity(0.9)
    }

    /// Concentric ripples spreading from a few points, like rain on still water.
    private func ripplePool(t: Double) -> some View {
        Canvas { ctx, size in
            guard size.width > 0, size.height > 0 else { return }
            ctx.blendMode = .plusLighter
            let palette = [accent, top, bottom, accent]
            let sources = 5
            for s in 0..<sources {
                let cx = (0.18 + 0.64 * hash01(s * 7)) * size.width
                let cy = (0.18 + 0.64 * hash01(s * 7 + 3)) * size.height
                let period = 2.4 + hash01(s + 1) * 2.2
                let rings = 4
                for k in 0..<rings {
                    let phase = (t / period + Double(k) / Double(rings)).truncatingRemainder(dividingBy: 1)
                    let radius = phase * size.width * 0.34
                    let alpha = (1 - phase) * (0.45 + 0.3 * intensity)
                    let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
                    ctx.stroke(Path(ellipseIn: rect), with: .color(palette[s % palette.count].opacity(alpha)),
                               lineWidth: 1.5 + 1.5 * (1 - phase))
                }
            }
        }
        .opacity(0.85)
    }

    /// A slow, full-spectrum rainbow sweep with continuous hue rotation.
    private func prism(t: Double) -> some View {
        let rainbow: [Color] = [
            Color(red: 1, green: 0.35, blue: 0.4), Color(red: 1, green: 0.62, blue: 0.3),
            Color(red: 1, green: 0.9, blue: 0.35), Color(red: 0.4, green: 0.85, blue: 0.5),
            Color(red: 0.35, green: 0.7, blue: 1), Color(red: 0.7, green: 0.45, blue: 1),
            Color(red: 1, green: 0.35, blue: 0.4),
        ]
        let angle = t * 0.18
        return LinearGradient(
            colors: rainbow,
            startPoint: UnitPoint(x: 0.5 + 0.5 * cos(angle), y: 0.5 + 0.5 * sin(angle)),
            endPoint: UnitPoint(x: 0.5 - 0.5 * cos(angle), y: 0.5 - 0.5 * sin(angle))
        )
        .hueRotation(.degrees(t * (16 + 34 * intensity)))
        .opacity(0.7)
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
