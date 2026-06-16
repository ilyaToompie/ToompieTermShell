import SwiftUI

/// The full-window тир overlay: dark scrim, difficulty/start screen, the live
/// field with targets, the border-sliding HUD, and the game-over screen. Sits
/// above the terminal content (inserted in `ContentView`). The game loop is
/// driven by `TirLoopDriver` so it pauses for free when the window is occluded.
struct TirGameOverlay: View {
    @ObservedObject private var game = TirGameController.shared
    @ObservedObject private var prefs = AppPreferences.shared
    @State private var showSettings = false
    @State private var selected: Difficulty = .medium

    private var hudVisible: Bool {
        game.phase == .countdown || game.phase == .playing || game.phase == .paused
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Scrim — dims the terminal and absorbs stray clicks (an empty-space
                // click during play breaks the combo).
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { game.registerMiss() }

                switch game.phase {
                case .selecting:
                    startCard
                case .over:
                    overCard
                default:
                    field(size: geo.size)
                }

                if game.phase == .countdown { countdownView }
                if game.phase == .paused { pausedView }
            }
            .overlay(alignment: .topLeading) { if hudVisible { hearts.padding(16).transition(.move(edge: .leading).combined(with: .opacity)) } }
            .overlay(alignment: .top) { if hudVisible { scorePill.padding(.top, 14).transition(.move(edge: .top).combined(with: .opacity)) } }
            .overlay(alignment: .bottom) { if hudVisible { controls.padding(.bottom, 20).transition(.move(edge: .bottom).combined(with: .opacity)) } }
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: hudVisible)
            .onAppear { selected = game.lastDifficulty; game.setFieldSize(geo.size) }
            .onChange(of: geo.size) { _, new in game.setFieldSize(new) }
        }
        .sheet(isPresented: $showSettings) { TirSettingsSheet() }
    }

    // MARK: - Field + targets

    private func field(size: CGSize) -> some View {
        ZStack {
            ForEach(game.targets, id: \.id) { target in
                TirTargetView(target: target)
                    .position(target.position)
                    .transition(.scale(scale: 0.35).combined(with: .opacity))
            }
            // Animate only on count changes (spawn / pop / expire) so per-frame
            // position updates stay crisp instead of lagging behind an animation.
            TirLoopDriver()
        }
        .frame(width: size.width, height: size.height)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: game.targets.count)
    }

    // MARK: - HUD clusters

    private var scorePill: some View {
        HStack(spacing: 14) {
            Label("\(game.score)", systemImage: "star.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            if game.combo > 1 {
                Text("×\(game.combo)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(prefs.accentColor)
                    .transition(.scale)
            }
            Divider().frame(height: 16)
            HStack(spacing: 5) {
                Image(systemName: "timer")
                Text(timeString)
                    .monospacedDigit()
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(loc("game.settings.title"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .glass(cornerRadius: 16)
    }

    private var hearts: some View {
        Group {
            if game.healthEnabled {
                HStack(spacing: 4) {
                    ForEach(0..<max(game.maxLives, 1), id: \.self) { i in
                        Image(systemName: i < game.lives ? "heart.fill" : "heart")
                            .foregroundStyle(i < game.lives ? .red : .white.opacity(0.25))
                    }
                }
            } else {
                Label(loc("game.onehp"), systemImage: "bolt.heart.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glass(cornerRadius: 14)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            roundButton(game.phase == .paused ? "play.fill" : "pause.fill") { game.togglePause() }
            roundButton("stop.fill", tint: .red) { game.stop() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glass(cornerRadius: 18)
    }

    private func roundButton(_ symbol: String, tint: Color = .primary, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
    }

    // MARK: - Countdown / pause

    private var countdownView: some View {
        Text(game.countdownValue > 0 ? "\(game.countdownValue)" : loc("game.countdownGo"))
            .font(.system(size: 120, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: prefs.accentColor.opacity(0.8), radius: 30)
            .id(game.countdownValue)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: game.countdownValue)
    }

    private var pausedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "pause.circle.fill").font(.system(size: 56))
            Text(loc("game.pause")).font(.title2.weight(.bold))
            Button(loc("game.resume")) { game.togglePause() }
                .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding(40)
        .glass(cornerRadius: 24)
    }

    // MARK: - Start screen

    private var startCard: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("game.tir.title")).font(.system(size: 30, weight: .heavy, design: .rounded))
                    Text(loc("game.tir.subtitle")).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { game.dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(loc("game.difficulty.label")).font(.headline)
                HStack(spacing: 10) {
                    ForEach(Difficulty.allCases) { d in
                        difficultyChip(d)
                    }
                }
                if selected == .progressive {
                    HStack(spacing: 8) {
                        Text(loc("game.difficulty.startFrom")).font(.subheadline).foregroundStyle(.secondary)
                        Picker("", selection: Binding(get: { game.progressiveStart }, set: { game.progressiveStart = $0 })) {
                            ForEach(Difficulty.rampStarts) { d in Text(loc(d.labelKey)).tag(d) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 260)
                    }
                    .transition(.opacity)
                }
            }

            HStack(spacing: 12) {
                Button {
                    showSettings = true
                } label: {
                    Label(loc("game.settings.title"), systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    game.start(difficulty: selected, progressiveStart: game.progressiveStart)
                } label: {
                    Label(loc("game.start"), systemImage: "scope")
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            if game.customized {
                Label(loc("game.customHint"), systemImage: "wand.and.stars")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 520)
        .glass(cornerRadius: 26)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    private func difficultyChip(_ d: Difficulty) -> some View {
        let isSel = selected == d
        return Button {
            selected = d
            game.applyDifficultyDefaults(d)
        } label: {
            Text(loc(d.labelKey))
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSel ? prefs.accentColor.opacity(0.85) : Color.white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(isSel ? Color.white : Color.primary)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(isSel ? 0 : 0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Over screen

    private var overCard: some View {
        VStack(spacing: 14) {
            Image(systemName: game.lastResultWin ? "trophy.fill" : "xmark.octagon.fill")
                .font(.system(size: 50))
                .foregroundStyle(game.lastResultWin ? .yellow : .red)
            Text(loc(game.lastResultWin ? "game.win" : "game.lose"))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
            HStack(spacing: 22) {
                stat(loc("game.score"), "\(game.score)")
                stat(loc("game.bestCombo"), "×\(game.bestCombo)")
            }
            HStack(spacing: 12) {
                Button(loc("game.close")) { game.dismiss() }
                    .buttonStyle(.bordered)
                Button(loc("game.retry")) { game.retry() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.top, 4)
        }
        .padding(30)
        .frame(width: 380)
        .glass(cornerRadius: 26)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var timeString: String {
        guard game.timeRemaining > 0 else { return "∞" }
        let total = Int(game.timeRemaining.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func loc(_ key: String) -> String { LocalizationManager.shared.string(key) }
}

// MARK: - Loop driver

/// Calls `tick(now:)` once per frame. Full speed via `TimelineView(.animation)`
/// when motion is allowed, a slow timeline under reduce-motion, and nothing at
/// all when the window is occluded (so the loop freezes with zero CPU).
private struct TirLoopDriver: View {
    @ObservedObject private var game = TirGameController.shared
    @ObservedObject private var motion = MotionController.shared
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        Group {
            if motion.animate && !prefs.reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / max(15, prefs.graphicsQuality.backgroundFPS))) { ctx in
                    Color.clear.onChange(of: ctx.date) { _, d in game.tick(now: d) }
                }
            } else if motion.animate {
                TimelineView(.periodic(from: .now, by: 0.12)) { ctx in
                    Color.clear.onChange(of: ctx.date) { _, d in game.tick(now: d) }
                }
            } else {
                Color.clear   // occluded / hidden — frozen
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Target view

private struct TirTargetView: View {
    let target: TirTarget
    @ObservedObject private var motion = MotionController.shared
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        ZStack {
            if target.lifetime > 0 {
                Circle()
                    .trim(from: 0, to: target.lifeFraction)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: target.size + 12, height: target.size + 12)
                    .opacity(0.85)
            }
            icon.frame(width: target.size, height: target.size)
        }
        .frame(width: target.size + 16, height: target.size + 16)
        .contentShape(Circle())
        .onTapGesture { TirGameController.shared.registerHit(target.id) }
    }

    @ViewBuilder private var icon: some View {
        if IconRef.isGif(target.icon) {
            AnimatedAssetView(path: IconRef.gifPath(target.icon), fit: true,
                              playing: motion.animate && !prefs.reduceMotion)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        } else {
            Text(target.icon)
                .font(.system(size: target.size * 0.9))
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
        }
    }

    private var ringColor: Color {
        let f = target.lifeFraction
        return f > 0.5 ? .green : (f > 0.25 ? .orange : .red)
    }
}
