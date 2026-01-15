# Agent Instructions for Shortcuts

## Overview

This document provides technical guidelines for AI agents working on the Shortcuts project. For user-facing documentation, see @README.md.

## Project Architecture

**Shortcuts** is a Windows automation project that provides CLI tools, shortcuts, and system utilities accessible through the Keypirinha launcher.

### Technical Stack

- **Language**: PowerShell 5.1+
- **Package Manager**: Scoop (for Windows tools)
- **Launcher Integration**: Keypirinha (fast keyboard-driven launcher)
- **Testing**: Pester 5.7.1+
- **Linting**: PSScriptAnalyzer 1.24.0+

### Directory Structure

- `bin/`: Installation and update scripts
- `config/`: Configuration files
- `tools/`: Tool-specific utilities and installers
- `tools/pslib/`: Shared PowerShell library (reusable functions)
  - `utils/`: Utility functions (`utils.ps1`)
  - `wsl/`: WSL-specific functions and tools (`wsl.ps1`, `wsl-manager.ps1`, etc.)
- `links/`: Keypirinha link definitions (.url files)
- `test/`: Test files and test utilities
- `.bootstrap/`: Bootstrap system for initial setup

#### PowerShell Script Wrapper Convention

**Executable PowerShell scripts should have a `.bat` wrapper in the same directory.**

This allows scripts to be executed directly from the command line or Keypirinha without requiring the full `pwsh -File` syntax.

**Example:**

```text
tools/pslib/wsl/
├── wsl-manager.ps1      # The actual PowerShell script
└── wsl-manager.bat      # Wrapper that calls: pwsh -ExecutionPolicy Bypass -File %~dp0wsl-manager.ps1 %*
```

**Benefits:**

- Users can run `wsl-manager` instead of `pwsh -File path/to/wsl-manager.ps1`
- Batch wrapper handles PowerShell execution policy
- Arguments are passed through automatically via `%*`
- Consistent user experience across all executable scripts

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

## PowerShell Implementation Guidelines

### Core Principles

When working with PowerShell code in this project, follow these guidelines:

#### 1. Use Existing Library Functions

**Before writing any new code, ALWAYS check `tools/pslib/` for existing utilities.**

To discover available functions:

1. **Read the library files** in `tools/pslib/utils/` and `tools/pslib/wsl/` (e.g., `utils.ps1`, `wsl.ps1`, `wsl-manager.ps1`)
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
. "$PSScriptRoot\tools\pslib\utils.ps1"

# Use library functions
Invoke-CommandLine -Command "scoop install nodejs" -StopAtError
New-Directory -Path "C:\Tools\MyApp"
```

> **Important:** If you need functionality that seems common (file operations, command execution, user prompts), it likely already exists in pslib. Check first!

#### 2. Error Handling

Always implement robust error handling with:

- `Set-StrictMode -Version Latest`
- `$ErrorActionPreference = "Stop"`
- `$InformationPreference = "Continue"`
- Try/catch blocks for main logic

See "Script Structure" section below for the complete template.

#### 3. Environment Awareness

Scripts must work in both interactive and CI environments using `Test-RunningInCIorTestEnvironment` from `tools/pslib/utils/utils.ps1`:

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

#### 4. Path Handling

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

#### 5. Output and Logging

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

#### 6. External Commands

**Always use `Invoke-CommandLine` from pslib for executing external commands.** This ensures consistent error handling and proper output capture.

```powershell
# Source the library first
. "$PSScriptRoot\tools\pslib\utils.ps1"

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

#### 7. Script Structure

Follow this standard structure:

```powershell
#Requires -Version 5.1

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
. "$PSScriptRoot\tools\pslib\utils.ps1"

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

### Testing Requirements

All PowerShell code must include **Pester tests**. See `tools/pslib/AGENTS.md` for detailed testing guidelines.

#### Quick Reference

**Test files:** `*.Tests.ps1` (located alongside source files)

**Test types:**

- **Unit tests**: `*.Tests.ps1` - Fast, isolated tests with mocked dependencies
- **Integration tests**: `*.Integration.Tests.ps1` - Tests that interact with real systems (WSL, file system, etc.)

**Local development workflow:**

1. Run unit tests first (`test.ps1 -Unit`) - provides fast feedback
2. Run integration tests afterwards (`test.ps1 -Integration`) - when necessary or before committing
3. Both test suites should pass before pushing to remote

**CI/GitHub Actions workflow:**

- Use `test.ps1` (no switches) to run all tests (unit + integration) in a single pass

**Running tests:**

```powershell
# Local development workflow (recommended):
# Step 1: Run unit tests first (faster feedback)
pwsh -File ".\test\bin\test.ps1" -Unit

# Step 2: Run integration tests afterwards when necessary
pwsh -File ".\test\bin\test.ps1" -Integration

