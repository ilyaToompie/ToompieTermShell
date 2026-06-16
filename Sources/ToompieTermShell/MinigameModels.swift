import CoreGraphics
import Foundation

// MARK: - Vocabulary

/// How hard the тир (target gallery) plays. `progressive` ramps over time from a
/// chosen starting tier — possible, but punishing.
enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard, progressive
    var id: String { rawValue }
    var labelKey: String { "game.difficulty.\(rawValue)" }

    /// Tiers a progressive run is allowed to *start* from.
    static var rampStarts: [Difficulty] { [.easy, .medium, .hard] }
}

enum TargetBehaviour: String, Codable, CaseIterable, Identifiable, Hashable {
    case stationary
    case moving
    var id: String { rawValue }
    var labelKey: String { "game.behaviour.\(rawValue)" }
}

/// When the refill target becomes spawnable after one is removed.
enum AppearanceMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case immediate   // a new target appears as soon as one is removed
    case delayed     // wait `respawnDelay` seconds before refilling
    var id: String { rawValue }
    var labelKey: String { "game.appearance.\(rawValue)" }
}

// MARK: - Settings

/// The full, user-editable тир configuration. Persisted as JSON by
/// `TirGameController`. Decoding is tolerant (every field defaults) so older
/// saved blobs survive new fields — same approach as `GifInstance`.
struct TirSettings: Codable, Equatable, Hashable {
    var targetsOnScreen: Int          // simultaneous targets (1...12)
    var lifetime: Double              // seconds a target lives before expiring (miss)
    var behaviour: TargetBehaviour
    var appearanceMode: AppearanceMode
    var respawnDelay: Double          // seconds, used when appearanceMode == .delayed
    var minDistance: Double           // min px between live target centers
    var maxDistance: Double           // max px from nearest live target (0 = unconstrained)
    var maxCPS: Double                // clicks-per-second cap (0 = uncapped)
    var healthEnabled: Bool           // false => play with 1 HP
    var startingLives: Int            // hearts when healthEnabled
    var moveSpeed: Double             // px/sec when behaviour == .moving
    var gameDuration: Double          // round length seconds (0 = endless)
    var targetSize: Double            // target diameter px
    var targetPool: [String]          // icon strings: "🎯" or "gif:<path>"

    static let defaultEmoji = "🎯"

    init(targetsOnScreen: Int, lifetime: Double, behaviour: TargetBehaviour,
         appearanceMode: AppearanceMode, respawnDelay: Double, minDistance: Double,
         maxDistance: Double, maxCPS: Double, healthEnabled: Bool, startingLives: Int,
         moveSpeed: Double, gameDuration: Double, targetSize: Double, targetPool: [String]) {
        self.targetsOnScreen = targetsOnScreen
        self.lifetime = lifetime
        self.behaviour = behaviour
        self.appearanceMode = appearanceMode
        self.respawnDelay = respawnDelay
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        self.maxCPS = maxCPS
        self.healthEnabled = healthEnabled
        self.startingLives = startingLives
        self.moveSpeed = moveSpeed
        self.gameDuration = gameDuration
        self.targetSize = targetSize
        self.targetPool = targetPool
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Difficulty.medium.baseSettings(targetPool: [TirSettings.defaultEmoji])
        targetsOnScreen = (try? c.decode(Int.self, forKey: .targetsOnScreen)) ?? fallback.targetsOnScreen
        lifetime = (try? c.decode(Double.self, forKey: .lifetime)) ?? fallback.lifetime
        behaviour = (try? c.decode(TargetBehaviour.self, forKey: .behaviour)) ?? fallback.behaviour
        appearanceMode = (try? c.decode(AppearanceMode.self, forKey: .appearanceMode)) ?? fallback.appearanceMode
        respawnDelay = (try? c.decode(Double.self, forKey: .respawnDelay)) ?? fallback.respawnDelay
        minDistance = (try? c.decode(Double.self, forKey: .minDistance)) ?? fallback.minDistance
        maxDistance = (try? c.decode(Double.self, forKey: .maxDistance)) ?? fallback.maxDistance
        maxCPS = (try? c.decode(Double.self, forKey: .maxCPS)) ?? fallback.maxCPS
        healthEnabled = (try? c.decode(Bool.self, forKey: .healthEnabled)) ?? fallback.healthEnabled
        startingLives = (try? c.decode(Int.self, forKey: .startingLives)) ?? fallback.startingLives
        moveSpeed = (try? c.decode(Double.self, forKey: .moveSpeed)) ?? fallback.moveSpeed
        gameDuration = (try? c.decode(Double.self, forKey: .gameDuration)) ?? fallback.gameDuration
        targetSize = (try? c.decode(Double.self, forKey: .targetSize)) ?? fallback.targetSize
        let pool = (try? c.decode([String].self, forKey: .targetPool)) ?? fallback.targetPool
        targetPool = pool.isEmpty ? [TirSettings.defaultEmoji] : pool
    }

    /// A non-empty pool, always safe to `randomElement()`.
    var resolvedPool: [String] { targetPool.isEmpty ? [TirSettings.defaultEmoji] : targetPool }
}

