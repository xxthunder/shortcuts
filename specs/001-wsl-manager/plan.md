# Implementation Plan: WSL Manager

**Branch**: `001-wsl-manager` | **Date**: 2026-01-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-wsl-manager/spec.md`

**Note**: This plan incorporates user feedback to add Docker setup refactoring task.

## Summary

The WSL Manager provides a comprehensive PowerShell-based tool for managing Windows Subsystem for Linux (WSL) distributions. It enables developers to create, clone, update, configure, and remove WSL distributions through both interactive menus and command-line interfaces. The implementation follows a library-first architecture with reusable functions in `tools/pslib/wsl/` and an interactive manager tool in `tools/pslib/wsl/wsl-manager.ps1`.

**Key capabilities:**
- List and view WSL distributions
- Create distributions from Microsoft Store catalog
- Clone existing distributions with full configuration preservation
- Update packages in Debian/Ubuntu distributions
- Setup user accounts with sudo privileges
- Install Docker Engine with systemd support
- Terminate running distributions
- Interactive mode for command discoverability

**Technical approach:** Fail-fast error handling with comprehensive prerequisite validation, pattern-based WSL output parsing for localization support, dual-mode support (interactive + CI/automation), and test-driven development with Pester unit and integration tests.

## Technical Context

**Language/Version**: PowerShell 5.1+ (compatible with both Windows PowerShell 5.1 and PowerShell 7.x)
**Primary Dependencies**:
  - WSL (Windows Subsystem for Linux) - required
  - Pester 5.7.1+ - testing framework
  - PSScriptAnalyzer 1.24.0+ - linting
  - No external PowerShell modules required (uses built-in cmdlets only)

**Storage**: No persistent storage - all state retrieved from:
  - WSL command-line interface (`wsl.exe`)
  - Linux filesystem within distributions (`/etc/wsl.conf`, `/etc/os-release`)
  - Temporary tar files for clone operations (cleaned up after use)

**Testing**:
  - Pester 5.7.1+ for unit tests (`*.Tests.ps1`) and integration tests (`*.Integration.Tests.ps1`)
  - Unit tests mock external dependencies (wsl.exe, file system, commands)
  - Integration tests use real WSL distributions
  - All tests must pass on PowerShell 5.1 and 7.x

**Target Platform**:
  - Windows 10 version 2004+ (required for WSL2)
  - Windows 11 (recommended)
  - PowerShell 5.1+ (Windows PowerShell or PowerShell Core/7.x)

**Project Type**: Single project (CLI tool + library)

**Performance Goals**:
  - List distributions: <1 second
  - Create distribution: <5 minutes (network dependent)
  - Clone distribution: <3 minutes for typical 5GB distribution
  - Docker installation: <10 minutes (network dependent)
  - User account creation: <30 seconds
  - Package updates: Variable (package count dependent)

**Constraints**:
  - PowerShell 5.1 compatibility (no PS 6.0+ exclusive features)
  - No external PowerShell modules (use built-in cmdlets only)
  - Support localized WSL output (pattern-based parsing, not position-based)
  - Fail-fast error handling (immediate failure with safe state)
  - Both interactive and CI/automation modes

**Scale/Scope**:
  - 28 library functions across 2 modules (`utils.ps1`, `wsl.ps1`)
  - 1 interactive manager tool (`wsl-manager.ps1`)
  - 9 user stories (8 implemented, 1 enhancement needed)
  - Support unlimited WSL distributions (limited by disk space)
  - Comprehensive test coverage (100% of functions tested)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Status**: ✅ PASS - All constitutional principles satisfied

### Principle I: Test-First Development (NON-NEGOTIABLE)
✅ **PASS** - Comprehensive Pester test suite exists:
  - Unit tests: `tools/pslib/wsl/wsl.Tests.ps1`, `tools/pslib/wsl/wsl-manager.Tests.ps1`
  - Integration tests: `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - All 28 functions have test coverage
  - Tests written before implementation (TDD cycle followed)

