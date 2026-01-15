# Research: WSL Manager

**Feature Branch**: `001-wsl-manager`
**Date**: 2026-01-13
**Phase**: 0 - Design Research

## Overview

This document captures key design decisions, architectural patterns, and research findings for the WSL Manager implementation. The WSL Manager builds upon an existing mature implementation in `tools/pslib/wsl/` with 28 functions covering distribution management, user accounts, Docker setup, and interactive workflows.

## Architecture & Design Decisions

### Decision 1: Library-First Architecture

**Decision**: Implement all reusable WSL management functionality as library functions in `tools/pslib/wsl/`, with the interactive manager tool (`wsl-manager.ps1`) building on these library functions.

**Rationale**:
- Promotes code reusability across multiple scripts and tools
- Enables independent testing of core functionality
- Separates business logic (library functions) from user interface (manager tool)
- Follows established project pattern: `tools/pslib/utils/utils.ps1` and `tools/pslib/wsl/wsl.ps1`
- Ensures each function has a clear, documented purpose (not organizational-only libraries)

**Alternatives Considered**:
- **Monolithic script**: All functionality in `wsl-manager.ps1`
  - **Rejected**: Would duplicate code when other scripts need WSL functionality (e.g., test fixtures, bootstrap scripts)
  - **Rejected**: Harder to test in isolation, violates DRY principle
- **Separate modules with manifests**: PowerShell module structure with `.psd1` manifests
  - **Rejected**: Adds complexity for a single-project tool, module loading overhead
  - **Rejected**: Project already uses simple dot-sourcing pattern successfully

### Decision 2: Fail-Fast Error Handling with Safe State Preservation

**Decision**: Implement fail-fast error handling that validates all prerequisites upfront, fails immediately on errors, and leaves the system in a safe state.

**Rationale**:
- Prevents cascading failures from continuing after an error occurs
- Provides clear, actionable error messages at the point of failure
- Avoids partial state changes that require manual cleanup
- Aligns with user expectation (from clarifications): "Fail immediately, prompt user to retry, and leave system in safe state"
- Uses PowerShell best practices: `Set-StrictMode -Version Latest`, `$ErrorActionPreference = "Stop"`

**Alternatives Considered**:
- **Automatic retry logic**: Retry failed operations automatically
  - **Rejected**: User explicitly requested manual retry with prompts
  - **Rejected**: Automatic retries can mask underlying issues (network failures, permission problems)
- **Rollback mechanisms**: Undo partial changes on failure
  - **Rejected**: WSL operations are atomic (wsl.exe handles this internally)
  - **Rejected**: Adds significant complexity for edge cases that WSL already handles
- **Continue on error**: Log errors and continue operations
  - **Rejected**: Can leave distributions in inconsistent states
  - **Rejected**: Violates fail-fast principle from constitution

### Decision 3: Pattern-Based (Not Position-Based) WSL Output Parsing

**Decision**: Parse `wsl.exe` output using regex pattern matching and keyword detection, not fixed column positions.

**Rationale**:
- Supports localized WSL output (German, French, etc.) where column headers change
- Resilient to formatting changes in WSL output across Windows versions
- Handles variable-width distribution names and whitespace
- Already proven effective in existing implementation for 9 different languages

**Pattern Examples**:
```powershell
# Distribution name validation
^([A-Za-z0-9][A-Za-z0-9_.-]*)

# Header detection (skip lines)
NAME|FRIENDLY|INSTALL|STATE|VERSION

# UTF-16 cleaning
$_.Trim() -replace '\x00', '' -replace '\r', ''
```

**Alternatives Considered**:
- **Position-based parsing**: Parse output by column positions
  - **Rejected**: Breaks on localized output where column widths differ
  - **Rejected**: Fragile to minor formatting changes in WSL
- **JSON output**: Request JSON from wsl.exe
  - **Rejected**: wsl.exe does not support JSON output format
