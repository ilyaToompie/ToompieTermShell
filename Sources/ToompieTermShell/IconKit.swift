import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Single convention for the `icon` strings stored on every entity and shortcut:
///
///   `"sf:<symbol>"`  → an SF Symbol
///   `"gif:<path>"`   → an animated GIF at an absolute file path
///   anything else    → literal text / emoji (the historical format)
///
/// Plain emojis stored before the icon picker existed keep working untouched —
/// they simply fall through to the text branch.
enum IconRef {
    static let symbolPrefix = "sf:"
    static let gifPrefix = "gif:"

    static func isSymbol(_ s: String) -> Bool { s.hasPrefix(symbolPrefix) }
    static func isGif(_ s: String) -> Bool { s.hasPrefix(gifPrefix) }

    static func symbolName(_ s: String) -> String { String(s.dropFirst(symbolPrefix.count)) }
    static func gifPath(_ s: String) -> String { String(s.dropFirst(gifPrefix.count)) }

    static func symbol(_ name: String) -> String { symbolPrefix + name }
    static func gif(_ path: String) -> String { gifPrefix + path }

    /// A plain-text form safe to interpolate into native menu / picker labels,
    /// which can't host a custom `IconView`: the emoji itself, or "" for `sf:` /
    /// `gif:` icons (their prefix must never leak as literal text).
    static func plainText(_ s: String) -> String {
        (isSymbol(s) || isGif(s)) ? "" : s
    }

    /// "<emoji> <name>" for emoji icons, or just "<name>" for symbol/gif icons.
    static func labelTitle(_ icon: String, _ name: String) -> String {
        let prefix = plainText(icon)
        return prefix.isEmpty ? name : "\(prefix) \(name)"
    }
}

/// Caches the raw bytes of small icon/GIF files so the same path isn't re-read
/// from disk per use, while still handing each view its OWN `NSImage`.
///
/// We deliberately do NOT share one `NSImage` instance: AppKit drives animated-GIF
/// playback off the image rep's internal frame index, so two `NSImageView`s sharing
/// one animated `NSImage` fight over that counter (desynced / stalled frames, and a
/// "still" preview flickering because an animating copy advances the shared rep).
enum IconImageCache {
    private static let cache = NSCache<NSString, NSData>()

    static func data(at path: String) -> Data? {
        guard !path.isEmpty else { return nil }
        let key = path as NSString
        if let hit = cache.object(forKey: key) { return hit as Data }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        cache.setObject(data as NSData, forKey: key)
        return data
    }

    /// A fresh `NSImage` per call (built from cached bytes), so each view animates
    /// its GIF independently while disk I/O is still paid only once per path.
    static func image(at path: String) -> NSImage? {
        guard let data = data(at: path) else { return nil }
        return NSImage(data: data)
    }
}

/// Renders any icon string (emoji, SF Symbol, or GIF) at a fixed square size.
/// GIF icons pause whenever the window is hidden, matching the rest of the app.
struct IconView: View {
    let icon: String
    var size: CGFloat = 18
    /// Animate GIF icons. Off for dense grids/previews where a still is enough.
    var animatedGif: Bool = true

    @ObservedObject private var motion = MotionController.shared

    init(_ icon: String, size: CGFloat = 18, animatedGif: Bool = true) {
        self.icon = icon
        self.size = size
        self.animatedGif = animatedGif
    }

    var body: some View {
        if IconRef.isGif(icon) {
            AnimatedAssetView(path: IconRef.gifPath(icon), fit: true, playing: animatedGif && motion.animate)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        } else if IconRef.isSymbol(icon) {
            Image(systemName: IconRef.symbolName(icon))
                .font(.system(size: size * 0.8))
                .frame(width: size, height: size)
        } else {
            Text(icon.isEmpty ? "•" : icon)
                .font(.system(size: size * 0.82))
                .frame(width: size, height: size)
        }
    }
}