### Principle II: Library-First Architecture
✅ **PASS** - All reusable functionality implemented as library functions:
  - Core library: `tools/pslib/wsl/wsl.ps1` (28 functions)
  - Utility library: `tools/pslib/utils/utils.ps1` (shared utilities)
  - Manager tool: `tools/pslib/wsl/wsl-manager.ps1` (builds on library functions)
  - `.bat` wrapper exists: `tools/pslib/wsl/wsl-manager.bat`
  - Uses `Invoke-CommandLine` for external commands

### Principle III: PowerShell Standards
✅ **PASS** - Adheres to PowerShell best practices:
  - PowerShell 5.1+ compatible syntax (no PS 6.0+ features)
  - Passes PSScriptAnalyzer checks (integrated in test suite)
  - Proper help documentation (SYNOPSIS, DESCRIPTION, EXAMPLE)
  - Standard script structure with `#Requires -Version 5.1`
  - Uses `[CmdletBinding()]` and proper parameter declarations

### Principle IV: Error Handling & Robustness
✅ **PASS** - Robust error handling throughout:
  - `Set-StrictMode -Version Latest` in all scripts
  - `$ErrorActionPreference = 'Stop'` configured
  - Try/catch blocks for main logic
  - Clear, user-friendly error messages with actionable guidance
  - Path and input validation before operations
  - Dependency checks (WSL, systemd, Docker)

### Principle V: Environment Awareness
✅ **PASS** - Dual-mode support (interactive + CI):
  - Uses `Test-RunningInCIorTestEnvironment` for context detection
  - Non-interactive paths for CI/automated scenarios
  - Interactive prompts for user-driven workflows
  - Mocked dependencies in tests
  - Both CI and interactive behavior tested separately

### Principle VI: Code Reusability (DRY)
✅ **PASS** - Follows DRY principles:
  - Common functionality extracted to library functions
  - No code duplication across scripts
  - SOLID principles applied (see research.md Decision 6)
  - Parameterized tests reduce test duplication
  - Manager tool reuses library functions

### Principle VII: Documentation & Traceability
✅ **PASS** - Well-documented with traceability:
  - Conventional commits used throughout git history
  - Clear commit messages explaining "why"
  - Comprehensive documentation (spec.md, research.md, data-model.md, contracts/)
  - Help documentation in all functions
  - File:line references in code reviews

**Conclusion**: All constitutional gates pass. Implementation ready to proceed.

## Project Structure

### Documentation (this feature)

```text
specs/001-wsl-manager/
├── spec.md              # Feature specification (user stories, requirements)
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0 output (design decisions, research findings)
├── data-model.md        # Phase 1 output (entities, relationships, state machines)
├── quickstart.md        # Phase 1 output (getting started guide)
├── contracts/
│   └── cli-interface.md # CLI commands, parameters, outputs
└── tasks.md             # Phase 2 output (NOT YET CREATED - /speckit.tasks command)
```

### Source Code (repository root)

```text
tools/pslib/
├── utils/
│   ├── utils.ps1           # Shared utility functions
│   └── utils.Tests.ps1     # Unit tests for utilities
└── wsl/
    ├── wsl.ps1             # WSL library functions (28 functions)
    ├── wsl.Tests.ps1       # Unit tests for WSL library
    ├── wsl-manager.ps1     # Interactive manager tool
    ├── wsl-manager.bat     # Batch wrapper for easy execution
    ├── wsl-manager.Tests.ps1            # Unit tests for manager
    └── wsl-manager.Integration.Tests.ps1 # Integration tests

test/
├── bin/
│   ├── init.ps1            # Test environment initialization
│   ├── testrunner.ps1      # Test runner (unit + integration)
│   └── linter.Tests.ps1    # PSScriptAnalyzer checks
└── out/                    # Test output directory (coverage, results)

docs/
└── stories/                # User story documentation (archived)

.github/
└── workflows/
    └── test.yml            # CI pipeline (PowerShell 5.1 + 7.x testing)
```

