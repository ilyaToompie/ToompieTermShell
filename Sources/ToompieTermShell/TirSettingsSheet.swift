import SwiftUI

/// The тир "secret settings": presets, health, target behaviour/appearance,
/// distances, counts, CPS cap, and the GIF target-pool multi-select (plus the
/// one-tap Cats preset). Edits mutate `TirGameController.shared.settings`, which
/// persists itself.
struct TirSettingsSheet: View {
    @ObservedObject private var game = TirGameController.shared
    @ObservedObject private var gifs = GifLibrary.shared
    @ObservedObject private var cats = CatsDownloadModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var newPresetName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    presetsCard
                    healthCard
                    behaviourCard
                    spawnCard
                    poolCard
                }
                .padding(18)
            }
        }
        .frame(width: 540, height: 660)
    }

    private var header: some View {
        HStack {
            Label(loc("game.settings.title"), systemImage: "slider.horizontal.3").font(.headline)
            Spacer()
            Button(loc("game.close")) { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(14)
    }

    // MARK: - Presets

    private var presetsCard: some View {
        card("game.settings.presets", "square.stack.3d.up.fill") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(game.allPresets) { preset in
                    HStack(spacing: 8) {
                        Button { game.apply(preset) } label: {
                            HStack {
                                Image(systemName: preset.name == TirPreset.catsName ? "cat.fill" : "scope")
                                Text(preset.name)
                                if preset.builtin {
                                    Text(loc("game.settings.builtin"))
                                        .font(.caption2).padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Color.white.opacity(0.1), in: Capsule())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        if !preset.builtin {
                            Button(role: .destructive) { game.deletePreset(preset.id) } label: {
                                Image(systemName: "trash").font(.caption)
                            }
                            .buttonStyle(.plain).foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Divider()

                HStack {
                    TextField(loc("game.settings.presetName"), text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                    Button(loc("game.settings.savePreset")) {
                        game.saveCurrentAsPreset(named: newPresetName)
                        newPresetName = ""
                    }
                    .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Button {
                    game.applyCatsPreset()
                } label: {
                    if cats.inProgress {
                        Label("\(loc("game.cats.downloading")) \(cats.completed)/\(cats.total)", systemImage: "arrow.down.circle")
                    } else {
                        Label(loc("game.settings.loadCats"), systemImage: "cat.fill")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(cats.inProgress)
            }
        }
    }

    // MARK: - Health

    private var healthCard: some View {
        card("game.settings.healthSection", "heart.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(loc("game.settings.health"), isOn: $game.settings.healthEnabled)
                Text(loc("game.settings.healthHint")).font(.caption).foregroundStyle(.secondary)
                if game.settings.healthEnabled {
                    Stepper(value: $game.settings.startingLives, in: 1...9) {
                        Text("\(loc("game.lives")): \(game.settings.startingLives)")
                    }
                }
            }
        }
    }

    // MARK: - Behaviour

    private var behaviourCard: some View {
        card("game.settings.behaviour.label", "arrow.up.and.down.and.arrow.left.and.right") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: $game.settings.behaviour) {
                    ForEach(TargetBehaviour.allCases) { b in Text(loc(b.labelKey)).tag(b) }
                }
                .pickerStyle(.segmented).labelsHidden()
                if game.settings.behaviour == .moving {
                    slider(loc("game.settings.moveSpeed"), $game.settings.moveSpeed, 20...260, suffix: "")
                }

                HStack {
                    Text(loc("game.settings.appearance.label")).font(.callout.weight(.medium))
                    Spacer()
                    Picker("", selection: $game.settings.appearanceMode) {
                        ForEach(AppearanceMode.allCases) { m in Text(loc(m.labelKey)).tag(m) }
                    }
                    .labelsHidden().frame(width: 200)
                }
                if game.settings.appearanceMode == .delayed {
                    decimalSlider(loc("game.settings.respawnDelay"), $game.settings.respawnDelay, 0...3, suffix: "s")
                }
            }
        }
    }

    // MARK: - Spawn knobs

    private var spawnCard: some View {
        card("game.settings.field", "target") {
            VStack(alignment: .leading, spacing: 10) {
                Stepper(value: $game.settings.targetsOnScreen, in: 1...12) {
                    Text("\(loc("game.settings.targetsOnScreen")): \(game.settings.targetsOnScreen)")
                }
                slider(loc("game.settings.targetSize"), $game.settings.targetSize, 40...140, suffix: "")
                decimalSlider(loc("game.settings.lifetime"), $game.settings.lifetime, 0.5...10, suffix: "s")
                slider(loc("game.settings.minDistance"), $game.settings.minDistance, 40...320, suffix: "")
                slider(loc("game.settings.maxDistance"), $game.settings.maxDistance, 0...700, suffix: "", zeroIsOff: true)
                slider(loc("game.settings.maxCPS"), $game.settings.maxCPS, 0...20, suffix: "", zeroIsOff: true)
                slider(loc("game.settings.duration"), $game.settings.gameDuration, 0...180, suffix: "s", zeroIsOff: true)
            }
        }
    }

    // MARK: - Target pool

    private var poolCard: some View {
        card("game.settings.targetPool", "photo.stack") {
            VStack(alignment: .leading, spacing: 8) {
                Text(loc("game.settings.poolHint")).font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 8)], spacing: 8) {
                    emojiChip
                    ForEach(gifs.items) { item in poolThumb(item) }
                }
                HStack {
                    Button(loc("game.settings.useEmoji")) { game.setPoolToEmojiDefault() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Text("\(game.settings.targetPool.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                if gifs.items.isEmpty {
                    Text(loc("icon.noGifs")).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emojiChip: some View {
        let selected = game.settings.targetPool.contains(TirSettings.defaultEmoji)
        return Button {
            game.togglePoolGif(TirSettings.defaultEmoji)
        } label: {
            Text("🎯").font(.system(size: 34))
                .frame(width: 64, height: 64)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : .white.opacity(0.12), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func poolThumb(_ item: GifItem) -> some View {
        let iconString = IconRef.gif(gifs.localPath(item))
        let selected = game.settings.targetPool.contains(iconString)
        return Button {
            game.togglePoolGif(iconString)
        } label: {
            AnimatedAssetView(path: gifs.localPath(item), playing: false)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.accentColor : .white.opacity(0.12), lineWidth: selected ? 2 : 1))
                .overlay(alignment: .topTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .background(Circle().fill(.black.opacity(0.5)))
                            .padding(3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Building blocks

    private func card<Content: View>(_ titleKey: String, _ icon: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(loc(titleKey), systemImage: icon).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glass()
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, suffix: String, zeroIsOff: Bool = false) -> some View {
        HStack {
            Text(title).font(.callout.weight(.medium))
            Slider(value: value, in: range)
            Text(zeroIsOff && value.wrappedValue <= 0 ? loc("game.settings.off") : "\(Int(value.wrappedValue))\(suffix)")
                .font(.callout.monospacedDigit()).frame(width: 52, alignment: .trailing)
        }
    }

    private func decimalSlider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, suffix: String) -> some View {
        HStack {
            Text(title).font(.callout.weight(.medium))
            Slider(value: value, in: range)
            Text(String(format: "%.1f%@", value.wrappedValue, suffix))
                .font(.callout.monospacedDigit()).frame(width: 52, alignment: .trailing)
        }
    }

    private func loc(_ key: String) -> String { LocalizationManager.shared.string(key) }
}