extension Difficulty {
    /// The settings a difficulty maps to. `.progressive` returns its medium base
    /// (the actual start tier is supplied separately by the controller).
    func baseSettings(targetPool: [String]) -> TirSettings {
        switch self {
        case .easy:
            return TirSettings(targetsOnScreen: 2, lifetime: 3.2, behaviour: .stationary,
                appearanceMode: .immediate, respawnDelay: 0, minDistance: 150, maxDistance: 0,
                maxCPS: 0, healthEnabled: true, startingLives: 5, moveSpeed: 0,
                gameDuration: 60, targetSize: 90, targetPool: targetPool)
        case .medium:
            return TirSettings(targetsOnScreen: 3, lifetime: 2.1, behaviour: .stationary,
                appearanceMode: .immediate, respawnDelay: 0, minDistance: 120, maxDistance: 0,
                maxCPS: 12, healthEnabled: true, startingLives: 4, moveSpeed: 0,
                gameDuration: 60, targetSize: 72, targetPool: targetPool)
        case .hard:
            return TirSettings(targetsOnScreen: 4, lifetime: 1.25, behaviour: .moving,
                appearanceMode: .immediate, respawnDelay: 0, minDistance: 90, maxDistance: 0,
                maxCPS: 10, healthEnabled: true, startingLives: 3, moveSpeed: 95,
                gameDuration: 60, targetSize: 58, targetPool: targetPool)
        case .progressive:
            return Difficulty.medium.baseSettings(targetPool: targetPool)
        }
    }
}

/// Pure progressive ramp: from a starting base, harder every 15 s, clamped so the
/// game stays *possible*. Applied only to spawn/expiry decisions; the persisted
/// `TirSettings` is never mutated.
func progressiveRamp(base: TirSettings, elapsed: Double) -> TirSettings {
    var s = base
    let stage = max(0, elapsed) / 15.0
    s.lifetime = max(0.65, base.lifetime - 0.16 * stage)
    s.targetsOnScreen = min(10, base.targetsOnScreen + Int(stage))
    s.minDistance = max(70, base.minDistance - 6 * stage)
    s.targetSize = max(40, base.targetSize - 3 * stage)
    if elapsed > 25 {
        s.behaviour = .moving
        s.moveSpeed = min(190, max(base.moveSpeed, 70) + 9 * stage)
    }
    return s
}

// MARK: - Presets

struct TirPreset: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var settings: TirSettings
    /// Built-in presets aren't user-deletable; the Cats preset also triggers a
    /// lazy GIF download and recomputes its pool on apply.
    var builtin: Bool

    init(id: UUID = UUID(), name: String, settings: TirSettings, builtin: Bool = false) {
        self.id = id
        self.name = name
        self.settings = settings
        self.builtin = builtin
    }

    /// Name the Cats preset carries so the controller knows to (re)hydrate its
    /// pool from the live GIF library on every apply.
    static let catsName = "Cats"
}

// MARK: - Runtime target (not persisted)

/// A live target on the field. Age and position are integrated by the controller
/// from per-frame `dt`, never from wall-clock `Date` — so a pause or an occluded
/// window (which simply stops ticking) can never cause a time jump or mass expiry.
struct TirTarget: Identifiable, Equatable {
    let id = UUID()
    var icon: String            // "🎯" or "gif:<path>"
    var position: CGPoint       // center, overlay-local coords
    var velocity: CGVector      // px/sec (moving targets)
    var age: Double = 0         // seconds alive (accumulated dt)
    var lifetime: Double        // seconds (0 = never expires)
    var size: Double
    /// Set briefly when popped so the view can play a hit flourish before removal.
    var dying: Bool = false

    /// 0…1 fraction of life remaining (drives the shrinking lifetime ring).
    var lifeFraction: Double {
        guard lifetime > 0 else { return 1 }
        return max(0, min(1, 1 - age / lifetime))
    }
}

// MARK: - Cats pack (verified animated GIF sources)

/// The "dumb cats" pack downloaded into `GifLibrary` on demand for the secret
/// Cats preset. All URLs verified to return `image/gif`.
enum TirCatPack {
    static let sources: [(name: String, url: String)] = [
        ("Airborne Loaf", "https://media1.tenor.com/m/vL5aLn5_M8EAAAAC/cat-falling.gif"),
        ("Unbothered Faller", "https://media1.tenor.com/m/BTPu0fO6d_UAAAAC/cat-cat-fall.gif"),
        ("Tumble Cat", "https://media1.tenor.com/m/YicETxq9qbQAAAAC/cat-falling.gif"),
        ("Derp Face", "https://media1.tenor.com/m/ZUXBgwiixf4AAAAC/cat-derp.gif"),
        ("Head-in-Bag Faceplant", "https://media1.tenor.com/m/7xXDALSYt44AAAAC/cat-fail-cat-head-in-bag.gif"),
        ("Gray Derp", "https://media1.tenor.com/m/5OeqooJf_LcAAAAC/cat-derp.gif"),
        ("Box-Peek Doofus", "https://media1.tenor.com/m/yTR5tQRTsK8AAAAC/cat-typical.gif"),
        ("Where Did It Go", "https://media1.tenor.com/m/b8qYLsc4JEsAAAAC/cat-looking.gif"),
        ("What Am I Looking At", "https://media1.tenor.com/m/WloUr6CWdckAAAAC/what-am-i-looking-at-cat.gif"),
        ("Bread Loaf", "https://media1.tenor.com/m/0w0DfQuKI2MAAAAC/cat-loaf.gif"),
        ("Furious Typist", "https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif"),
        ("Bored Manicure", "https://media.giphy.com/media/mlvseq9yvZhba/giphy.gif"),
        ("If It Fits I Sits", "https://media.giphy.com/media/v6aOjy0Qo1fIA/giphy.gif"),
        ("Butt-Wiggle Pounce", "https://media.giphy.com/media/13CoXDiaCcCoyk/giphy.gif")
    ]

    static var urls: [String] { sources.map(\.url) }
}
