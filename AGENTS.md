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
- `links/`: Keypirinha link definitions (.url files)
- `tests/`: Test files and test utilities
- `.bootstrap/`: Bootstrap system for initial setup

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

1. **Read the library files** in `tools/pslib/` (e.g., `utils.ps1`, `wsl.ps1`)
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

Always implement robust error handling:

```powershell
#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

try {
    # Your code here
} catch {
    Write-Error "Operation failed: $_"
    exit 1
}
```

#### 3. Environment Awareness

Scripts must work in both interactive and CI environments:

```powershell
if (Test-RunningInCIorTestEnvironment) {
    # Non-interactive path
    $confirm = $true
} else {
    # Interactive path
    $confirm = Get-UserConfirmation "Proceed with installation?"
}
```

**Note:** When manually testing interactive scripts (not Pester tests), you can set the environment variable `CI=true` to trigger non-interactive behavior and avoid blocking prompts. However, when running the Pester test suite via `test-all.ps1` or `test.ps1`, do NOT set the CI variable - let the tests run normally.

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

**Running tests:**

```powershell
# Run all tests (PowerShell 7.x - recommended)
pwsh -File ".\tests\bin\test-all.ps1"

# Run all tests (PowerShell 5.1 - for compatibility testing)
powershell -File ".\tests\bin\test-all.ps1"

# Run specific test file
Invoke-Pester -Path ".\path\to\script.Tests.ps1"

# Run all tests with code coverage (PowerShell 7.x)
pwsh -File ".\tests\bin\test-all.ps1" -Coverage

# Run all tests with code coverage (PowerShell 5.1)
powershell -File ".\tests\bin\test-all.ps1" -Coverage
```

**Code Coverage:**

The test suite supports code coverage analysis via the `-Coverage` switch. When enabled, it:

- Generates a JaCoCo XML coverage report at `tests/out/coverage.xml`
- Outputs a coverage summary to the console
- Creates a markdown summary at `tests/out/test-summary.md` for CI/PR comments
- Only analyzes files that have corresponding test files

Coverage reports include:
- Commands analyzed vs executed
- Coverage percentage
- Detailed line-by-line coverage in the XML report

**Testing requirements:**

- Mock external dependencies (file system, commands, environment)
- Test both success and failure paths
- Test CI and interactive environment behavior separately
- Ensure tests pass on both PowerShell 5.1 and 7.x
- **DO NOT** set `CI` environment variable when running tests manually (the test framework handles this automatically)
- Use PowerShell 5.1-compatible syntax (avoid features introduced in PowerShell 6.0+)

**CI Environment Detection:**

The project uses `Test-RunningInCIorTestEnvironment` from `tools/pslib/utils.ps1` to automatically detect CI and Pester test environments. This function checks for:
- CI environment variables (`CI`, `GITHUB_ACTIONS`, etc.)
- Pester test context (via `PesterPreference` or call stack)

When manually testing interactive scripts (not Pester tests), you can set `CI=true` to simulate non-interactive behavior and avoid blocking prompts.

### Calling PowerShell from Bash Tool (AI Agents)

When using AI agents (like Claude Code) that execute PowerShell commands through a Bash tool, follow these guidelines to avoid command failures:

#### Path Quoting Rules

**ALWAYS quote file paths** when calling PowerShell through bash. Windows paths contain backslashes which must be properly escaped.

**Correct usage:**

```bash
# PowerShell 7.x - quote the entire path
pwsh -File ".\tests\bin\test-all.ps1"
pwsh -File ".\tests\bin\test-all.ps1" -Coverage

# PowerShell 5.1 - quote the entire path
powershell -File ".\tests\bin\test-all.ps1"
powershell -File ".\tests\bin\test-all.ps1" -Coverage

# Running specific test files
pwsh -Command "Invoke-Pester -Path '.\tools\pslib\utils.Tests.ps1'"
```

**Incorrect usage (will fail):**

```bash
# Missing quotes - WRONG
pwsh -File .\tests\bin\test-all.ps1

# Backslashes not handled properly - WRONG
pwsh -File .testsbintest-all.ps1
```

#### PowerShell Version Selection

- **pwsh**: PowerShell 7.x (recommended for modern features)
- **powershell**: PowerShell 5.1 (for compatibility testing)

#### Common Commands via Bash