- **Windows API calls**: Use Windows internals directly
  - **Rejected**: Not accessible from PowerShell without P/Invoke
  - **Rejected**: Undocumented, may break across Windows versions

### Decision 4: Dual-Mode Support (Interactive + CI/Non-Interactive)

**Decision**: Support both interactive user-driven workflows and non-interactive CI/automation workflows using environment detection via `Test-RunningInCIorTestEnvironment`.

**Rationale**:
- Interactive mode provides best developer experience with discoverability
- CI mode enables automated testing and deployment pipelines
- Single codebase supports both modes without duplication
- Detection is automatic and reliable (checks CI env vars, Pester context, call stack)
- Aligns with constitution Principle V: Environment Awareness

**Implementation Pattern**:
```powershell
if (Test-RunningInCIorTestEnvironment) {
    # Non-interactive: Use parameters, skip prompts
    $confirm = $true
} else {
    # Interactive: Prompt user, show menus
    $confirm = Read-Host "Proceed? (y/n)"
}
```

**Alternatives Considered**:
- **Separate scripts**: `wsl-manager.ps1` (interactive) and `wsl-manager-ci.ps1` (non-interactive)
  - **Rejected**: Code duplication, maintenance burden
  - **Rejected**: Users confused about which script to use
- **Force mode flag**: `-Force` parameter to skip prompts
  - **Rejected**: Easy to accidentally skip important confirmations
  - **Rejected**: Requires users to remember to add -Force in CI
- **Always prompt**: No CI mode
  - **Rejected**: Blocks automated pipelines requiring user input
  - **Rejected**: Violates constitution requirement for CI support

### Decision 5: PowerShell 5.1 Compatibility (No PS 6.0+ Features)

**Decision**: Use only PowerShell 5.1-compatible syntax and features, avoiding PowerShell 6.0+ exclusive features.

**Rationale**:
- Windows 10 ships with PowerShell 5.1 by default
- Ensures compatibility across all Windows environments
- Enables testing on both Windows PowerShell 5.1 and PowerShell 7.x
- Aligns with constitution Principle III: PowerShell Standards
- Quality gate requires tests passing on both PS 5.1 and PS 7.x

**Avoided Features**:
- Ternary operator (`? :`) - Use `if/else` instead
- Null-coalescing (`??`) - Use `if ([string]::IsNullOrWhiteSpace(...))` instead
- `ErrorMessage` in `ValidateScript` - Use custom error handling
- Pipeline chain operators (`&&`, `||`) - Use sequential commands

**Alternatives Considered**:
- **Require PowerShell 7.x**: Use modern PowerShell features
  - **Rejected**: Forces users to install PS 7.x manually
  - **Rejected**: Breaks on systems with only Windows PowerShell 5.1
- **Conditional feature detection**: Use PS 7.x features when available
  - **Rejected**: Creates two code paths with different behavior
  - **Rejected**: Harder to test and maintain
- **Polyfills**: Implement PS 7.x features for PS 5.1
  - **Rejected**: Unnecessary complexity for minimal syntax improvements
  - **Rejected**: Codebase already handles PS 5.1 syntax well

### Decision 6: Test-First Development (TDD) with Pester

**Decision**: Write Pester tests BEFORE implementation, with separate unit tests (`*.Tests.ps1`) and integration tests (`*.Integration.Tests.ps1`).

**Rationale**:
- Ensures all code is testable by design
- Prevents regressions when modifying existing functions
- Tests serve as executable documentation
- Aligns with constitution Principle I: Test-First Development (NON-NEGOTIABLE)
- Existing implementation has comprehensive test coverage (28 functions, all tested)

**Test Strategy**:
```text
Unit Tests (*.Tests.ps1):
- Mock external dependencies (wsl.exe, file system)
- Test both success and failure paths
- Test CI and interactive modes separately
- Fast execution (<5 seconds for all unit tests)

Integration Tests (*.Integration.Tests.ps1):
- Use real WSL distributions
- Test actual workflows (create → update → clone → setup)
- Preserve test artifacts for manual exploration
- Tagged with -Tag "Integration" for filtering
```