**Structure Decision**: Single project (CLI tool + library) structure selected. All PowerShell code lives in `tools/pslib/` with:
- **Library functions** in `tools/pslib/wsl/wsl.ps1` - reusable, testable functions
- **Manager tool** in `tools/pslib/wsl/wsl-manager.ps1` - interactive interface building on library
- **Tests colocated** with source files following Pester conventions
- **Batch wrapper** for command-line execution without `pwsh -File` syntax
- **Shared utilities** in `tools/pslib/utils/utils.ps1` for cross-project reuse

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations detected.** All design decisions align with constitutional principles. This section is not applicable.

## Outstanding Work

### Phase 2: Tasks Generation (Not Yet Started)

The following work items need to be converted to actionable tasks via `/speckit.tasks`:

#### 1. Missing Core Functionality (Priority: High)

**User Story 5: Terminate Running Distribution (P5)**

**Current State**: Partially implemented
- `wsl --terminate` commands referenced in error messages
- No dedicated function in `wsl.ps1`
- No dedicated command in `wsl-manager.ps1` interactive menu

**Required Implementation**:
1. Add `Stop-WslDistro` function to `tools/pslib/wsl/wsl.ps1`
   - Detect if distribution is running
   - Execute `wsl --terminate <name>`
   - Provide feedback on success/already-stopped state
   - Include comprehensive error handling
2. Add `Invoke-TerminateDistro` wrapper to `wsl-manager.ps1`
   - Interactive distribution selection (number or name)
   - Handle "no running distributions" scenario
   - Show list of running distributions
3. Add "Terminate" command to interactive menu
   - New menu option: `[T] Terminate running distribution`
   - Integration with existing menu workflow
4. Write Pester tests
   - Unit tests for `Stop-WslDistro` (mock `wsl.exe`)
   - Unit tests for `Invoke-TerminateDistro` workflow
   - Integration tests with real WSL distributions

**Acceptance Criteria**: All scenarios from spec.md User Story 5 pass

**Related Functions**:
- Add `Get-WslDistroState` function (returns 'Running' | 'Stopped')
  - Parses `wsl --list --verbose` for state column
  - Handles localized output (pattern-based parsing)
- Add `Test-WslDistroRunning` helper function (returns $true/$false)
  - Calls `Get-WslDistroState` internally
  - Consistent with existing `Test-WslInstalled` pattern

**Estimated Complexity**: Medium (2-3 hours including tests)

---

#### 2. Docker Setup Refactoring (Priority: High - User Requested) **[DEFERRED]**

> **Status**: Deferred pending bash script design. Requires additional design artifacts:
> - Bash script structure/contract (`install-docker.sh`)
> - Script transfer pattern (PowerShell → WSL)
> - Exit code mapping table
>
> **Estimated Design Time**: 15-30 minutes
> **Implementation Time**: 4-6 hours after design complete

**Issue**: Current `Install-WslDockerEngine` function (lines 1162-1426 in `tools/pslib/wsl/wsl.ps1`) is a "mess of PowerShell calling bash oneliners" with ~15 separate `Invoke-WslDistroCommand` calls.

**Desired Approach**: "Execute one clean bash script from PowerShell"

**Current Implementation Problems**:
- Line 1329: Remove old Docker (bash oneliner)
- Lines 1332-1334: Update apt and install prerequisites (2 separate calls)
- Line 1338: Create keyrings directory (bash oneliner)
- Lines 1342-1360: Get distro info and download GPG key (complex multi-step)
- Lines 1363-1367: Configure Docker repository (bash oneliner with heredoc)
- Lines 1371-1372: Install Docker packages (2 separate apt calls)
- Line 1376: Add user to docker group (bash oneliner)
- Lines 1380-1383: Enable and start Docker service (2 systemctl calls)
- Lines 1391-1407: Verification steps (4 separate docker/systemctl calls)

**Proposed Solution**:
1. Create `tools/pslib/wsl/scripts/install-docker.sh` bash script
   - Self-contained Docker installation logic
   - Accepts parameters: `--distro-id`, `--codename`, `--arch`, `--username`
   - Returns structured exit codes (0=success, 1=prereq failure, 2=install failure, 3=verification failure)
   - Includes comprehensive error messages
   - Performs all installation steps internally
