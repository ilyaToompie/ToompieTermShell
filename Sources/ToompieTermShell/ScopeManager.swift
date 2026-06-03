import Combine
import Foundation

@MainActor
final class ScopeManager: ObservableObject {
    static let shared = ScopeManager()

    @Published var currentProjectID: UUID? {
        didSet {
            UserDefaults.standard.set(currentProjectID?.uuidString ?? "", forKey: "currentProjectID")
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "currentProjectID") ?? ""
        currentProjectID = UUID(uuidString: raw)
    }

    func belongs(_ id: UUID?) -> Bool {
        id == currentProjectID
    }

    var isGlobal: Bool { currentProjectID == nil }
}
