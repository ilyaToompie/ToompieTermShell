import AppKit
import CoreText
import Foundation

struct GoogleFontEntry: Identifiable, Hashable {
    let family: String
    let fileName: String
    let urlPath: String

    var id: String { family }

    var downloadURL: URL? {
        URL(string: "https://cdn.jsdelivr.net/gh/google/fonts@main/" + urlPath)
    }
}

@MainActor
final class FontLibrary: ObservableObject {
    static let shared = FontLibrary()

    @Published private(set) var downloadedFamilies: Set<String> = []
    @Published private(set) var downloadingFamilies: Set<String> = []
    @Published private(set) var failedFamilies: Set<String> = []

    let catalog: [GoogleFontEntry] = [
        GoogleFontEntry(family: "JetBrains Mono", fileName: "JetBrainsMono.ttf", urlPath: "ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf"),
        GoogleFontEntry(family: "Fira Code", fileName: "FiraCode.ttf", urlPath: "ofl/firacode/FiraCode%5Bwght%5D.ttf"),
        GoogleFontEntry(family: "Source Code Pro", fileName: "SourceCodePro.ttf", urlPath: "ofl/sourcecodepro/SourceCodePro%5Bwght%5D.ttf"),
        GoogleFontEntry(family: "IBM Plex Mono", fileName: "IBMPlexMono-Regular.ttf", urlPath: "ofl/ibmplexmono/IBMPlexMono-Regular.ttf"),
        GoogleFontEntry(family: "Roboto Mono", fileName: "RobotoMono.ttf", urlPath: "ofl/robotomono/RobotoMono%5Bwght%5D.ttf"),
        GoogleFontEntry(family: "Inconsolata", fileName: "Inconsolata.ttf", urlPath: "ofl/inconsolata/Inconsolata%5Bwdth,wght%5D.ttf"),
        GoogleFontEntry(family: "Space Mono", fileName: "SpaceMono-Regular.ttf", urlPath: "ofl/spacemono/SpaceMono-Regular.ttf"),
        GoogleFontEntry(family: "Ubuntu Mono", fileName: "UbuntuMono-Regular.ttf", urlPath: "ufl/ubuntumono/UbuntuMono-Regular.ttf"),
        GoogleFontEntry(family: "Anonymous Pro", fileName: "AnonymousPro-Regular.ttf", urlPath: "ofl/anonymouspro/AnonymousPro-Regular.ttf"),
        GoogleFontEntry(family: "Overpass Mono", fileName: "OverpassMono.ttf", urlPath: "ofl/overpassmono/OverpassMono%5Bwght%5D.ttf"),
        GoogleFontEntry(family: "Red Hat Mono", fileName: "RedHatMono.ttf", urlPath: "ofl/redhatmono/RedHatMono%5Bwght%5D.ttf"),
        GoogleFontEntry(family: "Spline Sans Mono", fileName: "SplineSansMono.ttf", urlPath: "ofl/splinesansmono/SplineSansMono%5Bwght%5D.ttf"),
        GoogleFontEntry(family: "Noto Sans Mono", fileName: "NotoSansMono.ttf", urlPath: "ofl/notosansmono/NotoSansMono%5Bwdth,wght%5D.ttf"),
        GoogleFontEntry(family: "Fragment Mono", fileName: "FragmentMono-Regular.ttf", urlPath: "ofl/fragmentmono/FragmentMono-Regular.ttf")
    ]

    private var registeredURLs: [String: URL] = [:]

    private init() {
        registerCached()
    }

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ToompieTermShell/Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func localURL(for entry: GoogleFontEntry) -> URL {
        cacheDirectory.appendingPathComponent(entry.fileName)
    }

    private func registerCached() {
        for entry in catalog {
            let url = localURL(for: entry)
            if FileManager.default.fileExists(atPath: url.path) {
                if register(url: url) {
                    registeredURLs[entry.family] = url
                    downloadedFamilies.insert(entry.family)
                }
            }
        }
    }

    @discardableResult
    private func register(url: URL) -> Bool {
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !ok, let cfError = error?.takeRetainedValue() {
            let code = CFErrorGetCode(cfError)
            if code == CTFontManagerError.alreadyRegistered.rawValue {
                return true
            }
            return false
        }
        return ok
    }

    func isDownloaded(_ family: String) -> Bool {
        downloadedFamilies.contains(family)
    }

    func isDownloading(_ family: String) -> Bool {
        downloadingFamilies.contains(family)
    }

    func font(family: String, size: CGFloat) -> NSFont? {
        guard let url = registeredURLs[family] else { return nil }
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first else { return nil }
        let ctFont = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        return ctFont as NSFont
    }

    func download(_ entry: GoogleFontEntry) {
        guard !downloadingFamilies.contains(entry.family), !downloadedFamilies.contains(entry.family) else { return }
        guard let remote = entry.downloadURL else { return }
        downloadingFamilies.insert(entry.family)
        failedFamilies.remove(entry.family)

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: remote)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count > 1024 else {
                    throw URLError(.badServerResponse)
                }
                let destination = localURL(for: entry)
                try data.write(to: destination, options: .atomic)
                downloadingFamilies.remove(entry.family)
                if register(url: destination) {
                    registeredURLs[entry.family] = destination
                    downloadedFamilies.insert(entry.family)
                } else {
                    try? FileManager.default.removeItem(at: destination)
                    failedFamilies.insert(entry.family)
                }
            } catch {
                downloadingFamilies.remove(entry.family)
                failedFamilies.insert(entry.family)
            }
        }
    }

    func removeAllDownloaded() {
        for entry in catalog {
            let url = localURL(for: entry)
            try? FileManager.default.removeItem(at: url)
        }
        registeredURLs.removeAll()
        downloadedFamilies.removeAll()
        failedFamilies.removeAll()
    }
}
