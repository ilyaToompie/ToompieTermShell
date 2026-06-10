import AppKit
import SwiftUI

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 14
    var strokeOpacity: Double = 0.18
    var fillOpacity: Double = 0.10

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(Color.white.opacity(fillOpacity))
            .background(.ultraThinMaterial, in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(strokeOpacity + 0.2), Color.white.opacity(strokeOpacity * 0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
            )
            .clipShape(shape)
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 5)
    }
}

extension View {
    func glass(cornerRadius: CGFloat = 14, strokeOpacity: Double = 0.18, fillOpacity: Double = 0.10) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity, fillOpacity: fillOpacity))
    }
}

struct AppBackground: View {
    @ObservedObject var prefs: AppPreferences
    @ObservedObject private var motion = MotionController.shared
    var parallax: CGSize = .zero

    var body: some View {
        baseLayer
            // Universal post-processing — applies to every background mode.
            .saturation(prefs.bgSaturation)
            .grayscale(prefs.bgGrayscale ? 1 : 0)
            .brightness(prefs.bgBrightness)
            .modifier(InvertIf(active: prefs.bgInvert))
            .blur(radius: prefs.bgBlur)
            .overlay {
                if prefs.bgDim > 0 { Color.black.opacity(prefs.bgDim) }
            }
            .overlay {
                if prefs.bgVignette > 0 { VignetteOverlay(strength: prefs.bgVignette) }
            }
            .overlay {
                if prefs.bgScanlines { ScanlinesOverlay() }
            }
            .overlay {
                if prefs.bgGrain > 0 { GrainOverlay(strength: prefs.bgGrain) }
            }
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var baseLayer: some View {
        ZStack {
            // Anchor color sits behind everything so heavy blur never reveals
            // the bare window chrome at the edges.
            if prefs.backgroundMode != .native {
                anchorColor
            }

            switch prefs.backgroundMode {
            case .native:
                Color(nsColor: .windowBackgroundColor)
            case .solid:
                Color(hex: prefs.windowColorHex)
            case .gradient:
                gradient
            case .image:
                if let image = loadImage() {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    gradient
                }
            case .animated:
                LiveBackgroundView(
                    style: prefs.liveBackground,
                    top: Color(hex: prefs.gradientTopHex),
                    bottom: Color(hex: prefs.gradientBottomHex),
                    accent: prefs.accentColor,
                    speed: prefs.bgEffectSpeed,
                    intensity: prefs.bgEffectIntensity,
                    parallax: parallax
                )
            case .gif:
                if !prefs.backgroundGifPath.isEmpty,
                   FileManager.default.fileExists(atPath: prefs.backgroundGifPath) {
                    // PassthroughImageView never steals clicks; animation pauses when
                    // the window is hidden to save CPU.
                    AnimatedAssetView(path: prefs.backgroundGifPath, fit: true, playing: motion.animate)
                        .clipped()
                } else {
                    gradient
                }
            }

            if showsDecorBlobs {
                DecorBlobs(accent: prefs.accentColor, parallax: parallax)
            }
        }
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: prefs.gradientTopHex), Color(hex: prefs.gradientBottomHex)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var anchorColor: Color {
        switch prefs.backgroundMode {
        case .solid: return Color(hex: prefs.windowColorHex)
        case .image, .gif: return .black
        default: return Color(hex: prefs.gradientBottomHex)
        }
    }

    /// Floating decorative blobs look good behind static fills, but clash with
    /// the animated live backgrounds (which provide their own motion) and photos.
    private var showsDecorBlobs: Bool {
        switch prefs.backgroundMode {
        case .native, .solid, .gradient: return true
        case .image, .animated, .gif: return false
        }
    }

    private func loadImage() -> NSImage? {
        BackgroundImageCache.image(at: prefs.backgroundImagePath)
    }
}

/// Decodes background images once and keeps them in memory, keyed by path +
/// modification date. Without this, `NSImage(contentsOfFile:)` was re-decoding
/// the full-resolution photo on *every* SwiftUI body pass (each preference
/// change and every parallax mouse-move) — saturating the main thread and
/// making the UI feel frozen / unclickable.
enum BackgroundImageCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(at path: String) -> NSImage? {
        guard !path.isEmpty else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let key = "\(path)|\(mtime)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

/// Owns the parallax state so cursor movement only re-renders the background
/// subtree — not the whole window (sidebar + terminals). Previously parallax
/// lived on ContentView, so every mouse-move invalidated the entire UI.
struct BackgroundContainer: View {
    @ObservedObject var prefs: AppPreferences
    @ObservedObject private var motion = MotionController.shared
    @State private var parallax: CGSize = .zero

