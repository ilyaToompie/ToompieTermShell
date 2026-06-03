# ToompieTermShell

SwiftUI-based SSH and terminal workspace manager for macOS with a liquid-glass design.

Repository: https://github.com/ilyaToompie/ToompieTermShell

## Features

- Up to 4 live terminal panels with tabs, built on SwiftTerm
- **Projects** workspace: Servers, SSH, Logs, Docker, Deploy and Notes — each wired to the terminal
- **Settings** tab with appearance, fonts, background and language controls
- Built-in **Google Fonts** library: download once, cached in the app's Caches directory, works offline afterwards
- Background customization: solid color, gradient or image (stored in the app cache)
- Color themes, terminal opacity, cursor style and per-tab editable titles
- **ru / en / 中文** localization, switchable at runtime
- Drag a file onto a terminal panel to paste its quoted path
- SSH passwords stored in the macOS Keychain

## Build

```
swift build
```

## Run

```
swift run
```

All preferences (font, colors, background, language, downloaded fonts) are persisted in `~/Library/Caches/ToompieTermShell` and `UserDefaults`.
