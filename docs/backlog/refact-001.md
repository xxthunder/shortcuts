[← Back to Backlog](README.md)

# [REFACT-001] ✅ COMPLETED - Add `-Selection` parameter to `Invoke-UpdateDistro` and `Invoke-RemoveDistro`

**Status**: Completed (2026-02-20)
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Blocks**: REFACT-003

**Description**:
`Invoke-UpdateDistro` and `Invoke-RemoveDistro` had no parameters — they were purely interactive, always calling `Read-Host`. Added an optional `-Selection` parameter to both functions. When `-Selection` is provided, `Read-Host` is skipped; all other logic (list display, number/name resolution, validation) runs in both cases — single code path. `Invoke-WslManager` passes `$Name` as `-Selection` for the `"update"` and `"remove"` commands.

**Acceptance Criteria**:
- [x] `Invoke-RemoveDistro -Selection "debian-test"` removes without prompting
- [x] `Invoke-UpdateDistro -Selection "Debian"` updates without prompting
- [x] `Invoke-WslManager -Command "remove" -Name "debian-test"` passes `$Name` as `-Selection`
- [x] `Invoke-WslManager -Command "update" -Name "Debian"` passes `$Name` as `-Selection`
- [x] When `-Selection` is omitted, interactive behaviour (Read-Host prompt) is unchanged
- [x] Unit tests cover both non-interactive (selection provided) and interactive paths
- [x] All existing tests continue to pass

[← Back to Backlog](README.md)
