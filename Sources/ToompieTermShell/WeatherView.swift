import AppKit
import SwiftUI

struct WeatherOverlay: NSViewRepresentable {
    let effect: WeatherEffect

    func makeNSView(context: Context) -> WeatherEffectView {
        let view = WeatherEffectView()
        view.apply(effect)
        return view
    }

    func updateNSView(_ nsView: WeatherEffectView, context: Context) {
        nsView.apply(effect)
    }
}

final class WeatherEffectView: NSView {
    private var current: WeatherEffect = .off

    override var isFlipped: Bool { false }

    func apply(_ effect: WeatherEffect) {
        if current == effect, layer?.sublayers?.isEmpty == false || effect == .off {
            if current == effect { return }
        }
        current = effect
        wantsLayer = true
        layer?.sublayers?.removeAll()
        guard effect != .off else { return }
        let emitter = makeEmitter(effect)
        layer?.addSublayer(emitter)
        layoutEmitter(emitter)
    }

    override func layout() {
        super.layout()
        if let emitter = layer?.sublayers?.first as? CAEmitterLayer {
            layoutEmitter(emitter)
        }
    }

    private func layoutEmitter(_ emitter: CAEmitterLayer) {
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY + 10)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
    }

    private func makeEmitter(_ effect: WeatherEffect) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.renderMode = .additive

        let cell = CAEmitterCell()
        cell.contents = Self.dotImage(for: effect)
        switch effect {
        case .snow:
            cell.birthRate = 24
            cell.lifetime = 16
            cell.velocity = 50
            cell.velocityRange = 25
            cell.yAcceleration = -28
            cell.xAcceleration = 6
            cell.emissionLongitude = .pi
            cell.emissionRange = 0.5
            cell.scale = 0.5
            cell.scaleRange = 0.35
            cell.spin = 0.6
            cell.spinRange = 1.0
            cell.alphaSpeed = -0.04
        case .rain:
            cell.birthRate = 80
            cell.lifetime = 6
            cell.velocity = 460
            cell.velocityRange = 80
            cell.yAcceleration = -700
            cell.emissionLongitude = .pi
            cell.emissionRange = 0.05
            cell.scale = 0.7
            cell.scaleRange = 0.2
        case .off:
            break
        }
        emitter.emitterCells = [cell]
        return emitter
    }

    private static func dotImage(for effect: WeatherEffect) -> CGImage? {
        let size: NSSize = effect == .rain ? NSSize(width: 2, height: 18) : NSSize(width: 8, height: 8)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.withAlphaComponent(0.85).setFill()
        if effect == .rain {
            NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 1, yRadius: 1).fill()
        } else {
            NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        }
        image.unlockFocus()
        var rect = NSRect(origin: .zero, size: size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