**Alternatives Considered**:
- **Manual testing only**: Test by running commands manually
  - **Rejected**: Time-consuming, not repeatable, misses edge cases
  - **Rejected**: No regression detection when modifying code
- **Integration tests only**: Skip unit tests, only test against real WSL
  - **Rejected**: Slow feedback loop (minutes vs. seconds)
  - **Rejected**: Can't test error paths without breaking real distributions
- **Test after implementation**: Write tests after code works
  - **Rejected**: Violates constitution (NON-NEGOTIABLE)
  - **Rejected**: Creates untestable code (tight coupling, no mocking)

### Decision 7: Interactive Menu as Default Entry Point

**Decision**: Launch interactive menu when `wsl-manager.ps1` is run without arguments, providing command discovery without documentation.

**Rationale**:
- Reduces cognitive load - users don't need to memorize command syntax
- Enables discoverability of available commands
- Provides guided workflows with distribution listing and selection
- Aligns with User Story 9: Interactive Mode (Priority P1)
- Skips menu in CI environments with helpful message

**Menu Structure**:
```text
=== Installed WSL Distributions ===
1. Debian
2. Ubuntu-22.04

Available commands:
  [I] Install new distribution
  [C] Clone existing distribution
  [U] Update distribution packages
  [S] Setup user account
  [D] Setup Docker Engine
  [R] Remove distribution
  [Q] Quit

Enter your choice:
```

**Alternatives Considered**:
- **Command-line only**: Require all operations via command-line arguments
  - **Rejected**: High barrier to entry, requires documentation
  - **Rejected**: Poor discoverability of available commands
- **Wizard-style prompts**: Step-by-step prompts for each operation
  - **Rejected**: Too verbose, wastes time for experienced users
  - **Rejected**: Hard to navigate back if user makes a mistake
- **TUI framework**: Use terminal UI library (e.g., Spectre.Console)
  - **Rejected**: External dependency, increases complexity
  - **Rejected**: PowerShell native `Read-Host` is sufficient

### Decision 8: Bash Command Composition for WSL Operations

**Decision**: Execute commands inside WSL distributions using `Invoke-WslDistroCommand` with proper bash variable escaping and command composition.

**Rationale**:
- Enables complex multi-step operations in a single WSL invocation
- Reduces overhead from multiple `wsl.exe` launches
- Supports bash variable usage and command chaining
- Handles escaping PowerShell → bash boundary correctly

**Escaping Strategy**:
```powershell
# Dollar signs escaped for bash variables
$command = "echo `$HOME && whoami"

# Single quotes around bash content to prevent PowerShell interpretation
$command = "echo 'username:password' | chpasswd"

# Command composition with && for sequential operations
$command = "useradd -m -s /bin/bash user && usermod -aG sudo user"
```

**Alternatives Considered**:
- **Multiple wsl.exe invocations**: Run each command separately
  - **Rejected**: Slower due to WSL startup overhead per command
  - **Rejected**: State not preserved between invocations
- **Heredoc scripts**: Create temporary bash scripts and execute
  - **Rejected**: Filesystem clutter, requires cleanup
  - **Rejected**: Harder to debug when commands fail
- **PowerShell remoting**: Use Enter-PSSession for WSL
  - **Rejected**: Not supported for WSL distributions
  - **Rejected**: Requires PowerShell inside Linux distribution

### Decision 9: ShouldProcess Support for Destructive Operations

**Decision**: Use `[CmdletBinding(SupportsShouldProcess)]` for destructive operations (remove, clone) with high impact.

**Rationale**:
- Provides PowerShell-native confirmation prompts
- Supports `-WhatIf` for previewing changes without execution
- Supports `-Confirm:$false` for non-interactive automation
- Follows PowerShell best practices for cmdlet design
- Aligns with User Story 4: "confirmation required in interactive mode"

**Impact Levels**:
```powershell
# High impact: Remove distribution (data loss)
$PSCmdlet.ShouldProcess($Name, "Remove WSL distribution")

