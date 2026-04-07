# Agent Instructions for Shortcuts

## Overview

This document provides technical guidelines for AI agents working on the Shortcuts project. For user-facing documentation, see @README.md.

## Project Architecture

**Shortcuts** is a Windows automation project that provides CLI tools, shortcuts, and system utilities accessible through the Keypirinha launcher.

### Technical Stack

- **Language**: PowerShell 7.4+ (bootstrap scripts remain PS 5.1-compatible)
- **Package Manager**: Scoop (for Windows tools)
- **Launcher Integration**: Keypirinha (fast keyboard-driven launcher)
- **Testing**: Pester 5.7.1+
- **Linting**: PSScriptAnalyzer 1.24.0+

### Directory Structure

- `bin/`: Installation and update scripts
- `config/`: Configuration files
- `lib/`: Shared PowerShell library (reusable functions)
  - `utils/`: Utility functions (`utils.ps1`)
  - `wsl/`: WSL-specific functions (`wsl.ps1`, etc.)
  - `install/`: Installation utilities
- `tools/`: Tool-specific utilities and installers
  - `wsl-manager/`: WSL Manager entry point and integration tests
- `links/`: Keypirinha link definitions (.url files)
- `test/`: Test files and test utilities
- `.bootstrap/`: Bootstrap system for initial setup

#### PowerShell Script Wrapper Convention

**Executable PowerShell scripts should have a `.bat` wrapper in the same directory.**

This allows scripts to be executed directly from the command line or Keypirinha without requiring the full `pwsh -File` syntax.

**Example:**

```text
tools/wsl-manager/
├── wsl-manager.ps1      # The actual PowerShell script
└── wsl-manager.bat      # Wrapper that calls: pwsh -ExecutionPolicy Bypass -File %~dp0wsl-manager.ps1 %*
```

**Benefits:**

- Users can run `wsl-manager` instead of `pwsh -File path/to/wsl-manager.ps1`
- Batch wrapper handles PowerShell execution policy
- Arguments are passed through automatically via `%*`
- Consistent user experience across all executable scripts

## Documentation Hierarchy

- Each tool gets one doc (e.g., `wsl-manager.md`). Supported workflows like DevContainer setup belong as a section within the tool's doc, not as standalone guides.
- **Don't let a feature outgrow its tool** - DevContainer support is a feature of WSL Manager, not a separate product.

### Writing Style

- **No em-dashes** (`—`) in any `.md` file. Use a colon (`:`) to introduce explanations, a semicolon (`;`) to join independent clauses, or a normal dash (`-`) for asides and parenthetical remarks.

## Backlog Lifecycle

When starting work on a backlog item, update its status to **In Progress** and move it in the README index before committing implementation changes. When a subtask or the full item is completed, update status accordingly per the closing checklist in `docs/backlog/README.md`. Backlog updates are part of the implementation commit, not a separate afterthought.

## Coding Guidelines

- TDD
- DRY
- SOLID
- boundary checks
- equivalence classes
- error handling
- parametrized tests
- test fixtures
- mocking external dependencies
- conventional commits

### Linting Suppression Policy

**Never suppress these rules; fix the code instead:**
- `PSReviewUnusedParameter`: make the parameter actually used, or remove it.
- `PSUseSingularNouns`: rename the function to use a singular noun (PowerShell convention: `Verb-SingularNoun`).

### No Speculative Alternatives

**Issue**: Building alternative/fallback approaches that weren't requested.

**Guideline**: Implement exactly what was requested. Do NOT create "alternative approaches", "backward compatibility" paths, or "optional fallback" mechanisms unless the user explicitly asks for them. One clean solution is better than two competing ones.

**Anti-pattern**:
```
# DON'T: Build two competing approaches "in case the user prefers one"
# DON'T: Create a migration path from an approach that was never shipped
```

**When to apply**: Always. If you think an alternative approach might be useful, mention it in conversation instead of building it.

## PowerShell Implementation Guidelines

### Core Principles

When working with PowerShell code in this project, follow these guidelines:

#### 1. Use Existing Library Functions

**Before writing any new code, ALWAYS check `lib/` for existing utilities.**

To discover available functions:

1. **Read the library files** in `lib/utils/` and `lib/wsl/` (e.g., `utils.ps1`, `wsl.ps1`)
2. **Check function documentation** - Each function has synopsis and examples
3. **Look at test files** (`*.Tests.ps1`) to see usage patterns
4. **Use Get-Help** after sourcing the library: `Get-Help Invoke-CommandLine -Full`

