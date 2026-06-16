import Combine
import CoreGraphics
import Foundation
import SwiftUI

/// Lifecycle of a тир round.
enum TirPhase: Equatable {
    case idle        // overlay not shown
    case selecting   // difficulty / start screen
    case countdown   // 3·2·1
    case playing
    case paused
    case over
}

/// The authoritative тир game state + loop. Owns no `Timer`: the overlay drives
/// `tick(now:)` from a `TimelineView` (or a slow timer under reduce-motion), so
/// the loop pauses for free when the window is occluded. All mutation is on the
/// main actor; `tick` is synchronous and never spawns a Task (avoids re-entrancy).
@MainActor
final class TirGameController: ObservableObject {
    static let shared = TirGameController()

    // Published run state (read by the overlay/HUD).
    @Published private(set) var phase: TirPhase = .idle
    @Published private(set) var score = 0
    @Published private(set) var combo = 0
    @Published private(set) var bestCombo = 0
    @Published private(set) var lives = 3
    @Published private(set) var maxLives = 3
    @Published private(set) var timeRemaining: Double = 60
    @Published private(set) var countdownValue = 3
    @Published private(set) var targets: [TirTarget] = []
    @Published private(set) var lastResultWin = false
    @Published private(set) var runDifficulty: Difficulty = .medium

    // Persisted, user-editable config.
    @Published var settings: TirSettings { didSet { persist(settings, encoded: true, key: settingsKey) } }
    @Published var presets: [TirPreset] { didSet { persist(presets, encoded: true, key: presetsKey) } }
    @Published var lastDifficulty: Difficulty { didSet { defaults.set(lastDifficulty.rawValue, forKey: lastDiffKey) } }
    @Published var progressiveStart: Difficulty { didSet { defaults.set(progressiveStart.rawValue, forKey: progStartKey) } }

    /// True while the live settings differ from the picked difficulty's defaults
    /// (so the start screen can show a "Custom" hint).
    @Published var customized = false

    // Private run bookkeeping.
    private var runSettings: TirSettings = Difficulty.medium.baseSettings(targetPool: [TirSettings.defaultEmoji])
    private var fieldSize: CGSize = .zero
    private var clock: Double = 0                 // seconds elapsed this round
    private var countdownRemaining: Double = 3
    private var lastTick: Date?
    private var nextSpawnAt: Double = 0           // clock value when refill is allowed again
    private var clickTimestamps: [Date] = []      // sliding 1s window for the CPS cap

    /// Vertical band reserved at the top for the HUD so targets never hide under it.
    private let hudTopInset: CGFloat = 96

    private let defaults = UserDefaults.standard
    private let settingsKey = "tir.settings"
    private let presetsKey = "tir.presets"
    private let lastDiffKey = "tir.lastDifficulty"
    private let progStartKey = "tir.progressiveStart"
    private var persisting = true

    private var prefs: AppPreferences { .shared }

    private init() {
        // Decode persisted blobs (tolerant: fall back to medium defaults).
        if let data = defaults.string(forKey: settingsKey)?.data(using: .utf8),
           let s = try? JSONDecoder().decode(TirSettings.self, from: data) {
            settings = s
        } else {
            settings = Difficulty.medium.baseSettings(targetPool: [TirSettings.defaultEmoji])
        }
        if let data = defaults.string(forKey: presetsKey)?.data(using: .utf8),
           let p = try? JSONDecoder().decode([TirPreset].self, from: data) {
            presets = p
        } else {
            presets = []
        }
        lastDifficulty = Difficulty(rawValue: defaults.string(forKey: lastDiffKey) ?? "") ?? .medium
        progressiveStart = Difficulty(rawValue: defaults.string(forKey: progStartKey) ?? "") ?? .easy
    }

    // MARK: - Presentation

    func present() {
        score = 0; combo = 0; bestCombo = 0
        targets = []
        lastTick = nil
        phase = .selecting
    }

    func dismiss() {
        targets = []
        lastTick = nil
        phase = .idle
    }

    /// Escape key: pause a live game, otherwise close the overlay.
    func handleEscape() {
        switch phase {
        case .playing: togglePause()
        case .idle: break
        default: dismiss()
        }
    }

    func setFieldSize(_ size: CGSize) { fieldSize = size }

    // MARK: - Difficulty / start

    /// Quick-preset the editable settings to a difficulty's defaults (keeping the
    /// current target pool). Picking a difficulty chip calls this.
    func applyDifficultyDefaults(_ d: Difficulty) {
        lastDifficulty = d
        guard d != .progressive else { customized = false; return }
        var s = d.baseSettings(targetPool: settings.resolvedPool)
        s.healthEnabled = settings.healthEnabled
        settings = s
        customized = false
    }

