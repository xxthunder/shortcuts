# lib Quick Reference

Quick reference for commonly used functions in the PowerShell library (`lib/`).

## Command Execution

### Invoke-CommandLine

Execute external commands with proper error handling and output capture.

**Location:** `lib/utils/utils.ps1`

**Usage:**
```powershell
# Basic usage
Invoke-CommandLine -Command "scoop list"

# With error handling
Invoke-CommandLine -Command "scoop install nodejs" -StopAtError

# Silent execution
Invoke-CommandLine -Command "git status" -Silent

# Show command before execution
Invoke-CommandLine -Command "npm install" -PrintCommand
```

**Parameters:**
- `-Command`: Command to execute
- `-StopAtError`: Stop script execution on error (default: $false)
- `-PrintCommand`: Print command before executing (default: $true)
- `-Silent`: Suppress output (default: $false)

**Returns:** Command output as string

## Environment Detection

### Test-RunningInCIorTestEnvironment

Detect if running in CI or test environment.

**Location:** `lib/utils/utils.ps1`

**Usage:**
```powershell
if (Test-RunningInCIorTestEnvironment) {
    # Non-interactive path
    $auto = $true
} else {
    # Interactive path
    $confirm = Read-Host "Proceed? (y/n)"
}
```

**Detects:**
- CI environment variables (`CI`, `GITHUB_ACTIONS`, etc.)
- Pester test context (via `PesterPreference` or call stack)

## User Interaction

### Get-UserConfirmation

Get user confirmation in interactive mode, auto-confirm in CI/test mode.

**Location:** `lib/utils/utils.ps1`

**Usage:**
```powershell
# Basic confirmation
$proceed = Get-UserConfirmation "Delete all files?"

# With custom default values
$proceed = Get-UserConfirmation `
    -Prompt "Continue with installation?" `
    -DefaultValueForUser $true `
    -ValueForCi $true
```

**Parameters:**
- `-Prompt`: Question to ask user
- `-DefaultValueForUser`: Default value in interactive mode
- `-ValueForCi`: Value to return in CI/test mode

## Directory Operations

### New-Directory

Create directory if it doesn't exist.

**Location:** `lib/utils/utils.ps1`

**Usage:**
```powershell
New-Directory -Path "C:\Tools\MyApp"
New-Directory -Path (Join-Path $PSScriptRoot "output")
```

## WSL Functions

### Get-WslDistroType

Get the type of a WSL distribution.

**Location:** `lib/wsl/wsl.ps1`

**Usage:**
```powershell
$type = Get-WslDistroType -DistroName "Ubuntu"
# Returns: "ubuntu", "debian", "alpine", etc.
```

### Test-WslDistroExists

Check if a WSL distribution exists.

**Location:** `lib/wsl/wsl.ps1`

**Usage:**
```powershell
if (Test-WslDistroExists -DistroName "Ubuntu") {
    Write-Host "Ubuntu is installed"
}
```

### Get-WslDistroIpAddress

Get IP address of a running WSL distribution.

**Location:** `lib/wsl/wsl.ps1`

**Usage:**
```powershell
$ip = Get-WslDistroIpAddress -DistroName "Ubuntu"
Write-Host "Ubuntu IP: $ip"
```

## Usage Patterns

### Sourcing the Library

Always source the library before using its functions:

```powershell
# From repository root
. "$PSScriptRoot\lib\utils\utils.ps1"

# From subdirectory (one level deep)
. "$PSScriptRoot\..\lib\utils\utils.ps1"

# WSL functions
. "$PSScriptRoot\lib\wsl\wsl.ps1"
```

### Error Handling Pattern

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\utils\utils.ps1"

try {
    Invoke-CommandLine -Command "dangerous-operation" -StopAtError
} catch {
    Write-Error "Operation failed: $_"
    exit 1
}
```

### CI-Aware Script Pattern

```powershell
. "$PSScriptRoot\lib\utils\utils.ps1"

if (Test-RunningInCIorTestEnvironment) {
    # Automated path
    $targetDir = "C:\Default\Path"
    $confirm = $true
} else {
    # Interactive path
    $targetDir = Read-Host "Enter target directory"
    $confirm = Get-UserConfirmation "Proceed with installation?"
}

if ($confirm) {
    New-Directory -Path $targetDir
    Invoke-CommandLine -Command "scoop install app" -StopAtError
}
```

## Discovery

To find more functions:

1. **Read the source files:**
   - `lib/utils/utils.ps1`
   - `lib/wsl/wsl.ps1`

2. **Check test files for usage examples:**
   - `lib/utils/utils.Tests.ps1`
   - `lib/wsl/wsl.Tests.ps1`

3. **Use Get-Help:**
   ```powershell
   . .\lib\utils\utils.ps1
   Get-Help Invoke-CommandLine -Full
   ```