**Key utilities include:**

- External command execution (use `Invoke-CommandLine`)
- File/directory operations (check before reimplementing)
- User interaction in CI/interactive contexts
- WSL management functions

**Example:**

```powershell
# Source the library
. "$PSScriptRoot\lib\utils\utils.ps1"

# Use library functions
Invoke-CommandLine -Command "scoop install nodejs" -StopAtError
New-Directory -Path "C:\Tools\MyApp"
```

> **Important:** If you need functionality that seems common (file operations, command execution, user prompts), it likely already exists in lib/. Check first!

#### 2. Error Handling

Always implement robust error handling with:

- `Set-StrictMode -Version Latest`
- `$ErrorActionPreference = "Stop"`
- `$InformationPreference = "Continue"`
- Try/catch blocks for main logic

See "Script Structure" section below for the complete template.

#### 3. File Encoding

**All `.ps1` files must be saved as UTF-8 with BOM** (Byte Order Mark).

PSScriptAnalyzer enforces `PSUseBOMForUnicodeEncodedFile`; any `.ps1` file containing non-ASCII characters (e.g., em dashes, accented letters, Unicode symbols) without a UTF-8 BOM will fail linting. To avoid issues, **always save `.ps1` files with BOM**, regardless of whether they currently contain non-ASCII characters.

This applies only to `.ps1` files. Other file types (`.sh`, `.yml`, `.json`, `.md`, `.bat`) should remain UTF-8 without BOM, as BOM can cause problems in those formats.

#### 4. Environment Awareness

Scripts must work in both interactive and CI environments using `Test-RunningInCIorTestEnvironment` from `lib/utils/utils.ps1`:

```powershell
if (Test-RunningInCIorTestEnvironment) {
    # Non-interactive path
    $confirm = $true
} else {
    # Interactive path
    $confirm = Get-UserConfirmation "Proceed with installation?"
}
```

**CI/Test Detection:** This function automatically detects:

- CI environment variables (`CI`, `GITHUB_ACTIONS`, etc.)
- Pester test context (via `PesterPreference` or call stack)

**Manual Testing:** Set `CI=true` to simulate non-interactive behavior when manually testing interactive scripts. DO NOT set `CI` when running the Pester test suite - the test framework handles this automatically.

#### 5. Path Handling

Use proper path resolution and validation:

```powershell
# Resolve relative paths
$scriptRoot = $PSScriptRoot
$targetPath = Join-Path $scriptRoot "config\settings.json"

# Validate existence
if (-not (Test-Path $targetPath)) {
    Write-Error "Required file not found: $targetPath"
    exit 1
}
```

#### 6. Output and Logging

Provide clear, user-friendly output:

```powershell
function Write-Status {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Usage
Write-Status "Installing Node.js..."
Write-Success "Installation complete"
```

#### 7. External Commands

**Always use `Invoke-CommandLine` from lib for executing external commands.** This ensures consistent error handling and proper output capture.

```powershell
# Source the library first
. "$PSScriptRoot\lib\utils\utils.ps1"

# Check if command exists
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Error "Scoop is not installed"
    exit 1
}

# Execute with Invoke-CommandLine
Invoke-CommandLine -Command "scoop list" -StopAtError

# For commands that may fail gracefully
$result = Invoke-CommandLine -Command "scoop list nodejs"
if (-not $result) {
    Write-Information "nodejs not installed, proceeding with installation"
}
```

**Key benefits of using `Invoke-CommandLine`:**

- Consistent error handling across all scripts
- Proper exit code checking
- Standardized output capture
- Integration with CI/test environments

#### 8. PowerShell Command Execution from Bash

**Issue**: Mixing Bash and PowerShell pipelines causes errors.

**Guideline**: NEVER pipe PowerShell output to PowerShell cmdlets through Bash.

**Anti-pattern** (what NOT to do):
```bash
# DON'T: This fails because Select-String is not a Bash command
powershell -File script.ps1 | Select-String -Pattern "foo"

# DON'T: This also fails
pwsh -Command "Get-Content file.txt" | Select-String "pattern"
```

**Correct patterns**:

```bash
# Option 1: Keep everything in PowerShell
pwsh -Command "powershell -File script.ps1 | Select-String -Pattern 'foo'"

# Option 2: Use Bash-native tools
powershell -File script.ps1 | grep "foo"

# Option 3: Use Read tool to read PowerShell output, then process
# (Preferred for AI agents - saves output to file first)
```

