# Changelog

## v4.0.0 - 2026-11-23

### Added

- Update a single installed app, update all installed apps, and a dry-run update check in the Install Apps menu.
- Update paths tried in order: winget, Microsoft Store, GitHub Releases, then the vendor's official website. Apps with no safe update path are marked as not supported.
- Installed -> latest version display, download and Authenticode verification, in-place installers, and a running-app check that asks you to close the app instead of killing it.
- Freebuff, Proton VPN, Fenn, ScreenWise, QwikTwik, and Revo Uninstaller in the App Hub catalog and the terminal Install Apps menu.

### Changed

- Version 4.0.0 across the helper, App Hub editions, build script, workflow, and documentation.
- The original helper stores its theme configuration in `%APPDATA%\NewSetupHelper\spicetify-helper-config.json`; an existing config next to the script is migrated on first run.

### Fixed

- Compiled-EXE detection now resolves the launcher and config paths from the actual executable instead of the PowerShell host.
- Empty or unavailable console input no longer throws while reading menu choices.
- Theme config saving creates the target directory and preserves existing values.
