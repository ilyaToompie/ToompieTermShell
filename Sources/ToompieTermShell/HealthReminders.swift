import Combine
import Foundation
import UserNotifications

/// The wellness nudges offered by the **Health** menu. Each kind ships a sensible
/// default cadence; the user can flip any on/off and retune its interval. Titles
/// and bodies resolve through `LocalizationManager` (`health.<raw>.title/.body`).
enum HealthReminderKind: String, CaseIterable, Identifiable {
    case water
    case eyes        // 20-20-20 eye rest
    case stretch
    case posture
    case stand
    case breathe
    case blink
    case wrists
    case sunlight
    case breakTime   // Pomodoro-style step away

    var id: String { rawValue }

    /// Default minutes between fires. Deliberately spread out so enabling several
    /// at once doesn't bury the user in banners.
    var defaultMinutes: Int {
        switch self {
        case .eyes: return 20
        case .blink: return 25
        case .breakTime: return 25
        case .water: return 30
        case .posture: return 35
        case .wrists: return 40
        case .stretch: return 45
        case .stand: return 50
        case .breathe: return 60
        case .sunlight: return 120
        }
    }

    var emoji: String {
        switch self {
        case .water: return "💧"
        case .eyes: return "👀"
        case .stretch: return "🤸"
        case .posture: return "🪑"
        case .stand: return "🧍"
        case .breathe: return "🌬️"
        case .blink: return "😌"
        case .wrists: return "✋"
        case .sunlight: return "☀️"
        case .breakTime: return "☕️"
        }
    }

    /// SF Symbol for in-app toasts / menu rows.
    var symbol: String {
        switch self {
        case .water: return "drop.fill"
        case .eyes: return "eye.fill"
        case .stretch: return "figure.flexibility"
        case .posture: return "figure.seated.side"
        case .stand: return "figure.stand"
        case .breathe: return "wind"
        case .blink: return "eyes"
        case .wrists: return "hand.raised.fill"
        case .sunlight: return "sun.max.fill"
        case .breakTime: return "cup.and.saucer.fill"
        }
    }

    var titleKey: String { "health.\(rawValue).title" }
    var bodyKey: String { "health.\(rawValue).body" }
    var labelKey: String { "health.\(rawValue).label" }
}

/// Delivers `willPresent` banners even while the app is frontmost. Kept as a
/// separate `NSObject` because `UNUserNotificationCenterDelegate` requires it.
private final class HealthNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

@MainActor
final class HealthReminders: ObservableObject {
    static let shared = HealthReminders()

    /// Which reminders are armed.
    @Published private(set) var enabled: Set<HealthReminderKind> {
        didSet { persistEnabled() }
    }

    /// Per-kind interval overrides in minutes (absent ⇒ `kind.defaultMinutes`).
    @Published private(set) var intervalOverrides: [String: Int] {
        didSet { persistIntervals() }
    }

    /// nil = not yet asked, true/false = last known authorization result.
    @Published private(set) var notificationsAuthorized: Bool?

    private let defaults = UserDefaults.standard
    private let enabledKey = "health.enabled"
    private let intervalsKey = "health.intervals"
    private let delegate = HealthNotificationDelegate()
    /// Fallback timers used when notifications aren't authorized/available.
    private var fallbackTimers: [String: Timer] = [:]

    private init() {
        enabled = Set(
            (defaults.string(forKey: enabledKey) ?? "")
                .split(separator: ",")
                .compactMap { HealthReminderKind(rawValue: String($0)) }
        )
        if let data = defaults.data(forKey: intervalsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            intervalOverrides = decoded
        } else {
            intervalOverrides = [:]
        }
        if notificationsAvailable {
            let center = UNUserNotificationCenter.current()
            center.delegate = delegate
            center.getNotificationSettings { [weak self] settings in
                let ok = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                Task { @MainActor in
                    self?.notificationsAuthorized = ok
                    self?.reschedule()
                }
            }
        } else {
            notificationsAuthorized = false
            reschedule()
        }
    }

    /// `UNUserNotificationCenter.current()` traps when the binary isn't running
    /// inside an app bundle (e.g. `swift run`); guard on a real bundle id.
    private var notificationsAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    var anyEnabled: Bool { !enabled.isEmpty }