# Medium impact: Clone distribution (disk space)
$PSCmdlet.ShouldProcess($SourceName, "Clone WSL distribution to $TargetName")

# Low impact: Create, update (no data loss)
# No ShouldProcess needed
```

**Alternatives Considered**:
- **Custom confirmation prompts**: `Read-Host "Are you sure? (y/n)"`
  - **Rejected**: Doesn't support `-WhatIf` or `-Confirm` parameters
  - **Rejected**: Not idiomatic PowerShell
- **No confirmation**: Always execute
  - **Rejected**: Dangerous for destructive operations
  - **Rejected**: Violates user expectations (SC-010)
- **Always prompt**: Prompt even with `-Confirm:$false`
  - **Rejected**: Blocks non-interactive automation

## Best Practices Research

### WSL Management Best Practices

**Distribution Lifecycle:**
1. **Creation**: Use `wsl --install -d <name>` for Microsoft Store distributions
2. **Cloning**: Export → Import workflow with tar files
3. **Cleanup**: Always remove temporary tar files in `finally` blocks
4. **State Management**: Check if distribution is running before termination-required operations

**Systemd Handling:**
- Check if systemd is configured: Parse `/etc/wsl.conf` for `[boot] systemd=true`
- Check if systemd is running: Execute `systemctl --version` inside distribution
- Warmup fresh distributions: Run `echo warmup` before accessing files (ensures WSL is ready)

**User Account Best Practices:**
- Validate usernames: `^[a-z_][a-z0-9_-]*$` (lowercase, start with letter or underscore, max 32 chars)
- Always create home directory: `useradd -m -s /bin/bash`
- Set as default user: Configure `/etc/wsl.conf` [user] section
- Restart distribution after user config: `wsl --terminate <name>`
- Security warning: Display NOPASSWD sudo implications for development environments

**Docker Installation Best Practices:**
- Prerequisite validation: WSL2, systemd configured and running, Debian/Ubuntu, default user exists
- GPG key verification: Download and verify Docker GPG key
- Repository setup: Add Docker apt repository
- Service management: Enable and start via systemd
- Post-installation verification: Check version, service status, run hello-world test
- User permissions: Add default user to docker group

### PowerShell Testing Patterns with Pester

**Mocking External Commands:**
```powershell
# Mock wsl.exe with parameter filtering
Mock wsl {
    @("Debian", "Ubuntu-22.04")
} -ParameterFilter { $args -contains "--list" -and $args -contains "--quiet" }

# Mock command failures
Mock Invoke-CommandLine {
    $global:LASTEXITCODE = 1
    throw "Command failed"
} -ParameterFilter { $Command -match "invalid" }
```

**Parameterized Tests:**
```powershell
It "Should handle <Scenario>" -ForEach @(
    @{ Input = "valid"; Expected = $true; Scenario = "valid input" }
    @{ Input = "invalid"; Expected = $false; Scenario = "invalid input" }
) {
    Test-Function -Input $Input | Should -Be $Expected
}
```

**Testing Interactive vs CI Modes:**
```powershell
Context "When running in CI environment" {
    BeforeAll {
        $env:CI = "true"
    }
    AfterAll {
        Remove-Item env:CI
    }

    It "Should skip interactive prompts" {
        # Test non-interactive behavior
    }
}
```

### Localization Handling for WSL Output

**Challenge**: `wsl.exe` output is localized based on Windows display language, changing column headers and error messages.

**Solution**: Pattern-based parsing with keyword detection
```powershell
# Detect headers by keyword (works in German, English, French, etc.)
$isHeader = $line -match 'NAME|FRIENDLY|INSTALL|STATE|VERSION|NOM|NOMBRE'

