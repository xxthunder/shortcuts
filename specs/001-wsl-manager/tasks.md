# Tasks: WSL Manager - Phase 1 Implementation

**Input**: Design documents from `/specs/001-wsl-manager/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli-interface.md

**Tests**: This project follows TDD (Test-First Development) - a NON-NEGOTIABLE constitutional principle. All test tasks are MANDATORY and must be completed BEFORE implementation.

**Organization**: Tasks are grouped by outstanding work items from plan.md. Each work item represents a complete, independently testable feature increment.

**Phase 1 Scope**: This tasks file covers Items #1, #3, and #4 from plan.md. Item #2 (Docker Setup Refactoring) is deferred pending bash script design and will be generated in a separate Phase 2.

## Terminology Guide

This tasks file uses three levels of organization to maintain traceability:

- **User Stories (US-1 through US-8)**: Feature-level requirements from spec.md with priority P1-P8
- **Work Items (Item1, Item3, Item4)**: Implementation groupings from plan.md's "Outstanding Work" section
- **Tasks (T001-T034)**: Granular implementation steps labeled with [Item#] markers

**Mapping for Phase 1**:
- **Work Item #1** implements **User Story 5** (P5) - Terminate Running Distribution
- **Work Item #3** implements **User Story 6** (P6) - Update Distribution (state validation portion)
- **Work Item #4** implements **User Story 7** (P7) - Setup User (NOPASSWD warning portion)

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

- [ ] T001 Verify Pester 5.7.1+ is installed (run `test/bin/init.ps1` if needed)
- [ ] T002 Verify PSScriptAnalyzer 1.24.0+ is installed
- [ ] T003 Run existing test suite to ensure baseline passes: `pwsh -File ".\test\bin\test.ps1" -Unit`
- [ ] T004 Review constitution principles in `.specify/memory/constitution.md` to understand TDD requirements

---

## Phase 2: Work Item #4 - NOPASSWD Security Warning (Priority: Low - Quick Win) 🎯

**Goal**: Display security warning when creating users with NOPASSWD sudo access (FR-029)

**Independent Test**: Create a user account and verify warning is displayed about NOPASSWD implications

**Estimated Effort**: 30 minutes

**Related Requirements**: FR-029, User Story 7 scenario 7

### Tests for Work Item #4 (MANDATORY - TDD)

> **TDD REQUIREMENT**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] T005 [P] [Item4] Add test case in `tools/pslib/wsl/wsl.Tests.ps1` for `New-WslUser` warning display
  - Mock `Invoke-WslDistroCommand` to simulate successful user creation
  - Verify `Write-Warning` is called with expected message about NOPASSWD
  - Use `Should -Invoke Write-Warning` to verify warning displayed
  - Run test, confirm it FAILS (warning not yet implemented)

### Implementation for Work Item #4

- [ ] T006 [Item4] Add NOPASSWD warning in `New-WslUser` function in `tools/pslib/wsl/wsl.ps1`
  - Locate the `New-WslUser` function (approximately line 599-740)
  - After successful user creation and before function return
  - Add: `Write-Warning "NOPASSWD sudo has been configured for '$Username'. This allows running commands as root without password prompt. Suitable for development environments but not recommended for production systems."`
  - Place warning after user creation success message but before restart instructions
  - Run test from T005, confirm it now PASSES

- [ ] T007 [Item4] Verify integration test includes warning check in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - Add assertion to existing user creation integration test
  - Verify warning appears in integration scenario
  - Run: `pwsh -File ".\test\bin\test.ps1" -Integration`

**Checkpoint**: NOPASSWD warning is displayed and tested. Run full test suite to verify no regressions.

---

## Phase 3: Work Item #1 - Terminate Running Distribution (Priority: High) 🎯

**Goal**: Implement ability to terminate (stop) running WSL distributions (User Story 5, FR-031, FR-032, FR-033)

**Independent Test**: Start a WSL distribution, terminate it via the manager, verify it's stopped and can be restarted

**Estimated Effort**: 2-3 hours

**Related Requirements**: FR-031, FR-032, FR-033, User Story 5 (all 6 acceptance scenarios)

### Tests for Work Item #1 - Helper Functions (MANDATORY - TDD)

> **TDD REQUIREMENT**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] T008 [P] [Item1] Add test cases for `Get-WslDistroState` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Test WSL not installed → throws error
  - Test distribution doesn't exist → throws error
  - Test running distribution → returns 'Running' (mock `wsl --list --verbose` with "Running" state)
  - Test stopped distribution → returns 'Stopped' (mock `wsl --list --verbose` with "Stopped" state)
  - Test localized output (German: "Wird ausgeführt", French: "En cours d'exécution") → returns 'Running'
  - Test null character cleaning in output
  - Run tests, confirm they FAIL (function not yet implemented)

- [ ] T009 [P] [Item1] Add test cases for `Test-WslDistroRunning` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Test WSL not installed → throws error
  - Test distribution doesn't exist → throws error
  - Test running distribution → returns $true (mock `Get-WslDistroState` to return 'Running')
  - Test stopped distribution → returns $false (mock `Get-WslDistroState` to return 'Stopped')
  - Verify it calls `Get-WslDistroState` internally
  - Run tests, confirm they FAIL (function not yet implemented)

- [ ] T010 [P] [Item1] Add test cases for `Stop-WslDistro` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Test WSL not installed → throws error
  - Test distribution doesn't exist → throws error
  - Test already stopped distribution → informational message (no error)
  - Test running distribution → calls `wsl --terminate <name>`, success message
  - Test with `-Confirm:$false` → skips confirmation
  - Test with `-Confirm:$true` in CI → proceeds without prompt
  - Mock `Test-WslDistroRunning` and `wsl.exe` execution
  - Run tests, confirm they FAIL (function not yet implemented)

### Implementation for Work Item #1 - Helper Functions

- [ ] T011 [Item1] Implement `Get-WslDistroState` function in `tools/pslib/wsl/wsl.ps1`
  - Add function after `Get-WslDistroType` (approximately line 535)
  - Parse `wsl --list --verbose` output for state column
  - Handle localized output using pattern matching (Running|Stopped|Wird ausgeführt|Arrêté|En cours|etc.)
  - Return 'Running' or 'Stopped' as string
  - Include comprehensive error handling (WSL not installed, distro not found)
  - Add help documentation with SYNOPSIS, DESCRIPTION, EXAMPLES
  - Run tests from T008, confirm they now PASS

- [ ] T012 [Item1] Implement `Test-WslDistroRunning` function in `tools/pslib/wsl/wsl.ps1`
  - Add function after `Get-WslDistroState`
  - Call `Get-WslDistroState` internally
  - Return `$true` if state is 'Running', `$false` if 'Stopped'
  - Include error handling that passes through from `Get-WslDistroState`
  - Add help documentation with SYNOPSIS, DESCRIPTION, EXAMPLES
  - Run tests from T009, confirm they now PASS

- [ ] T013 [Item1] Implement `Stop-WslDistro` function in `tools/pslib/wsl/wsl.ps1`
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

- [ ] T014 [P] [Item1] Add test cases for `Invoke-TerminateDistro` in `tools/pslib/wsl/wsl-manager.Tests.ps1`
  - Test interactive selection by number (mock user selects "1")
  - Test interactive selection by name (mock user enters "Debian")
  - Test no running distributions → displays message
  - Test invalid selection → error message
  - Test user cancels (empty input) → operation cancelled
  - Mock `Get-WslDistroList`, `Test-WslDistroRunning`, `Stop-WslDistro`, `Read-Host`
  - Run tests, confirm they FAIL (function not yet implemented)

### Implementation for Work Item #1 - Manager Integration

- [ ] T015 [Item1] Add "terminate" to ValidateSet in `tools/pslib/wsl/wsl-manager.ps1`
  - Locate param block at line 50
  - Add "terminate" to ValidateSet: `[ValidateSet("list", "create", "clone", "remove", "update", "setup-user", "setup-docker", "terminate", "")]`

- [ ] T016 [Item1] Implement `Invoke-TerminateDistro` function in `tools/pslib/wsl/wsl-manager.ps1`
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

- [ ] T017 [Item1] Add terminate command handler in `Invoke-WslManager` function in `tools/pslib/wsl/wsl-manager.ps1`
  - Locate the switch statement (approximately line 687-717)
  - Add case for "terminate": `"terminate" { Invoke-TerminateDistro }`
  - Ensure consistency with other command handlers

- [ ] T018 [Item1] Add "[T] Terminate running distribution" to interactive menu in `tools/pslib/wsl/wsl-manager.ps1`
  - Locate `Show-InteractiveMenu` function (approximately line 560-668)
  - Add menu option after "[D] Setup Docker" (approximately line 595)
  - Add: `Write-Host "  [T] Terminate running distribution" -ForegroundColor White`
  - Add case "T" in switch statement (approximately line 602-664)
  - Call `Invoke-TerminateDistro`, wrap in try/catch
  - Add Read-Host prompt after execution

### Integration Tests for Work Item #1 (MANDATORY - TDD)

- [ ] T019 [Item1] Add integration test for terminate command in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - Start a test WSL distribution
  - Execute: `.\tools\pslib\wsl\wsl-manager.ps1 terminate <name>`
  - Verify distribution is stopped (check `wsl --list --verbose`)
  - Verify distribution can be restarted
  - Clean up test distribution
  - Run: `pwsh -File ".\test\bin\test.ps1" -Integration`

**Checkpoint**: Terminate functionality is complete. Run full test suite to verify: `pwsh -File ".\test\bin\test.ps1"`

---

## Phase 4: Work Item #3 - Pre-Operation State Validation (Priority: Medium)

**Goal**: Add state validation to operations requiring stopped distributions (FR-030)

**Independent Test**: Attempt to clone/remove/update a running distribution, verify error message directs user to terminate it first

**Estimated Effort**: 2-3 hours

**Related Requirements**: FR-030, User Story 3 (scenario 6), User Story 4 (scenario 5), User Story 6 (scenario 6)

**Dependencies**: Work Item #1 must be complete (provides `Test-WslDistroRunning` function)

### Tests for Work Item #3 (MANDATORY - TDD)

> **TDD REQUIREMENT**: Write these tests FIRST, ensure they FAIL before implementation

- [ ] T020 [P] [Item3] Add state validation test for `Update-WslDistro` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Test-WslDistroRunning` to return $true (distribution running)
  - Call `Update-WslDistro -Name "Debian"`
  - Verify it throws error with message: "Distribution 'Debian' is running. Stop it first with: wsl --terminate Debian"
  - Verify apt update is NOT called when distribution is running
  - Run test, confirm it FAILS (validation not yet implemented)

