import AppKit
import Foundation

struct GifItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var fileName: String
    var sourceURL: String

    init(id: UUID = UUID(), name: String, fileName: String, sourceURL: String = "") {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.sourceURL = sourceURL
    }
}

@MainActor
final class GifLibrary: ObservableObject {
    static let shared = GifLibrary()

    @Published private(set) var items: [GifItem] = []
    @Published private(set) var downloading = false
    @Published var lastError: String = ""

    private let indexKey = "gifLibraryIndex"

    private init() {
        load()
    }

    var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ToompieTermShell/Gifs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func localPath(_ item: GifItem) -> String {
        directory.appendingPathComponent(item.fileName).path
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: indexKey),
              let decoded = try? JSONDecoder().decode([GifItem].self, from: data) else { return }
        items = decoded.filter { FileManager.default.fileExists(atPath: localPath($0)) }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: indexKey)
        }
    }

    @discardableResult
    func importFile(_ url: URL) -> GifItem? {
        let fileName = "\(UUID().uuidString).\(url.pathExtension.isEmpty ? "gif" : url.pathExtension)"
        let destination = directory.appendingPathComponent(fileName)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
        let item = GifItem(name: url.deletingPathExtension().lastPathComponent, fileName: fileName, sourceURL: url.path)
        items.append(item)
        persist()
        return item
    }

    func download(from urlString: String, completion: ((GifItem?) -> Void)? = nil) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let remote = URL(string: trimmed), remote.scheme?.hasPrefix("http") == true else {
            lastError = "Invalid URL"
            completion?(nil)
            return
        }
        downloading = true
        lastError = ""
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: remote)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count > 64 else {
                    throw URLError(.badServerResponse)
                }
                let ext = remote.pathExtension.isEmpty ? "gif" : remote.pathExtension
                let fileName = "\(UUID().uuidString).\(ext)"
                let destination = directory.appendingPathComponent(fileName)
                try data.write(to: destination, options: .atomic)
                let name = remote.deletingPathExtension().lastPathComponent
                let item = GifItem(name: name.isEmpty ? "gif" : name, fileName: fileName, sourceURL: trimmed)
                items.append(item)
                persist()
                downloading = false
                completion?(item)
            } catch {
                downloading = false
                lastError = error.localizedDescription
                completion?(nil)
            }
        }
    }

    func remove(_ item: GifItem) {
        try? FileManager.default.removeItem(atPath: localPath(item))
        items.removeAll { $0.id == item.id }
        persist()
    }
}
