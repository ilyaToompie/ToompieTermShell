import AppKit
import SwiftUI

struct WeatherOverlay: NSViewRepresentable {
    let effects: [WeatherEffect]

    func makeNSView(context: Context) -> WeatherEffectView {
        let view = WeatherEffectView()
        view.apply(effects)
        return view
    }

    func updateNSView(_ nsView: WeatherEffectView, context: Context) {
        nsView.apply(effects)
    }
}

enum ParticleKind {
    case dot
    case rainLine
    case star
    case heart
    case leaf
    case ring
    case confetti
    case snowflake
    case glyph(String)
}

private struct EffectSpec {
    var kinds: [ParticleKind]
    var colors: [NSColor]
    var birthRate: Float
    var lifetime: Float
    var velocity: CGFloat
    var velocityRange: CGFloat
    var yAcceleration: CGFloat
    var xAcceleration: CGFloat
    var emissionLongitude: CGFloat
    var emissionRange: CGFloat
    var scale: CGFloat
    var scaleRange: CGFloat
    var scaleSpeed: CGFloat = 0
    var spin: CGFloat = 0
    var spinRange: CGFloat = 0
    var alphaSpeed: Float = 0
    var alphaRange: Float = 0
    var origin: Origin
    var baseSize: CGFloat = 10

    enum Origin { case top, bottom, area }
}

final class WeatherEffectView: NSView {
    private var current: Set<WeatherEffect> = []

    override var isFlipped: Bool { false }

    func apply(_ effects: [WeatherEffect]) {
        let incoming = Set(effects).subtracting([.off])
        guard current != incoming else { return }
        current = incoming
        wantsLayer = true
        layer?.sublayers?.removeAll()
        for effect in incoming {
            let emitter = makeEmitter(effect)
            emitter.name = effect.rawValue
            layer?.addSublayer(emitter)
            layoutEmitter(emitter, effect: effect)
        }
    }

    override func layout() {
        super.layout()
        for case let emitter as CAEmitterLayer in (layer?.sublayers ?? []) {
            if let effect = WeatherEffect(rawValue: emitter.name ?? "") {
                layoutEmitter(emitter, effect: effect)
            }
        }
    }

