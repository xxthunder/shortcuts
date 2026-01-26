# Tasks: WSL Manager - Phase 1 Implementation

**Input**: Design documents from `/specs/001-wsl-manager/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli-interface.md

**Tests**: This project follows TDD (Test-First Development) - a NON-NEGOTIABLE constitutional principle. All test tasks are MANDATORY and must be completed BEFORE implementation.

**Organization**: Tasks are grouped by outstanding work items from plan.md. Each work item represents a complete, independently testable feature increment.

**Scope**: This tasks file covers Items #1, #3, #4, and #5 from plan.md. Item #2 (Docker Setup Refactoring) is deferred pending bash script design and will be generated in a separate Phase 2.

**Latest Update (2026-01-14)**: Added Work Item #5 - Centralize Distribution Information Parsing. This refactoring makes `Get-WslDistroList` the single source of truth for all distribution information, eliminating duplicate parsing code.

## Terminology Guide

This tasks file uses three levels of organization to maintain traceability:

- **User Stories (US-1 through US-8)**: Feature-level requirements from spec.md with priority P1-P8
- **Work Items (Item1, Item3, Item4)**: Implementation groupings from plan.md's "Outstanding Work" section
- **Tasks (T001-T034)**: Granular implementation steps labeled with [Item#] markers

**Mapping for Phase 1**:
- **Work Item #1** implements **User Story 5** (P5) - Terminate Running Distribution
- **Work Item #3** implements **User Story 6** (P6) - Update Distribution (state validation portion)
- **Work Item #4** implements **User Story 7** (P7) - Setup User (NOPASSWD warning portion)
- **Work Item #5** (NEW) - Internal refactoring to centralize distribution parsing (DRY principle)

This separation allows:
- **spec.md** to focus on user-facing features and acceptance criteria
- **plan.md** to group related implementation work across multiple requirements
- **tasks.md** to provide granular, executable steps with clear dependencies

## Format: `[ID] [P?] [Item] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Item]**: Which work item this task belongs to (Item1, Item3, Item4)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md project structure:
- **PowerShell library**: `tools/pslib/wsl/wsl.ps1` (library functions)
- **Manager tool**: `tools/pslib/wsl/wsl-manager.ps1` (interactive interface)
- **Unit tests**: `tools/pslib/wsl/wsl.Tests.ps1`, `tools/pslib/wsl/wsl-manager.Tests.ps1`
- **Integration tests**: `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`

---

## Phase 1: Setup (Verify Prerequisites)

**Purpose**: Ensure development environment is ready for implementation

- [X] T001 Verify Pester 5.7.1+ is installed (run `test/bin/init.ps1` if needed)
- [X] T002 Verify PSScriptAnalyzer 1.24.0+ is installed
- [X] T003 Run existing test suite to ensure baseline passes: `pwsh -File ".\test\bin\testrunner.ps1" -Unit`
- [X] T003b Establish robust testing infrastructure (custom runner, linter integration, pre-commit hooks)
- [X] T004 Review constitution principles in `.specify/memory/constitution.md` to understand TDD requirements

---

## Phase 2: Work Item #4 - NOPASSWD Security Warning (Priority: Low - Quick Win) 🎯

**Goal**: Display security warning when creating users with NOPASSWD sudo access (FR-029)

**Independent Test**: Create a user account and verify warning is displayed about NOPASSWD implications

**Estimated Effort**: 30 minutes

**Related Requirements**: FR-029, User Story 7 scenario 7

### Tests for Work Item #4 (MANDATORY - TDD)

> **TDD REQUIREMENT**: Write these tests FIRST, ensure they FAIL before implementation

- [X] T005 [P] [Item4] Add test case in `tools/pslib/wsl/wsl.Tests.ps1` for `New-WslUser` warning display
  - Mock `Invoke-WslDistroCommand` to simulate successful user creation
  - Verify `Write-Warning` is called with expected message about NOPASSWD
  - Use `Should -Invoke Write-Warning` to verify warning displayed
  - Run test, confirm it FAILS (warning not yet implemented)

### Implementation for Work Item #4

- [X] T006 [Item4] Add NOPASSWD warning in `New-WslUser` function in `tools/pslib/wsl/wsl.ps1`
  - Locate the `New-WslUser` function (approximately line 599-740)
  - After successful user creation and before function return
  - Add: `Write-Warning "NOPASSWD sudo has been configured for '$Username'. This allows running commands as root without password prompt. Suitable for development environments but not recommended for production systems."`
  - Place warning after user creation success message but before restart instructions
  - Run test from T005, confirm it now PASSES

- [X] T007 [Item4] Verify integration test includes warning check in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - Add assertion to existing user creation integration test
  - Verify warning appears in integration scenario
  - Run: `pwsh -File ".\test\bin\testrunner.ps1" -Integration`

**Checkpoint**: NOPASSWD warning is displayed and tested. Run full test suite to verify no regressions.

---

## Phase 3: Work Item #5 - Centralize Distribution Information Parsing (Priority: High - Foundational) 🎯

**Goal**: Make `Get-WslDistroList` the single source of truth for all distribution information (Name, State, Version, IsDefault) by adding a `-Detailed` switch parameter. Refactor `Get-WslDistroState` and `Test-Wsl2Version` to use this centralized data.

**Independent Test**: Call `Get-WslDistroList -Detailed` and verify it returns structured objects with all fields; verify `Get-WslDistroState` and `Test-Wsl2Version` return same results as before.

**Estimated Effort**: 3-4 hours

