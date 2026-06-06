import AppKit
import Foundation
import SwiftUI

/// Result of an install attempt, used to pick the right toast.
enum CLIInstallOutcome {
    case linked        // symlinked into a directory already on PATH — works immediately
    case pathEdited    // shim written + PATH appended to shell rc — works in new terminals
    case failed
}

/// Backs the `code .`-style launcher: a tiny shim script the user drops on their PATH that
/// hands a folder + panel number to the running app over the `toompieterm://` URL scheme.
///
/// The command *name* is user-configurable (it's just the shim's filename); the URL scheme is
/// fixed. The path is base64-encoded in the shim so any folder name — spaces, unicode, quotes —
/// survives the round-trip through `open` and `URLComponents` untouched.
@MainActor
final class CLILauncher: ObservableObject {
    static let shared = CLILauncher()

    /// Fixed custom URL scheme; mirrored in Info.plist's CFBundleURLTypes.
    static let urlScheme = "toompieterm"

    /// Directory the shim lives in. Appended to PATH when we can't symlink system-wide.
    static let binDirRelative = ".toompie/bin"

    @Published var commandName: String
    @Published private(set) var installed: Bool = false
    @Published var promptDismissed: Bool

    private let defaults = UserDefaults.standard
    private let fm = FileManager.default

    private init() {
        commandName = Self.sanitize(defaults.string(forKey: "cliCommandName") ?? "tt")
        promptDismissed = defaults.bool(forKey: "cliPromptDismissed")
        refreshInstalled()
    }

    // MARK: - Paths

    var binDirectory: URL {
        fm.homeDirectoryForCurrentUser.appendingPathComponent(Self.binDirRelative, isDirectory: true)
    }

    var shimURL: URL { binDirectory.appendingPathComponent(commandName) }

    /// `/usr/local/bin` is on the stock macOS PATH (`/etc/paths`), so a symlink there "just works".
    private func systemLink(for name: String) -> URL {
        URL(fileURLWithPath: "/usr/local/bin").appendingPathComponent(name)
    }

    /// The line we append to shell rc files; name-independent (it adds the bin dir, not the command).
    private var exportLine: String { "export PATH=\"$HOME/\(Self.binDirRelative):$PATH\"" }
    private let rcMarker = "# ToompieTermShell CLI"

    // MARK: - State

    func refreshInstalled() {
        installed = fm.fileExists(atPath: shimURL.path)
    }

    var shouldShowPrompt: Bool { !installed && !promptDismissed }

    func dismissPrompt() {
        promptDismissed = true
        defaults.set(true, forKey: "cliPromptDismissed")
    }

