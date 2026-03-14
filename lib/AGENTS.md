# Agent Instructions for lib/

This directory contains the shared PowerShell library for the Shortcuts project.

## Structure

- `utils/` - General utility functions (`utils.ps1`, `utils.Tests.ps1`)
- `wsl/` - WSL management library (`wsl.ps1` and modules, with `*.Tests.ps1` unit tests)
- `install/` - Installation utilities (`install-npm-global.ps1`)

## Guidelines

For detailed development guidelines, see the root `AGENTS.md`.

Key points specific to this library:

- **Dot-sourced library files**: Do NOT use `Set-StrictMode` in library files - it persists in the caller's scope.
- **Unit tests**: Each source file has a corresponding `*.Tests.ps1` in the same directory.
- **Integration tests**: All WSL integration tests (`wsl.Integration.Tests.ps1`, `manager.docker.Integration.Tests.ps1`, `manager.podman.Integration.Tests.ps1`) are co-located here in `lib/wsl/`.
- **Source path**: When sourcing `utils.ps1` from within `lib/wsl/`, use `"$PSScriptRoot\..\utils\utils.ps1"`.