**When to use each**:
- **Option 1**: When you need PowerShell cmdlet features (objects, -Context, etc.)
- **Option 2**: When simple text matching is sufficient
- **Option 3**: When processing large outputs or need to reference multiple times

#### 9. Script Structure

**IMPORTANT: Set-StrictMode in Dot-Sourced Files**

- **Standalone executable scripts** (e.g., `install.ps1`, `wsl-manager.ps1`): **Use `Set-StrictMode -Version Latest`**
- **Dot-sourced library files** (e.g., `utils.ps1`, `wsl.ps1`, `setProxy.ps1`): **DO NOT use `Set-StrictMode`**

**Reason**: When a script is dot-sourced (`. .\script.ps1`), `Set-StrictMode` persists in the caller's scope and affects all subsequent code in that PowerShell session. This can break other scripts that weren't written to handle strict mode, especially when sourced into PowerShell profiles.

**Standalone Executable Script Structure:**

```powershell
#Requires -Version 7.4

<#
.SYNOPSIS
    Brief description

.DESCRIPTION
    Detailed description

.EXAMPLE
    .\script.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Option = "default"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Source dependencies
. "$PSScriptRoot\lib\utils\utils.ps1"

# Helper functions
function Private-Helper {
    # Implementation
}

# Main logic
try {
    # Implementation
} catch {
    Write-Error "Error: $_"
    exit 1
}
```

**Dot-Sourced Library File Structure:**

```powershell
#Requires -Version 7.4

<#
.DESCRIPTION
    Utility functions for common tasks.
    This file is meant to be dot-sourced into other scripts.
#>

# DO NOT use Set-StrictMode in dot-sourced files
$InformationPreference = 'Continue'  # Optional, for logging
$ErrorActionPreference = 'Stop'

function Public-Function {
    <#
    .SYNOPSIS
        Brief description
    #>
    [CmdletBinding()]
    param()

    # Implementation
}
```
```

### Testing Requirements

All PowerShell code must include **Pester tests**.

**For comprehensive Pester test execution guidance, use the `powershell-test-exec` skill** (`.claude/skills/powershell-test-exec/`).

The skill covers:

- Running unit tests (`-Unit`), integration tests (`-Integration`), and coverage (`-Coverage`)
- PowerShell 7.4+ test execution
- AI agent patterns for calling PowerShell from Bash
- GitHub Actions CI/CD patterns
- TDD workflow and pre-commit checks

#### Quick Reference

```bash
# Unit tests (fast feedback)
pwsh -File ".\test\bin\testrunner.ps1" -Unit

# Integration tests
pwsh -File ".\test\bin\testrunner.ps1" -Integration

# All tests with coverage
pwsh -File ".\test\bin\testrunner.ps1" -Coverage

# Bootstrap script (PS 5.1 only - install.ps1 and .bootstrap/ scripts)
powershell -File ".\bin\install.ps1"
```

**Test types:**

- `*.Tests.ps1` - Unit tests (mocked dependencies)
- `*.Integration.Tests.ps1` - Integration tests (real systems)

**Testing requirements:**

- Mock external dependencies
- Test both success and failure paths
- Ensure tests pass on PowerShell 7.4+

**Never mock `Test-RunningInCIorTestEnvironment` in integration tests.**
This function exists to prevent interactive prompts (`Read-Host`) in CI/test environments.
Mocking it to `$false` in integration tests would trigger real `Read-Host` calls that hang CI.
In **unit tests**, mocking it is allowed and encouraged to cover both CI and interactive code paths.

**Cross-file test isolation (MANDATORY):**
Pester runs all test files in the same PowerShell process. Functions loaded via dot-sourcing
persist across files and cause flaky, order-dependent failures. Every test file that
dot-sources a library **must** use `Start-SutIsolation`/`Stop-SutIsolation` from `test/bin/lib/TestIsolation.ps1`:

```powershell
BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\module.ps1"
}

