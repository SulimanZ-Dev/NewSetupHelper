# Architecture

## Components

```text
SulimanAppHub.ps1             WinForms GUI
SulimanAppHub.Terminal.ps1    advanced terminal interface and quiet mode
spicetify-app.ps1             original Spicetify and PC setup terminal
modules/
  SulimanAppHub.Core.psm1     shared operations and safety boundaries
data/
  catalog.json                built-in apps, repos, and profiles
  hub-config.example.json     custom catalog schema example
tests/
  Core.Tests.ps1              offline core tests
scripts/
  Test.ps1                    parser, JSON, and Pester test entrypoint
build.ps1                     reproducible three-EXE build
```

The frontends do not implement package handling themselves. Install, update, uninstall, release selection, checksum validation, state, history, repositories, backup, diagnostics, and self-update are owned by the core module.

## Runtime state

User-owned runtime state is stored outside the repository in `%LOCALAPPDATA%\SulimanAppHub`. The built-in catalog remains read-only; custom entries are merged from the user configuration when the catalog loads.

GitHub-installed app versions cannot always be discovered through Windows, so successful installs are recorded in `state.json`. Winget packages are discovered from one cached inventory call rather than one process per app.

## Release selection

1. Query `repos/{owner}/{repo}/releases/latest` at runtime.
2. Filter assets through catalog include and exclude patterns.
3. Narrow candidates through ordered preference patterns such as setup and x64.
4. Require a trusted HTTPS GitHub URL.
5. Download to an isolated temporary directory.
6. Verify a published checksum when present.
7. Reject known-invalid Authenticode signatures.
8. Dispatch by extension to EXE, MSI, MSIX/MSIXBundle, ZIP, or portable handling.
9. Record result, version, checksum status, signature status, and troubleshooting ID.

## Build and release

PS2EXE embeds the core module and data catalog into each executable. The release bundle still includes readable copies for auditing and source-based use. Tag builds publish three executables so GUI and terminal users are never forced into the other interface.
