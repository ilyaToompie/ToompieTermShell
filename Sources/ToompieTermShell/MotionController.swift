import AppKit
import Combine
import SwiftUI

/// Single source of truth for "should continuous background animations run?".
///
/// Every `TimelineView(.animation)` redraws ~30×/sec forever, burning CPU even
/// when nothing is on screen. This controller flips `animate` off whenever none
/// of the app's windows are actually visible (fully covered by other windows,
/// minimized, or on another Space) and back on the moment one is. Because the
/// pause only happens while the window is invisible, there is no visible change
/// to motion or UX — only a large CPU saving when the app is in the background.
@MainActor
final class MotionController: ObservableObject {
    static let shared = MotionController()

    @Published private(set) var animate: Bool = true

    private var observers: [NSObjectProtocol] = []

    private init() {
        let nc = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSApplication.didBecomeActiveNotification,
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification,
        ]
        for name in names {
            let token = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.recompute() }
            }
            observers.append(token)
        }
    }

    private func recompute() {
        let visible = NSApp.windows.contains { window in
            window.isVisible && !window.isMiniaturized && window.occlusionState.contains(.visible)
        }
        if visible != animate { animate = visible }
    }
}
