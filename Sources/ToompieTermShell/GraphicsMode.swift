import Foundation
import SwiftUI

/// User-facing "graphics mode" with deliberately silly names. Picks how hard the
/// app pushes the ambient eye-candy (live backgrounds, decor blobs, particle
/// weather, the focused-terminal glow). `.auto` reads the machine's RAM and lands
/// on a sensible tier; the rest are manual overrides.
///
/// The default is `.auto`, which resolves to **high** on machines with more than
/// 8 GB of RAM and **medium** on 8 GB or less — keeping the heaviest, per-frame
/// effects (the rotating focus halo, 60 fps backgrounds) opt-in via Ludicrous.
enum GraphicsMode: String, CaseIterable, Identifiable {
    case auto
    case potato
    case medium
    case high
    case ultra

    var id: String { rawValue }
    var labelKey: String { "graphics.\(rawValue)" }

    /// SF Symbol shown in the picker chip.
    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .potato: return "tortoise.fill"
        case .medium: return "figure.walk"
        case .high: return "hare.fill"
        case .ultra: return "flame.fill"
        }
    }

    /// The concrete tier this mode renders at. `.auto` defers to the RAM probe.
    var resolvedTier: GraphicsTier {
        switch self {
        case .auto: return SystemGraphics.autoTier
        case .potato: return .potato
        case .medium: return .medium
        case .high: return .high
        case .ultra: return .ultra
        }
    }
}

/// The concrete rendering level. Manual modes map 1:1; `.auto` is resolved to one
/// of these by RAM.
enum GraphicsTier: String {
    case potato
    case medium
    case high
    case ultra

    var quality: GraphicsQuality { GraphicsQuality(tier: self) }
}

/// Reads hardware facts once. `physicalMemory` never changes at runtime, so the
/// auto tier is computed a single time and cached.
enum SystemGraphics {
    /// Installed RAM in gibibytes (e.g. 16.0 on a 16 GB machine).
    static let memoryGB: Double = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

    /// User's rule: more than 8 GB → high, 8 GB or less → medium. Compared in raw
    /// bytes so an exactly-8 GB Mac lands on medium without float rounding surprises.
    static let autoTier: GraphicsTier =
        ProcessInfo.processInfo.physicalMemory > 8 * 1_073_741_824 ? .high : .medium
}

/// Per-tier knobs the rest of the UI reads to scale its eye-candy. One struct so
/// callers never branch on the tier themselves.
struct GraphicsQuality {
    let tier: GraphicsTier

    /// Frame cap for the continuously-animating procedural backgrounds and decor
    /// blobs. Higher = smoother but more GPU recomposites per second.
    var backgroundFPS: Double {
        switch tier {
        case .potato: return 15
        case .medium: return 24
        case .high: return 30
        case .ultra: return 60
        }
    }

    /// Multiplier on particle birth rates so weather thins out on weak machines.
    var particleScale: Double {
        switch tier {
        case .potato: return 0.35
        case .medium: return 0.65
        case .high: return 1.0
        case .ultra: return 1.25
        }
    }

    /// Density multiplier for the starfield (and any other point-cloud) background.
    var starCountScale: Double {
        switch tier {
        case .potato: return 0.4
        case .medium: return 0.7
        case .high: return 1.0
        case .ultra: return 1.3
        }
    }

    /// The floating, heavily-blurred decor blobs behind static backgrounds.
    var decorBlobs: Bool { tier != .potato }

    /// Filmic grain overlay is allowed (it animates a blend every frame).
    var grain: Bool { tier != .potato }

    /// Whether the focused terminal panel gets its accent drop-shadow glow at all.
    var focusGlow: Bool { tier != .potato }

    /// Radius of that glow. 0 on potato (disabled), gentle on medium, full on ultra.
    var focusGlowRadius: CGFloat {
        switch tier {
        case .potato: return 0
        case .medium: return 7
        case .high: return 11
        case .ultra: return 14
        }
    }

    /// The *rotating* angular focus halo. This is the single most expensive idle
    /// effect — it re-rasterizes the shadowed, clipped terminal view every frame —
    /// so it's reserved for Ludicrous. Other tiers show a static accent border,
    /// which still marks focus at no per-frame cost. This is the direct fix for
    /// "the terminal glow loads the system too much".
    var animatedFocusBorder: Bool { tier == .ultra }
}