    var body: some View {
        AppBackground(prefs: prefs, parallax: parallax)
            .onContinuousHover { phase in
                guard motion.animate, case .active(let loc) = phase else { return }
                let target = CGSize(width: (loc.x - 500) * 0.03, height: (loc.y - 380) * 0.03)
                // Ignore sub-pixel jitter to avoid a re-render on every event.
                if abs(target.width - parallax.width) + abs(target.height - parallax.height) > 0.6 {
                    withAnimation(.easeOut(duration: 0.4)) { parallax = target }
                }
            }
    }
}

struct InvertIf: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.colorInvert() } else { content }
    }
}

/// NSImageView that never participates in hit-testing, so it can't steal clicks/drags from SwiftUI.
final class PassthroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct AnimatedGifView: NSViewRepresentable {
    let path: String
    var fit: Bool = true
    /// When false, the first frame is shown without animating (cheap; used for previews).
    var animating: Bool = true

    func makeNSView(context: Context) -> NSImageView {
        let view = PassthroughImageView()
        view.animates = animating
        view.canDrawSubviewsIntoLayer = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image == nil || context.coordinator.path != path {
            // Shared cache: the same GIF used in several chips/widgets is decoded
            // into memory once instead of once per view.
            nsView.image = IconImageCache.image(at: path)
            context.coordinator.path = path
        }
        nsView.imageScaling = fit ? .scaleProportionallyUpOrDown : .scaleAxesIndependently
        nsView.animates = animating
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var path: String = ""
    }
}

/// Renders an animated asset from disk. GIF-only since the Lottie integration was removed;
/// kept under this name so existing call sites stay unchanged.
struct AnimatedAssetView: View {
    let path: String
    var fit: Bool = true
    /// When false, the asset is shown as a static still (first frame) with no animation / CPU cost.
    var playing: Bool = true

    var body: some View {
        AnimatedGifView(path: path, fit: fit, animating: playing)
    }
}

enum BackgroundImageStore {
    private static var backgroundsDir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ToompieTermShell/Backgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func importImage(from source: URL) -> String? {
        // Unique filename per import: `copyItem` preserves the source's
        // modification date, so a fixed name could collide in the image cache
        // when two different photos happen to share an mtime.
        let ext = source.pathExtension.isEmpty ? "img" : source.pathExtension
        let destination = backgroundsDir.appendingPathComponent("bg-\(UUID().uuidString).\(ext)")
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return destination.path
        } catch {
            return nil
        }
    }

    /// Imports a local GIF. Uses a unique filename so the player reliably reloads
    /// (AnimatedGifView only swaps its image when the path changes).
    static func importGif(from source: URL) -> String? {
        let ext = source.pathExtension.isEmpty ? "gif" : source.pathExtension
        let destination = backgroundsDir.appendingPathComponent("bg-\(UUID().uuidString).\(ext)")
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return destination.path
        } catch {
            return nil
        }
    }

    /// Downloads a GIF (or image) from a URL into the backgrounds cache and
    /// returns the local path, or nil on failure.
    static func downloadGif(from urlString: String) async -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let remote = URL(string: trimmed), remote.scheme?.hasPrefix("http") == true else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: remote)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count > 64 else { return nil }
            let ext = remote.pathExtension.isEmpty ? "gif" : remote.pathExtension
            let destination = backgroundsDir.appendingPathComponent("bg-\(UUID().uuidString).\(ext)")
            try data.write(to: destination, options: .atomic)
            return destination.path
        } catch {
            return nil
        }
    }
}