    func start(difficulty: Difficulty, progressiveStart from: Difficulty) {
        runDifficulty = difficulty
        lastDifficulty = difficulty
        progressiveStart = from
        let pool = settings.resolvedPool

        if difficulty == .progressive {
            var base = from.baseSettings(targetPool: pool)
            base.healthEnabled = settings.healthEnabled
            base.startingLives = settings.startingLives
            base.gameDuration = settings.gameDuration
            base.maxCPS = settings.maxCPS
            runSettings = base
        } else {
            runSettings = settings
        }

        let startLives = runSettings.healthEnabled ? max(1, runSettings.startingLives) : 1
        maxLives = startLives
        lives = startLives
        score = 0; combo = 0; bestCombo = 0
        timeRemaining = runSettings.gameDuration
        clock = 0
        nextSpawnAt = 0
        lastTick = nil
        clickTimestamps = []
        targets = []
        countdownRemaining = 3
        countdownValue = 3
        SessionStats.shared.record(.gameStarted)
        phase = .countdown
    }

    func togglePause() {
        switch phase {
        case .playing: phase = .paused; lastTick = nil
        case .paused: phase = .playing; lastTick = nil
        default: break
        }
    }

    /// Stop button: end the round now and show the score.
    func stop() {
        guard phase == .playing || phase == .paused || phase == .countdown else { return }
        endGame(win: false)
    }

    func retry() { present() }

    // MARK: - The loop

    func tick(now: Date) {
        guard phase == .playing || phase == .countdown else { lastTick = nil; return }
        let dt: Double
        if let last = lastTick {
            dt = min(0.1, max(0, now.timeIntervalSince(last)))   // clamp survives frame hitches / occlusion gaps
        } else {
            dt = 0
        }
        lastTick = now

        if phase == .countdown {
            countdownRemaining -= dt
            countdownValue = max(1, Int(ceil(countdownRemaining)))
            if countdownRemaining <= 0 { beginPlaying() }
            return
        }

        clock += dt
        let eff = effective()

        // Round timer (0 == endless).
        if eff.gameDuration > 0 {
            timeRemaining = max(0, timeRemaining - dt)
            if timeRemaining <= 0 { endGame(win: true); return }
        }

        moveAndAge(dt: dt, eff: eff)
        expireDeadTargets()
        if phase != .playing { return }   // expiry may have ended the game
        refill(eff: eff)
    }

    private func beginPlaying() {
        phase = .playing
        // Keep the countdown tick's timestamp so the first playing frame gets a
        // real (small) dt instead of a wasted zero-advancement frame.
        clock = 0
        refill(eff: effective())
    }

    private func moveAndAge(dt: Double, eff: TirSettings) {
        guard !targets.isEmpty else { return }
        let moving = eff.behaviour == .moving
        for i in targets.indices {
            targets[i].age += dt
            guard moving, targets[i].velocity != .zero else { continue }
            var p = targets[i].position
            let r = targets[i].size / 2
            p.x += targets[i].velocity.dx * dt
            p.y += targets[i].velocity.dy * dt
            if p.x < r { p.x = r; targets[i].velocity.dx = abs(targets[i].velocity.dx) }
            if p.x > fieldSize.width - r { p.x = fieldSize.width - r; targets[i].velocity.dx = -abs(targets[i].velocity.dx) }
            let top = hudTopInset + r
            if p.y < top { p.y = top; targets[i].velocity.dy = abs(targets[i].velocity.dy) }
            if p.y > fieldSize.height - r { p.y = fieldSize.height - r; targets[i].velocity.dy = -abs(targets[i].velocity.dy) }
            targets[i].position = p
        }
    }

    private func expireDeadTargets() {
        let dead = targets.filter { $0.lifetime > 0 && $0.age >= $0.lifetime }
        guard !dead.isEmpty else { return }
        let deadIDs = Set(dead.map(\.id))
        targets.removeAll { deadIDs.contains($0.id) }
        for _ in dead {
            loseLife()
            if phase == .over { return }
        }
    }

    private func refill(eff: TirSettings) {
        guard clock >= nextSpawnAt else { return }
        var guardCount = 0
        while targets.count < eff.targetsOnScreen && guardCount < eff.targetsOnScreen + 2 {
            guardCount += 1
            guard let t = makeTarget(eff) else { break }
            targets.append(t)
        }
    }

    private func makeTarget(_ eff: TirSettings) -> TirTarget? {
        guard fieldSize.width > 40, fieldSize.height > 40 else { return nil }
        let size = eff.targetSize
        let r = size / 2
        let minX = r + 10, maxX = fieldSize.width - r - 10
        let minY = hudTopInset + r, maxY = fieldSize.height - r - 10
        guard maxX > minX, maxY > minY else { return nil }

        func randomPoint() -> CGPoint {
            CGPoint(x: .random(in: minX...maxX), y: .random(in: minY...maxY))
        }
        let centers = targets.map(\.position)
        var chosen: CGPoint?
        for _ in 0..<30 {
            let p = randomPoint()
            let minOK = centers.allSatisfy { hypot(p.x - $0.x, p.y - $0.y) >= CGFloat(eff.minDistance) }
            let maxOK = eff.maxDistance <= 0 || centers.isEmpty
                || centers.contains { hypot(p.x - $0.x, p.y - $0.y) <= CGFloat(eff.maxDistance) }
            if minOK && maxOK { chosen = p; break }
        }
        let pos = chosen ?? randomPoint()   // fallback guarantees the field keeps filling

        var velocity = CGVector.zero
        if eff.behaviour == .moving, eff.moveSpeed > 0 {
            let angle = Double.random(in: 0..<(2 * Double.pi))
            velocity = CGVector(dx: cos(angle) * eff.moveSpeed, dy: sin(angle) * eff.moveSpeed)
        }
        let icon = eff.resolvedPool.randomElement() ?? TirSettings.defaultEmoji
        return TirTarget(icon: icon, position: pos, velocity: velocity, lifetime: eff.lifetime, size: size)
    }