    /// Strips anything that wouldn't be a sane command name; never returns empty.
    static func sanitize(_ raw: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        let filtered = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).filter { allowed.contains($0) })
        return filtered.isEmpty ? "tt" : filtered
    }

    func setCommandName(_ raw: String) {
        let clean = Self.sanitize(raw)
        guard clean != commandName else { return }
        // Carry an existing install over to the new name rather than orphaning the old shim/link.
        let wasInstalled = installed
        let oldShim = shimURL
        let oldLink = systemLink(for: commandName)
        commandName = clean
        defaults.set(clean, forKey: "cliCommandName")
        if wasInstalled {
            try? fm.removeItem(at: oldShim)
            if (try? fm.destinationOfSymbolicLink(atPath: oldLink.path)) == oldShim.path {
                try? fm.removeItem(at: oldLink)
            }
            _ = install()
        }
        refreshInstalled()
    }

    // MARK: - Install / uninstall

    /// Writes the shim and makes it reachable. Prefers a system-wide symlink (immediate); falls
    /// back to appending the bin dir to the user's shell rc files.
    @discardableResult
    func install() -> CLIInstallOutcome {
        do {
            try fm.createDirectory(at: binDirectory, withIntermediateDirectories: true)
            try scriptContents().write(to: shimURL, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: shimURL.path)
        } catch {
            return .failed
        }

        var outcome: CLIInstallOutcome = .pathEdited
        let link = systemLink(for: commandName)
        if fm.isWritableFile(atPath: link.deletingLastPathComponent().path) {
            try? fm.removeItem(at: link)
            if (try? fm.createSymbolicLink(at: link, withDestinationURL: shimURL)) != nil {
                outcome = .linked
            }
        }
        if outcome != .linked {
            ensurePathInShellProfiles()
        }

        refreshInstalled()
        dismissPrompt()
        return outcome
    }

    func uninstall() {
        try? fm.removeItem(at: shimURL)
        let link = systemLink(for: commandName)
        if (try? fm.destinationOfSymbolicLink(atPath: link.path)) == shimURL.path {
            try? fm.removeItem(at: link)
        }
        removePathFromShellProfiles()
        refreshInstalled()
    }

    private func profileURLs() -> [URL] {
        let home = fm.homeDirectoryForCurrentUser
        // .zshrc is the default (login shell is zsh on modern macOS); touch bash/profile only if present.
        var urls = [home.appendingPathComponent(".zshrc")]
        for name in [".bashrc", ".bash_profile", ".profile"] {
            let url = home.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) { urls.append(url) }
        }
        return urls
    }

    private func ensurePathInShellProfiles() {
        let block = "\n\(rcMarker)\n\(exportLine)\n"
        for url in profileURLs() {
            let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            guard !existing.contains(rcMarker) else { continue }
            try? (existing + block).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func removePathFromShellProfiles() {
        for url in profileURLs() {
            guard let existing = try? String(contentsOf: url, encoding: .utf8), existing.contains(rcMarker) else { continue }
            let kept = existing
                .components(separatedBy: "\n")
                .filter { !$0.contains(rcMarker) && $0.trimmingCharacters(in: .whitespaces) != exportLine }
                .joined(separator: "\n")
            try? kept.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Convenience for a "copy this line" button when the user prefers to wire PATH by hand.
    var manualPathLine: String { exportLine }

    // MARK: - Shim script

    func scriptContents() -> String {
        """
        #!/bin/bash
        # ToompieTermShell launcher — open a folder (or file) in a terminal panel, like `code .`.
        # Usage: \(commandName) [path] [panel 1-4]
        #   \(commandName)          → current dir in panel 1
        #   \(commandName) 2        → current dir in panel 2
        #   \(commandName) ~/proj 3 → that folder in panel 3
        target="."
        panel="1"
        if [ "$#" -eq 1 ]; then
          case "$1" in
            1|2|3|4) panel="$1" ;;
            *) target="$1" ;;
          esac
        elif [ "$#" -ge 2 ]; then
          target="$1"
          panel="$2"
        fi
        case "$panel" in 1|2|3|4) ;; *) panel=1 ;; esac
        if [ -d "$target" ]; then
          abs="$(cd "$target" 2>/dev/null && pwd)"
        elif [ -e "$target" ]; then
          abs="$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
        else
          echo "\(commandName): no such file or directory: $target" >&2
          exit 1
        fi
        b64="$(printf %s "$abs" | base64 | tr -d '\\n')"
        open "\(Self.urlScheme)://open?path=${b64}&panel=${panel}"
        """
    }

    // MARK: - Incoming URL

    /// Routes `toompieterm://open?path=<base64>&panel=<1-4>` to the workspace.
    func handle(_ url: URL, manager: TerminalWorkspaceManager) {
        guard url.scheme == Self.urlScheme,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let items = comps.queryItems ?? []
        let panelRaw = Int(items.first { $0.name == "panel" }?.value ?? "") ?? 1
        let panelIndex = min(max(panelRaw, 1), 4) - 1

        guard let encoded = items.first(where: { $0.name == "path" })?.value,
              let path = Self.decodePath(encoded) else { return }

        NSApp.activate(ignoringOtherApps: true)
        if panelIndex >= manager.visiblePanelCount {
            manager.setVisiblePanelCount(panelIndex + 1)
        }

        var isDir: ObjCBool = false
        let exists = fm.fileExists(atPath: path, isDirectory: &isDir)
        if exists && isDir.boolValue {
            manager.openDirectory(path, in: panelIndex)
        } else if exists {
            manager.openLocalFileEditor(path: path, in: panelIndex)
        } else {
            manager.focusPanel(panelIndex)
            ToastCenter.shared.show(
                String(format: LocalizationManager.shared.string("cli.notFound"), (path as NSString).lastPathComponent),
                icon: "exclamationmark.triangle.fill", tint: .orange
            )
        }
    }

    /// Standard base64; `+` `/` `=` ride through a URL query untouched. A space only appears if
    /// something downstream mangled a `+`, so restore it before decoding as a safety net.
    private static func decodePath(_ encoded: String) -> String? {
        for candidate in [encoded, encoded.replacingOccurrences(of: " ", with: "+")] {
            if let data = Data(base64Encoded: candidate), let path = String(data: data, encoding: .utf8) {
                return path
            }
        }
        return nil
    }
}

/// Small dismissable card, pinned bottom-left, nudging the user to install the terminal command.
struct CLIInstallPrompt: View {
    @ObservedObject var cli = CLILauncher.shared
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "terminal.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 6) {
                Text(loc("cli.promptTitle"))
                    .font(.callout.weight(.semibold))
                Text(String(format: loc("cli.promptBody"), cli.commandName, cli.commandName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button {
                        switch cli.install() {
                        case .linked:
                            ToastCenter.shared.show(String(format: loc("cli.installed"), cli.commandName), icon: "checkmark.seal.fill")
                        case .pathEdited:
                            ToastCenter.shared.show(loc("cli.installedManual"), icon: "checkmark.seal.fill")
                        case .failed:
                            ToastCenter.shared.show(loc("cli.installFailed"), icon: "exclamationmark.triangle.fill", tint: .red)
                        }
                    } label: {
                        Text(String(format: loc("cli.installNamed"), cli.commandName))
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(loc("cli.later")) { cli.dismissPrompt() }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(13)
        .frame(width: 330, alignment: .leading)
        .glass()
        .padding(16)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }
}
