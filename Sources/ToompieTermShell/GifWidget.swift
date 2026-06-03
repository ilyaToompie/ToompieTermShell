import SwiftUI

struct GifWidget: View {
    @ObservedObject var prefs: AppPreferences
    @State private var dragStart: CGSize?
    @State private var sizeStart: Double?

    var body: some View {
        if !prefs.gifPath.isEmpty {
            content
                .offset(x: prefs.gifOffsetX, y: prefs.gifOffsetY)
                .gesture(prefs.gifEditable ? dragGesture : nil)
                .animation(.interactiveSpring(), value: prefs.gifEditable)
        }
    }

    private var content: some View {
        let radius = prefs.gifShowBox ? prefs.gifCornerRadius : 0
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack(alignment: .bottomTrailing) {
            AnimatedGifView(path: prefs.gifPath, fit: prefs.gifFit)
                .scaleEffect(prefs.gifInnerScale)
                .scaleEffect(x: prefs.gifFlip ? -1 : 1, y: 1)
                .rotationEffect(.degrees(prefs.gifRotation))
                .frame(width: prefs.gifSize, height: prefs.gifSize)
                .opacity(prefs.gifOpacity)
                .background(boxBackground)
                .clipShape(shape)
                .overlay(
                    shape.stroke(Color.white.opacity(prefs.gifBorder && prefs.gifShowBox ? 0.2 : 0))
                )
                .overlay(editChrome(shape))

            if prefs.gifEditable {
                resizeHandle
            }
        }
        .frame(width: prefs.gifSize, height: prefs.gifSize)
    }

    @ViewBuilder
    private var boxBackground: some View {
        if prefs.gifShowBox {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(prefs.gifBoxOpacity)
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func editChrome(_ shape: RoundedRectangle) -> some View {
        if prefs.gifEditable {
            shape.stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(Color.accentColor))
            .offset(x: 4, y: 4)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if sizeStart == nil { sizeStart = prefs.gifSize }
                        let delta = (value.translation.width + value.translation.height) / 2
                        prefs.gifSize = min(max((sizeStart ?? prefs.gifSize) + delta, 48), 360)
                    }
                    .onEnded { _ in sizeStart = nil }
            )
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == nil { dragStart = CGSize(width: prefs.gifOffsetX, height: prefs.gifOffsetY) }
                prefs.gifOffsetX = (dragStart?.width ?? 0) + value.translation.width
                prefs.gifOffsetY = (dragStart?.height ?? 0) + value.translation.height
            }
            .onEnded { _ in dragStart = nil }
    }
}