**Related Requirements**: Constitution Principle VI (DRY), research.md Addendum (2026-01-14)

**Why This Matters**: Currently 3 functions independently parse `wsl --list` output with duplicate null-character cleaning and localization handling. This refactoring:
1. Eliminates ~80% duplicate parsing code
2. Single point for bug fixes and localization improvements
3. Single WSL call vs. multiple calls for state+version checks
4. Captures `IsDefault` field (currently discarded)

### Tests for Work Item #5 - Get-WslDistroList -Detailed (MANDATORY - TDD)

> **TDD REQUIREMENT**: Write these tests FIRST, ensure they FAIL before implementation

- [X] T035 [P] [Item5] Add test case for `Get-WslDistroList -Detailed` basic parsing in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `wsl.exe --list --verbose` to return English output with 2 distributions
  - Test output format: `"  NAME            STATE           VERSION`\n`* Debian          Running         2`\n`  Ubuntu          Stopped         2"`
  - Verify returns array of PSCustomObjects
  - Verify first object has: Name="Debian", State="Running", Version=2, IsDefault=$true
  - Verify second object has: Name="Ubuntu", State="Stopped", Version=2, IsDefault=$false
  - Run test, confirm it FAILS (parameter not yet implemented)

- [X] T036 [P] [Item5] Add test case for `Get-WslDistroList -Detailed` localized state (German) in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `wsl.exe --list --verbose` with German output: `"  NAME            STATUS          VERSION`\n`* Debian          Wird ausgeführt 2`\n`  Ubuntu          Beendet         2"`
  - Verify State is normalized: "Wird ausgeführt" → "Running", "Beendet" → "Stopped"
  - Run test, confirm it FAILS

- [X] T037 [P] [Item5] Add test case for `Get-WslDistroList -Detailed` localized state (French) in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `wsl.exe --list --verbose` with French output: `"  NOM             ÉTAT            VERSION`\n`* Debian          En cours d'exécution 2"`
  - Verify State is normalized: "En cours d'exécution" → "Running"
  - Run test, confirm it FAILS

- [X] T038 [P] [Item5] Add test case for `Get-WslDistroList -Detailed` UTF-16 null character handling in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `wsl.exe --list --verbose` with embedded null chars: `"D`0e`0b`0i`0a`0n"`
  - Verify null characters are cleaned from Name field
  - Run test, confirm it FAILS

- [X] T039 [P] [Item5] Add test case for `Get-WslDistroList -Detailed` empty list in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `wsl.exe --list --verbose` to return header only
  - Verify returns empty array (not $null)
  - Run test, confirm it FAILS

- [X] T040 [P] [Item5] Add test case for `Get-WslDistroList -Detailed` single distribution in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `wsl.exe --list --verbose` with only one distribution
  - Verify returns array with one object (not just the object)
  - Run test, confirm it FAILS

- [X] T041 [P] [Item5] Add test case for `Get-WslDistroList -Detailed` WSL1 version in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock output with WSL1 distribution: `"  Ubuntu-18.04   Stopped         1"`
  - Verify Version field is integer 1 (not string)
  - Run test, confirm it FAILS

- [X] T042 [P] [Item5] Add test case for backward compatibility of `Get-WslDistroList` (no parameter) in `tools/pslib/wsl/wsl.Tests.ps1`
  - Call `Get-WslDistroList` without `-Detailed`
  - Verify returns string array (not objects)
  - Verify existing behavior is unchanged
  - Run test, should PASS (existing behavior preserved)

### Implementation for Work Item #5 - Get-WslDistroList -Detailed

- [X] T043 [Item5] Add `-Detailed` switch parameter to `Get-WslDistroList` in `tools/pslib/wsl/wsl.ps1`
  - Locate `Get-WslDistroList` function (lines 177-208)
  - Add parameter: `[switch]$Detailed`
  - Keep existing logic for non-Detailed path (calls `wsl --list --quiet`)
  - Add conditional: `if ($Detailed) { # new parsing logic }`
  - Run test T042, confirm backward compatibility PASSES

- [X] T044 [Item5] Implement verbose output parsing in `Get-WslDistroList -Detailed` in `tools/pslib/wsl/wsl.ps1`
  - When `-Detailed` specified: Call `wsl.exe --list --verbose`
  - Split output into lines
  - For each line (after header):
    - Remove null characters: `-replace '\x00', ''`
    - Remove carriage returns: `-replace '\r', ''`
    - Trim whitespace
    - Skip header line (matches `NAME|STATE|VERSION|NOM|NOMBRE|STATUS`)
    - Detect default marker (asterisk at line start)
    - Remove asterisk: `-replace '^\*\s*', ''`
    - Split by whitespace into fields
    - Create PSCustomObject with: Name, State (normalized), Version (int), IsDefault
  - Run tests T035-T041, confirm they all PASS

- [X] T045 [Item5] Implement state normalization helper in `Get-WslDistroList` in `tools/pslib/wsl/wsl.ps1`
  - Create private helper function or inline logic
  - Running patterns: `Running`, `Wird`, `ausgeführt`, `cours`, `exécution`, `Ausführen`
  - Return "Running" if pattern matches, "Stopped" otherwise
  - Run tests T036, T037, confirm they PASS

- [X] T046 [Item5] Update help documentation for `Get-WslDistroList` in `tools/pslib/wsl/wsl.ps1`
  - Add `-Detailed` parameter description in .PARAMETER block
  - Add example: `Get-WslDistroList -Detailed`
  - Document return type difference: string[] vs PSCustomObject[]