    func isEnabled(_ kind: HealthReminderKind) -> Bool { enabled.contains(kind) }

    func minutes(for kind: HealthReminderKind) -> Int {
        intervalOverrides[kind.rawValue] ?? kind.defaultMinutes
    }

    func setMinutes(_ minutes: Int, for kind: HealthReminderKind) {
        intervalOverrides[kind.rawValue] = max(1, minutes)
        if enabled.contains(kind) { schedule(kind) }
    }

    func toggle(_ kind: HealthReminderKind) {
        setEnabled(!enabled.contains(kind), for: kind)
    }

    func setEnabled(_ on: Bool, for kind: HealthReminderKind) {
        if on {
            enabled.insert(kind)
            ensureAuthorization { [weak self] in self?.schedule(kind) }
        } else {
            enabled.remove(kind)
            cancel(kind)
        }
    }

    func disableAll() {
        for kind in enabled { cancel(kind) }
        enabled = []
    }

    /// Fires a reminder immediately so the user can preview it (and trips the
    /// authorization prompt on first use).
    func fireNow(_ kind: HealthReminderKind) {
        ensureAuthorization { [weak self] in
            guard let self else { return }
            if self.notificationsAuthorized == true, self.notificationsAvailable {
                let content = self.content(for: kind)
                let request = UNNotificationRequest(
                    identifier: "health.test.\(kind.rawValue)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                )
                UNUserNotificationCenter.current().add(request)
            } else {
                self.showToast(kind)
            }
        }
    }

    // MARK: - Authorization

    private var authInFlight = false
    private var pendingAuthCompletions: [() -> Void] = []

    private func ensureAuthorization(then completion: @escaping () -> Void) {
        guard notificationsAvailable else { notificationsAuthorized = false; completion(); return }
        if notificationsAuthorized == true { completion(); return }
        // Coalesce: rapid toggles must not stack multiple system prompts.
        pendingAuthCompletions.append(completion)
        guard !authInFlight else { return }
        authInFlight = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in
                guard let self else { return }
                self.notificationsAuthorized = granted
                self.authInFlight = false
                let pending = self.pendingAuthCompletions
                self.pendingAuthCompletions = []
                pending.forEach { $0() }
            }
        }
    }

    // MARK: - Scheduling

    private func reschedule() {
        // Drop everything, then re-arm only what's enabled.
        if notificationsAvailable {
            let ids = HealthReminderKind.allCases.map { "health.\($0.rawValue)" }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        fallbackTimers.values.forEach { $0.invalidate() }
        fallbackTimers.removeAll()
        for kind in enabled { schedule(kind) }
    }

    private func schedule(_ kind: HealthReminderKind) {
        let seconds = TimeInterval(max(1, minutes(for: kind)) * 60)
        // Clear any prior instance of this kind first.
        cancel(kind)

        if notificationsAuthorized == true, notificationsAvailable {
            let request = UNNotificationRequest(
                identifier: "health.\(kind.rawValue)",
                content: content(for: kind),
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
            )
            UNUserNotificationCenter.current().add(request)
        } else {
            // In-app fallback: a repeating toast while the app is running.
            let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.showToast(kind) }
            }
            fallbackTimers[kind.rawValue] = timer
        }
    }

    private func cancel(_ kind: HealthReminderKind) {
        if notificationsAvailable {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["health.\(kind.rawValue)"])
        }
        fallbackTimers[kind.rawValue]?.invalidate()
        fallbackTimers[kind.rawValue] = nil
    }

    private func content(for kind: HealthReminderKind) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(kind.emoji)  \(LocalizationManager.shared.string(kind.titleKey))"
        content.body = LocalizationManager.shared.string(kind.bodyKey)
        content.sound = .default
        return content
    }

    private func showToast(_ kind: HealthReminderKind) {
        ToastCenter.shared.show(
            "\(kind.emoji) \(LocalizationManager.shared.string(kind.titleKey))",
            icon: kind.symbol,
            tint: .teal
        )
    }

    // MARK: - Persistence

    private func persistEnabled() {
        defaults.set(enabled.map(\.rawValue).sorted().joined(separator: ","), forKey: enabledKey)
    }

    private func persistIntervals() {
        if let data = try? JSONEncoder().encode(intervalOverrides) {
            defaults.set(data, forKey: intervalsKey)
        }
    }
}
