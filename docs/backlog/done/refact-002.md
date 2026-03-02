# [REFACT-002] ✅ COMPLETED - Fix `Invoke-SetupUser` CI guard scope and add explicit parameters

**Status**: **Completed** (2026-02-20) | **Branch**: `feature/feat-002-podman-wsl`
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Blocks**: REFACT-003

**Description**:
Added optional `-Username` and `-Password` parameters to `Invoke-SetupUser`. Moved the `Test-RunningInCIorTestEnvironment` guard to wrap only the prompting block, so programmatic calls with explicit parameters work even under Pester. `Invoke-WslManager` passes both params through for the `"setup-user"` command.

**Acceptance Criteria**:
- [x] `Invoke-SetupUser -DistroName "debian-test" -Username "testuser" -Password "pass"` calls `New-WslUser` without prompting, even under Pester
- [x] `Invoke-WslManager -Command "setup-user" -Name "debian-test" -Username "testuser" -Password "pass"` passes both params through
- [x] When `-Username`/`-Password` are omitted, interactive behaviour is unchanged
- [x] CI guard fires when prompting is needed but is bypassed when both params are provided
- [x] Unit tests cover both non-interactive and interactive paths
- [x] All existing tests continue to pass
