import Combine
import Foundation

/// Lightweight session + lifetime counters surfaced by the **Stats** menu.
///
/// Two kinds of numbers live here: *session* counters reset every launch (tabs
/// opened this run, palette opens, theme shuffles…) and *lifetime* counters that
/// persist in `UserDefaults` (total targets popped in the тир minigame, the
/// all-time high score). Instrumentation call sites stay tiny — everywhere just
/// calls `SessionStats.shared.record(.tabOpened)`.
@MainActor
final class SessionStats: ObservableObject {
    static let shared = SessionStats()

    /// When the app process started — basis for the "uptime" readout.
    let launchDate = Date()

    // Session-scoped (reset on relaunch).
    @Published private(set) var tabsOpened = 0
    @Published private(set) var tabsClosed = 0
    @Published private(set) var paletteOpens = 0
    @Published private(set) var themeShuffles = 0
    @Published private(set) var gamesPlayed = 0

    // Lifetime (persisted).
    @Published private(set) var targetsHit: Int { didSet { defaults.set(targetsHit, forKey: "stats.targetsHit") } }
    @Published private(set) var tirHighScore: Int { didSet { defaults.set(tirHighScore, forKey: "stats.tirHighScore") } }
    @Published private(set) var tirBestStreak: Int { didSet { defaults.set(tirBestStreak, forKey: "stats.tirBestStreak") } }

    private let defaults = UserDefaults.standard

    private init() {
        targetsHit = defaults.integer(forKey: "stats.targetsHit")
        tirHighScore = defaults.integer(forKey: "stats.tirHighScore")
        tirBestStreak = defaults.integer(forKey: "stats.tirBestStreak")
    }

    enum Event {
        case tabOpened
        case tabClosed
        case paletteOpened
        case themeShuffled
        case gameStarted
        case targetHit
    }

    func record(_ event: Event) {
        switch event {
        case .tabOpened: tabsOpened += 1
        case .tabClosed: tabsClosed += 1
        case .paletteOpened: paletteOpens += 1
        case .themeShuffled: themeShuffles += 1
        case .gameStarted: gamesPlayed += 1
        case .targetHit: targetsHit += 1
        }
    }

    /// Records a finished тир run, keeping the best score/streak ever seen.
    func recordGameResult(score: Int, streak: Int) {
        if score > tirHighScore { tirHighScore = score }
        if streak > tirBestStreak { tirBestStreak = streak }
    }

    func resetLifetime() {
        targetsHit = 0
        tirHighScore = 0
        tirBestStreak = 0
    }

    /// "2h 14m" style uptime string for the menu.
    var uptimeString: String {
        let seconds = Int(Date().timeIntervalSince(launchDate))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