```bash
# Run all tests with coverage
Bash(pwsh -File ".\tests\bin\test-all.ps1" -Coverage)

# Run all tests without coverage
Bash(pwsh -File ".\tests\bin\test-all.ps1")

# Run specific test file
Bash(pwsh -Command "Invoke-Pester -Path '.\tools\pslib\utils.Tests.ps1'")

# Run linter checks
Bash(pwsh -File ".\tests\bin\linter.Tests.ps1")

# Check PowerShell version
Bash(pwsh -Command "$PSVersionTable.PSVersion")
```

#### Error Prevention

When calling PowerShell scripts through the Bash tool:

1. **Always use double quotes** around file paths with the `-File` parameter
2. **Always use single quotes inside double quotes** when using `-Command` parameter with paths
3. **Verify the path** exists before executing if unsure
4. **Check for proper backslash handling** - if backslashes disappear, you need better quoting

**Example workflow in AI agent:**

```
# Step 1: Verify test script exists
Bash(Test-Path ".\tests\bin\test-all.ps1")

# Step 2: Run tests with proper quoting
Bash(pwsh -File ".\tests\bin\test-all.ps1")
```

### Common Patterns

#### Installing/Updating via Scoop

```powershell
# Source library
. "$PSScriptRoot\tools\pslib\utils.ps1"

if (Get-Command tool -ErrorAction SilentlyContinue) {
    Write-Status "Updating tool..."
    Invoke-CommandLine -Command "scoop update tool" -StopAtError
} else {
    Write-Status "Installing tool..."
    Invoke-CommandLine -Command "scoop install tool" -StopAtError
}
```

#### Installing/Updating via npm

```powershell
# Source library
. "$PSScriptRoot\tools\pslib\utils.ps1"

# Check if package is installed
$result = Invoke-CommandLine -Command "npm list -g package --depth=0"
if ($result) {
    Invoke-CommandLine -Command "npm update -g package" -StopAtError
} else {
    Invoke-CommandLine -Command "npm install -g package" -StopAtError
}
```

#### Keypirinha Integration

Scripts should remind users to refresh Keypirinha after changes:

```powershell
Write-Success "Installation complete!"
Write-Host ""
Write-Host "Remember to refresh Keypirinha catalog (see README.md for details)" -ForegroundColor Yellow
```

### Project-Specific Considerations

#### Directory Structure

- `bin/`: Installation and update scripts
- `config/`: Configuration files
- `tools/`: Tool-specific utilities and installers
- `tools/pslib/`: Shared PowerShell library
- `links/`: Keypirinha link definitions
- `tests/`: Test files and test utilities

#### Scoop Integration

This project heavily uses Scoop:

- Check for Scoop before using it
- Use `scoop install`, `scoop update`, `scoop list`
- Reference `scoopfile.json` for managed packages

#### Bootstrap System

The project uses a `.bootstrap` system (see `.bootstrap/` directory):

- Handles initial setup
- Manages dependencies
- Keep bootstrap scripts independent from main tools

### Workflow

When implementing new functionality:

1. **Research**: Check if similar functionality exists in `tools/pslib/` or other scripts
2. **Design**: Plan the script structure and identify reusable components
3. **Test First**: Write Pester tests before implementation (TDD)
4. **Implement**: Write the PowerShell script following guidelines
5. **Test**: Run Pester tests and manual testing
6. **Document**: Add comments and help documentation
7. **Integration**: Ensure Keypirinha can discover new shortcuts if applicable

### Review Guidelines

#### PowerShell Code Quality

- Adherence to project coding guidelines (TDD, DRY, SOLID)
- Proper error handling with Set-StrictMode and $ErrorActionPreference
- Use of pslib functions (Invoke-CommandLine, New-Directory, etc.)
- Environment awareness (CI vs interactive)
- Proper path handling and validation
- Clear output and logging

#### Testing

- Presence of Pester tests for new functionality
- Test coverage for both success and failure paths
- Proper mocking of external dependencies

#### Security

- No hardcoded credentials or sensitive data
- Proper input validation
- Safe command execution

#### Documentation

- Clear comments where logic isn't self-evident
- Synopsis and examples in script headers
- Updated README if needed

#### Integration

- Compatibility with existing scripts
- Proper Keypirinha integration if applicable
- Conventional commit messages

Provide specific, actionable feedback with file:line references.

### Reference Documentation

For detailed PowerShell library guidelines, see:

- `tools/pslib/AGENTS.md`: In-depth PowerShell development guide
- `tools/pslib/CLAUDE.md`: Library-specific Claude instructions

For project usage:

- `README.md`: User-facing installation and usage guide
- `bin/install.ps1`: Main installation entry point
