# Valpero for macOS

A lightweight macOS menu bar application for [Valpero](https://valpero.com) — real-time uptime monitoring right in your menu bar.

![macOS](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0070C9)

---

## Features

- **Live status** — monitors, heartbeats, server agents updated on a configurable interval
- **Instant alerts** — menu bar icon turns red when any monitor is down
- **Open incidents** — see active incidents with duration at a glance
- **Server metrics** — CPU and RAM usage for connected server agents
- **Secure API key storage** — key is saved in macOS Keychain, never in a file
- **Zero clutter** — no Dock icon, lives quietly in the menu bar

---

## Requirements

- macOS 13 Ventura or later
- A [Valpero](https://valpero.com) account with an API key

---

## Getting Started

### 1. Download the latest release

Grab `Valpero.app` from the [Releases](../../releases) page.

### 2. Run

Move `Valpero.app` to your `/Applications` folder and open it. A status indicator will appear in the menu bar.

### 3. Enter your API key

Click the menu bar icon → **⚙ Settings**, paste your Valpero API key and click **Validate → Save**.

---

## Build from Source

```bash
git clone https://github.com/valpero/valpero-macos.git
cd valpero-macos
open valpero-macos.xcodeproj
```

Select **My Mac** as the run destination and press **⌘R**.

---

## Project Structure

```
valpero-macos/
├── ValperoMenuBarApp.swift         # Application entry point, SwiftUI App scene
├── AppDelegate.swift               # Menu bar item, popover, settings window
├── Info.plist                      # App metadata (LSUIElement hides Dock icon)
├── valpero-macos.entitlements      # Sandbox + network entitlements
├── Model/
│   ├── Models.swift                # API response models (Monitor, Incident, Agent, Heartbeat)
│   ├── APIClient.swift             # URLSession-based Valpero REST API client
│   ├── AppState.swift              # Central state + auto-refresh timer (Combine)
│   └── KeychainManager.swift       # Keychain read/write wrapper
└── Views/
    ├── PopoverView.swift           # Main popover panel (click menu bar icon to open)
    ├── SettingsView.swift          # API key + preferences window
    └── MonitorRowView.swift        # Individual monitor row component
```

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI framework | SwiftUI |
| App architecture | ObservableObject + Combine |
| Menu bar | NSStatusItem + NSPopover |
| API key storage | macOS Keychain (Security framework) |
| HTTP | URLSession async/await |
| Settings persistence | UserDefaults |

---

## License

MIT © 2026 Valpero