2. Refactor `Install-WslDockerEngine` in PowerShell
   - Prerequisite validation (steps 1-8) remain in PowerShell
   - Detect distro info (ID, codename, arch) in PowerShell
   - Copy bash script to WSL distribution (temp location)
   - Execute single `bash /tmp/install-docker.sh --distro-id=ubuntu --codename=jammy --arch=amd64 --username=developer`
   - Parse exit code and provide user feedback
   - Clean up temp script file
3. Update tests
   - Mock the bash script execution in unit tests
   - Integration tests verify end-to-end Docker installation
   - Test script independently in bash environment

**Benefits**:
- Cleaner separation: PowerShell for orchestration, bash for Linux operations
- Easier to maintain bash installation logic
- Bash script can be tested independently
- Reduces PowerShell → bash → PowerShell context switching
- More idiomatic for Linux package installation

**Acceptance Criteria**:
- All existing Docker installation tests pass
- Bash script can be executed standalone for debugging
- Error handling equivalent or better than current implementation
- All User Story 8 acceptance scenarios pass

**Estimated Complexity**: Medium-High (4-6 hours including bash script creation, PowerShell refactoring, and test updates)

---

#### 3. Pre-Operation State Validation (Priority: Medium)

**Current State**: Partial implementation
- Some functions check distribution state in error messages
- No centralized state validation before operations
- Inconsistent enforcement across functions

**Required Implementation**:
1. Add `Test-WslDistroRunning` to `tools/pslib/wsl/wsl.ps1`
   - Parse `wsl --list --verbose` for state column
   - Return `$true` if Running, `$false` if Stopped
   - Handle localized output (pattern-based parsing)
2. Add state validation to operations requiring stopped distributions:
   - `Update-WslDistro` - add state check before apt operations
   - `Copy-WslDistro` - add state check for source distribution
   - `Remove-WslDistro` - add state check before unregister
3. Update error messages to be consistent:
   - "Distribution '{Name}' is running. Stop it first with: wsl --terminate {Name}"
4. Write comprehensive tests
   - Unit tests with mocked `wsl --list --verbose` output
   - Test both English and localized (German, French) output
   - Integration tests with real running/stopped distributions

**Acceptance Criteria**: FR-030 fully implemented across all operations

**Estimated Complexity**: Low-Medium (2-3 hours including tests)

---

#### 4. Security Warning for NOPASSWD Sudo (Priority: Low)

**Current State**: Not implemented
- `New-WslUser` creates users with NOPASSWD sudo
- No warning displayed to users

**Required Implementation**:
1. Add warning display in `New-WslUser` (after user creation, before returning)
   ```powershell
   Write-Warning "NOPASSWD sudo has been configured for '$Username'. This allows running commands as root without password prompt. Suitable for development environments but not recommended for production systems."
   ```
2. Display warning once per user creation operation (displayed every time `New-WslUser` is called, not on subsequent operations with that created user account)
3. Update tests to verify warning is displayed
4. Update documentation to mention NOPASSWD implications

**Acceptance Criteria**: FR-029 implemented, User Story 7 scenario 7 passes

**Estimated Complexity**: Low (30 minutes including test update)

---

#### 5. Centralize Distribution Information Parsing (Priority: High - Foundational) **[NEW 2026-01-14]**

**Issue**: Multiple functions independently parse `wsl --list --verbose` output with duplicate logic:
- `Get-WslDistroList` (lines 177-208) - parses `wsl --list --quiet` for names only
- `Get-WslDistroState` (lines 546-648) - parses `wsl --list --verbose` for state
- `Test-Wsl2Version` (lines 1257-1340) - parses `wsl --list --verbose` for version

**Problems**:
1. **Duplicate parsing logic**: ~80% code overlap between `Get-WslDistroState` and `Test-Wsl2Version`
2. **Inconsistent handling**: Each function implements its own null-character cleaning and localization
3. **Multiple WSL calls**: Checking state AND version requires two calls to `wsl.exe`
4. **Maintenance burden**: Any change to WSL output format requires updates in 3 places
5. **Lost data**: `IsDefault` flag (asterisk marker) currently discarded

**Proposed Solution**: Make `Get-WslDistroList` the single source of truth

