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
    var parallax: CGSize = .zero

    var body: some View {
        ZStack {
            switch prefs.backgroundMode {
            case .native:
                Color(nsColor: .windowBackgroundColor)
            case .solid:
                Color(hex: prefs.windowColorHex)
            case .gradient:
                LinearGradient(
                    colors: [Color(hex: prefs.gradientTopHex), Color(hex: prefs.gradientBottomHex)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .image:
                if let image = loadImage() {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .grayscale(prefs.bgGrayscale ? 1 : 0)
                        .brightness(prefs.bgBrightness)
                        .blur(radius: prefs.bgBlur)
                        .modifier(InvertIf(active: prefs.bgInvert))
                        .overlay(Color.black.opacity(prefs.bgDim))
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color(hex: prefs.gradientTopHex), Color(hex: prefs.gradientBottomHex)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
        .overlay {
            if prefs.backgroundMode != .image {
                DecorBlobs(accent: prefs.accentColor, parallax: parallax).ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }

    private func loadImage() -> NSImage? {
        guard !prefs.backgroundImagePath.isEmpty else { return nil }
        return NSImage(contentsOfFile: prefs.backgroundImagePath)
    }
}

struct InvertIf: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active { content.colorInvert() } else { content }
    }
}

struct AnimatedGifView: NSViewRepresentable {
    let path: String
    var fit: Bool = true

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.animates = true
        view.canDrawSubviewsIntoLayer = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image == nil || context.coordinator.path != path {
            nsView.image = NSImage(contentsOfFile: path)
            context.coordinator.path = path
        }
        nsView.imageScaling = fit ? .scaleProportionallyUpOrDown : .scaleAxesIndependently
        nsView.animates = true
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var path: String = ""
    }
}

enum BackgroundImageStore {
    static func importImage(from source: URL) -> String? {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ToompieTermShell/Backgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = dir.appendingPathComponent("background." + (source.pathExtension.isEmpty ? "img" : source.pathExtension))
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            return destination.path
        } catch {
            return nil
        }
    }
}