AfterAll {
    Stop-SutIsolation
}
```

See `lib/AGENTS.md` for additional testing guidelines

### Project-Specific Considerations

#### Directory Structure

- `bin/`: Installation and update scripts
- `config/`: Configuration files
- `lib/`: Shared PowerShell library
- `tools/`: Tool-specific utilities and installers
- `links/`: Keypirinha link definitions
- `test/`: Test files and test utilities

#### Scoop Integration

This project heavily uses Scoop for package management:

- Check for Scoop before using it
- Use `scoop install`, `scoop update`, `scoop list`
- Reference `scoopfile.json` for managed packages
- Use `Invoke-CommandLine` for all Scoop commands (see "External Commands" section)

#### Keypirinha Integration

Scripts that add/modify shortcuts should remind users to refresh the Keypirinha catalog:

```powershell
Write-Host "Remember to refresh Keypirinha catalog (see README.md for details)" -ForegroundColor Yellow
```

#### Bootstrap System

The project uses a `.bootstrap` system (see `.bootstrap/` directory):

- Handles initial setup
- Manages dependencies
- Keep bootstrap scripts independent from main tools

### Workflow

#### CI and Branch Hygiene

**Context**: This project uses GitHub Actions CI. The `develop` branch is always green.

**CRITICAL: There are no pre-existing test failures. Ever.** CI ensures `develop` is always green. Feature branches are created from `develop`. Therefore, any failure on a feature branch was introduced by that branch; no exceptions.

**You MUST NOT:**
- Dismiss failures as "pre-existing" or "unrelated to my changes"
- Skip failing tests or proceed to commit with uninvestigated failures
- Assume that tests in files you didn't directly modify can't be affected by your changes

**You MUST:**
- Investigate every failure - even in files you didn't touch
- If uncertain whether your changes caused it, flag it to the user - never silently skip
- Fix the issue before proceeding

**Investigation steps**:
1. `git diff develop..HEAD`: review ALL changes on the branch
2. Analyze if ANY change (even cosmetic ones like string formatting) could affect tests
3. If uncertain, use `git bisect` to identify the breaking commit

**Anti-pattern**:
```bash
# DON'T: Assume failures are unrelated
"These test failures are pre-existing, not caused by my bullet point change"
```

**Correct pattern**:
```bash
# DO: Investigate if your changes could be the cause
git diff develop..HEAD  # Review ALL changes
git log develop..HEAD   # Review ALL commits on branch
# Even cosmetic changes to test files can break things
```

#### GitHub Actions Shell

The CI workflow no longer uses a matrix (only one shell: `pwsh`). Steps use `shell: pwsh` directly, except the "Remote install" step which uses `shell: powershell` to simulate a fresh machine running `install.ps1` under Windows PowerShell 5.1.

#### CI Environment: Never Assume, Always Verify

**Issue**: Fabricating claims about what is or isn't available in CI without checking.

**Context**: The CI runner is a full Windows machine with WSL, PwshSpectreConsole, Scoop, and all project dependencies. `install.ps1` installs production dependencies; `test/bin/init.ps1` installs test dependencies (Pester, PSScriptAnalyzer) and runs `wsl --update`. All 1000+ tests run with 0 skipped.

**Guideline**: Before making any claim about the CI environment (what's installed, what's available, what's skipped), read `test.yml`, `init.ps1`, and `install.ps1`. Trust CI test results over assumptions. If CI reports 0 skipped, nothing is skipped.

**You MUST NOT:**
- Assume standard GitHub Actions limitations apply (e.g., "WSL isn't available") without checking
- Invent plausible-sounding explanations for test behavior without verifying
- Add defensive stubs or skip-guards for dependencies that are actually installed in CI
- Double down on wrong assumptions when challenged; re-investigate instead

**You MUST:**
- Read the CI workflow and setup scripts before claiming anything about the CI environment
- When CI results contradict your mental model, trust the data
- Say "I don't know" rather than fabricate an explanation

#### Backlog Conventions

Backlog structure and format are defined by the `refinement` skill (from the `xxthunder-dev-skills` plugin). See `docs/backlog/README.md` for the TOC and notes.

- **No unrelated files in feature commits**: keep commits scoped to the feature; unrelated additions get their own commit.
- **Always update backlog with every commit**: move item to IN PROGRESS at start, check off acceptance criteria as they're completed, move to DONE when finished. Backlog updates go in the same commit as the code.

#### Communication

- **Problem statements are not build directives**: when the user describes a problem or goal, ask what approach they want before implementing. Especially for changes to shared infrastructure (hooks, CI, config) that affect all contributors.

#### Windows/Git Bash Pitfalls

- **NUL vs /dev/null**: On Windows under Git Bash/MSYS2, redirecting to `NUL` creates a literal file named `nul`. Always use `/dev/null` in Bash contexts.

#### When to Use EnterPlanMode (MANDATORY)

**ALWAYS use EnterPlanMode before implementation when:**

1. **User says "review" or "plan"** - They explicitly want exploration, not implementation
2. **Backlog items** - Items in `docs/backlog/` require architectural understanding before coding
3. **New features** - Adding functionality, not just fixing bugs
4. **Architectural decisions** - Unclear where functionality belongs in existing structure
5. **"Belongs to" questions** - When you're unsure which module/function should own the code

**Red flags that require planning first:**
- "Where should this go?"
- "Does this already exist somewhere?"
- "Is this related to [existing feature]?"
- Any uncertainty about architecture, ownership, or approach

**Anti-pattern (what NOT to do):**
```
User: "Review FEAT-001 for DevContainer prep"
Agent: *immediately creates new functions and commits*
```

**Correct pattern:**
```
User: "Review FEAT-001 for DevContainer prep"
Agent: *uses EnterPlanMode to explore architecture, understand relationships,
        propose whether this is new feature vs. enhancement to existing*
