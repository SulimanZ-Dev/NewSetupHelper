# Suliman App Hub + Spicetify PC Setup Helper

Suliman App Hub is a Windows app for installing, updating, backing up, and managing apps and GitHub repositories. Version 4 keeps the original PowerShell terminal helper and adds a separate WinForms GUI powered by the same PowerShell core.

## Editions

| File | Purpose |
|---|---|
| `SulimanAppHub.exe` | Full Windows GUI with search, tabs, queues, progress, retry, and clear results |
| `SulimanAppHub.Terminal.exe` | Advanced terminal edition with the same catalog and management engine |
| `SpicetifySetupHelper.exe` | Original terminal-based Spicetify and PC setup helper, now with App Hub launch options |
| `NewSetupHelper-v4.0.0.exe` | Versioned build of the original terminal helper; requests administrator rights for installs |

The GUI never replaces the terminal version. Both editions remain available in every release.

## Main features

- Install, update, and uninstall winget or GitHub-hosted apps.
- Resolve current GitHub releases dynamically without pinned versions.
- Handle EXE, MSI, MSIX, MSIXBundle, ZIP, winget, and portable apps.
- Prefer setup assets, show release notes, verify published SHA-256 checksums, and inspect Authenticode status.
- Track installed GitHub versions and compare them with the latest release.
- Run installation profiles: Minimal, New PC, Gaming, Development, and My Apps.
- Add custom winget apps, GitHub apps, repositories, and profiles through JSON configuration.
- Clone repositories and run safe `git pull --ff-only`, open folders, launch VS Code, or run `git fsck` and remote pruning.
- Export and restore computer profiles containing winget packages, App Hub settings/state/history, repository inventory, Spicetify configuration, privacy settings snapshot, and system information.
- Compare a backup from another computer with the current machine.
- Update winget apps, tracked GitHub apps, Spicetify, and the helper from one flow.
- Update one installed app or all installed apps from the Install Apps menu, with a dry-run check first.
- Update through winget, Microsoft Store, GitHub Releases, or the vendor's official website, always in place.
- Install Freebuff, Proton VPN, Fenn, ScreenWise, QwikTwik, and Revo Uninstaller from the same menu.
- Keep JSONL installation history, troubleshooting IDs, and a readable log.
- Diagnose Windows, disk, RAM, drivers, winget, Git, Node.js, PowerShell, and Spicetify.
- Optional post-install shortcut, taskbar pin, app launch, and Windows app settings actions.
- Attempt a Windows restore point before larger queues, uninstall operations, and profile restores.
- Check automatically for new Setup Helper releases and stage a verified self-update.

Taskbar pinning is best effort because current Windows versions may hide that shell action. Digital signing is supported by the build script when a code-signing certificate thumbprint is provided; a certificate is not included in the repository.

## Built-in Suliman apps

