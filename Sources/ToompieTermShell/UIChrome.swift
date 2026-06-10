import Combine
import Foundation

/// Ephemeral (non-persisted) toggle for "cinema mode": hide all UI chrome
/// (sidebar, terminals, toasts) and show only the background. Driven by a GIF
/// tap action; tapping the GIF again — or pressing Escape — restores the UI.
@MainActor
final class UIChrome: ObservableObject {
    static let shared = UIChrome()

    @Published var hidden = false

    private init() {}

    func toggleHidden() { hidden.toggle() }
}
