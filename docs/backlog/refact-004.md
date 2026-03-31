[← Back to Backlog](README.md)

# [REFACT-004] ✅ DONE - Remove redundant `Test-WslInstalled` guard checks (DRY)

**Status**: Done (2026-02-24)
**Priority**: Medium
**Component**: `tools/pslib/wsl/` (8 source files, 8 test files)

**Description**:
Removed 32 redundant `Test-WslInstalled` guard blocks from 8 source files and ~250 `Mock Test-WslInstalled { $true }` boilerplate lines from 8 test files. WSL 2 availability is now validated once at the `Invoke-WslManager` entry point via a new `Assert-Wsl2Installed` function. This also upgraded the check from WSL 1 detection to WSL 2 detection (`wsl --version` only exists in the WSL 2 store app).

**Acceptance Criteria**:
- [x] New `Assert-Wsl2Installed` function that throws if WSL 2 is not installed
- [x] `Invoke-WslManager` calls the assertion once before dispatching
- [x] All 32 `if (-not (Test-WslInstalled))` guard blocks removed from individual functions
- [x] 23 "When WSL is not installed" test contexts deleted from test files
- [x] ~250 `Mock Test-WslInstalled { $true }` lines removed from remaining test contexts
- [x] Mocks preserved in `Test-WslInstalled` and `Assert-Wsl2Installed` test describes
- [x] `Test-WslInstalled` (the boolean check) remains available for non-throwing use cases
- [x] All tests pass (27 redundant guard tests removed)
- [x] No change in user-facing behavior

[← Back to Backlog](README.md)
