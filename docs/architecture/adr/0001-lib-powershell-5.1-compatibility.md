[← Back to Architecture](../README.md)

# ADR 0001: Scoop and utils libraries stay Windows PowerShell 5.1-compatible

**Status**: Accepted (2026-07-24)
**Context item**: [SC-047](../../backlog/sc-047.md)

## Context

The project targets PowerShell 7.4+ for library code (`lib/`), with only the bootstrap scripts kept 5.1-compatible. The Scoop update helper (`tools/scoop/update-scoop.ps1`), however, must run under **Windows PowerShell 5.1** in a classic console:

- Updating `pwsh` itself fails while `pwsh.exe` is the running host (the executable is file-locked). Running the helper under `powershell.exe` (5.1) leaves `pwsh.exe` free to be replaced.
- Updating Windows Terminal fails while it is the running console host. Launching the helper in a classic `conhost.exe` window (see `update-scoop.bat`) avoids locking `WindowsTerminal.exe`.

The helper keeps its logic in `lib/scoop/scoop.ps1`, which dot-sources `lib/utils/utils.ps1`. Both files are therefore executed under 5.1 as well as 7.4+.

A `#Requires -Version 5.1` line was considered and rejected: `#Requires` is a version *floor* and checks only the running engine version, not the syntax used, so it cannot catch a PS7-only construct (e.g. `??`, ternary, `-Parallel`) that fails only at runtime under 5.1. It would add nothing over this ADR plus a real CI check.

## Decision

`lib/scoop/scoop.ps1` and `lib/utils/utils.ps1` **MUST remain Windows PowerShell 5.1-compatible**. Any change to these two files (or code they newly depend on) must avoid PowerShell 7-only language features and cmdlets.

This is enforced by a CI smoke guard, `test/bin/smoke-ps51.ps1`, run under `shell: powershell` (5.1) in `.github/workflows/test.yml`. It dot-sources both files under 5.1 (so any PS7-only parse/load regression fails the build), asserts the key functions are defined, and validates `Get-ScoopUpdatableApp` parsing via a shadow-stubbed `Invoke-CommandLine`. It is dependency-free (no Pester under 5.1) and fast.

## Consequences

- Contributors editing `scoop.ps1` or `utils.ps1` must stay within the 5.1 language/cmdlet subset; the CI smoke guard will fail otherwise.
- The constraint is scoped to these two files only. The rest of `lib/` remains 7.4+.
- If a future feature genuinely needs a PS7-only construct in `utils.ps1`, that shared code must be factored so the 5.1 consumer (the Scoop helper) does not load it, or this ADR must be revisited.
- The full Pester suite still runs under pwsh 7.x; the 5.1 guard is an additional, lightweight gate, not a second test suite.

[← Back to Architecture](../README.md)