- [ ] T021 [P] [Item3] Add state validation test for `Copy-WslDistro` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Test-WslDistroRunning` to return $true for source distribution
  - Call `Copy-WslDistro -SourceName "Debian" -TargetName "MyProject"`
  - Verify it throws error with message: "Distribution 'Debian' is running. Stop it first with: wsl --terminate Debian"
  - Verify export is NOT called when distribution is running
  - Run test, confirm it FAILS (validation not yet implemented)

- [ ] T022 [P] [Item3] Add state validation test for `Remove-WslDistro` in `tools/pslib/wsl/wsl.Tests.ps1`
  - Mock `Test-WslDistroRunning` to return $true (distribution running)
  - Call `Remove-WslDistro -Name "TestProject" -Confirm:$false`
  - Verify it throws error with message: "Distribution 'TestProject' is running. Stop it first with: wsl --terminate TestProject"
  - Verify unregister is NOT called when distribution is running
  - Run test, confirm it FAILS (validation not yet implemented)

### Implementation for Work Item #3

- [ ] T023 [Item3] Add state validation to `Update-WslDistro` in `tools/pslib/wsl/wsl.ps1`
  - Locate `Update-WslDistro` function (approximately line 536-597)
  - After distribution existence check (around line 576-578)
  - Add state check: `if (Test-WslDistroRunning -Name $Name) { throw "Distribution '$Name' is running. Stop it first with: wsl --terminate $Name" }`
  - Ensure error is thrown BEFORE any apt operations
  - Run test from T020, confirm it now PASSES

- [ ] T024 [Item3] Add state validation to `Copy-WslDistro` in `tools/pslib/wsl/wsl.ps1`
  - Locate `Copy-WslDistro` function (approximately line 830-930)
  - After source distribution existence check
  - Add state check: `if (Test-WslDistroRunning -Name $SourceName) { throw "Distribution '$SourceName' is running. Stop it first with: wsl --terminate $SourceName" }`
  - Ensure error is thrown BEFORE export operation
  - Run test from T021, confirm it now PASSES

- [ ] T025 [Item3] Add state validation to `Remove-WslDistro` in `tools/pslib/wsl/wsl.ps1`
  - Locate `Remove-WslDistro` function (approximately line 764-828)
  - After distribution existence check (around line 779-781)
  - Add state check: `if (Test-WslDistroRunning -Name $Name) { throw "Distribution '$Name' is running. Stop it first with: wsl --terminate $Name" }`
  - Ensure error is thrown BEFORE unregister operation
  - Run test from T022, confirm it now PASSES

### Integration Tests for Work Item #3 (MANDATORY - TDD)

- [ ] T026 [Item3] Add integration test for state validation in `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
  - Create and start a test WSL distribution
  - Attempt to update while running → verify error message
  - Attempt to clone while running → verify error message
  - Attempt to remove while running → verify error message
  - Terminate distribution
  - Verify operations succeed after termination
  - Clean up test distribution
  - Run: `pwsh -File ".\test\bin\test.ps1" -Integration`