/// A compact control that shows the current icon and opens a popover to pick an
/// emoji, an SF Symbol, or a GIF from the library. Drop-in replacement for the
/// old free-text `EmojiField`; it reads and writes the same `icon: String`.
struct IconPicker: View {
    @Binding var icon: String
    var allowGif: Bool = true

    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: 6) {
                IconView(icon, size: 20)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.12)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            IconPickerPanel(icon: $icon, allowGif: allowGif, dismiss: { showing = false })
                .frame(width: 320, height: 380)
        }
    }
}

private struct IconPickerPanel: View {
    @Binding var icon: String
    let allowGif: Bool
    let dismiss: () -> Void

    @EnvironmentObject private var loc: LocalizationManager
    @ObservedObject private var gifs = GifLibrary.shared

    enum Tab: Hashable { case emoji, symbol, gif }
    @State private var tab: Tab = .emoji
    @State private var symbolQuery = ""
    @State private var customEmoji = ""
    @State private var showGifImporter = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let symbolColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private let gifColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 10) {
            Picker("", selection: $tab) {
                Text(loc("icon.emoji")).tag(Tab.emoji)
                Text(loc("icon.symbols")).tag(Tab.symbol)
                if allowGif { Text(loc("icon.gif")).tag(Tab.gif) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            switch tab {
            case .emoji: emojiTab
            case .symbol: symbolTab
            case .gif: gifTab
            }
        }
        .padding(12)
        // SwiftUI-native picker: NSOpenPanel.runModal() from inside this popover ran
        // a nested modal loop that left the popover (and the sheet behind it) dead.
        .fileImporter(isPresented: $showGifImporter, allowedContentTypes: [.gif, .image], allowsMultipleSelection: false, onCompletion: handleGifPick)
    }

    private var emojiTab: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("🙂", text: $customEmoji)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .onChange(of: customEmoji) { _, newValue in
                        if newValue.count > 2 { customEmoji = String(newValue.prefix(2)) }
                    }
                Button(loc("common.choose")) {
                    if !customEmoji.isEmpty { icon = customEmoji; dismiss() }
                }
                .disabled(customEmoji.isEmpty)
                Spacer()
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Self.emojis, id: \.self) { e in
                        Button { icon = e; dismiss() } label: {
                            Text(e).font(.system(size: 20)).frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .background(icon == e ? Color.accentColor.opacity(0.25) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private var symbolTab: some View {
        VStack(spacing: 8) {
            SearchLikeField(text: $symbolQuery, placeholder: loc("icon.searchSymbols"))
            ScrollView {
                LazyVGrid(columns: symbolColumns, spacing: 8) {
                    ForEach(filteredSymbols, id: \.self) { name in
                        Button { icon = IconRef.symbol(name); dismiss() } label: {
                            Image(systemName: name).font(.system(size: 18)).frame(width: 36, height: 32)
                        }
                        .buttonStyle(.plain)
                        .help(name)
                        .background(icon == IconRef.symbol(name) ? Color.accentColor.opacity(0.25) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private var gifTab: some View {
        VStack(spacing: 8) {
            HStack {
                Button { showGifImporter = true } label: { Label(loc("gif.import"), systemImage: "square.and.arrow.down") }
                    .controlSize(.small)
                Spacer()
            }
            if gifs.items.isEmpty {
                Spacer()
                Text(loc("icon.noGifs")).font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: gifColumns, spacing: 8) {
                        ForEach(gifs.items) { item in
                            let path = gifs.localPath(item)
                            Button { icon = IconRef.gif(path); dismiss() } label: {
                                gifThumb(path)
                            }
                            .buttonStyle(.plain)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(icon == IconRef.gif(path) ? Color.accentColor : Color.white.opacity(0.1),
                                            lineWidth: icon == IconRef.gif(path) ? 2 : 1)
                            )
                        }
                    }
                }
            }
        }
    }

    /// A still first-frame thumbnail. Rendered as a SwiftUI `Image` (not the
    /// passthrough `AnimatedAssetView`, whose nil hit-test made the grid buttons
    /// unclickable), and given an explicit content shape so the whole tile taps.
    @ViewBuilder
    private func gifThumb(_ path: String) -> some View {
        Group {
            if let img = IconImageCache.image(at: path) {
                Image(nsImage: img).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(width: 60, height: 60)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func handleGifPick(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        if let item = gifs.importFile(url) {
            icon = IconRef.gif(gifs.localPath(item))
            dismiss()
        }
    }

    private var filteredSymbols: [String] {
        let q = symbolQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Self.symbols }
        return Self.symbols.filter { $0.contains(q) }
    }

    // A practical, curated set — enough to cover terminals, dev work, git, and UI.
    static let symbols: [String] = [
        "terminal", "terminal.fill", "bolt.fill", "bolt", "star.fill", "star", "heart.fill",
        "folder.fill", "folder", "doc.fill", "doc", "tray.fill", "archivebox.fill",
        "play.fill", "pause.fill", "stop.fill", "arrow.clockwise", "arrow.triangle.2.circlepath",
        "arrow.up.circle.fill", "arrow.down.circle.fill", "arrow.right.circle.fill",
        "network", "wifi", "globe", "antenna.radiowaves.left.and.right", "cloud.fill",
        "server.rack", "externaldrive.fill", "internaldrive", "memorychip", "cpu",
        "hammer.fill", "wrench.and.screwdriver.fill", "gearshape.fill", "gear", "slider.horizontal.3",
        "shippingbox.fill", "cube.fill", "cube.box.fill", "shippingbox.and.arrow.backward",
        "chevron.left.forwardslash.chevron.right", "curlybraces", "command", "keyboard",
        "key.fill", "lock.fill", "lock.open.fill", "shield.fill", "checkmark.seal.fill",
        "arrow.branch", "arrow.triangle.branch", "arrow.up.to.line", "arrow.down.to.line",
        "trash.fill", "xmark.octagon.fill", "exclamationmark.triangle.fill", "flame.fill",
        "sparkles", "wand.and.stars", "paintbrush.fill", "eyedropper", "moon.fill", "sun.max.fill",
        "bell.fill", "tag.fill", "pin.fill", "mappin.and.ellipse", "house.fill", "building.2.fill",
        "person.fill", "person.2.fill", "envelope.fill", "paperplane.fill", "link",
        "magnifyingglass", "list.bullet", "square.grid.2x2.fill", "rectangle.stack.fill",
        "doc.text.fill", "note.text", "book.fill", "bookmark.fill", "calendar", "clock.fill",
        "gauge.with.dots.needle.67percent", "chart.bar.fill", "waveform", "dot.radiowaves.left.and.right",
        "battery.100", "powerplug.fill", "display", "laptopcomputer", "desktopcomputer",
        "leaf.fill", "drop.fill", "snowflake", "bubbles.and.sparkles.fill", "circle.hexagongrid.fill",
        "flag.fill", "crown.fill", "gift.fill", "ticket.fill", "puzzlepiece.fill", "ladybug.fill"
    ]

    static let emojis: [String] = {
        let raw = "⚡️🚀🔥✨🌟💡🛠️🔧⚙️📦📁📂🗂️📝📌🔑🔒🔓🛡️✅❌⭐️❤️💜💙💚🧡💛🖥️💻⌨️🖱️🐳🐙🐍☕️🌐🌍🛰️📡📶🔌🔋🧪🧬🔬🧰🧲🎯🎨🖌️🌈🌙☀️⛅️🌧️❄️🍃🌱🌳🪴🐞🦋🐝🦊🐺🦄🌸🌺💎👑🎁🎫🧩🎮🕹️📊📈📉📅⏰🔔📣🎵🎬✈️📍🏠🏢👤👥📧💬🔗🔍🧠💀🤖👾🎉"
        return raw.map { String($0) }
    }()
}

/// A lightweight search box for the symbol picker (the project's `SearchField`
/// is bound to sidebar styling; this keeps the popover self-contained).
private struct SearchLikeField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
            TextField(placeholder, text: $text).textFieldStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
    }
}
