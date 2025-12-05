# Agent Instructions for Shortcuts

@README.md

## Purpose

The **Shortcuts** project provides a curated collection of tools, links, and automation scripts for Windows, centered around the Keypirinha launcher. It enables users to quickly access their favorite applications, URLs, and custom shortcuts through a keyboard-driven interface.

Key components:

- **Keypirinha**: Fast launcher for accessing applications and shortcuts
- **Scoop**: Package manager for Windows tools
- **PowerShell utilities**: Reusable functions in `tools/pslib/`
- **Installation system**: Automated setup via `bin/install.ps1`

## Coding Guidelines

- TDD
- DRY
- SOLID
- conventional commits

## PowerShell Implementation Guidelines

### Core Principles

When working with PowerShell code in this project, follow these guidelines:

#### 1. Use Existing Library Functions

Before writing new code, check `tools/pslib/` for existing utilities:

- `Invoke-CommandLine`: Execute external commands with proper error handling
- `New-Directory`: Create directories safely
- `Remove-Path`: Delete files/directories with safety checks
- `Get-UserConfirmation`: Handle user prompts (CI-aware)
- `Test-RunningInCIorTestEnvironment`: Detect automation context

**Example:**

```powershell
# Source the library
. "$PSScriptRoot\tools\pslib\utils.ps1"

# Use library functions
Invoke-CommandLine -Command "scoop install nodejs" -StopAtError
New-Directory -Path "C:\Tools\MyApp"
```

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

When running any script for testing, set the environment variable CI to ensure non-blocking execution.

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

Use proper command invocation patterns:

```powershell
# Check if command exists
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Error "Scoop is not installed"
    exit 1
}

# Execute with error handling
$result = scoop list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Scoop command failed"
    exit 1
}
```

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

Quick reference:

- Test files: `*.Tests.ps1`
- Run tests: `Invoke-Pester -Path .\script.Tests.ps1`
- Mock external dependencies
- Test both success and failure paths

### Common Patterns

#### Installing/Updating via Scoop

```powershell
if (Get-Command tool -ErrorAction SilentlyContinue) {
    Write-Status "Updating tool..."
    scoop update tool
} else {
    Write-Status "Installing tool..."
    scoop install tool
}
```

#### Installing/Updating via npm

```powershell
$installed = npm list -g package --depth=0 2>$null
if ($LASTEXITCODE -eq 0) {
    npm update -g package
} else {
    npm install -g package
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