**Checkpoint**: State validation is complete. All operations correctly enforce stopped state requirement.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and documentation updates

- [ ] T027 [P] Run full unit test suite with coverage: `pwsh -File ".\test\bin\test.ps1" -Unit -Coverage`
- [ ] T028 [P] Run full integration test suite: `pwsh -File ".\test\bin\test.ps1" -Integration`
- [ ] T029 [P] Run linter checks: `pwsh -File ".\test\bin\linter.Tests.ps1"`
- [ ] T030 Verify PowerShell 5.1 compatibility: `powershell -File ".\test\bin\test.ps1"`
- [ ] T031 Update `specs/001-wsl-manager/quickstart.md` with terminate command examples
- [ ] T032 Update CLI interface contract `specs/001-wsl-manager/contracts/cli-interface.md` to mark terminate as implemented
- [ ] T033 Verify all acceptance criteria from spec.md are met for implemented user stories
- [ ] T034 Run manual smoke test: Create → Setup User → Terminate → Clone → Update → Remove workflow

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - verify environment ready
- **Work Item #4 (Phase 2)**: Can start immediately after Setup - Independent
- **Work Item #1 (Phase 3)**: Can start immediately after Setup - Independent
- **Work Item #3 (Phase 4)**: DEPENDS on Work Item #1 (needs `Test-WslDistroRunning` function)
- **Polish (Phase 5)**: Depends on all work items being complete