# CI/GitHub Actions - Run all tests (unit + integration)
pwsh -File ".\test\bin\test.ps1"

# Run all tests with code coverage (PowerShell 7.x)
pwsh -File ".\test\bin\test.ps1" -Coverage

# Run unit tests with code coverage
pwsh -File ".\test\bin\test.ps1" -Unit -Coverage

# Run integration tests with code coverage
pwsh -File ".\test\bin\test.ps1" -Integration -Coverage

# Run specific test file
Invoke-Pester -Path ".\path\to\script.Tests.ps1"

# PowerShell 5.1 compatibility testing
powershell -File ".\test\bin\test.ps1" -Unit
powershell -File ".\test\bin\test.ps1" -Integration
powershell -File ".\test\bin\test.ps1"
```

**Code Coverage:**

The test suite supports code coverage analysis via the `-Coverage` switch. When enabled, it:

- Generates a JaCoCo XML coverage report at `test/out/coverage.xml`
- Outputs a coverage summary to the console
- Creates a markdown summary at `test/out/test-summary.md` for CI/PR comments
- Only analyzes files that have corresponding test files

Coverage reports include:

- Commands analyzed vs executed
- Coverage percentage
- Detailed line-by-line coverage in the XML report

**Testing requirements:**

- Mock external dependencies (file system, commands, environment)
- Test both success and failure paths
- Test CI and interactive environment behavior separately (see "Environment Awareness" section)
- Ensure tests pass on both PowerShell 5.1 and 7.x
- Use PowerShell 5.1-compatible syntax (avoid features introduced in PowerShell 6.0+)

### Calling PowerShell from Bash Tool (AI Agents)

When using AI agents (like Claude Code) that execute PowerShell commands through a Bash tool, follow these guidelines to avoid command failures:

#### Path Quoting Rules

**ALWAYS quote file paths** when calling PowerShell through bash. Windows paths contain backslashes which must be properly escaped.

**Correct usage:**

```bash
# PowerShell 7.x - quote the entire path
pwsh -File ".\test\bin\test.ps1"
pwsh -File ".\test\bin\test.ps1" -Coverage

# PowerShell 5.1 - quote the entire path
powershell -File ".\test\bin\test.ps1"
powershell -File ".\test\bin\test.ps1" -Coverage

# Running specific test files
pwsh -Command "Invoke-Pester -Path '.\tools\pslib\utils.Tests.ps1'"
```

**Incorrect usage (will fail):**

```bash
# Missing quotes - WRONG
pwsh -File .\test\bin\test.ps1

# Backslashes not handled properly - WRONG
pwsh -File .testsbintest.ps1
```

#### PowerShell Version Selection

- **pwsh**: PowerShell 7.x (recommended for modern features)
- **powershell**: PowerShell 5.1 (for compatibility testing)

#### PowerShell Piping and Cmdlets

**CRITICAL:** When using PowerShell cmdlets or piping commands, you MUST execute the entire pipeline within PowerShell using `-Command`, NOT by piping in bash.

**The Problem:**

When you call PowerShell from bash and try to pipe the output to a PowerShell cmdlet, the pipe happens in the **bash context**, not PowerShell. Bash doesn't know about PowerShell cmdlets like `Select-String`, `Where-Object`, etc.

**Incorrect usage (will fail):**

```bash
# This tries to pipe in BASH, not PowerShell - WRONG
pwsh -File ".\test\bin\test.ps1" | Select-String -Pattern "Error"

# Bash tries to find 'Select-String' as a bash command and fails
```

**Correct usage:**

```bash
# Option 1: Use -Command to run the entire pipeline in PowerShell
pwsh -Command ".\test\bin\test.ps1 | Select-String -Pattern 'Error'"

# Option 2: Use -Command with cmdlet pipeline
pwsh -Command "Get-Content '.\logfile.txt' | Where-Object { $_ -match 'Error' }"

# Option 3: Filter within the PowerShell script itself (preferred for complex logic)
# Modify the script to do the filtering, or create a wrapper script
```

**Examples of PowerShell cmdlets that MUST be inside `-Command`:**

- `Select-String` (use `grep` in bash if you need to pipe bash-to-bash)
- `Where-Object`
- `Select-Object`
- `ForEach-Object`
- `Measure-Object`
- Any PowerShell-specific cmdlet

**When to use bash piping vs PowerShell piping:**

```bash
# Bash-to-bash piping (using bash/unix tools) - OK
pwsh -File ".\script.ps1" | grep "Error"

# PowerShell-to-PowerShell piping - use -Command
pwsh -Command ".\script.ps1 | Select-String 'Error'"
```

#### Common Commands via Bash

```bash
# Local development workflow (recommended):
# Run unit tests first (faster feedback)
Bash(pwsh -File ".\test\bin\test.ps1" -Unit)

# Run integration tests afterwards when necessary
Bash(pwsh -File ".\test\bin\test.ps1" -Integration)

