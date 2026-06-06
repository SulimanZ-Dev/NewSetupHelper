# Spicetify + PC Setup Helper

A personal PowerShell menu tool for setting up a new Windows PC quickly — with a focus on **Spicetify**, app installs, privacy tweaks, and everyday utilities.

No extra dependencies beyond **PowerShell 5.1+** and **winget** (standard on modern Windows 10/11).

---

## What it does

This script is a one-stop helper when you move to a new machine, use a laptop away from home, or want to reinstall your usual setup without digging through bookmarks and install guides.

### New PC Setup Wizard

Walks you through the full chain:

1. Install Spotify (winget)
2. Install Spicetify CLI
3. Optionally import a saved config ZIP
4. `backup` + `apply` + enable DevTools
5. Block Spotify auto-updates
6. Optionally install Spicetify Marketplace

### Spicetify Tools

Everything you need to manage Spicetify day to day:

- Install / upgrade CLI and Marketplace
- Apply, restore, restart Spotify
- Block or unblock Spotify updates
- Fix Spicetify after a Spotify client update (`backup apply`)
- Theme picker (numbered list)
- Extension remover (numbered list, correct `-` suffix)
- Export / import full config as ZIP (`%AppData%\spicetify`)
- DevTools, version check, open config folder

### Install Apps

One menu for apps you commonly reinstall, grouped by category:

| Category | Apps |
|----------|------|
| Music and Social | Spotify, BetterDiscord, Vencord |
| Remote and Network | AweSun, OFF Helper, LANDrop |
| Browsers | Firefox, Brave, Chrome |
| Gaming | Steam, Epic Games Launcher |
| Dev Tools | Git, VS Code, Node.js LTS, Windows Terminal, 7-Zip |

Batch options install all dev tools or all gaming launchers at once. Every winget install falls back to the official download page if winget fails.

### Windows Privacy and Tweaks

Optional privacy-focused changes (registry and services):

- Disable telemetry and related services
- Remove common preinstalled Microsoft apps (bloatware)
- Disable ads, Start menu suggestions, and tips
- Disable Bing in Start Menu search
- Disable activity history and location tracking
- Disable Cortana
- Apply all tweaks at once, or restore defaults

HKLM changes require running as Administrator.

### Power and Sleep Tools

- Schedule shutdown or sleep after X minutes
- Cancel active timers
- Switch power plan (Balanced, High Performance, Power Saver, Ultimate Performance)
- Show current active power plan

### Utilities

- Chris Titus WinUtil (with confirmation + admin re-launch)
- Open Ninite
- `winget upgrade --all`
- Script version info + GitHub link
- View session log in Notepad

---

## Requirements

- Windows 10 (1809+) or Windows 11
- PowerShell 5.1 or newer
- [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) (for most app installs)
- Internet access (install scripts download from official sources)
- **Administrator** — only needed for privacy tweaks (HKLM) and some system utilities

---

## Quick start

### 1. Download

Clone or download this repo:

```powershell
git clone https://github.com/Wooting2HEEHEE/spicetify-pc-setup-helper.git
cd spicetify-pc-setup-helper
```

### 2. Run

```powershell
powershell -ExecutionPolicy Bypass -File .\spicetify-app.ps1
```

If Windows blocks the script, right-click the file → **Properties** → check **Unblock** (if shown), or run the command above which bypasses execution policy for that session.

### 3. New PC? Start here

1. Main menu → **[1] New PC Setup Wizard**
2. Before leaving your old PC: **Spicetify Tools → [18] Export Config (ZIP)** and save the file to USB or cloud
3. On the new PC: run the wizard and import that ZIP at step 3

---

## Main menu

```
========================================
   SPICETIFY + PC SETUP HELPER
========================================
 [1] New PC Setup Wizard
 [2] System Status Check
 [3] Spicetify Tools     -->
 [4] Install Apps        -->
 [5] Windows Privacy     -->
 [6] Power and Sleep     -->
 [7] Utilities           -->
 [0] Exit
========================================
```

Every submenu has **[0] Back** to return to the main menu.

---

## Session log

Actions are logged to:

```
%TEMP%\spicetify-helper-log.txt
```

View it from **Utilities → [5] View Session Log**.

---

## Important notes

- **Spicetify** modifies the Spotify desktop client. Spotify updates can break Spicetify — use **After Spotify Update** or re-run `backup apply` when that happens.
- **Chris Titus WinUtil** runs a third-party script from the internet. Only use it if you trust the source.
- **Privacy tweaks** change registry keys and services. Use **Restore Windows Defaults** in the Privacy menu to undo. Some changes need a restart.
- **OFF Helper** and **AweSun** are third-party remote/shutdown tools — follow their own setup (e.g. install the OFF app on your phone).
- This is a **personal helper script**, not an official Spicetify or Spotify product.

---

## File reference

| Path | Purpose |
|------|---------|
| `spicetify-app.ps1` | Main script |
| `%AppData%\spicetify\` | Spicetify config (exported/imported by ZIP feature) |
| `%TEMP%\spicetify-helper-log.txt` | Session log |
| `%TEMP%\OffHelper\` | OFF Helper extraction folder |

---

## Version

Current script version: **v2.0** (see `$ScriptVersion` at the top of `spicetify-app.ps1`).

---

## License

Personal use. Install scripts and apps belong to their respective authors (Spicetify, Spotify, winget package maintainers, etc.). Use at your own risk.
