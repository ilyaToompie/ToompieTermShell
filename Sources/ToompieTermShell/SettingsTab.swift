import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsTab: View {
    @EnvironmentObject private var prefs: AppPreferences
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var fonts: FontLibrary
    @EnvironmentObject private var gifs: GifLibrary
    @State private var gifURLField = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                languageCard
                presetsCard
                interfaceCard
                gifCard
                appearanceCard
                fontCard
                backgroundCard
                aboutCard
            }
            .padding(18)
        }
    }

    private var presetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("settings.presets", "paintbrush.pointed.fill")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(UIThemePreset.all) { preset in
                    Button { prefs.applyPreset(preset) } label: {
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: preset.accent)).frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white.opacity(0.4)))
                            Text(preset.name).font(.caption.weight(.semibold)).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10).frame(height: 34)
                        .background(LinearGradient(colors: [Color(hex: preset.gradientTop), Color(hex: preset.gradientBottom)], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: preset.accent).opacity(0.5)))
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .hoverScale(1.04)
                }
            }
        }
        .padding(14)
        .glass()
    }

    private var interfaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("settings.textCase", "textformat.size")
            Picker("", selection: $prefs.textCase) {
                ForEach(TextCaseStyle.allCases) { style in
                    Text(loc(style.labelKey)).tag(style)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            HStack {
                Text(loc("settings.scheme")).font(.callout.weight(.medium))
                Spacer()
                Picker("", selection: Binding(get: { prefs.scheme }, set: { prefs.scheme = $0 })) {
                    ForEach(UIScheme.allCases) { Text(loc($0.labelKey)).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 220)
            }

            colorRow(loc("settings.accent"), hex: bindingHex(\.accentHex))
            Toggle(loc("settings.crt"), isOn: $prefs.crtMode)

            Text(loc("settings.weather")).font(.callout.weight(.medium))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(WeatherEffect.allCases) { effect in
                    effectChip(effect)
                }
            }
        }
        .padding(14)
        .glass()
    }

    private func effectChip(_ effect: WeatherEffect) -> some View {
        let active = effect == .off ? prefs.activeEffects.isEmpty : prefs.activeEffects.contains(effect)
        return Button {
            prefs.toggleEffect(effect)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: effect.icon).font(.system(size: 15))
                Text(loc(effect.labelKey)).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(active ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(active ? Color.accentColor : Color.white.opacity(0.1)))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(active ? Color.accentColor : Color.secondary)
        .hoverScale(1.05)
    }

    private var gifCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("gif.library", "photo.stack")

            if gifs.items.isEmpty {
                Text(loc("gif.none")).font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(gifs.items) { item in
                            gifThumb(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 8) {
                Button { addGifFile() } label: { Label(loc("gif.addFile"), systemImage: "folder") }
                if gifs.downloading { ProgressView().controlSize(.small) }
            }
            HStack(spacing: 8) {
                TextField(loc("gif.url"), text: $gifURLField).textFieldStyle(.roundedBorder)
                Button { addGifURL() } label: { Image(systemName: "arrow.down.circle.fill") }
                    .buttonStyle(.plain).disabled(gifURLField.isEmpty)
            }
            if !gifs.lastError.isEmpty {
                Text(gifs.lastError).font(.caption2).foregroundStyle(.orange).lineLimit(2)
            }

            Divider().opacity(0.2)

            slider(loc("gif.size"), value: $prefs.gifSize, range: 48...360, suffix: "")
            slider(loc("gif.opacity"), value: $prefs.gifOpacity, range: 0.1...1.0, percent: true)
            slider(loc("gif.innerScale"), value: $prefs.gifInnerScale, range: 0.3...3.0, percent: true)
            slider(loc("gif.radius"), value: $prefs.gifCornerRadius, range: 0...60, suffix: "")
            HStack {
                Text(loc("gif.rotation")).font(.callout.weight(.medium))
                Slider(value: $prefs.gifRotation, in: -180...180)
                Text("\(Int(prefs.gifRotation))°").font(.callout.monospacedDigit()).frame(width: 44, alignment: .trailing)
            }

            Toggle(loc("gif.fit"), isOn: $prefs.gifFit)
            Toggle(loc("gif.flip"), isOn: $prefs.gifFlip)
            Toggle(loc("gif.box"), isOn: $prefs.gifShowBox)
            if prefs.gifShowBox {
                slider(loc("gif.boxOpacity"), value: $prefs.gifBoxOpacity, range: 0...1.0, percent: true)
                Toggle(loc("gif.border"), isOn: $prefs.gifBorder)
            }

            Divider().opacity(0.2)
            Toggle(loc("gif.editable"), isOn: $prefs.gifEditable)
            if prefs.gifEditable {
                Text(loc("gif.editHint")).font(.caption2).foregroundStyle(.secondary)
            }
            Button {
                prefs.gifOffsetX = 0
                prefs.gifOffsetY = 0
            } label: {
                Label(loc("gif.resetPos"), systemImage: "arrow.counterclockwise")
            }
        }
        .padding(14)
        .glass()
    }

    private func gifThumb(_ item: GifItem) -> some View {
        let path = gifs.localPath(item)
        let active = prefs.gifPath == path
        return VStack(spacing: 4) {
            AnimatedGifView(path: path)
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Color.accentColor : Color.white.opacity(0.12), lineWidth: active ? 2 : 1))
                .onTapGesture { prefs.gifPath = active ? "" : path }
            Button(role: .destructive) {
                if active { prefs.gifPath = "" }
                gifs.remove(item)
            } label: { Image(systemName: "trash").font(.caption2) }
                .buttonStyle(.plain).foregroundStyle(.red)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, percent: Bool = false, suffix: String = "") -> some View {
        HStack {
            Text(title).font(.callout.weight(.medium))
            Slider(value: value, in: range)
            Text(percent ? "\(Int(value.wrappedValue * 100))%" : "\(Int(value.wrappedValue))\(suffix)")
                .font(.callout.monospacedDigit()).frame(width: 44, alignment: .trailing)
        }
    }

    private func addGifFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.gif, .image]
        if panel.runModal() == .OK, let url = panel.url, let item = gifs.importFile(url) {
            prefs.gifPath = gifs.localPath(item)
        }
    }

    private func addGifURL() {
        let url = gifURLField
        gifs.download(from: url) { item in
            if let item { prefs.gifPath = gifs.localPath(item) }
        }
        gifURLField = ""
    }

    private func sectionHeader(_ key: String, _ icon: String) -> some View {
        Label(loc(key), systemImage: icon)
            .font(.headline)
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("settings.language", "globe")
            HStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { lang in
                    languageButton(lang)
                }
            }
        }
        .padding(14)
        .glass()
    }

    private func languageButton(_ lang: AppLanguage) -> some View {
        let active = loc.language == lang
        return Button {
            loc.language = lang
        } label: {
            HStack(spacing: 6) {
                Text(lang.flag)
                Text(lang.nativeName).font(.callout.weight(.medium))
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(active ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? Color.accentColor : Color.white.opacity(0.12)))
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("settings.appearance", "paintpalette")

            Text(loc("settings.theme"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TerminalTheme.all) { theme in
                        Button {
                            prefs.applyTheme(theme)
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: theme.background))
                                    .frame(width: 56, height: 34)
                                    .overlay(
                                        Text("Ab")
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundStyle(Color(hex: theme.foreground))
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(isActiveTheme(theme) ? Color.accentColor : Color.white.opacity(0.15), lineWidth: isActiveTheme(theme) ? 2 : 1))
                                Text(theme.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            colorRow(loc("settings.foreground"), hex: bindingHex(\.foregroundHex))
            colorRow(loc("settings.bgColor"), hex: bindingHex(\.backgroundHex))
            colorRow("Caret", hex: bindingHex(\.caretHex))

            HStack {
                Text(loc("settings.cursor"))
                    .font(.callout.weight(.medium))
                Spacer()
                Picker("", selection: $prefs.cursorStyle) {
                    ForEach(TerminalCursorStyle.allCases) { style in
                        Text(loc(style.labelKey)).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)
            }

            HStack {
                Text(loc("settings.fontSize"))
                    .font(.callout.weight(.medium))
                Slider(value: $prefs.fontSize, in: 9...28, step: 1)
                Text("\(Int(prefs.fontSize))")
                    .font(.callout.monospacedDigit())
                    .frame(width: 28)
            }

            HStack {
                Text(loc("settings.opacity"))
                    .font(.callout.weight(.medium))
                Slider(value: $prefs.terminalOpacity, in: 0.4...1.0, step: 0.02)
                Text("\(Int(prefs.terminalOpacity * 100))%")
                    .font(.callout.monospacedDigit())
                    .frame(width: 44)
            }

            Toggle(loc("settings.aliased"), isOn: $prefs.disableAntialiasing)
            Toggle(loc("settings.confirmDangerous"), isOn: $prefs.confirmDangerous)
        }
        .padding(14)
        .glass()
    }

    private var fontCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("settings.fontLibrary", "textformat")

            Button {
                prefs.fontFamily = ""
            } label: {
                HStack {
                    Image(systemName: prefs.fontFamily.isEmpty ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(prefs.fontFamily.isEmpty ? Color.accentColor : Color.secondary)
                    Text(loc("settings.systemFont"))
                        .font(.callout)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            ForEach(fonts.catalog) { entry in
                fontRow(entry)
            }
        }
        .padding(14)
        .glass()
    }

    private func fontRow(_ entry: GoogleFontEntry) -> some View {
        let downloaded = fonts.isDownloaded(entry.family)
        let downloading = fonts.isDownloading(entry.family)
        let selected = prefs.fontFamily == entry.family
        return HStack(spacing: 10) {
            Button {
                if downloaded { prefs.fontFamily = entry.family }
            } label: {
                Image(systemName: selected ? "checkmark.circle.fill" : (downloaded ? "circle" : "circle.dotted"))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!downloaded)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.family)
                    .font(downloaded ? .custom(entry.family, size: 14) : .callout)
                if downloaded {
                    Text(loc("settings.offlineReady"))
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else if fonts.failedFamilies.contains(entry.family) {
                    Text("⚠︎")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()

            if downloading {
                ProgressView()
                    .controlSize(.small)
            } else if downloaded {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                    .help(loc("settings.downloaded"))
            } else {
                Button {
                    fonts.download(entry)
                } label: {
                    Label(loc("settings.download"), systemImage: "arrow.down.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }

    private var backgroundCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("settings.background", "photo")

            Picker("", selection: $prefs.backgroundMode) {
                ForEach(AppBackgroundMode.allCases) { mode in
                    Text(loc(mode.labelKey)).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            switch prefs.backgroundMode {
            case .native:
                Text(loc("bg.native")).font(.caption).foregroundStyle(.secondary)
            case .solid:
                colorRow(loc("settings.bgColor"), hex: bindingHex(\.windowColorHex))
            case .gradient:
                colorRow("Top", hex: bindingHex(\.gradientTopHex))
                colorRow("Bottom", hex: bindingHex(\.gradientBottomHex))
            case .image:
                HStack(spacing: 10) {
                    Button {
                        chooseImage()
                    } label: {
                        Label(loc("settings.chooseImage"), systemImage: "photo.on.rectangle")
                    }
                    if !prefs.backgroundImagePath.isEmpty {
                        Button(role: .destructive) {
                            prefs.backgroundImagePath = ""
                        } label: {
                            Label(loc("settings.clearImage"), systemImage: "xmark")
                        }
                    }
                }
                if !prefs.backgroundImagePath.isEmpty, let image = NSImage(contentsOfFile: prefs.backgroundImagePath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 90)
                        .frame(maxWidth: .infinity)
                        .grayscale(prefs.bgGrayscale ? 1 : 0)
                        .brightness(prefs.bgBrightness)
                        .blur(radius: min(prefs.bgBlur, 8))
                        .modifier(InvertIf(active: prefs.bgInvert))
                        .overlay(Color.black.opacity(prefs.bgDim))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(loc("settings.bgAdjust")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Toggle(loc("settings.bgInvert"), isOn: $prefs.bgInvert)
                    Toggle(loc("settings.bgGrayscale"), isOn: $prefs.bgGrayscale)
                    slider(loc("settings.bgBlur"), value: $prefs.bgBlur, range: 0...30, suffix: "")
                    slider(loc("settings.bgDim"), value: $prefs.bgDim, range: 0...0.85, percent: true)
                    HStack {
                        Text(loc("settings.bgBrightness")).font(.callout.weight(.medium))
                        Slider(value: $prefs.bgBrightness, in: -0.5...0.5)
                        Text("\(Int(prefs.bgBrightness * 100))").font(.callout.monospacedDigit()).frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .padding(14)
        .glass()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("settings.about", "info.circle")
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ToompieTermShell")
                        .font(.subheadline.weight(.bold))
                    Text("v\(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Link(destination: URL(string: "https://github.com/ilyaToompie/ToompieTermShell")!) {
                Label(loc("settings.repo"), systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Button(role: .destructive) {
                fonts.removeAllDownloaded()
                if !prefs.fontFamily.isEmpty { prefs.fontFamily = "" }
            } label: {
                Label(loc("settings.resetFonts"), systemImage: "trash")
            }
        }
        .padding(14)
        .glass()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private func isActiveTheme(_ theme: TerminalTheme) -> Bool {
        prefs.foregroundHex.caseInsensitiveCompare(theme.foreground) == .orderedSame &&
            prefs.backgroundHex.caseInsensitiveCompare(theme.background) == .orderedSame
    }

    private func colorRow(_ title: String, hex: Binding<Color>) -> some View {
        HStack {
            Text(title)
                .font(.callout.weight(.medium))
            Spacer()
            ColorPicker("", selection: hex, supportsOpacity: false)
                .labelsHidden()
        }
    }

    private func bindingHex(_ keyPath: ReferenceWritableKeyPath<AppPreferences, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: prefs[keyPath: keyPath]) },
            set: { prefs[keyPath: keyPath] = NSColor($0).hexString }
        )
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .image]
        if panel.runModal() == .OK, let url = panel.url, let stored = BackgroundImageStore.importImage(from: url) {
            prefs.backgroundImagePath = stored
        }
    }
}
