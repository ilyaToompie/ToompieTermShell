import Combine
import Foundation

/// Progress for the on-demand Cats download, observed by the settings sheet.
@MainActor
final class CatsDownloadModel: ObservableObject {
    static let shared = CatsDownloadModel()
    @Published var inProgress = false
    @Published var completed = 0
    @Published var total = 0
    @Published var failed = 0
    private init() {}
}

/// Lazily pulls the `TirCatPack` GIFs into `GifLibrary` (idempotent across
/// launches via the library's own persistence) and resolves them to `gif:`
/// target-pool strings. Falls back to the 🎯 emoji if everything fails / offline.
@MainActor
enum CatsPresetLoader {
    private static func existingItem(for url: String) -> GifItem? {
        GifLibrary.shared.items.first { $0.sourceURL == url }
    }

    /// `gif:` pool strings for every cat already present in the library.
    static func poolStrings() -> [String] {
        let lib = GifLibrary.shared
        return TirCatPack.urls.compactMap { url in
            existingItem(for: url).map { IconRef.gif(lib.localPath($0)) }
        }
    }

    static var allPresent: Bool { poolStrings().count == TirCatPack.urls.count }

    private static func resolvedPool() -> [String] {
        let pool = poolStrings()
        return pool.isEmpty ? [TirSettings.defaultEmoji] : pool
    }

    /// Downloads any missing cats, then delivers the resolved pool. Safe to call
    /// repeatedly — already-present cats are skipped.
    static func ensureLoaded(completion: @escaping ([String]) -> Void) {
        let model = CatsDownloadModel.shared
        // Reentrancy guard: a second call while a batch is in flight would spin up
        // a parallel counter and fire completions early. Just hand back what we have.
        guard !model.inProgress else {
            completion(resolvedPool())
            return
        }
        let missing = TirCatPack.sources.filter { existingItem(for: $0.url) == nil }
        guard !missing.isEmpty else {
            completion(resolvedPool())
            return
        }
        model.inProgress = true
        model.total = missing.count
        model.completed = 0
        model.failed = 0
        var remaining = missing.count
        for source in missing {
            GifLibrary.shared.download(from: source.url) { item in
                // GifLibrary.download hops its completion back to the main actor.
                if item == nil { model.failed += 1 } else { model.completed += 1 }
                remaining -= 1
                if remaining == 0 {
                    model.inProgress = false
                    completion(resolvedPool())
                }
            }
        }
    }
}
