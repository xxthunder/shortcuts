# [REFACT-003] ✅ COMPLETED - Refactor wsl-manager integration tests to call wsl-manager functions

**Status**: **Completed** (2026-02-21) | **Branch**: `feature/refact-001-002-003`
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.docker.Integration.Tests.ps1`

**Description**:
Refactored integration tests to dot-source `wsl-manager.ps1` and call `Invoke-WslManager` in-process instead of subprocess invocations. All operations with a wsl-manager wrapper now route through the public API. BeforeAll/AfterAll retain pslib calls for setup/teardown. Script Execution and Docker Setup contexts retain direct pslib calls (no wsl-manager wrapper exists).

**Acceptance Criteria**:
- [x] No subprocess calls (`& $script:wslManagerPath`) remain in the test file
- [x] No direct pslib calls for operations that have a wsl-manager wrapper (including State Validation)
- [x] `Invoke-UpdateDistro`, `Invoke-CloneDistro`, `Invoke-SetupUser` are exercised indirectly via `Invoke-WslManager` routing
- [x] `Script Execution` and `Docker Setup` contexts retain their direct pslib calls unchanged
- [x] BeforeAll/AfterAll retain pslib calls for setup/teardown
- [x] Output assertions updated to match in-process output (no null-char stripping or stream merging workarounds)
- [x] All integration tests pass end-to-end