# CI - Run all tests (unit + integration)
Bash(pwsh -File ".\test\bin\test.ps1")

# Run all tests with coverage
Bash(pwsh -File ".\test\bin\test.ps1" -Coverage)

# Run unit tests with coverage
Bash(pwsh -File ".\test\bin\test.ps1" -Unit -Coverage)

# Run integration tests with coverage
Bash(pwsh -File ".\test\bin\test.ps1" -Integration -Coverage)

# Run specific test file
Bash(pwsh -Command "Invoke-Pester -Path '.\tools\pslib\utils.Tests.ps1'")

# Run linter checks
Bash(pwsh -File ".\test\bin\linter.Tests.ps1")

# Check PowerShell version
Bash(pwsh -Command "$PSVersionTable.PSVersion")
```

#### Error Prevention

When calling PowerShell scripts through the Bash tool:

1. **Always use double quotes** around file paths with the `-File` parameter
2. **Always use single quotes inside double quotes** when using `-Command` parameter with paths
3. **NEVER pipe PowerShell cmdlets in bash** - use `pwsh -Command "script.ps1 | Select-String 'pattern'"` instead of `pwsh -File "script.ps1" | Select-String` (see "PowerShell Piping and Cmdlets" section above)
4. **Verify the path** exists before executing if unsure
5. **Check for proper backslash handling** - if backslashes disappear, you need better quoting

**Example workflow in AI agent:**

```text
# Step 1: Verify test script exists
Bash(Test-Path ".\test\bin\test.ps1")

# Step 2: Run tests with proper quoting
Bash(pwsh -File ".\test\bin\test.ps1")
```

### GitHub Actions Workflows

When working with GitHub Actions workflows for this project, be aware of these important limitations:

#### Shell Selection in Matrix Strategies

**IMPORTANT:** You CANNOT use matrix variables in the `shell` field of GitHub Actions steps. The `shell` field only accepts literal values, not matrix interpolation.

**Incorrect (will not work):**

```yaml
shell: ${{ matrix.shell }}  # This does NOT work
run: |
  Write-Output $PSVersionTable
  .\test\bin\test.ps1
```

**Correct approach:**

```yaml
shell: cmd  # Use a literal shell value
run: |
  # Then invoke the matrix shell within the command
  ${{ matrix.shell }} -Command "Write-Output $PSVersionTable; .\test\bin\init.ps1; .\test\bin\test.ps1 -Coverage"
```

This limitation is fundamental to GitHub Actions and requires using a wrapper shell (like `cmd`) to invoke the desired PowerShell version from the matrix.

**Current test workflow pattern (.github/workflows/test.yml):**

- Uses `shell: cmd` as the literal shell
- Invokes `${{ matrix.shell }}` (either `pwsh` or `powershell`) within the command
- This allows testing across multiple PowerShell versions using matrix strategy

### Project-Specific Considerations

#### Directory Structure

- `bin/`: Installation and update scripts
- `config/`: Configuration files
- `tools/`: Tool-specific utilities and installers
- `tools/pslib/`: Shared PowerShell library
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

#### When Implementing New Functionality

1. **Research**: Check if similar functionality exists in `tools/pslib/` or other scripts
2. **Design**: Plan the script structure and identify reusable components
3. **Test First**: Write Pester tests before implementation (TDD)
4. **Implement**: Write the PowerShell script following guidelines
5. **Test**: Run Pester tests and manual testing
6. **Document**: Add comments and help documentation
7. **Integration**: Ensure Keypirinha can discover new shortcuts if applicable

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
Edit tools/pslib/wsl.Tests.ps1  # Update parameter filter

# 2. Run tests - should FAIL
pwsh -File ".\test\bin\test.ps1" -Unit  # Expected: 1 failure

# 3. Update implementation
Edit tools/pslib/wsl/wsl.ps1  # Change the command

# 4. Run tests - should PASS
pwsh -File ".\test\bin\test.ps1" -Unit  # Expected: all pass

# 5. Commit both together
git add tools/pslib/wsl/wsl.ps1 tools/pslib/wsl.Tests.ps1
git commit -m "refactor: update Get-WslDistroType command"
```

#### Mandatory Pre-Commit Checks

**Before every commit, you MUST:**

1. **Run unit tests**: `pwsh -File ".\test\bin\test.ps1" -Unit`
   - All tests must pass
   - If any fail, fix them before committing
2. **Run integration tests** (if you modified integration points): `pwsh -File ".\test\bin\test.ps1" -Integration`
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

### Reference Documentation

For detailed PowerShell library guidelines, see:

- `tools/pslib/AGENTS.md`: In-depth PowerShell development guide
- `tools/pslib/CLAUDE.md`: Library-specific Claude instructions

For project usage:

- `README.md`: User-facing installation and usage guide
- `bin/install.ps1`: Main installation entry point