# Extract data by pattern, not position
if ($line -match '^([A-Za-z0-9][A-Za-z0-9_.-]*)\s+(\w+)\s+(\d+)') {
    $name = $matches[1]
    $state = $matches[2]  # Running/Stopped (localized)
    $version = $matches[3]  # 1 or 2
}
```

**Character Encoding**: Always clean UTF-16 null bytes and carriage returns
```powershell
$line = $line.Trim() -replace '\x00', '' -replace '\r', ''
```

## Implementation Priorities

Based on existing code analysis and user story priorities:

### Already Implemented (Mature)
1. ✅ List and view distributions (P1) - `Get-WslDistroList`, `Show-WslDistroList`
2. ✅ Create new distribution (P2) - `New-WslDistro`, `Invoke-CreateDistro`
3. ✅ Clone existing distribution (P3) - `Copy-WslDistro`, `Invoke-CloneDistro`
4. ✅ Remove distribution (P4) - `Remove-WslDistro`, `Invoke-RemoveDistro`
5. ✅ Update packages (P6) - `Update-WslDistro`, `Invoke-UpdateDistro`
6. ✅ Setup user account (P7) - `New-WslUser`, `Invoke-SetupUser`
7. ✅ Setup Docker Engine (P8) - `Install-WslDockerEngine`, `Invoke-SetupDocker`
8. ✅ Interactive mode (P1) - `Show-InteractiveMenu`, `Invoke-WslManager`

### Needs Implementation
1. ⚠️ Terminate running distribution (P5) - Partially implemented via `wsl --terminate` in error messages, needs dedicated command
2. ⚠️ Running state detection - Need `Test-WslDistroRunning` function
3. ⚠️ Pre-operation state validation - Need to check distribution state before clone/remove/update operations

### Enhancement Opportunities
1. Security warning for NOPASSWD sudo (FR-029) - Need to add warning display during user creation
2. Comprehensive error messages for running distributions (FR-030) - Standardize across clone/remove/update operations

## Research Findings Summary

| Research Area | Finding | Impact |
|---|---|---|
| Architecture | Library-first with manager tool | Enables reusability, independent testing |
| Error Handling | Fail-fast with safe state | Prevents cascading failures, clear user feedback |
| WSL Parsing | Pattern-based (not position) | Supports localization, resilient to format changes |
| Environment Support | Dual-mode (interactive + CI) | Works in automation and manual workflows |
| Compatibility | PowerShell 5.1+ syntax only | Broad compatibility, testable on PS 5.1 and 7.x |
| Testing | TDD with Pester (unit + integration) | Ensures correctness, prevents regressions |
| User Experience | Interactive menu as default | Low barrier to entry, command discoverability |
| Bash Integration | Proper escaping and composition | Reliable command execution inside distributions |
| Destructive Operations | ShouldProcess support | PowerShell-native confirmation, supports -WhatIf |

## Open Questions (Resolved via Clarifications)

All questions from spec.md clarifications section (Session 2026-01-12) have been incorporated into design decisions:

1. ✅ Long-running operation failures → Fail immediately, safe state, prompt retry
2. ✅ Clone preservation → Everything preserved (filesystem, users, Docker, configs)
3. ✅ Operational logs → Use PowerShell transcript (Start-Transcript)
4. ✅ NOPASSWD sudo warning → Display brief warning during user creation
5. ✅ Running distribution operations → Require stopped state, fail with termination command

## Next Steps (Phase 1)

With research complete, proceed to Phase 1:
1. Generate `data-model.md` - Define entities and state transitions
2. Generate `contracts/cli-interface.md` - Document CLI commands, parameters, outputs
3. Generate `quickstart.md` - Create getting started guide
4. Update agent context - Add WSL Manager to agent-specific context files
5. Re-evaluate Constitution Check - Verify design compliance