- [Budget](https://github.com/SulimanZ-Dev/Budget)
- [Personlig livsplanerare](https://github.com/SulimanZ-Dev/personlig-livsplanerare)
- [Vault](https://github.com/SulimanZ-Dev/Vault)

The catalog checks the repositories' latest GitHub releases at runtime, so new releases are discovered without changing the helper source.

## Install Apps and updates

The original helper's Install Apps menu includes an Updates section:

- **[25] Update a single installed app** lists the installed apps it can update, with their installed versions.
- **[26] Update all installed apps** checks every installed app in the menu and updates only those with a newer version.
- **[27] Check for updates (dry run)** reports installed and latest versions without downloading or installing anything.

Updates run in place; nothing is uninstalled and no settings or user data are removed. Each app is handled by the first method that applies: winget, Microsoft Store, GitHub Releases, or the vendor's official website. BetterDiscord, Vencord, and OFF Helper have no reliable in-place update source, so they are listed as not supported. If an app is running, the helper asks you to close it and does not terminate it.

## Run from source

Windows PowerShell 5.1 or newer is supported.

```powershell
git clone https://github.com/SulimanZ-Dev/NewSetupHelper.git
cd NewSetupHelper

# GUI
powershell -ExecutionPolicy Bypass -File .\SulimanAppHub.ps1

# Advanced terminal edition
powershell -ExecutionPolicy Bypass -File .\SulimanAppHub.Terminal.ps1

# Original Spicetify terminal helper
powershell -ExecutionPolicy Bypass -File .\spicetify-app.ps1
```

Administrator rights are requested by Windows only when an operation requires them. Browsing the catalog and checking status do not require elevation.

## Run the compiled helper

Download `NewSetupHelper-v4.0.0.exe` from the Version 4 release and run it. The executable requests administrator rights when it starts, because installing and updating apps needs elevation. It is the same terminal helper as `spicetify-app.ps1`.

The helper stores its theme configuration at `%APPDATA%\NewSetupHelper\spicetify-helper-config.json`. If an older `spicetify-helper-config.json` exists next to the script, it is copied there on first run and the existing theme choice is kept.

## Quiet profiles

The terminal edition supports non-interactive profile installation and diagnostics:

```powershell
.\SulimanAppHub.Terminal.exe -end -Action InstallProfile -Profile development -Quiet
.\SulimanAppHub.Terminal.exe -end -Action UpdateAll -Quiet
.\SulimanAppHub.Terminal.exe -end -Action Diagnostics -Quiet
```

PS2EXE reserves arguments before `-end`; script arguments must follow it.

## Custom apps and repositories

The user configuration is created at:

```text
%LOCALAPPDATA%\SulimanAppHub\hub-config.json
```

The GUI opens this file from Settings. `data/hub-config.example.json` documents the shape. Custom winget apps need `kind: "Winget"` and `packageId`. Custom GitHub apps need a trusted `owner/repository`, release asset patterns, and an install mode.

Example GitHub app:

```json
{
  "id": "my-app",
  "name": "My App",
  "kind": "GitHub",
  "repository": "owner/repository",
  "assetInclude": ["(?i)\\.(exe|msi|zip)$"],
  "assetPrefer": ["(?i)(setup|install)", "(?i)x64"],
  "installMode": "Installer",
  "silentArgs": ["/S"],
  "category": "Custom",
  "profiles": []
}
```

Invalid configuration is preserved with an `.invalid-TIMESTAMP` suffix and replaced by safe defaults.

## Data and logs

Runtime data is stored under `%LOCALAPPDATA%\SulimanAppHub`:

- `hub-config.json`: settings and custom catalog entries
- `state.json`: tracked GitHub and portable installations
- `history.jsonl`: operation history
- `hub.log`: detailed log with troubleshooting IDs

The original terminal helper keeps its session log at `%TEMP%\spicetify-helper-log.txt`.

## Build and test

Run all parser, JSON, and Pester checks:

```powershell
.\scripts\Test.ps1
```

Build all three Windows executables, a release ZIP, and SHA-256 checksums:

```powershell
Install-Module ps2exe -Scope CurrentUser
.\build.ps1 -Version 4.0.0
```

Optional Authenticode signing:

```powershell
.\build.ps1 -Version 4.0.0 -CertificateThumbprint YOUR_CERTIFICATE_THUMBPRINT
```

GitHub Actions tests and builds every push and pull request. A `v*` tag creates or updates the matching GitHub release and uploads both GUI and terminal executables, the classic helper, the ZIP bundle, and `SHA256SUMS.txt`.

## Safety model

- Install and uninstall queues require explicit confirmation in interactive editions.
- Repository updates stop when local changes exist and use fast-forward-only pulls.
- Release downloads must use HTTPS GitHub hosts and the expected repository path.
- Published checksums are verified when available; mismatches stop installation.
- Invalid or untrusted Authenticode signatures stop installation; unsigned apps are reported in history.
- Portable uninstall paths must remain inside the configured managed install root.
- System-wide and privacy changes remain explicit actions; they are never applied during status checks.

See [Architecture](docs/ARCHITECTURE.md) for component and state details.

## Version

Current application version: **v4.0.0**.

This is a personal helper project and is not affiliated with Spotify or Spicetify.