### Tests for Work Item #5 - Refactor Consumers (MANDATORY - TDD)

- [X] T047 [P] [Item5] Add test case for refactored `Get-WslDistroState` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Get-WslDistroList -Detailed` to return array with target distribution
  - Call `Get-WslDistroState -DistroName "Debian"`
  - Verify it calls `Get-WslDistroList -Detailed` (not `wsl.exe` directly)
  - Verify returns "Running" or "Stopped" string (unchanged behavior)
  - Run test, confirm it FAILS (not yet refactored)

- [X] T048 [P] [Item5] Add test case for refactored `Test-Wsl2Version` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Get-WslDistroList -Detailed` to return array with target distribution
  - Call `Test-Wsl2Version -DistroName "Debian"` where Version=2
  - Verify it calls `Get-WslDistroList -Detailed` (not `wsl.exe` directly)
  - Verify returns $true (unchanged behavior)
  - Call with Version=1 distribution, verify returns $false
  - Run test, confirm it FAILS (not yet refactored)

### Implementation for Work Item #5 - Refactor Consumers

- [X] T049 [Item5] Refactor `Get-WslDistroState` to use `Get-WslDistroList -Detailed` in `tools/pslib/wsl/wsl.ps1`
  - Locate `Get-WslDistroState` function (lines 546-648)
  - Replace existing `wsl.exe --list --verbose` parsing with:
    ```powershell
    $distros = Get-WslDistroList -Detailed
    $distro = $distros | Where-Object { $_.Name -eq $DistroName }
    if (-not $distro) { throw "Distribution '$DistroName' does not exist." }
    return $distro.State
    ```
  - Keep existing error handling for WSL not installed
  - Significantly simplify function (remove ~80 lines of parsing code)
  - Run test T047, confirm it PASSES
  - Run existing `Get-WslDistroState` tests (T008-T009), confirm they still PASS

- [X] T050 [Item5] Refactor `Test-Wsl2Version` to use `Get-WslDistroList -Detailed` in `tools/pslib/wsl/wsl.ps1`
  - Locate `Test-Wsl2Version` function (lines 1257-1340)
  - Replace existing `wsl.exe --list --verbose` parsing with:
    ```powershell
    $distros = Get-WslDistroList -Detailed
    $distro = $distros | Where-Object { $_.Name -eq $DistroName }
    if (-not $distro) { throw "Distribution '$DistroName' does not exist." }
    return $distro.Version -eq 2
    ```
  - Keep existing error handling for WSL not installed
  - Significantly simplify function (remove ~60 lines of parsing code)
  - Run test T048, confirm it PASSES

### Integration Tests for Work Item #5 (MANDATORY)

- [X] T051 [Item5] Add integration test for `Get-WslDistroList -Detailed` in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - Call `Get-WslDistroList -Detailed` on real system
  - Verify returns array of objects with expected properties
  - Verify Name matches `Get-WslDistroList` (string version)
  - Verify State is "Running" or "Stopped"
  - Verify Version is 1 or 2
  - Verify IsDefault is boolean
  - Run: `pwsh -File ".\test\bin\testrunner.ps1" -Integration`

- [X] T052 [Item5] Verify no regressions in dependent functions in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - Run existing `Get-WslDistroState` integration tests
  - Run existing `Test-Wsl2Version` integration tests (if any)
  - Verify `Test-WslDistroRunning` still works (uses `Get-WslDistroState`)
  - Verify `Stop-WslDistro` still works (uses `Test-WslDistroRunning`)
  - Run: `pwsh -File ".\test\bin\testrunner.ps1" -Integration`

### Defensive Parsing Tests (Edge Case Coverage)