### Work Item Dependencies

- **Work Item #4 (NOPASSWD Warning)**: No dependencies - Can start immediately
- **Work Item #1 (Terminate Distribution)**: No dependencies - Can start immediately
- **Work Item #3 (State Validation)**: REQUIRES Work Item #1 complete first

### Within Each Work Item

- **TDD REQUIREMENT**: Tests MUST be written and FAIL before implementation
- Helper functions before callers (Get-WslDistroState → Test-WslDistroRunning → Stop-WslDistro)
- Library functions before manager integration
- Unit tests before integration tests
- All tests must pass before moving to next work item

### Parallel Opportunities

- **Phase 1 (Setup)**: All tasks marked [P] can run in parallel (T001-T004)
- **Work Items #1 and #4**: Can be worked on in parallel by different developers (no dependencies)
- **Within Work Item #1**:
  - T008, T009, T010 (test writing) can run in parallel
  - T014 (manager test) can be written in parallel with helper function tests
- **Within Work Item #3**:
  - T020, T021, T022 (test writing) can run in parallel
- **Phase 5 (Polish)**:
  - T027, T028, T029 (different test suites) can run in parallel
  - T031, T032 (documentation) can run in parallel

---

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
3. Complete Work Item #1: Terminate Distribution (T008-T019) - 2-3 hours
4. Complete Work Item #3: State Validation (T020-T026) - 2-3 hours
5. Complete Phase 5: Polish (T027-T034)
6. **TOTAL ESTIMATED TIME**: 5-7 hours

### Parallel Team Strategy

With 2 developers:

1. Both complete Phase 1: Setup together
2. Split work items:
   - **Developer A**: Work Item #1 (Terminate) - 2-3 hours
   - **Developer B**: Work Item #4 (NOPASSWD Warning) - 30 minutes, then start Work Item #3 test writing
3. After Developer A completes Work Item #1:
   - **Developer B** can complete Work Item #3 implementation (depends on #1)
4. Both complete Phase 5: Polish together

### Validation Checkpoints

- After each work item: Run full test suite (`pwsh -File ".\test\bin\test.ps1"`)
- After Work Item #1: Test terminate command manually
- After Work Item #3: Test clone/remove/update with running distribution
- Before final commit: Run both PowerShell 5.1 and 7.x test suites

---

## Notes

- **[P] tasks**: Different files or test sections, no dependencies, can run in parallel
- **[Item] label**: Maps task to specific work item from plan.md for traceability
- **TDD is NON-NEGOTIABLE**: Constitution Principle I - tests MUST be written before implementation
- **All tests must pass**: Before committing, run full test suite on both PowerShell versions
- **Commit strategy**: Commit after each work item completes with all tests passing
- **Constitutional compliance**: This implementation follows all 7 constitutional principles
- **Phase 2 (Docker Refactoring)**: Deferred - will be added after bash script design complete

---

## Deferred Work (Phase 2)

**Work Item #2 - Docker Setup Refactoring** is intentionally excluded from this tasks file. It requires:

1. Bash script design (`tools/pslib/wsl/scripts/install-docker.sh`)
2. Script transfer pattern specification
3. Exit code mapping table
4. Additional design time: 15-30 minutes

After design artifacts are complete, run `/speckit.tasks` again to generate Phase 2 tasks for Docker refactoring.