    private func layoutEmitter(_ emitter: CAEmitterLayer, effect: WeatherEffect) {
        emitter.frame = bounds
        let spec = Self.spec(for: effect)
        switch spec.origin {
        case .top:
            emitter.emitterShape = .line
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY + 12)
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        case .bottom:
            emitter.emitterShape = .line
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: -12)
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
        case .area:
            emitter.emitterShape = .rectangle
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
            emitter.emitterSize = bounds.size
        }
    }

    private func makeEmitter(_ effect: WeatherEffect) -> CAEmitterLayer {
        let spec = Self.spec(for: effect)
        let emitter = CAEmitterLayer()
        emitter.renderMode = (effect == .embers || effect == .fireflies || effect == .stars || effect == .sparkles || effect == .bokeh) ? .additive : .unordered
        emitter.beginTime = CACurrentMediaTime()
        var cells: [CAEmitterCell] = []
        for kind in spec.kinds {
            for color in spec.colors {
                cells.append(Self.cell(spec: spec, kind: kind, color: color))
            }
        }
        emitter.emitterCells = cells
        return emitter
    }

    private static func cell(spec: EffectSpec, kind: ParticleKind, color: NSColor) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = particleImage(kind: kind, color: color, size: spec.baseSize)
        cell.birthRate = spec.birthRate / Float(max(spec.colors.count * spec.kinds.count, 1))
        cell.lifetime = spec.lifetime
        cell.lifetimeRange = spec.lifetime * 0.3
        cell.velocity = spec.velocity
        cell.velocityRange = spec.velocityRange
        cell.yAcceleration = spec.yAcceleration
        cell.xAcceleration = spec.xAcceleration
        cell.emissionLongitude = spec.emissionLongitude
        cell.emissionRange = spec.emissionRange
        cell.scale = spec.scale
        cell.scaleRange = spec.scaleRange
        cell.scaleSpeed = spec.scaleSpeed
        cell.spin = spec.spin
        cell.spinRange = spec.spinRange
        cell.alphaSpeed = spec.alphaSpeed
        cell.alphaRange = spec.alphaRange
        return cell
    }

    private static func spec(for effect: WeatherEffect) -> EffectSpec {
        switch effect {
        case .off:
            return EffectSpec(kinds: [.dot], colors: [.clear], birthRate: 0, lifetime: 1, velocity: 0, velocityRange: 0, yAcceleration: 0, xAcceleration: 0, emissionLongitude: 0, emissionRange: 0, scale: 0, scaleRange: 0, origin: .top)
        case .snow:
            return EffectSpec(kinds: [.dot, .snowflake], colors: [.white], birthRate: 26, lifetime: 18, velocity: 40, velocityRange: 20, yAcceleration: -26, xAcceleration: 6, emissionLongitude: .pi, emissionRange: 0.5, scale: 0.5, scaleRange: 0.35, spin: 0.6, spinRange: 1.0, alphaSpeed: -0.03, origin: .top, baseSize: 12)
        case .rain:
            return EffectSpec(kinds: [.rainLine], colors: [NSColor(calibratedRed: 0.7, green: 0.8, blue: 1, alpha: 0.8)], birthRate: 90, lifetime: 6, velocity: 480, velocityRange: 90, yAcceleration: -800, xAcceleration: 0, emissionLongitude: -.pi / 2, emissionRange: 0.05, scale: 0.7, scaleRange: 0.2, origin: .top, baseSize: 18)
        case .stars:
            return EffectSpec(kinds: [.star], colors: [.white, NSColor(calibratedRed: 1, green: 0.95, blue: 0.7, alpha: 1)], birthRate: 14, lifetime: 4, velocity: 4, velocityRange: 6, yAcceleration: 0, xAcceleration: 0, emissionLongitude: 0, emissionRange: .pi * 2, scale: 0.28, scaleRange: 0.22, spin: 0.4, spinRange: 0.6, alphaSpeed: -0.28, alphaRange: 0.2, origin: .area, baseSize: 16)
        case .sparkles:
            return EffectSpec(kinds: [.star, .dot], colors: [NSColor(calibratedRed: 1, green: 0.85, blue: 0.4, alpha: 1), .white], birthRate: 26, lifetime: 2.6, velocity: 8, velocityRange: 12, yAcceleration: 0, xAcceleration: 0, emissionLongitude: 0, emissionRange: .pi * 2, scale: 0.22, scaleRange: 0.18, scaleSpeed: -0.06, spin: 1.0, spinRange: 1.0, alphaSpeed: -0.45, origin: .area, baseSize: 14)
        case .confetti:
            return EffectSpec(kinds: [.confetti], colors: [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPink, .systemPurple, .systemTeal], birthRate: 36, lifetime: 9, velocity: 60, velocityRange: 40, yAcceleration: -120, xAcceleration: 12, emissionLongitude: .pi, emissionRange: 0.7, scale: 0.5, scaleRange: 0.3, spin: 3.0, spinRange: 4.0, origin: .top, baseSize: 12)
        case .bubbles:
            return EffectSpec(kinds: [.ring], colors: [NSColor(calibratedRed: 0.6, green: 0.85, blue: 1, alpha: 0.7), .white], birthRate: 16, lifetime: 10, velocity: 50, velocityRange: 30, yAcceleration: 30, xAcceleration: 8, emissionLongitude: .pi / 2, emissionRange: 0.5, scale: 0.5, scaleRange: 0.4, alphaSpeed: -0.05, origin: .bottom, baseSize: 20)
        case .fireflies:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 0.8, green: 1, blue: 0.4, alpha: 1)], birthRate: 12, lifetime: 5, velocity: 14, velocityRange: 18, yAcceleration: 0, xAcceleration: 0, emissionLongitude: 0, emissionRange: .pi * 2, scale: 0.18, scaleRange: 0.12, alphaSpeed: -0.22, alphaRange: 0.3, origin: .area, baseSize: 14)
        case .leaves:
            return EffectSpec(kinds: [.leaf], colors: [NSColor(calibratedRed: 0.85, green: 0.5, blue: 0.2, alpha: 1), NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.2, alpha: 1), NSColor(calibratedRed: 0.7, green: 0.3, blue: 0.15, alpha: 1)], birthRate: 14, lifetime: 12, velocity: 50, velocityRange: 25, yAcceleration: -40, xAcceleration: 18, emissionLongitude: .pi, emissionRange: 0.6, scale: 0.5, scaleRange: 0.3, spin: 1.4, spinRange: 2.0, origin: .top, baseSize: 18)
        case .embers:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 1, green: 0.6, blue: 0.2, alpha: 1), NSColor(calibratedRed: 1, green: 0.35, blue: 0.1, alpha: 1)], birthRate: 40, lifetime: 6, velocity: 80, velocityRange: 40, yAcceleration: 50, xAcceleration: 10, emissionLongitude: .pi / 2, emissionRange: 0.6, scale: 0.18, scaleRange: 0.14, scaleSpeed: -0.02, alphaSpeed: -0.15, origin: .bottom, baseSize: 12)
        case .hearts:
            return EffectSpec(kinds: [.heart], colors: [.systemPink, .systemRed, NSColor(calibratedRed: 1, green: 0.5, blue: 0.7, alpha: 1)], birthRate: 14, lifetime: 9, velocity: 55, velocityRange: 25, yAcceleration: 35, xAcceleration: 14, emissionLongitude: .pi / 2, emissionRange: 0.5, scale: 0.4, scaleRange: 0.25, spin: 0.5, spinRange: 1.0, alphaSpeed: -0.06, origin: .bottom, baseSize: 18)
        case .matrix:
            return EffectSpec(kinds: [.glyph("ﾊ"), .glyph("ﾐ"), .glyph("0"), .glyph("1"), .glyph("ｱ")], colors: [NSColor(calibratedRed: 0.2, green: 1, blue: 0.4, alpha: 1)], birthRate: 40, lifetime: 7, velocity: 220, velocityRange: 80, yAcceleration: -120, xAcceleration: 0, emissionLongitude: -.pi / 2, emissionRange: 0.02, scale: 0.7, scaleRange: 0.3, alphaSpeed: -0.08, origin: .top, baseSize: 20)
        case .petals:
            return EffectSpec(kinds: [.leaf], colors: [NSColor(calibratedRed: 1, green: 0.8, blue: 0.88, alpha: 1), NSColor(calibratedRed: 1, green: 0.7, blue: 0.82, alpha: 1)], birthRate: 16, lifetime: 12, velocity: 45, velocityRange: 22, yAcceleration: -34, xAcceleration: 16, emissionLongitude: .pi, emissionRange: 0.6, scale: 0.4, scaleRange: 0.25, spin: 1.2, spinRange: 1.8, origin: .top, baseSize: 16)
        case .bokeh:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 0.6, green: 0.8, blue: 1, alpha: 0.5), NSColor(calibratedRed: 1, green: 0.7, blue: 0.9, alpha: 0.5), NSColor(calibratedRed: 0.8, green: 1, blue: 0.8, alpha: 0.5)], birthRate: 8, lifetime: 8, velocity: 10, velocityRange: 14, yAcceleration: 6, xAcceleration: 4, emissionLongitude: 0, emissionRange: .pi * 2, scale: 1.1, scaleRange: 0.8, scaleSpeed: 0.05, alphaSpeed: -0.1, origin: .area, baseSize: 40)
        }
    }

    private static func particleImage(kind: ParticleKind, color: NSColor, size: CGFloat) -> CGImage? {
        let dimension: NSSize
        switch kind {
        case .rainLine: dimension = NSSize(width: max(size * 0.14, 2), height: size)
        default: dimension = NSSize(width: size, height: size)
        }
        let image = NSImage(size: dimension)
        image.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: dimension)
        switch kind {
        case .dot:
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.1, dy: size * 0.1)).fill()
        case .rainLine:
            NSBezierPath(roundedRect: rect, xRadius: dimension.width / 2, yRadius: dimension.width / 2).fill()
        case .ring:
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.12, dy: size * 0.12))
            path.lineWidth = size * 0.12
            color.setStroke()
            path.stroke()
        case .confetti:
            NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.3, dy: size * 0.08), xRadius: 1, yRadius: 1).fill()
        case .star:
            starPath(in: rect).fill()
        case .heart:
            heartPath(in: rect).fill()
        case .leaf:
            let p = NSBezierPath()
            p.move(to: NSPoint(x: rect.midX, y: rect.minY))
            p.curve(to: NSPoint(x: rect.midX, y: rect.maxY), controlPoint1: NSPoint(x: rect.maxX, y: rect.midY), controlPoint2: NSPoint(x: rect.maxX, y: rect.midY))
            p.curve(to: NSPoint(x: rect.midX, y: rect.minY), controlPoint1: NSPoint(x: rect.minX, y: rect.midY), controlPoint2: NSPoint(x: rect.minX, y: rect.midY))
            p.fill()
        case .snowflake:
            color.setStroke()
            let path = NSBezierPath()
            path.lineWidth = size * 0.08
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3
                path.move(to: NSPoint(x: rect.midX, y: rect.midY))
                path.line(to: NSPoint(x: rect.midX + cos(angle) * size * 0.45, y: rect.midY + sin(angle) * size * 0.45))
            }
            path.stroke()
        case .glyph(let text):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: size * 0.9, weight: .bold),
                .foregroundColor: color
            ]
            let s = NSAttributedString(string: text, attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: (dimension.width - sz.width) / 2, y: (dimension.height - sz.height) / 2))
        }
        image.unlockFocus()
        var r = NSRect(origin: .zero, size: dimension)
        return image.cgImage(forProposedRect: &r, context: nil, hints: nil)
    }

    private static func starPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let outer = rect.width * 0.45
        let inner = outer * 0.42
        for i in 0..<10 {
            let radius = i % 2 == 0 ? outer : inner
            let angle = CGFloat(i) * .pi / 5 - .pi / 2
            let point = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.line(to: point) }
        }
        path.close()
        return path
    }

    private static func heartPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let w = rect.width
        let h = rect.height
        path.move(to: NSPoint(x: rect.midX, y: rect.minY + h * 0.18))
        path.curve(to: NSPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.7),
                   controlPoint1: NSPoint(x: rect.midX - w * 0.28, y: rect.minY + h * 0.36),
                   controlPoint2: NSPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.46))
        path.curve(to: NSPoint(x: rect.midX, y: rect.maxY - h * 0.08),
                   controlPoint1: NSPoint(x: rect.minX + w * 0.04, y: rect.maxY - h * 0.18),
                   controlPoint2: NSPoint(x: rect.midX - w * 0.18, y: rect.maxY - h * 0.04))
        path.curve(to: NSPoint(x: rect.maxX - w * 0.04, y: rect.minY + h * 0.7),
                   controlPoint1: NSPoint(x: rect.midX + w * 0.18, y: rect.maxY - h * 0.04),
                   controlPoint2: NSPoint(x: rect.maxX - w * 0.04, y: rect.maxY - h * 0.18))
        path.curve(to: NSPoint(x: rect.midX, y: rect.minY + h * 0.18),
                   controlPoint1: NSPoint(x: rect.maxX - w * 0.04, y: rect.minY + h * 0.46),
                   controlPoint2: NSPoint(x: rect.midX + w * 0.28, y: rect.minY + h * 0.36))
        path.close()
        return path
    }
}