1. Add `-Detailed` switch parameter to `Get-WslDistroList`
   - Without `-Detailed`: Current behavior (returns string array of names)
   - With `-Detailed`: Returns array of `WslDistroInfo` objects

2. Define `WslDistroInfo` structure:
   ```powershell
   [PSCustomObject]@{
       Name      = [string]    # Distribution name (e.g., "Debian")
       State     = [string]    # Normalized: "Running" or "Stopped"
       Version   = [int]       # WSL version: 1 or 2
       IsDefault = [bool]      # True if default distribution (asterisk marker)
   }
   ```

3. Refactor consumers to use `Get-WslDistroList -Detailed`:
   ```powershell
   # Refactored Get-WslDistroState
   function Get-WslDistroState {
       param([string]$DistroName)
       $distros = Get-WslDistroList -Detailed
       $distro = $distros | Where-Object { $_.Name -eq $DistroName }
       if (-not $distro) { throw "Distribution '$DistroName' does not exist." }
       return $distro.State
   }

   # Refactored Test-Wsl2Version
   function Test-Wsl2Version {
       param([string]$DistroName)
       $distros = Get-WslDistroList -Detailed
       $distro = $distros | Where-Object { $_.Name -eq $DistroName }
       if (-not $distro) { throw "Distribution '$DistroName' does not exist." }
       return $distro.Version -eq 2
   }
   ```

**Benefits**:
- Single point for WSL output parsing and localization handling
- Single WSL call for all distribution info (vs. multiple calls)
- Consistent null-character and carriage-return cleaning
- `IsDefault` field now available (previously discarded)
- ~140 lines of duplicate code eliminated
- Easier to add new fields in the future

**Backward Compatibility**:
- `Get-WslDistroList` without `-Detailed` returns string array (unchanged)
- `Get-WslDistroState` returns same values ("Running" or "Stopped")
- `Test-Wsl2Version` returns same values ($true or $false)
- All existing callers continue to work without modification

**Test Cases Required**:
1. Basic parsing (English output with multiple distributions)
2. Localized state (German "Wird ausgeführt", French "En cours d'exécution")
3. UTF-16 null character handling
4. Empty distribution list
5. Default marker detection (IsDefault field)
6. Mixed WSL1/WSL2 versions
7. Special characters in distribution names (Ubuntu-22.04)
8. Backward compatibility (string array return type)

**Acceptance Criteria**:
- `Get-WslDistroList -Detailed` returns correct WslDistroInfo objects
- `Get-WslDistroState` and `Test-Wsl2Version` return identical results to before
- All existing tests pass without modification
- Constitution Principle VI (DRY) improved

**Estimated Complexity**: Medium (3-4 hours including tests)

**Dependencies**: Should be completed BEFORE Item #1 (Terminate Distribution) since `Get-WslDistroState` will be refactored

---

### Summary of Outstanding Work

| Item | Priority | Status | Complexity | Related User Stories |
|------|----------|--------|------------|---------------------|
| #5 Centralize Parsing | **High - Foundational** | Ready for Tasks | Medium | DRY principle (internal) |
| #1 Terminate Distribution | High | Ready for Tasks | Medium | US-5 (P5) |
| #2 Docker Setup Refactoring | High | **DEFERRED** (needs design) | Medium-High | US-8 (P8) - Enhancement |
| #3 State Validation | Medium | Ready for Tasks | Low-Medium | US-3, US-4, US-6 (FR-030) |
| #4 NOPASSWD Warning | Low | Ready for Tasks | Low | US-7 (FR-029) |

**Phase 1 Effort** (Items 1, 3, 4, 5): 8-11 hours
**Phase 2 Effort** (Item 2 - after design): 4-6 hours
**Total Estimated Effort**: 12-17 hours