    // MARK: - Hits / misses

    /// A target was clicked. Honors the CPS cap and awards combo-scaled points.
    func registerHit(_ id: UUID) {
        guard phase == .playing else { return }
        let now = Date()
        clickTimestamps.removeAll { now.timeIntervalSince($0) > 1 }
        let eff = effective()
        if eff.maxCPS > 0, Double(clickTimestamps.count) >= eff.maxCPS { return }   // autoclicker / spam guard
        clickTimestamps.append(now)

        guard let idx = targets.firstIndex(where: { $0.id == id }) else { return }
        let target = targets.remove(at: idx)
        combo += 1
        bestCombo = max(bestCombo, combo)
        let lifeBonus = Int(target.lifeFraction * 10)        // reward fast hits
        score += 10 + min(combo, 30) + lifeBonus
        SessionStats.shared.record(.targetHit)

        if eff.appearanceMode == .delayed { nextSpawnAt = clock + eff.respawnDelay }
    }

    /// Click on empty space — breaks the combo but costs no life (forgiving).
    func registerMiss() {
        guard phase == .playing else { return }
        combo = 0
    }

    private func loseLife() {
        combo = 0
        lives -= 1
        if lives <= 0 { endGame(win: false) }
    }

    private func endGame(win: Bool) {
        lastResultWin = win
        targets = []
        lastTick = nil
        SessionStats.shared.recordGameResult(score: score, streak: bestCombo)
        phase = .over
    }

    // MARK: - Effective settings (ramp + quality gating)

    private func effective() -> TirSettings {
        var s = runDifficulty == .progressive ? progressiveRamp(base: runSettings, elapsed: clock) : runSettings
        if prefs.reduceMotion { s.behaviour = .stationary }
        if prefs.graphicsQuality.tier == .potato { s.targetsOnScreen = min(s.targetsOnScreen, 3) }
        return s
    }

    var healthEnabled: Bool { runSettings.healthEnabled }

    // MARK: - Presets

    /// Built-ins shown above user presets; not deletable.
    var builtinPresets: [TirPreset] {
        let defaultPreset = TirPreset(name: "Default",
                                      settings: Difficulty.medium.baseSettings(targetPool: [TirSettings.defaultEmoji]),
                                      builtin: true)
        let catsPreset = TirPreset(name: TirPreset.catsName, settings: catsSettings(), builtin: true)
        return [defaultPreset, catsPreset]
    }

    var allPresets: [TirPreset] { builtinPresets + presets }

    private func catsSettings() -> TirSettings {
        var s = Difficulty.medium.baseSettings(targetPool: CatsPresetLoader.poolStrings())
        s.behaviour = .moving
        s.moveSpeed = 80
        s.lifetime = 2.6
        s.targetSize = 96
        if s.targetPool.isEmpty { s.targetPool = [TirSettings.defaultEmoji] }
        return s
    }

    func apply(_ preset: TirPreset) {
        if preset.builtin, preset.name == TirPreset.catsName {
            applyCatsPreset()
        } else {
            settings = preset.settings
            customized = false
        }
    }

    /// Downloads the cats (idempotent) then swaps the live settings to the cat pool.
    func applyCatsPreset() {
        CatsPresetLoader.ensureLoaded { [weak self] pool in
            guard let self else { return }
            var s = self.settings
            s.targetPool = pool
            s.behaviour = .moving
            if s.moveSpeed <= 0 { s.moveSpeed = 80 }
            self.settings = s
            self.customized = true
            ToastCenter.shared.show(
                LocalizationManager.shared.string(pool.first == TirSettings.defaultEmoji ? "game.cats.failed" : "game.cats.ready"),
                icon: "cat.fill", tint: .orange
            )
        }
    }

    func saveCurrentAsPreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        presets.append(TirPreset(name: trimmed, settings: settings))
    }

    func deletePreset(_ id: UUID) {
        presets.removeAll { $0.id == id }
    }

    func markCustomized() { customized = true }

    // MARK: - Target pool editing (used by the settings sheet)

    func togglePoolGif(_ gifString: String) {
        var pool = settings.targetPool
        if let idx = pool.firstIndex(of: gifString) {
            pool.remove(at: idx)
        } else {
            pool.append(gifString)
        }
        settings.targetPool = pool
        customized = true
    }

    func setPoolToEmojiDefault() {
        settings.targetPool = [TirSettings.defaultEmoji]
        customized = true
    }

    // MARK: - Persistence helper

    private func persist<T: Encodable>(_ value: T, encoded: Bool, key: String) {
        guard persisting else { return }
        if let data = try? JSONEncoder().encode(value), let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: key)
        }
    }
}
