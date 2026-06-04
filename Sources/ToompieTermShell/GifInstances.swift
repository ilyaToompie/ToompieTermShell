import Foundation

struct GifInstance: Identifiable, Codable, Equatable {
    var id: UUID
    var path: String
    var x: Double
    var y: Double
    var size: Double
    var opacity: Double
    var innerScale: Double
    var rotation: Double
    var cornerRadius: Double
    var fit: Bool
    var flip: Bool
    var showBox: Bool
    var boxOpacity: Double
    var border: Bool

    init(path: String) {
        id = UUID()
        self.path = path
        x = 0
        y = 0
        size = 140
        opacity = 1
        innerScale = 1
        rotation = 0
        cornerRadius = 14
        fit = true
        flip = false
        showBox = false
        boxOpacity = 0
        border = false
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        path = (try? c.decode(String.self, forKey: .path)) ?? ""
        x = (try? c.decode(Double.self, forKey: .x)) ?? 0
        y = (try? c.decode(Double.self, forKey: .y)) ?? 0
        size = (try? c.decode(Double.self, forKey: .size)) ?? 140
        opacity = (try? c.decode(Double.self, forKey: .opacity)) ?? 1
        innerScale = (try? c.decode(Double.self, forKey: .innerScale)) ?? 1
        rotation = (try? c.decode(Double.self, forKey: .rotation)) ?? 0
        cornerRadius = (try? c.decode(Double.self, forKey: .cornerRadius)) ?? 14
        fit = (try? c.decode(Bool.self, forKey: .fit)) ?? true
        flip = (try? c.decode(Bool.self, forKey: .flip)) ?? false
        showBox = (try? c.decode(Bool.self, forKey: .showBox)) ?? false
        boxOpacity = (try? c.decode(Double.self, forKey: .boxOpacity)) ?? 0
        border = (try? c.decode(Bool.self, forKey: .border)) ?? false
    }
}

@MainActor
final class GifInstanceStore: ObservableObject {
    static let shared = GifInstanceStore()
    @Published var instances: [GifInstance] { didSet { persist() } }

    private let key = "gifInstances"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([GifInstance].self, from: data) {
            instances = decoded.filter { FileManager.default.fileExists(atPath: $0.path) }
        } else {
            instances = []
            let legacy = UserDefaults.standard.string(forKey: "gifPath") ?? ""
            if !legacy.isEmpty, FileManager.default.fileExists(atPath: legacy) {
                var inst = GifInstance(path: legacy)
                let size = UserDefaults.standard.double(forKey: "gifSize")
                inst.size = size == 0 ? 140 : size
                instances = [inst]
            }
        }
    }

    func add(path: String) {
        var inst = GifInstance(path: path)
        let n = Double(instances.count)
        inst.x = n * 26
        inst.y = n * 26
        instances.append(inst)
    }

    func remove(_ id: UUID) {
        instances.removeAll { $0.id == id }
    }

    func removeAll() {
        instances.removeAll()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(instances) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