```

**Enforcement**: When in doubt, ALWAYS prefer planning over immediate implementation. Use EnterPlanMode proactively to avoid architectural misalignment.

#### When Implementing New Functionality

1. **Research**: Check if similar functionality exists in `lib/` or other scripts
2. **Design**: Plan the script structure and identify reusable components
3. **Test First**: Write Pester tests before implementation (TDD)
4. **Implement**: Write the PowerShell script following guidelines
5. **Test**: Run Pester tests and manual testing
6. **Document**: Add comments and help documentation
7. **Integration**: Ensure Keypirinha can discover new shortcuts if applicable

> **Backlog tracking is mandatory**: see Development Workflow in `docs/development-principles.md` for the full start/finish protocol.

#### When Modifying Existing Functions

**CRITICAL: Never modify implementation without updating tests!**

1. **Read Tests First**: Understand what the current tests verify
2. **Update Tests**: Modify tests to expect new behavior (Red phase)
3. **Run Tests**: Confirm tests fail with current implementation
4. **Modify Implementation**: Update the function (Green phase)
5. **Run Tests Again**: Verify all tests pass
6. **Commit Together**: Tests and implementation must be in the same commit

**Example of the correct workflow:**

```bash
# 1. Modify the test to expect new behavior
Edit lib/wsl/wsl.Tests.ps1  # Update parameter filter

# 2. Run tests - should FAIL
pwsh -File ".\test\bin\testrunner.ps1" -Unit  # Expected: 1 failure

# 3. Update implementation
Edit lib/wsl/wsl.ps1  # Change the command

# 4. Run tests - should PASS
pwsh -File ".\test\bin\testrunner.ps1" -Unit  # Expected: all pass

# 5. Commit both together
git add lib/wsl/wsl.ps1 lib/wsl/wsl.Tests.ps1
git commit -m "refactor: update Get-WslDistroType command"
```

#### Mandatory Pre-Commit Checks

**Before every commit, you MUST:**

1. **Run unit tests**: `pwsh -File ".\test\bin\testrunner.ps1" -Unit`
   - All tests must pass
   - If any fail, fix them before committing
2. **Run integration tests** (if you modified integration points): `pwsh -File ".\test\bin\testrunner.ps1" -Integration`
3. **Run linter**: Tests include PSScriptAnalyzer checks automatically

**Never commit if:**

- Any unit test fails
- Any integration test fails
- You changed a function but didn't update its tests
- You're unsure if tests cover your changes

### Code Review Checklist

When reviewing code, verify adherence to:

- **Guidelines**: TDD, DRY, SOLID principles (see "Coding Guidelines")
- **Structure**: Script structure, error handling, pslib usage (see "Core Principles")
- **Testing**: Pester tests with proper mocking (see "Testing Requirements")
- **Security**: No hardcoded secrets, proper input validation
- **Documentation**: Clear comments, synopsis/examples in headers
- **Integration**: Conventional commits, Keypirinha compatibility

Provide specific feedback with `file:line` references.

### Shared Skills Plugin

This project uses the [xxthunder/xxthunder-dev-skills](https://github.com/xxthunder/xxthunder-dev-skills) plugin for shared skills (refinement, commit-helper, tdd-workflow, retrospective). The plugin is loaded automatically:

- **Locally**: installed to `~/.claude/plugins/` via `claude plugins add`
- **GitHub Actions**: configured via the `plugins` input in `.github/workflows/claude.yml`

### Reference Documentation

For core development principles and quality gates:

- `docs/development-principles.md`: Core principles (TDD, error handling, environment awareness, etc.)

For detailed PowerShell library guidelines:

- `lib/AGENTS.md`: In-depth PowerShell development guide

For project documentation:

- `docs/wsl-manager.md`: WSL Manager consolidated specification
- `README.md`: User-facing installation and usage guide
- `bin/install.ps1`: Main installation entry point
