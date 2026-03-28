[← Back to Backlog](README.md)

# [REFACT-005] ✅ COMPLETED - Extract `Assert-WslDistroExists` guard to replace inline distro validation (DRY)

**Status**: Completed (2026-02-24)
**Priority**: Medium
**Component**: `tools/pslib/wsl/` (7 source files, 7 test files)
**Related**: REFACT-004 (same pattern — entry-point guard extraction)

**Description**:
Extracted throwing `Assert-WslDistroExists` and `Assert-WslDistroNotExists` guard functions into `core.ps1` and replaced 22 inline distro-existence validation patterns (trim + `Get-WslDistroList` + `-notin` + throw) across 7 source files. Also absorbed `.Trim()` into `Test-WslDistroExists`. Error messages now consistently include the list of installed distributions. Following the `Assert-Wsl2Installed` pattern from REFACT-004.

**Acceptance Criteria**:
- [x] `Test-WslDistroExists` absorbs `.Trim()` internally
- [x] New `Assert-WslDistroExists` function with unit tests
- [x] New `Assert-WslDistroNotExists` function with unit tests
- [x] All 22 inline distro-existence checks replaced (including the 2 enhanced-message sites and the inverse check)
- [x] Redundant `$DistroName.Trim()` / `$Name.Trim()` calls removed where they only served the validation
- [x] `Test-WslDistroExists` (boolean) remains available for non-throwing use
- [x] Error message always includes installed distros list: `"Distribution '<name>' does not exist. Installed distributions: <list>"`
- [x] All tests pass (mock updates only, no behavior change)
- [x] No change in user-facing behavior

[← Back to Backlog](README.md)
