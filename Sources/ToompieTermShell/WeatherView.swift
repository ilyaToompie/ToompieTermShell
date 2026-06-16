import AppKit
import SwiftUI

struct WeatherOverlay: NSViewRepresentable {
    let effects: [WeatherEffect]
    var tints: [String: String] = [:]
    /// Steady wind force added to every particle (from the user's direction setting).
    var wind: CGVector = .zero
    /// Multiplier on every emitter's birth rate (from the graphics-quality tier).
    var birthRateScale: Double = 1
    /// When false, the particle emitters are frozen (render server stops
    /// simulating cells) — used to pause them while the window is hidden.
    var running: Bool = true

    func makeNSView(context: Context) -> WeatherEffectView {
        let view = WeatherEffectView()
        view.apply(effects, tints: tints, wind: wind, birthRateScale: birthRateScale)
        view.setRunning(running)
        return view
    }

    func updateNSView(_ nsView: WeatherEffectView, context: Context) {
        nsView.apply(effects, tints: tints, wind: wind, birthRateScale: birthRateScale)
        nsView.setRunning(running)
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
    private var currentTints: [String: String] = [:]
    private var currentWind: CGVector = .zero
    private var currentBirthScale: Double = 1
    private var running = true

    override var isFlipped: Bool { false }

    /// Never participate in hit-testing: this full-window NSView overlay must
    /// never swallow clicks/drags meant for the SwiftUI UI underneath it.
    /// (SwiftUI's `.allowsHitTesting(false)` does not stop the hosted AppKit
    /// view from intercepting events — this does.)
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func apply(_ effects: [WeatherEffect], tints: [String: String] = [:],
               wind: CGVector = .zero, birthRateScale: Double = 1) {
        let incoming = Set(effects).subtracting([.off])
        guard current != incoming || currentTints != tints
            || currentWind != wind || currentBirthScale != birthRateScale else { return }
        current = incoming
        currentTints = tints
        currentWind = wind
        currentBirthScale = birthRateScale
        wantsLayer = true
        layer?.sublayers?.removeAll()
        for effect in incoming {
            let emitter = makeEmitter(effect, tint: tintColor(for: effect),
                                      wind: wind, birthScale: birthRateScale)
            emitter.name = effect.rawValue
            layer?.addSublayer(emitter)
            layoutEmitter(emitter, effect: effect)
        }
        applyRunningState()
    }

    private func tintColor(for effect: WeatherEffect) -> NSColor? {
        guard effect.tintable, let hex = currentTints[effect.rawValue] else { return nil }
        return NSColor(hex: hex)
    }

    /// Freezes or resumes the CAEmitterLayer simulation. Core Animation keeps
    /// spawning/animating particles on the render server independent of SwiftUI,
    /// so without this the emitters burn CPU even when the window is hidden.
    func setRunning(_ value: Bool) {
        running = value
        applyRunningState()
    }

    private func applyRunningState() {
        for sub in (layer?.sublayers ?? []) {
            if running {
                if sub.speed == 0 {
                    let pausedAt = sub.timeOffset
                    sub.speed = 1
                    sub.timeOffset = 0
                    sub.beginTime = 0
                    sub.beginTime = sub.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
                }
            } else if sub.speed != 0 {
                let pausedAt = sub.convertTime(CACurrentMediaTime(), from: nil)
                sub.speed = 0
                sub.timeOffset = pausedAt
            }
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

    private func makeEmitter(_ effect: WeatherEffect, tint: NSColor?,
                             wind: CGVector, birthScale: Double) -> CAEmitterLayer {
        let spec = Self.spec(for: effect)
        let emitter = CAEmitterLayer()
        let additive: Set<WeatherEffect> = [.embers, .fireflies, .stars, .sparkles, .bokeh, .dust, .meteors, .lanterns, .glitter, .aurora, .fireworks, .cinders, .spores, .wisps, .comets, .pollen]
        emitter.renderMode = additive.contains(effect) ? .additive : .unordered
        emitter.beginTime = CACurrentMediaTime()
        if effect == .rain {
            emitter.emitterCells = Self.rainCells(wind: wind, birthScale: birthScale)
            return emitter
        }
        let colors = tint.map { [$0] } ?? spec.colors
        var cells: [CAEmitterCell] = []
        for kind in spec.kinds {
            for color in colors {
                cells.append(Self.cell(spec: spec, kind: kind, color: color, colorCount: colors.count,
                                       wind: wind, birthScale: birthScale))
            }
        }
        emitter.emitterCells = cells
        return emitter
    }

    private static func cell(spec: EffectSpec, kind: ParticleKind, color: NSColor, colorCount: Int,
                             wind: CGVector, birthScale: Double) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = particleImage(kind: kind, color: color, size: spec.baseSize)
        cell.birthRate = spec.birthRate / Float(max(colorCount * spec.kinds.count, 1)) * Float(max(birthScale, 0))
        cell.lifetime = spec.lifetime
        cell.lifetimeRange = spec.lifetime * 0.3
        cell.velocity = spec.velocity
        cell.velocityRange = spec.velocityRange
        // Wind is added on top of the effect's own gravity/drift so it slants in the
        // chosen direction without erasing its hand-tuned vertical motion.
        cell.yAcceleration = spec.yAcceleration + wind.dy
        cell.xAcceleration = spec.xAcceleration + wind.dx
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
        case .dust:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedWhite: 0.92, alpha: 0.55), NSColor(calibratedRed: 1, green: 0.96, blue: 0.85, alpha: 0.5)], birthRate: 20, lifetime: 14, velocity: 9, velocityRange: 9, yAcceleration: 2, xAcceleration: 7, emissionLongitude: 0, emissionRange: .pi * 2, scale: 0.12, scaleRange: 0.09, alphaSpeed: -0.04, alphaRange: 0.25, origin: .area, baseSize: 10)
        case .fog:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedWhite: 0.82, alpha: 0.16), NSColor(calibratedWhite: 0.7, alpha: 0.14)], birthRate: 4, lifetime: 18, velocity: 22, velocityRange: 12, yAcceleration: 0, xAcceleration: 5, emissionLongitude: 0, emissionRange: 0.6, scale: 2.4, scaleRange: 1.3, scaleSpeed: 0.05, alphaSpeed: -0.012, origin: .area, baseSize: 60)
        case .meteors:
            return EffectSpec(kinds: [.rainLine], colors: [.white, NSColor(calibratedRed: 0.7, green: 0.85, blue: 1, alpha: 1)], birthRate: 6, lifetime: 4, velocity: 540, velocityRange: 140, yAcceleration: -200, xAcceleration: -200, emissionLongitude: -.pi / 2 - 0.6, emissionRange: 0.06, scale: 0.9, scaleRange: 0.3, alphaSpeed: -0.16, origin: .top, baseSize: 26)
        case .lanterns:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 1, green: 0.75, blue: 0.35, alpha: 1), NSColor(calibratedRed: 1, green: 0.5, blue: 0.2, alpha: 1)], birthRate: 8, lifetime: 12, velocity: 42, velocityRange: 18, yAcceleration: 18, xAcceleration: 8, emissionLongitude: .pi / 2, emissionRange: 0.35, scale: 0.4, scaleRange: 0.2, alphaSpeed: -0.05, alphaRange: 0.2, origin: .bottom, baseSize: 22)
        case .glitter:
            return EffectSpec(kinds: [.star, .dot], colors: [NSColor(calibratedRed: 1, green: 0.9, blue: 0.5, alpha: 1), NSColor(calibratedRed: 0.7, green: 0.9, blue: 1, alpha: 1), NSColor(calibratedRed: 1, green: 0.7, blue: 0.9, alpha: 1), .white], birthRate: 44, lifetime: 2.0, velocity: 6, velocityRange: 10, yAcceleration: 0, xAcceleration: 0, emissionLongitude: 0, emissionRange: .pi * 2, scale: 0.16, scaleRange: 0.14, scaleSpeed: -0.05, spin: 1.2, spinRange: 1.4, alphaSpeed: -0.5, origin: .area, baseSize: 12)
        case .aurora:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 0.3, green: 1.0, blue: 0.6, alpha: 0.4), NSColor(calibratedRed: 0.3, green: 0.85, blue: 0.95, alpha: 0.35), NSColor(calibratedRed: 0.6, green: 0.4, blue: 1.0, alpha: 0.35)], birthRate: 6, lifetime: 16, velocity: 16, velocityRange: 10, yAcceleration: 0, xAcceleration: 6, emissionLongitude: 0, emissionRange: 0.4, scale: 2.6, scaleRange: 1.2, scaleSpeed: 0.04, alphaSpeed: -0.025, origin: .area, baseSize: 60)
        case .fireworks:
            return EffectSpec(kinds: [.dot, .star], colors: [NSColor(calibratedRed: 1, green: 0.3, blue: 0.4, alpha: 1), NSColor(calibratedRed: 1, green: 0.85, blue: 0.3, alpha: 1), NSColor(calibratedRed: 0.4, green: 0.7, blue: 1, alpha: 1), NSColor(calibratedRed: 0.6, green: 1, blue: 0.5, alpha: 1), NSColor(calibratedRed: 1, green: 0.5, blue: 0.9, alpha: 1)], birthRate: 34, lifetime: 1.7, velocity: 120, velocityRange: 80, yAcceleration: -90, xAcceleration: 0, emissionLongitude: 0, emissionRange: .pi * 2, scale: 0.16, scaleRange: 0.12, scaleSpeed: -0.05, spin: 1.0, spinRange: 1.5, alphaSpeed: -0.5, origin: .area, baseSize: 12)
        case .smoke:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedWhite: 0.55, alpha: 0.18), NSColor(calibratedWhite: 0.42, alpha: 0.15)], birthRate: 6, lifetime: 12, velocity: 40, velocityRange: 18, yAcceleration: 10, xAcceleration: 7, emissionLongitude: .pi / 2, emissionRange: 0.5, scale: 1.1, scaleRange: 0.6, scaleSpeed: 0.13, alphaSpeed: -0.02, origin: .bottom, baseSize: 52)
        case .ripples:
            return EffectSpec(kinds: [.ring], colors: [NSColor(calibratedRed: 0.6, green: 0.85, blue: 1, alpha: 0.7), NSColor(calibratedWhite: 1, alpha: 0.6)], birthRate: 8, lifetime: 4, velocity: 0, velocityRange: 4, yAcceleration: 0, xAcceleration: 0, emissionLongitude: 0, emissionRange: .pi * 2, scale: 0.1, scaleRange: 0.05, scaleSpeed: 0.9, alphaSpeed: -0.25, origin: .area, baseSize: 60)
        case .rainbow:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 1, green: 0.32, blue: 0.32, alpha: 1), NSColor(calibratedRed: 1, green: 0.62, blue: 0.25, alpha: 1), NSColor(calibratedRed: 1, green: 0.9, blue: 0.3, alpha: 1), NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.4, alpha: 1), NSColor(calibratedRed: 0.3, green: 0.6, blue: 1, alpha: 1), NSColor(calibratedRed: 0.6, green: 0.4, blue: 1, alpha: 1)], birthRate: 30, lifetime: 10, velocity: 45, velocityRange: 20, yAcceleration: -30, xAcceleration: 8, emissionLongitude: .pi, emissionRange: 0.6, scale: 0.4, scaleRange: 0.25, spin: 0.4, spinRange: 0.8, alphaSpeed: -0.04, origin: .top, baseSize: 14)
        case .snowstorm:
            return EffectSpec(kinds: [.dot, .snowflake], colors: [.white, NSColor(calibratedWhite: 0.9, alpha: 1)], birthRate: 70, lifetime: 12, velocity: 120, velocityRange: 50, yAcceleration: -60, xAcceleration: 40, emissionLongitude: .pi, emissionRange: 0.7, scale: 0.4, scaleRange: 0.3, spin: 0.8, spinRange: 1.4, alphaSpeed: -0.02, origin: .top, baseSize: 12)
        case .blossoms:
            return EffectSpec(kinds: [.leaf], colors: [NSColor(calibratedRed: 1, green: 0.75, blue: 0.85, alpha: 1), NSColor(calibratedRed: 1, green: 0.6, blue: 0.78, alpha: 1), NSColor(calibratedRed: 1, green: 0.85, blue: 0.9, alpha: 1)], birthRate: 16, lifetime: 13, velocity: 42, velocityRange: 22, yAcceleration: -30, xAcceleration: 20, emissionLongitude: .pi, emissionRange: 0.7, scale: 0.5, scaleRange: 0.3, spin: 1.5, spinRange: 2.2, origin: .top, baseSize: 18)
        case .cinders:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 1, green: 0.55, blue: 0.2, alpha: 1), NSColor(calibratedRed: 1, green: 0.3, blue: 0.1, alpha: 1), NSColor(calibratedRed: 1, green: 0.8, blue: 0.4, alpha: 1)], birthRate: 18, lifetime: 9, velocity: 50, velocityRange: 30, yAcceleration: 26, xAcceleration: 14, emissionLongitude: .pi / 2, emissionRange: 0.7, scale: 0.3, scaleRange: 0.2, scaleSpeed: -0.02, alphaSpeed: -0.08, origin: .bottom, baseSize: 18)
        case .pollen:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 0.95, green: 0.9, blue: 0.45, alpha: 0.8), NSColor(calibratedRed: 0.8, green: 0.95, blue: 0.5, alpha: 0.7)], birthRate: 18, lifetime: 16, velocity: 10, velocityRange: 10, yAcceleration: -3, xAcceleration: 6, emissionLongitude: 0, emissionRange: .pi * 2, scale: 0.12, scaleRange: 0.08, alphaSpeed: -0.04, alphaRange: 0.3, origin: .area, baseSize: 10)
        case .comets:
            return EffectSpec(kinds: [.rainLine], colors: [.white, NSColor(calibratedRed: 0.6, green: 0.85, blue: 1, alpha: 1), NSColor(calibratedRed: 0.85, green: 0.7, blue: 1, alpha: 1)], birthRate: 4, lifetime: 5, velocity: 360, velocityRange: 110, yAcceleration: -120, xAcceleration: -160, emissionLongitude: -.pi / 2 - 0.7, emissionRange: 0.05, scale: 0.8, scaleRange: 0.3, alphaSpeed: -0.12, origin: .top, baseSize: 30)
        case .spores:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 0.5, green: 1, blue: 0.7, alpha: 0.7), NSColor(calibratedRed: 0.7, green: 1, blue: 0.9, alpha: 0.6)], birthRate: 14, lifetime: 13, velocity: 28, velocityRange: 16, yAcceleration: 8, xAcceleration: 5, emissionLongitude: .pi / 2, emissionRange: 0.9, scale: 0.16, scaleRange: 0.14, alphaSpeed: -0.05, alphaRange: 0.3, origin: .bottom, baseSize: 14)
        case .wisps:
            return EffectSpec(kinds: [.dot], colors: [NSColor(calibratedRed: 0.6, green: 0.8, blue: 1, alpha: 0.22), NSColor(calibratedRed: 0.8, green: 0.7, blue: 1, alpha: 0.2)], birthRate: 5, lifetime: 16, velocity: 26, velocityRange: 14, yAcceleration: 0, xAcceleration: 8, emissionLongitude: 0, emissionRange: 0.5, scale: 2.2, scaleRange: 1.0, scaleSpeed: 0.05, alphaSpeed: -0.014, origin: .area, baseSize: 56)
        }
    }

    private static func rainCells(wind: CGVector, birthScale: Double) -> [CAEmitterCell] {
        let drop = NSColor(calibratedRed: 0.78, green: 0.86, blue: 1.0, alpha: 1.0)
        let image = particleImage(kind: .rainLine, color: drop, size: 30)
        let layers: [(scale: CGFloat, velocity: CGFloat, alpha: CGFloat, birth: Float, life: Float)] = [
            (0.42, 620, 0.28, 140, 1.5),
            (0.68, 860, 0.42, 95, 1.15),
            (1.0, 1080, 0.6, 60, 0.95)
        ]
        return layers.map { layer in
            let cell = CAEmitterCell()
            cell.contents = image
            cell.birthRate = layer.birth * Float(max(birthScale, 0))
            cell.lifetime = layer.life
            cell.lifetimeRange = layer.life * 0.3
            cell.velocity = layer.velocity
            cell.velocityRange = layer.velocity * 0.18
            cell.yAcceleration = -900 + wind.dy
            cell.xAcceleration = wind.dx
            cell.emissionLongitude = -.pi / 2 - 0.12
            cell.emissionRange = 0.04
            cell.scale = layer.scale
            cell.scaleRange = layer.scale * 0.25
            cell.alphaSpeed = -0.04
            cell.color = NSColor.white.withAlphaComponent(layer.alpha).cgColor
            return cell
        }
    }

    private static func particleImage(kind: ParticleKind, color: NSColor, size: CGFloat) -> CGImage? {
        let dimension: NSSize
        switch kind {
        case .rainLine: dimension = NSSize(width: max(size * 0.09, 2), height: size * 1.3)
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
            let streak = NSBezierPath(roundedRect: rect, xRadius: dimension.width / 2, yRadius: dimension.width / 2)
            if let gradient = NSGradient(colors: [NSColor.clear, color.withAlphaComponent(0.9), color, NSColor.clear],
                                         atLocations: [0.0, 0.35, 0.7, 1.0],
                                         colorSpace: .deviceRGB) {
                gradient.draw(in: streak, angle: 90)
            } else {
                streak.fill()
            }
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