- [X] T052c [P] Add malformed wsl.conf test for `Get-WslDefaultUser` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Invoke-WslDistroCommand` to return malformed INI content:
    - Missing closing bracket: `[user`
    - Invalid characters: `default = user@#$%`
    - Empty sections: `[user]\n\n[boot]`
    - Duplicate keys: `default=user1\ndefault=user2`
  - Verify function returns $null (graceful failure)
  - Verify function does not throw exception
  - Run test, confirm behavior is defensive

- [X] T052d [P] Add malformed wsl.conf test for `Test-WslSystemdConfigured` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Invoke-WslDistroCommand` to return malformed INI content
  - Verify function returns $false (graceful failure)
  - Verify function does not throw exception
  - Run test, confirm behavior is defensive

**Checkpoint**: Distribution list centralization is complete. `Get-WslDistroList -Detailed` is the single source of truth. Run full test suite to verify no regressions: `pwsh -File ".\test\bin\testrunner.ps1"`

---

## Phase 4: Work Item #1 - Terminate Running Distribution (Priority: High)

**Goal**: Implement ability to terminate (stop) running WSL distributions (User Story 5, FR-031, FR-032, FR-033)

**Independent Test**: Start a WSL distribution, terminate it via the manager, verify it's stopped and can be restarted

**Note**: This phase can now use `Get-WslDistroList -Detailed` from Work Item #5 for state checking.

**Function Naming**: PowerShell convention requires approved verbs. `Stop-WslDistro` is the function name (using approved verb "Stop"), while "terminate" is the user-facing terminology matching WSL CLI (`wsl --terminate`). Both refer to the same operation.

**Key Deliverables**:
- Library function: `Stop-WslDistro` in `tools/pslib/wsl/wsl.ps1`
- Manager command: `terminate` in `wsl-manager.ps1` CLI
- Interactive menu: "[T] Terminate running distribution"

**Estimated Effort**: 2-3 hours

**Related Requirements**: FR-031, FR-032, FR-033, User Story 5 (all 6 acceptance scenarios)

### Tests for Work Item #1 - Helper Functions (MANDATORY - TDD)

> **TDD REQUIREMENT**: Write these tests FIRST, ensure they FAIL before implementation

- [X] T008 [P] [Item1] Add test cases for `Get-WslDistroState` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Test WSL not installed → throws error
  - Test distribution doesn't exist → throws error
  - Test running distribution → returns 'Running' (mock `wsl --list --verbose` with "Running" state)
  - Test stopped distribution → returns 'Stopped' (mock `wsl --list --verbose` with "Stopped" state)
  - Test localized output (German: "Wird ausgeführt", French: "En cours d'exécution") → returns 'Running'
  - Test null character cleaning in output
  - Run tests, confirm they FAIL (function not yet implemented)

- [X] T009 [P] [Item1] Add test cases for `Test-WslDistroRunning` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Test WSL not installed → throws error
  - Test distribution doesn't exist → throws error
  - Test running distribution → returns $true (mock `Get-WslDistroState` to return 'Running')
  - Test stopped distribution → returns $false (mock `Get-WslDistroState` to return 'Stopped')
  - Verify it calls `Get-WslDistroState` internally
  - Run tests, confirm they FAIL (function not yet implemented)

- [X] T010 [P] [Item1] Add test cases for `Stop-WslDistro` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Test WSL not installed → throws error
  - Test distribution doesn't exist → throws error
  - Test already stopped distribution → informational message (no error)
  - Test running distribution → calls `wsl --terminate <name>`, success message
  - Test with `-Confirm:$false` → skips confirmation
  - Test with `-Confirm:$true` in CI → proceeds without prompt
  - Mock `Test-WslDistroRunning` and `wsl.exe` execution
  - Run tests, confirm they FAIL (function not yet implemented)

### Implementation for Work Item #1 - Helper Functions

- [X] T011 [Item1] Implement `Get-WslDistroState` function in `tools/pslib/wsl/wsl.ps1`
  - Add function after `Get-WslDistroType` (approximately line 535)
  - Parse `wsl --list --verbose` output for state column
  - Handle localized output using pattern matching (Running|Stopped|Wird ausgeführt|Arrêté|En cours|etc.)
  - Return 'Running' or 'Stopped' as string
  - Include comprehensive error handling (WSL not installed, distro not found)
  - Add help documentation with SYNOPSIS, DESCRIPTION, EXAMPLES
  - Run tests from T008, confirm they now PASS

- [X] T012 [Item1] Implement `Test-WslDistroRunning` function in `tools/pslib/wsl/wsl.ps1`
  - Add function after `Get-WslDistroState`
  - Call `Get-WslDistroState` internally
  - Return `$true` if state is 'Running', `$false` if 'Stopped'
  - Include error handling that passes through from `Get-WslDistroState`
  - Add help documentation with SYNOPSIS, DESCRIPTION, EXAMPLES
  - Run tests from T009, confirm they now PASS

- [X] T013 [Item1] Implement `Stop-WslDistro` function in `tools/pslib/wsl/wsl.ps1`
  - Function name: `Stop-WslDistro` (PowerShell approved verb)
  - Help documentation should mention: "Terminates (stops) a running WSL distribution using `wsl --terminate <name>`"
  - Add function after `Test-WslDistroRunning`
  - Use `[CmdletBinding(SupportsShouldProcess)]` for confirmation prompts
  - Validate: WSL installed, distribution exists
  - Check if distribution is running using `Test-WslDistroRunning`
  - If already stopped: Display informational message, return success
  - If running: Execute `wsl.exe --terminate <Name>` using `Invoke-CommandLine`
  - Display success message: "✓ Successfully terminated distribution '<Name>'"
  - Include comprehensive error handling
  - Add help documentation with SYNOPSIS, DESCRIPTION, EXAMPLES
  - Run tests from T010, confirm they now PASS

### Tests for Work Item #1 - Manager Integration (MANDATORY - TDD)

- [X] T014 [P] [Item1] Add test cases for `Invoke-TerminateDistro` in `tools/pslib/wsl/wsl-manager.Tests.ps1`
  - Test interactive selection by number (mock user selects "1")
  - Test interactive selection by name (mock user enters "Debian")
  - Test no running distributions → displays message
  - Test invalid selection → error message
  - Test user cancels (empty input) → operation cancelled
  - Mock `Get-WslDistroList`, `Test-WslDistroRunning`, `Stop-WslDistro`, `Read-Host`
  - Run tests, confirm they FAIL (function not yet implemented)

### Implementation for Work Item #1 - Manager Integration

- [X] T015 [Item1] Add "terminate" to ValidateSet in `tools/pslib/wsl/wsl-manager.ps1`
  - Locate param block at line 50
  - Add "terminate" to ValidateSet: `[ValidateSet("list", "create", "clone", "remove", "update", "setup-user", "setup-docker", "terminate", "")]`

- [X] T016 [Item1] Implement `Invoke-TerminateDistro` function in `tools/pslib/wsl/wsl-manager.ps1`
  - Add function after `Invoke-SetupDockerInteractive` (approximately line 479)
  - Check if WSL is installed
  - Get list of running distributions (filter using `Test-WslDistroRunning`)
  - If no running distributions: Display message, return
  - Display numbered list of running distributions
  - Prompt for selection (number or name)
  - Validate selection
  - Call `Stop-WslDistro -Name $selectedName -Confirm:$false` (confirmation handled interactively)
  - Handle errors gracefully
  - Run tests from T014, confirm they now PASS

- [X] T017 [Item1] Add terminate command handler in `Invoke-WslManager` function in `tools/pslib/wsl/wsl-manager.ps1`
  - Locate the switch statement (approximately line 687-717)
  - Add case for "terminate": `"terminate" { Invoke-TerminateDistro }`
  - Ensure consistency with other command handlers

- [X] T018 [Item1] Add "[T] Terminate running distribution" to interactive menu in `tools/pslib/wsl/wsl-manager.ps1`
  - Locate `Show-InteractiveMenu` function (approximately line 560-668)
  - Add menu option after "[D] Setup Docker" (approximately line 595)
  - Add: `Write-Host "  [T] Terminate running distribution" -ForegroundColor White`
  - Add case "T" in switch statement (approximately line 602-664)
  - Call `Invoke-TerminateDistro`, wrap in try/catch
  - Add Read-Host prompt after execution

### Integration Tests for Work Item #1 (MANDATORY - TDD)

- [X] T019 [Item1] Add integration test for terminate command in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - Start a test WSL distribution
  - Execute: `.\tools\pslib\wsl\wsl-manager.ps1 terminate <name>`
  - Verify distribution is stopped (check `wsl --list --verbose`)
  - Verify distribution can be restarted
  - Clean up test distribution
  - Run: `pwsh -File ".\test\bin\testrunner.ps1" -Integration`

**Checkpoint**: Terminate functionality is complete. Run full test suite to verify: `pwsh -File ".\test\bin\testrunner.ps1"`

---

## Phase 5: Work Item #3 - Pre-Operation State Validation (Priority: Medium)

**Goal**: Add state validation to operations requiring stopped distributions (FR-030)

**Independent Test**: Attempt to clone/remove/update a running distribution, verify error message directs user to terminate it first

**Estimated Effort**: 2-3 hours

**Related Requirements**: FR-030, User Story 3 (scenario 6), User Story 4 (scenario 5), User Story 6 (scenario 6)

**Dependencies**: Work Item #1 must be complete (provides `Test-WslDistroRunning` function)

### Tests for Work Item #3 (MANDATORY - TDD)

> **TDD REQUIREMENT**: Write these tests FIRST, ensure they FAIL before implementation

- [X] T020 [P] [Item3] Add state validation test for `Update-WslDistro` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Test-WslDistroRunning` to return $true (distribution running)
  - Call `Update-WslDistro -Name "Debian"`
  - Verify it throws error with message: "Distribution 'Debian' is running. Stop it first with: wsl --terminate Debian"
  - Verify apt update is NOT called when distribution is running
  - Run test, confirm it FAILS (validation not yet implemented)

- [X] T021 [P] [Item3] Add state validation test for `Copy-WslDistro` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Test-WslDistroRunning` to return $true for source distribution
  - Call `Copy-WslDistro -SourceName "Debian" -TargetName "MyProject"`
  - Verify it throws error with message: "Distribution 'Debian' is running. Stop it first with: wsl --terminate Debian"
  - Verify export is NOT called when distribution is running
  - Run test, confirm it FAILS (validation not yet implemented)

- [X] T022 [P] [Item3] Add state validation test for `Remove-WslDistro` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Test-WslDistroRunning` to return $true (distribution running)
  - Call `Remove-WslDistro -Name "TestProject" -Confirm:$false`
  - Verify it throws error with message: "Distribution 'TestProject' is running. Stop it first with: wsl --terminate TestProject"
  - Verify unregister is NOT called when distribution is running
  - Run test, confirm it FAILS (validation not yet implemented)

### Implementation for Work Item #3

- [X] T023 [Item3] Add state validation to `Update-WslDistro` in `tools/pslib/wsl/wsl.ps1`
  - Locate `Update-WslDistro` function (approximately line 536-597)
  - After distribution existence check (around line 576-578)
  - Add state check: `if (Test-WslDistroRunning -Name $Name) { throw "Distribution '$Name' is running. Stop it first with: wsl --terminate $Name" }`
  - Ensure error is thrown BEFORE any apt operations
  - Run test from T020, confirm it now PASSES

- [X] T024 [Item3] Add state validation to `Copy-WslDistro` in `tools/pslib/wsl/wsl.ps1`
  - Locate `Copy-WslDistro` function (approximately line 830-930)
  - After source distribution existence check
  - Add state check: `if (Test-WslDistroRunning -Name $SourceName) { throw "Distribution '$SourceName' is running. Stop it first with: wsl --terminate $SourceName" }`
  - Ensure error is thrown BEFORE export operation
  - Run test from T021, confirm it now PASSES

- [X] T025 [Item3] Add state validation to `Remove-WslDistro` in `tools/pslib/wsl/wsl.ps1`
  - Locate `Remove-WslDistro` function (approximately line 764-828)
  - After distribution existence check (around line 779-781)
  - Add state check: `if (Test-WslDistroRunning -Name $Name) { throw "Distribution '$Name' is running. Stop it first with: wsl --terminate $Name" }`
  - Ensure error is thrown BEFORE unregister operation
  - Run test from T022, confirm it now PASSES

### Integration Tests for Work Item #3 (MANDATORY - TDD)

- [X] T026 [Item3] Add integration test for state validation in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - Create and start a test WSL distribution
  - Attempt to update while running → verify error message
  - Attempt to clone while running → verify error message
  - Attempt to remove while running → verify error message
  - Terminate distribution
  - Verify operations succeed after termination
  - Clean up test distribution
  - Run: `pwsh -File ".\test\bin\testrunner.ps1" -Integration`

**Checkpoint**: State validation is complete. All operations correctly enforce stopped state requirement.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and documentation updates

- [X] T053 [P] Run full unit test suite with coverage: `pwsh -File ".\test\bin\testrunner.ps1" -Unit -Coverage`
- [X] T054 [P] Run full integration test suite: `pwsh -File ".\test\bin\testrunner.ps1" -Integration`
- [X] T055 [P] Run linter checks: `pwsh -File ".\test\bin\linter.Tests.ps1"`
- [X] T056 Verify PowerShell 5.1 compatibility: `powershell -File ".\test\bin\testrunner.ps1"`
- [X] T057 Update `specs/001-wsl-manager/quickstart.md` with `Get-WslDistroList -Detailed` and terminate examples
- [X] T058 Update CLI interface contract `specs/001-wsl-manager/contracts/cli-interface.md` to mark terminate as implemented
- [X] T059 Verify all acceptance criteria from spec.md are met for implemented user stories
- [X] T060 Run manual smoke test: Create → Setup User → Terminate → Clone → Update → Remove workflow

---

## Phase 7: Refactoring & Infrastructure (New Priorities)

**Goal**: Slice "monolithic" `wsl.ps1` and `wsl.Tests.ps1` into maintainable modules and implement enhanced script execution.

**Prerequisites**: Phase 6 complete.

**Acceptance Criteria**:
1. **Backward Compatibility**: All existing consumers of `wsl.ps1` work without modification
   - `wsl-manager.ps1` continues to function identically
   - All 28 functions remain accessible via `. tools/pslib/wsl/wsl.ps1`
   - External scripts sourcing `wsl.ps1` are unaffected
2. **Module Structure**: Functions logically grouped into 6 module files (`core.ps1`, `install.ps1`, `ops.ps1`, `user.ps1`, `exec.ps1`, `docker.ps1`)
3. **Test Organization**: Test files mirror module structure in `tests/` directory
4. **Test Coverage**: All existing tests pass without modification (100% backward compatibility)
5. **Linter Clean**: All module files pass PSScriptAnalyzer checks
6. **Documentation Updated**: Help comments updated to reflect new file locations

**Definition of Done**:
- [ ] `wsl.ps1` successfully dot-sources all `lib/*.ps1` files
- [ ] All unit tests pass: `pwsh -File ".\test\bin\testrunner.ps1" -Unit`
- [ ] All integration tests pass: `pwsh -File ".\test\bin\testrunner.ps1" -Integration`
- [ ] PowerShell 5.1 compatibility verified: `powershell -File ".\test\bin\testrunner.ps1"`
- [ ] Git history shows tests committed before refactoring (TDD compliance)
- [ ] Code review confirms no functional changes, only structural reorganization

### Refactoring Work - Tests (MANDATORY - TDD)

> **TDD REQUIREMENT**: Write these tests FIRST, ensure they PASS for backward compatibility

- [X] T066-test [P] Add backward compatibility tests for module structure in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock existing `wsl.ps1` dot-sourcing behavior
  - Verify all 19 functions remain accessible after refactoring
  - Test that existing callers (like `wsl-manager.ps1`) work unchanged
  - Run test, confirm it PASSES with current monolithic structure

- [ ] T067-test [P] Add tests for individual module files in `tools/pslib/wsl/tests/`
  - Create test files: `core.Tests.ps1`, `install.Tests.ps1`, `ops.Tests.ps1`, `user.Tests.ps1`, `exec.Tests.ps1`, `docker.Tests.ps1`
  - Copy existing test cases to appropriate module test files
  - Run tests, confirm they PASS with current structure
  - **NOTE**: Skipped - existing tests already validate backward compatibility

### Refactoring Work - Implementation

- [X] T066 [P] Create directory structure `tools/pslib/wsl/lib` and `tools/pslib/wsl/tests`

- [X] T067 [P] Split `wsl.ps1` functions into modules:
  - `tools/pslib/wsl/lib/core.ps1`: Test-WslInstalled, Get-WslDistroList, Get-WslDistroState, Test-WslDistroRunning, Get-WslDistroType, Test-Wsl2Version, Test-WslSystemd, Stop-WslDistro (8 functions, 536 lines)
  - `tools/pslib/wsl/lib/install.ps1`: Get-WslAvailableDistro, New-WslDistro (2 functions, 149 lines)
  - `tools/pslib/wsl/lib/ops.ps1`: Remove-WslDistro, Copy-WslDistro, Update-WslDistro (3 functions, 235 lines)
  - `tools/pslib/wsl/lib/user.ps1`: New-WslUser, Get-WslDefaultUser, Test-WslSystemdConfigured (3 functions, 365 lines)
  - `tools/pslib/wsl/lib/exec.ps1`: Invoke-WslDistroCommand (1 function, 112 lines)
  - `tools/pslib/wsl/lib/docker.ps1`: Test-WslDockerInstalled, Install-WslDockerEngine (2 functions, 338 lines)

- [X] T068 [P] Update `wsl.ps1` to dot-source all files in `lib/`
  - Verified T066-test still passes (backward compatibility maintained)
  - wsl.ps1 reduced from 1697 lines to 19 lines

- [ ] T069 [P] Move test cases to corresponding files in `tools/pslib/wsl/tests/`
  - Verify T067-test passes with new structure
  - **NOTE**: Skipped - monolithic test file works fine with modular implementation

- [X] T070 Verify all tests pass with refactored structure: `pwsh -File ".\test\bin\testrunner.ps1" -Unit`
  - All T066-test assertions pass (461/461 unit tests)
  - All integration tests pass (23/23)

### Enhanced Execution Work - Tests (MANDATORY - TDD)

- [X] T071-test [P] Add test cases for `Invoke-WslDistroScript` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Test script path validation:
    - Script exists → proceeds to execution
    - Script doesn't exist → throws "Script not found: <path>"
  - Test path conversion:
    - C: drive path → converts to /mnt/c/...
    - D: drive path → converts to /mnt/d/...
    - Backslashes → converts to forward slashes
  - Test WSL execution:
    - Mock `Invoke-CommandLine` to return success (exit 0)
    - Mock `Invoke-CommandLine` to return failure (exit 2)
  - Test argument passing:
    - No arguments → executes script only
    - Multiple arguments → passes correctly to script
  - Mock `Test-Path`, `Test-WslInstalled`, `Get-WslDistroList`, `Invoke-CommandLine`
  - Tests FAILED initially (function not yet implemented) ✓
  - Tests PASS after implementation ✓

### Enhanced Execution Work - Implementation

- [X] T071 [P] Implement `Invoke-WslDistroScript` in `tools/pslib/wsl/lib/exec.ps1`
  - Accepts `-ScriptPath` (Windows path), `-DistroName`, and `-Arguments`
  - Validates script existence on Windows filesystem
  - Converts Windows path to WSL mount path (e.g., C:\Users\... → /mnt/c/Users/...)
  - Executes via `wsl.exe -d <DistroName> --exec bash <converted-path> <arguments>`
  - Returns exit code from script execution
  - Tests from T071-test now PASS (475/475 unit tests) ✓

- [X] T072 Integration test for `Invoke-WslDistroScript` in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - **COMPLETED (2026-01-26)**: Added comprehensive integration tests
  - Test 1: Execute bash script with arguments and verify exit code
  - Test 2: Execute bash script with AsRoot=true/false and verify sudo execution
  - Tests verify Windows-to-WSL path conversion and exit code handling
  - All integration tests passing (26/26) ✓

### Docker Setup Work - Tests (MANDATORY - TDD)

- [X] T073-test [P] Add tests for refactored `Install-WslDockerEngine` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Invoke-WslDistroScript` execution
  - Verify correct script path passed (install-docker.sh)
  - Verify arguments correctly formatted (--distro-id, --codename, --arch, --username)
  - Verify exit code handling (0=success, 1=prereq, 2=install, 3=verify, 4=args)
  - Tests FAILED initially (refactoring not yet done) ✓
  - Tests PASS after refactoring ✓

### Docker Setup Work - Implementation

- [X] T073 [P] Finalize `tools/pslib/wsl/scripts/install-docker.sh` (ensure it's executable and correct)
  - Script already complete and validated
  - Exit codes properly defined: 0=success, 1=prereq, 2=install, 3=verification, 4=args

- [X] T074 Refactor `Install-WslDockerEngine` in `tools/pslib/wsl/lib/docker.ps1`
  - Use `Invoke-WslDistroScript` to run `install-docker.sh`
  - Pass arguments correctly: `--distro-id`, `--codename`, `--arch`, `--username`
  - Handle exit codes with user-friendly error messages
  - Removed old manual command execution (75 lines → 30 lines for script execution)
  - Tests from T073-test now PASS (469/469 unit tests) ✓
  - **CRITICAL BUG FIX (2026-01-26)**: Added `-AsRoot $true` parameter
    - Initial implementation failed user acceptance test: "Error: This script must be run as root"
    - Root cause: install-docker.sh requires root but was executing as regular user
    - Fix: Added AsRoot parameter to Invoke-WslDistroScript, pass `-AsRoot $true` in Install-WslDockerEngine
    - **TDD VIOLATION CORRECTED**: Added unit test to verify AsRoot parameter usage
    - All tests passing (504/504) ✓

- [X] T075 Integration test for Docker setup in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - **COMPLETED (2026-01-26)**: Added comprehensive Docker installation integration test
  - Tests Docker installation from scratch OR verifies existing installation
  - Verifies: docker --version, systemctl is-active docker, docker ps as non-root user
  - Tests Docker service is running after installation
  - Tests user can run docker without sudo (group membership works)
  - Integration test passing, Docker successfully installed and functional ✓

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - verify environment ready
- **Work Item #4 (Phase 2)**: Can start immediately after Setup - Independent
- **Work Item #5 (Phase 3)**: Can start immediately after Setup - **FOUNDATIONAL for other work items**
- **Work Item #1 (Phase 4)**: DEPENDS on Work Item #5 (uses `Get-WslDistroList -Detailed` via `Get-WslDistroState`)
- **Work Item #3 (Phase 5)**: DEPENDS on Work Item #1 (needs `Test-WslDistroRunning` function)
- **Polish (Phase 6)**: Depends on all work items being complete

### Work Item Dependencies

- **Work Item #4 (NOPASSWD Warning)**: No dependencies - Can start immediately
- **Work Item #5 (Centralize Parsing)**: No dependencies - **Should be done first** (foundational)
- **Work Item #1 (Terminate Distribution)**: REQUIRES Work Item #5 complete (for refactored `Get-WslDistroState`)
- **Work Item #3 (State Validation)**: REQUIRES Work Item #1 complete (needs `Test-WslDistroRunning`)

### Within Each Work Item

- **TDD REQUIREMENT**: Tests MUST be written and FAIL before implementation
- Helper functions before callers (Get-WslDistroState → Test-WslDistroRunning → Stop-WslDistro)
- Library functions before manager integration
- Unit tests before integration tests
- All tests must pass before moving to next work item

### Parallel Opportunities

- **Phase 1 (Setup)**: All tasks marked [P] can run in parallel (T001-T004)
- **Work Items #4 and #5**: Can be worked on in parallel by different developers
- **Within Work Item #5**:
  - T035-T042 (test writing for Get-WslDistroList -Detailed) can run in parallel
  - T047, T048 (consumer refactor tests) can run in parallel
- **Within Work Item #1**:
  - T008, T009, T010 (test writing) can run in parallel
  - T014 (manager test) can be written in parallel with helper function tests
- **Within Work Item #3**:
  - T020, T021, T022 (test writing) can run in parallel
- **Phase 6 (Polish)**:
  - T053, T054, T055 (different test suites) can run in parallel
  - T057, T058 (documentation) can run in parallel

---

## Parallel Example: Work Item #5 Tests

```bash
# Launch all test writing tasks for Work Item #5 together:
Task: "Add test case for Get-WslDistroList -Detailed basic parsing in tools/pslib/wsl/wsl.Tests.ps1"
Task: "Add test case for Get-WslDistroList -Detailed localized state (German) in tools/pslib/wsl/wsl.Tests.ps1"
Task: "Add test case for Get-WslDistroList -Detailed localized state (French) in tools/pslib/wsl/wsl.Tests.ps1"
Task: "Add test case for Get-WslDistroList -Detailed UTF-16 null character handling in tools/pslib/wsl/wsl.Tests.ps1"
Task: "Add test case for Get-WslDistroList -Detailed empty list in tools/pslib/wsl/wsl.Tests.ps1"
Task: "Add test case for backward compatibility of Get-WslDistroList in tools/pslib/wsl/wsl.Tests.ps1"

# All these tests can be written simultaneously in different test blocks
```

## Parallel Example: Work Item #1 Tests

```bash
# Launch all test writing tasks for Work Item #1 together:
Task: "Add test cases for Get-WslDistroState in tools/pslib/wsl/wsl.Tests.ps1"
Task: "Add test cases for Test-WslDistroRunning in tools/pslib/wsl/wsl.Tests.ps1"
Task: "Add test cases for Stop-WslDistro in tools/pslib/wsl/wsl.Tests.ps1"
Task: "Add test cases for Invoke-TerminateDistro in tools/pslib/wsl/wsl-manager.Tests.ps1"

# All these tests can be written simultaneously in different sections of test files
```

---

## Implementation Strategy

### Sequential Execution (Recommended for Solo Development)

1. Complete Phase 1: Setup (T001-T004)
2. Complete Work Item #4: NOPASSWD Warning (T005-T007) - 30 minutes
3. Complete Work Item #5: Centralize Parsing (T035-T052) - **3-4 hours** ← NEW FOUNDATIONAL WORK
4. Complete Work Item #1: Terminate Distribution (T008-T019) - 2-3 hours
5. Complete Work Item #3: State Validation (T020-T026) - 2-3 hours
6. Complete Phase 6: Polish (T053-T060)
7. **TOTAL ESTIMATED TIME**: 8-11 hours

### Parallel Team Strategy

With 2 developers:

1. Both complete Phase 1: Setup together
2. Split initial work items:
   - **Developer A**: Work Item #5 (Centralize Parsing) - 3-4 hours ← Critical path
   - **Developer B**: Work Item #4 (NOPASSWD Warning) - 30 minutes
3. After Developer A completes Work Item #5:
   - **Developer A** continues to Work Item #1 (depends on #5)
   - **Developer B** can write Work Item #1 tests in parallel
4. After Developer A completes Work Item #1:
   - **Developer B** can complete Work Item #3 implementation (depends on #1)
5. Both complete Phase 6: Polish together

### Critical Path

**Work Item #5 → Work Item #1 → Work Item #3** forms the critical path:
- #5 provides `Get-WslDistroList -Detailed`
- #1 uses it via `Get-WslDistroState` for `Test-WslDistroRunning`
- #3 uses `Test-WslDistroRunning` for state validation

Work Item #4 (NOPASSWD Warning) is independent and can be done anytime.

### Validation Checkpoints

- After Work Item #5: Verify `Get-WslDistroList -Detailed` returns correct structure
- After Work Item #1: Test terminate command manually
- After Work Item #3: Test clone/remove/update with running distribution
- Before final commit: Run both PowerShell 5.1 and 7.x test suites

---

## Task Summary

| Phase | Work Item | Tasks | Estimated Time |
|-------|-----------|-------|----------------|
| 1 | Setup | T001-T004 (4 tasks) | 15 minutes |
| 2 | #4 NOPASSWD Warning | T005-T007 (3 tasks) | 30 minutes |
| 3 | #5 Centralize Parsing | T035-T052 (18 tasks) | 3-4 hours |
| 4 | #1 Terminate Distribution | T008-T019 (12 tasks) | 2-3 hours |
| 5 | #3 State Validation | T020-T026 (7 tasks) | 2-3 hours |
| 6 | Polish | T053-T060 (8 tasks) | 1 hour |
| 7 | Refactoring & Infrastructure | T066-T072 (7 tasks) | 2-3 hours |
| 8 | Docker Setup | T073-T075 (3 tasks) | 2 hours |
| **Total** | | **67 tasks** | **14-19 hours** |
