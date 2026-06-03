import SwiftUI

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String
    let tint: Color

    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    @Published var current: ToastItem?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ text: String, icon: String = "checkmark.circle.fill", tint: Color = .green) {
        current = ToastItem(text: text, icon: icon, tint: tint)
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.current = nil }
        }
    }

    func key(_ key: String, icon: String = "checkmark.circle.fill", tint: Color = .green) {
        show(LocalizationManager.shared.string(key), icon: icon, tint: tint)
    }
}

struct ToastOverlay: View {
    @ObservedObject var center = ToastCenter.shared

    var body: some View {
        VStack {
            if let toast = center.current {
                HStack(spacing: 8) {
                    Image(systemName: toast.icon).foregroundStyle(toast.tint)
                    Text(toast.text).font(.callout.weight(.medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15)))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 10)
            }
            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: center.current)
        .allowsHitTesting(false)
    }
}
