<p align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="RemindMe Logo" width="128" height="128">
</p>

<h1 align="center">RemindMe</h1>

<p align="center">
  <strong>A minimalist, natural language-powered reminder app for macOS</strong>
</p>

<p align="center">
  <a href="https://github.com/samirpatil2000/remindme/releases/latest">
    <img src="https://img.shields.io/badge/Download-v1.0-blue?style=for-the-badge&logo=apple" alt="Download">
  </a>
  <img src="https://img.shields.io/badge/macOS-15.0+-black?style=for-the-badge&logo=apple" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift-6.0-orange?style=for-the-badge&logo=swift" alt="Swift 6.0">
  <a href="https://deepwiki.com/samirpatil2000/remindme"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
</p>

---

### ✨ Why RemindMe?
- **Ultra-lightweight** — Built with SwiftUI for modern macOS performance, minimal RAM/CPU usage.
- **Natural Language Parsing** — Set reminders with ease using tokens like `@1m`, `@10m`, `@1h`.
- **Dual Input Modes** — Type your time to get smart suggestions, or select custom durations directly from an elegant visual TimePicker UI.
- **Focus Analytics** — Track your productivity with aggregate focus time and snooze counts natively in the Status Board.
- **Global Hotkey** — Use a customizable global shortcut to instantly bring up the command window from anywhere.
- **Todoist-inspired Design** — Clean, functional interface, beautiful hover-reveal UI for completed tasks, and elegant popovers.
- **Auto Launch** — Enable launch at login so your reminder system is always ready when you are.
- **Privacy First** — Everything stays on your Mac, no cloud syncing, no data tracking.
- **Native Experience** — Deeply integrated with macOS notifications and menu bar tools.

---

### 📥 Download

<p align="center">
  <a href="https://github.com/samirpatil2000/remindme/releases/download/v1.0/RemindMe_Release.dmg">
    <img src="https://img.shields.io/badge/⬇️_Download_RemindMe.dmg-1.0-2ea44f?style=for-the-badge" alt="Download RemindMe.dmg">
  </a>
</p>

1. Download the `.dmg` from the latest release.
2. Drag **RemindMe.app** to your **Applications** folder.
3. Launch it (lives in your menu bar).
4. **Note (not yet notarized)**: Right-click → Open → confirm in security dialog.

---

## 🚀 Getting Started

1. **Launch** RemindMe — it will appear in your menu bar with a clock icon.
2. **Press ⌘⇧Space** from any app to open the Command Window.
3. **Type your reminder** (e.g., `Call Mom @10m` or `Check the oven @5m`).
4. **Press Enter** to set the reminder.
5. **Receive a native notification** when the timer expires!

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧Space` | Open command window |
| `↵` Enter | Save reminder |
| `⎋` Esc | Close command window |
| `⌘ ,` | Open Settings |

---

## Screenshots 

1. Quick Reminder Entry with Smart Time Suggestion

<img width="593" height="95" alt="Screenshot 2026-04-05 at 13 52 31" src="https://github.com/user-attachments/assets/b1d92e4c-f5ad-45a5-b16c-ce893cf2631f" />

2. Natural Language Input with @ Time Tokens

<img width="591" height="96" alt="Screenshot 2026-04-05 at 14 01 07" src="https://github.com/user-attachments/assets/ea8a85fe-f4fc-4584-8713-33c2abc5ae8d" />

3. Visual TimePicker for Custom Durations

<img width="598" height="241" alt="Screenshot 2026-04-05 at 13 52 54" src="https://github.com/user-attachments/assets/beb0d90f-93cc-423c-9aae-db9b0e4e83bb" />

4. Status Board: All Clear & Focus Summary
<img width="383" height="452" alt="Screenshot 2026-04-05 at 13 53 57" src="https://github.com/user-attachments/assets/dc287118-4aa1-472f-a267-31d528d26fa1" />

5. Actionable Reminder Notification with Snooze Options
<img width="404" height="171" alt="Screenshot 2026-04-05 at 13 53 28" src="https://github.com/user-attachments/assets/c85e63f4-1ec0-4b52-899b-d8c129edc9c7" />



## 🛠️ Building from Source

```bash
# Clone the repository
git clone https://github.com/samirpatil2000/remindme.git
cd remindme

# Open in Xcode
open Package.swift

# Build and run
# Press ⌘R in Xcode
```

### Requirements
- macOS 15.0 or later
- Xcode 16.0 or later
- Swift 6.0

---

## 📁 Project Structure

```
RemindMe/
├── App/
│   ├── AppDelegate.swift       # App lifecycle & Carbon hotkey setup
│   └── RemindMeApp.swift       # Swift entry point
├── Managers/
│   ├── HotkeyManager.swift     # Global keyboard shortcuts (Carbon API)
│   ├── NotificationManager.swift # macOS notification delivery
│   └── PermissionsManager.swift # Notification permissions handler
├── Parser/
│   ├── ReminderParser.swift    # Natural language parsing logic
│   └── TimeToken.swift         # Duration token definitions (@1m, etc.)
├── Models/
│   └── Reminder.swift         # Core data structure
└── Views/
    ├── CommandWindow.swift     # Quick entry UI
    ├── MenuBarView.swift       # Menu bar item controller
    └── SettingsView.swift      # App preferences
```

---

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

---

## 📄 License

MIT License — feel free to use this project however you like.

---

<p align="center">
  Made with ❤️ for macOS
</p>
