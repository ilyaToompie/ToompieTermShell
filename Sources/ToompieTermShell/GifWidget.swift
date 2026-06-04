import SwiftUI

struct GifWidget: View {
    @Binding var instance: GifInstance
    let editable: Bool
    @State private var dragStart: CGSize?
    @State private var sizeStart: Double?

    var body: some View {
        content
            .contentShape(Rectangle())
            .offset(x: instance.x, y: instance.y)
            .gesture(editable ? dragGesture : nil)
    }

    private var content: some View {
        let radius = instance.showBox ? instance.cornerRadius : 0
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack(alignment: .bottomTrailing) {
            AnimatedAssetView(path: instance.path, fit: instance.fit)
                .scaleEffect(instance.innerScale)
                .scaleEffect(x: instance.flip ? -1 : 1, y: 1)
                .rotationEffect(.degrees(instance.rotation))
                .frame(width: instance.size, height: instance.size)
                .opacity(instance.opacity)
                .background(boxBackground)
                .clipShape(shape)
                .overlay(shape.stroke(Color.white.opacity(instance.border && instance.showBox ? 0.2 : 0)))
                .overlay(editChrome(shape))

            if editable {
                resizeHandle
            }
        }
        .frame(width: instance.size, height: instance.size)
    }

    @ViewBuilder
    private var boxBackground: some View {
        if instance.showBox {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(instance.boxOpacity)
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func editChrome(_ shape: RoundedRectangle) -> some View {
        if editable {
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
                        if sizeStart == nil { sizeStart = instance.size }
                        let delta = (value.translation.width + value.translation.height) / 2
                        instance.size = min(max((sizeStart ?? instance.size) + delta, 48), 400)
                    }
                    .onEnded { _ in sizeStart = nil }
            )
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == nil { dragStart = CGSize(width: instance.x, height: instance.y) }
                instance.x = (dragStart?.width ?? 0) + value.translation.width
                instance.y = (dragStart?.height ?? 0) + value.translation.height
            }
            .onEnded { _ in dragStart = nil }
    }
}