**Current Implementation Order** (Phase 1):
1. **NOPASSWD Warning** (quick win, no dependencies)
2. **Centralize Parsing** (foundational - enables cleaner state checking)
3. **Terminate Distribution** (depends on #5, unblocks state validation)
4. **State Validation** (depends on terminate)
5. *Docker Setup Refactoring deferred to Phase 2* (needs bash script design first)

## Next Steps

This plan has completed Phases 0 and 1:
- ✅ Phase 0: Research complete (see `research.md`)
- ✅ Phase 1: Design artifacts complete (see `data-model.md`, `contracts/`, `quickstart.md`)

**Ready to proceed with Phase 1 Implementation** (4 items ready):
1. ✅ Item #4: NOPASSWD Warning - specifications complete
2. ✅ Item #5: Centralize Parsing - specifications complete (NEW - foundational)
3. ✅ Item #1: Terminate Distribution - specifications complete (depends on #5)
4. ✅ Item #3: State Validation - specifications complete (depends on #1)
5. ⏸️ Item #2: Docker Refactoring - **DEFERRED** (needs bash script design)

**To proceed with Phase 1**:
1. Run `/speckit.tasks` to generate `tasks.md` for Items 1, 3, 4, and 5
   - Docker refactoring (Item #2) will be excluded from initial task generation
2. Tasks will be broken down into:
   - Test writing tasks (TDD - write tests first)
   - Implementation tasks (write code to pass tests)
   - Integration tasks (update interactive menu, documentation)
3. Run `/speckit.implement` to execute Phase 1 tasks systematically

**Critical Path**: Item #5 (Centralize Parsing) → Item #1 (Terminate) → Item #3 (State Validation)

---

### Phase 2: Refactoring & Infrastructure (New Priorities for 2026-01-14)

Based on project size (>1700 lines in `wsl.ps1` and >2800 lines in `wsl.Tests.ps1`) and new requirements, Phase 2 completely replaces the original Docker deployment plan with a structured refactoring and feature expansion approach.

#### 1. Library Refactoring (Priority: High)
**Goal**: Slice "monolithic" `wsl.ps1` and `wsl.Tests.ps1` into maintainable modules.
**Approach**:
- Create `tools/pslib/wsl/lib/` directory
- Split `wsl.ps1` functions into logical groups:
  - `lib/core.ps1`: Lifecycle (List, State, Stop, Remove) and Info (Type, Version, Validations)
  - `lib/install.ps1`: Creation/Installation (New-WslDistro, Get-WslAvailableDistro)
  - `lib/ops.ps1`: Operations (Copy, Update)
  - `lib/user.ps1`: User management (New-WslUser, defaults)
  - `lib/exec.ps1`: Execution commands (Invoke-*, scripts) - *base for next step*
  - `lib/docker.ps1`: Docker-specific functions
- Update `wsl.ps1` to be a loader script that dot-sources all files in `lib/`
  - Maintains backward compatibility for consumers sourcing `wsl.ps1`
- Split `wsl.Tests.ps1` similarly into `tests/core.Tests.ps1`, `tests/ops.Tests.ps1`, etc.

#### 2. Enhanced Script Execution (Priority: High)
**Goal**: Implement `Invoke-WslDistroScript` for executing scripts mapped from Windows filesystem.
**Concept**:
- wsl.exe automatically mounts the host CWD (e.g., `/mnt/c/...`) when invoked
- `Invoke-WslDistroScript` takes a local Windows script path
- Does NOT copy file to distro filesystem (assumes shared mount)
- Logic:
  - Verify script exists
  - Verify CWD is mountable/accessible
  - Execute `bash ./script.sh` relative to current location
- **Benefits**: Simplifies file management, no cleanup of temp files needed, simpler debug cycle

#### 3. Docker Setup Implementation (Priority: Medium)
**Goal**: Implement robust Docker setup using the new `install-docker.sh` + `Invoke-WslDistroScript`.
**Plan**:
- Finalize `install-docker.sh` (already in `contracts/` and `scripts/`)
- Remove old `Install-WslDockerEngine` logic (the "mess of PowerShell calling bash oneliners")
- Implement new logic using `Invoke-WslDistroScript`
- Pass arguments (`--distro-id` etc.) cleanly
- Better error handling and verification

---

**Branch**: Implementation will continue on `001-wsl-manager`
**Artifacts**: All plan artifacts available in `specs/001-wsl-manager/`
