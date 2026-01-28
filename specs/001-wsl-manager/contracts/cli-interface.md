# CLI Interface Contract: WSL Manager

**Feature Branch**: `001-wsl-manager`
**Date**: 2026-01-13
**Phase**: 1 - Design Artifacts

## Overview

This document defines the command-line interface contract for the WSL Manager tool. It specifies commands, parameters, outputs, exit codes, and error messages to ensure consistent user experience and enable comprehensive testing.

## Invocation Methods

### Method 1: Interactive Mode (Default)

**Command**:
```powershell
.\tools\pslib\wsl\wsl-manager.ps1
# OR
wsl-manager  # Via .bat wrapper
```

**Behavior**:
- Displays list of installed WSL distributions
- Presents interactive menu with available commands
- Loops until user selects Quit or presses Ctrl+C
- Skips menu in CI environment with helpful message

**Exit Codes**:
- `0` - User quit normally
- `1` - Error occurred (WSL not installed, etc.)

---

### Method 2: Direct Command Mode

**Command**:
```powershell
.\tools\pslib\wsl\wsl-manager.ps1 <command> [options]
# OR
wsl-manager <command> [options]  # Via .bat wrapper
```

**Behavior**:
- Executes specified command directly
- No interactive prompts (suitable for scripting)
- Returns after command completion

**Exit Codes**:
- `0` - Command succeeded
- `1` - Command failed

---

## Commands

### 1. List Distributions

**Command**: `list`

**Synopsis**: Display all installed WSL distributions

**Syntax**:
```powershell
wsl-manager list
```

**Parameters**: None

**Output** (Success):
```text
=== Installed WSL Distributions ===
1. Debian
2. Ubuntu-22.04
3. MyProject
```

**Output** (No Distributions):
```text
No WSL distributions found.
```

**Output** (WSL Not Installed):
```text
Error: WSL is not installed. Please install WSL first.
```

**Exit Codes**:
- `0` - Success (distributions listed or none found)
- `1` - WSL not installed

**Functional Requirements**: FR-001, FR-002

---

### 2. Create Distribution

**Command**: `create`

**Synopsis**: Create a new WSL distribution from available distributions

**Syntax**:
```powershell
wsl-manager create [<name>]
```

**Parameters**:

| Parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `<name>` | String | No | Distribution name to install (e.g., Debian, Ubuntu-22.04) | Must be available via `wsl --list --online` |

**Interactive Flow** (no parameters):
```text
Available distributions for installation:
  1. Debian
  2. Ubuntu
  3. Ubuntu-20.04
  4. Ubuntu-22.04
  5. Ubuntu-24.04

Select a distribution by number or name: _
```

**Output** (Success):
```text
Installing Debian...
✓ Successfully created distribution 'Debian'
```

**Output** (Already Exists):
```text
Error: Distribution 'Debian' already exists.
```

**Output** (Invalid Name):
```text
Error: Distribution 'InvalidName' is not available.

Available distributions:
  - Debian
  - Ubuntu
  - Ubuntu-22.04

Run 'wsl.exe --list --online' to see all available distributions.
```

**Exit Codes**:
- `0` - Distribution created successfully
- `1` - Distribution already exists, invalid name, or WSL error

**Functional Requirements**: FR-003, FR-005

---

### 3. Clone Distribution

**Command**: `clone`

**Synopsis**: Clone an existing WSL distribution to a new name

**Syntax**:
```powershell
wsl-manager clone [<source>] [<target>]
```

**Parameters**:

| Parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `<source>` | String | No | Source distribution name or number | Must exist, must be stopped |
| `<target>` | String | No | Target distribution name | Must be unique, valid naming pattern |

**Interactive Flow** (no parameters):
```text
=== Installed WSL Distributions ===
1. Debian
2. Ubuntu-22.04

Select source distribution by number or name: 1
Enter target distribution name: MyProject
```

**Output** (Success):
```text
Cloning 'Debian' to 'MyProject'...
✓ Successfully cloned 'Debian' to 'MyProject'
```

**Output** (Source Running):
```text
Error: Distribution 'Debian' is running.
Please stop it first with: wsl --terminate Debian
```

**Output** (Target Exists):
```text
Error: Distribution 'MyProject' already exists.
```

**Output** (Source Not Found):
```text
Error: Distribution 'Debian' does not exist.
```

**Exit Codes**:
- `0` - Distribution cloned successfully
- `1` - Source not found, source running, target exists, or operation failed

**Functional Requirements**: FR-004, FR-005, FR-024, FR-027, FR-030

---

### 4. Remove Distribution

**Command**: `remove`

**Synopsis**: Remove an installed WSL distribution

**Syntax**:
```powershell
wsl-manager remove [<name>] [-Confirm:$false]
```

**Parameters**:

| Parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `<name>` | String | No | Distribution name or number to remove | Must exist |
| `-Confirm` | Switch | No | Skip confirmation prompt | Use `-Confirm:$false` for automation |

**Interactive Flow** (no parameters):
```text
=== Installed WSL Distributions ===
1. Debian
2. Ubuntu-22.04
3. MyProject

Select distribution to remove by number or name: 3

Are you sure you want to remove 'MyProject'?
[Y] Yes  [N] No  [?] Help (default is "Y"): _
```

**Output** (Success):
```text
Removing 'MyProject'...
✓ Successfully removed distribution 'MyProject'
```

**Output** (User Declined):
```text
Operation cancelled by user.
```

**Output** (Distribution Running):
```text
Error: Distribution 'MyProject' is running.
Please stop it first with: wsl --terminate MyProject
```

**Output** (Not Found):
```text
Error: Distribution 'MyProject' does not exist.
```

**Exit Codes**:
- `0` - Distribution removed successfully
- `1` - Distribution not found, user declined, distribution running, or operation failed

**Functional Requirements**: FR-006, FR-007, FR-030

---

### 5. Terminate Distribution

**Command**: `terminate` (Implemented)

**Synopsis**: Stop a running WSL distribution

**Syntax**:
```powershell
wsl-manager terminate [<name>]
```

**Parameters**:

| Parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `<name>` | String | No | Distribution name or number to terminate | Must exist |

**Interactive Flow** (no parameters):
```text
=== Running WSL Distributions ===
1. Debian
2. Ubuntu-22.04

Select distribution to terminate by number or name: _
```

**Interactive Flow** (no running distributions):
```text
No running distributions to terminate.
```

**Output** (Success):
```text
Terminating 'Debian'...
✓ Successfully terminated distribution 'Debian'
```

**Output** (Already Stopped):
```text
Distribution 'Debian' is not running.
```

**Output** (Not Found):
```text
Error: Distribution 'Debian' does not exist.
```

**Exit Codes**:
- `0` - Distribution terminated successfully or already stopped
- `1` - Distribution not found or operation failed

**Functional Requirements**: FR-031, FR-032, FR-033

---

### 6. Update Distribution

**Command**: `update`

**Synopsis**: Update packages in Debian or Ubuntu distributions

**Syntax**:
```powershell
wsl-manager update [<name>]
```

**Parameters**:

| Parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `<name>` | String | No | Distribution name or number to update | Must exist, must be Debian/Ubuntu, must be stopped |

**Interactive Flow** (no parameters):
```text
=== Installed WSL Distributions ===
1. Debian
2. Ubuntu-22.04

Select distribution to update by number or name: _
```

**Output** (Success):
```text
Updating 'Debian'...
✓ Successfully updated distribution 'Debian'
Cleaned apt cache to free disk space.
```

**Output** (Unsupported Distribution):
```text
Error: Distribution 'Arch' is not supported for updates.
Only Debian and Ubuntu distributions can be updated using this tool.
```

**Output** (Distribution Running):
```text
Error: Distribution 'Debian' is running.
Please stop it first with: wsl --terminate Debian
```

**Exit Codes**:
- `0` - Packages updated successfully
- `1` - Unsupported distribution type, distribution running, or update failed

**Functional Requirements**: FR-008, FR-009, FR-030

---

### 7. Setup User Account

**Command**: `setup-user`

**Synopsis**: Create a user account with sudo privileges in a distribution

**Syntax**:
```powershell
wsl-manager setup-user [<distribution>] [<username>] [<password>]
```

**Parameters**:

| Parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `<distribution>` | String | No | Distribution name or number | Must exist |
| `<username>` | String | No | Linux username | Lowercase, start with letter/underscore, max 32 chars, pattern: `^[a-z_][a-z0-9_-]*$` |
| `<password>` | String/SecureString | No | User password | Non-empty |

**Interactive Flow** (no parameters):
```text
=== Installed WSL Distributions ===
1. Debian
2. Ubuntu-22.04

Select distribution by number or name: 1
Enter username: developer
Enter password: ************
Confirm password: ************
```

**Interactive Flow** (CI Environment):
```text
Skipping user setup in CI/test environment.
```

**Output** (Success):
```text
Creating user 'developer' in 'Debian'...

WARNING: This user will be configured with NOPASSWD sudo access.
This is convenient for development but reduces security. Only use in development environments.

✓ User 'developer' created successfully
✓ Added to sudo group with NOPASSWD access
✓ Set as default user
Distribution restarted to apply changes.
```

**Output** (Invalid Username - Uppercase):
```text
Error: Invalid username 'Developer'.
Username must be lowercase, start with a letter or underscore,
and contain only letters, digits, underscores, and hyphens.
Maximum length: 32 characters.
```

**Output** (User Already Exists):
```text
Error: User 'developer' already exists in distribution 'Debian'.
```

**Exit Codes**:
- `0` - User created successfully or skipped in CI
- `1` - Invalid username, user exists, or operation failed

**Functional Requirements**: FR-010, FR-011, FR-012, FR-013, FR-029

---

### 8. Setup Docker Engine

**Command**: `setup-docker`

**Synopsis**: Install Docker Engine in a Debian or Ubuntu distribution

**Syntax**:
```powershell
wsl-manager setup-docker [<distribution>] [-Confirm:$false]
```

**Parameters**:

| Parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `<distribution>` | String | No | Distribution name or number | Must exist, must be WSL2, must have systemd, must be Debian/Ubuntu, must have default user |
| `-Confirm` | Switch | No | Skip confirmation prompt | Use `-Confirm:$false` for automation |

**Interactive Flow** (no parameters):
```text
=== Installed WSL Distributions ===
1. Debian
2. Ubuntu-22.04

Select distribution by number or name: _

Docker installation will:
  - Download and install Docker Engine
  - Enable and start the Docker service
  - Add the default user to the docker group

This operation may take several minutes.
Proceed with installation?
[Y] Yes  [N] No  [?] Help (default is "Y"): _
```

**Output** (Success):
```text
Installing Docker Engine in 'Debian'...

Step 1/10: Updating package index...
Step 2/10: Installing prerequisites...
Step 3/10: Creating keyrings directory...
Step 4/10: Downloading Docker GPG key...
Step 5/10: Adding Docker repository...
Step 6/10: Updating package index...
Step 7/10: Installing Docker packages...
Step 8/10: Enabling Docker service...
Step 9/10: Starting Docker service...
Step 10/10: Adding user to docker group...

✓ Docker Engine installed successfully

Verification:
  Docker version: 24.0.7
  Service status: active (running)
  Hello-world test: passed

The default user has been added to the docker group.
Log out and log back in for group changes to take effect.
```

**Output** (WSL1 Error):
```text
Error: Distribution 'Debian' is using WSL1.
Docker requires WSL2. Upgrade with:
  wsl.exe --set-version Debian 2
```

**Output** (Systemd Not Configured):
```text
Error: Systemd is not configured in 'Debian'.
Docker requires systemd. Add the following to /etc/wsl.conf:

  [boot]
  systemd=true

Then restart the distribution:
  wsl.exe --terminate Debian
```

**Output** (Systemd Not Running):
```text
Error: Systemd is not running in 'Debian'.
Restart the distribution to start systemd:
  wsl.exe --terminate Debian
```

**Output** (Unsupported Distribution):
```text
Error: Docker setup only supports Debian and Ubuntu distributions.
Distribution 'Arch' is not supported.
```

**Output** (No Default User):
```text
Error: No default user configured in 'Debian'.
Docker setup requires a non-root user to add to the docker group.

Please setup a user first:
  wsl-manager setup-user Debian

Then run setup-docker again.
```

**Output** (Already Installed):
```text
Error: Docker 24.0.7 is already installed in 'Debian'.

To verify the installation, run:
  wsl -d Debian docker --version
  wsl -d Debian docker run --rm hello-world
```

**Exit Codes**:
- `0` - Docker installed successfully or user declined confirmation
- `1` - Prerequisites not met, already installed, or installation failed

**Functional Requirements**: FR-014, FR-015, FR-016, FR-025

---

## Interactive Menu

**Displayed When**: No command-line arguments provided

**Menu Structure**:

```text
=== Installed WSL Distributions ===
1. Debian
2. Ubuntu-22.04
3. MyProject

Available commands:
  [I] Install new distribution
  [C] Clone existing distribution
  [U] Update distribution packages
  [S] Setup user account
  [D] Setup Docker Engine
  [T] Terminate running distribution
  [R] Remove distribution
  [Q] Quit

Enter your choice: _
```

**Input Handling**:
- Case-insensitive (I, i, Install, install all work)
- Invalid input: Display error and re-prompt
- Ctrl+C: Exit immediately with code 0

**Menu Flow**:
1. Display distributions
2. Display menu options
3. Get user choice
4. Execute corresponding workflow function
5. Return to menu (unless Q selected)

**CI Environment**:
```text
Interactive mode is not available in CI environment.
Use command-line arguments instead.

Examples:
  wsl-manager list
  wsl-manager create Debian
  wsl-manager clone Debian MyProject
```

**Functional Requirements**: FR-017, FR-018, FR-019, FR-022

---

## Output Formats

### Success Messages

**Pattern**: `✓ <Action completed successfully>`

**Examples**:
```text
✓ Successfully created distribution 'Debian'
✓ Successfully cloned 'Debian' to 'MyProject'
✓ Successfully removed distribution 'MyProject'
✓ Successfully terminated distribution 'Debian'
✓ Successfully updated distribution 'Debian'
✓ User 'developer' created successfully
✓ Docker Engine installed successfully
```

**Color**: Green (via `Write-Host -ForegroundColor Green`)

---

### Status Messages

**Pattern**: `==> <Action in progress>`

**Examples**:
```text
==> Installing Debian...
==> Cloning 'Debian' to 'MyProject'...
==> Updating package index...
==> Adding Docker repository...
```

**Color**: Cyan (via `Write-Host -ForegroundColor Cyan`)

---

### Warning Messages

**Pattern**: `WARNING: <Important information>`

**Examples**:
```text
WARNING: This user will be configured with NOPASSWD sudo access.
This is convenient for development but reduces security.
```

**Color**: Yellow (via `Write-Host -ForegroundColor Yellow`)

---

### Error Messages

**Pattern**: `Error: <Problem description>` + optional `<Remediation steps>`

**Examples**:
```text
Error: WSL is not installed. Please install WSL first.

Error: Distribution 'Debian' is running.
Please stop it first with: wsl --terminate Debian

Error: Distribution 'InvalidName' is not available.
Available distributions:
  - Debian
  - Ubuntu
  - Ubuntu-22.04
```

**Color**: Red (via `Write-Host -ForegroundColor Red`)

---

### Information Messages

**Pattern**: Plain text for informational content

**Examples**:
```text
No WSL distributions found.
Skipping user setup in CI/test environment.
Cleaned apt cache to free disk space.
```

**Color**: Default

---

## Exit Codes

| Code | Meaning | When Used |
|---|---|---|
| `0` | Success | Operation completed successfully, user quit menu, user declined confirmation |
| `1` | Failure | WSL not installed, operation failed, prerequisites not met, validation error |

---

## Error Message Catalog

### WSL Not Installed
```text
Error: WSL is not installed. Please install WSL first.
```

### Distribution Not Found
```text
Error: Distribution '<name>' does not exist.
```

### Distribution Already Exists
```text
Error: Distribution '<name>' already exists.
```

### Distribution Is Running (Clone)
```text
Error: Distribution '<name>' is running.
Please stop it first with: wsl --terminate <name>
```

### Distribution Is Running (Remove)
```text
Error: Distribution '<name>' is running.
Please stop it first with: wsl --terminate <name>
```

### Distribution Is Running (Update)
```text
Error: Distribution '<name>' is running.
Please stop it first with: wsl --terminate <name>
```

### Invalid Distribution Name
```text
Error: Distribution '<name>' is not available.

Available distributions:
  - Debian
  - Ubuntu
  - Ubuntu-22.04

Run 'wsl.exe --list --online' to see all available distributions.
```

### Unsupported Distribution Type (Update)
```text
Error: Distribution '<name>' is not supported for updates.
Only Debian and Ubuntu distributions can be updated using this tool.
```

### Unsupported Distribution Type (Docker)
```text
Error: Docker setup only supports Debian and Ubuntu distributions.
Distribution '<name>' is not supported.
```

### Invalid Username
```text
Error: Invalid username '<username>'.
Username must be lowercase, start with a letter or underscore,
and contain only letters, digits, underscores, and hyphens.
Maximum length: 32 characters.
```

### User Already Exists
```text
Error: User '<username>' already exists in distribution '<distro>'.
```

### WSL1 Distribution (Docker)
```text
Error: Distribution '<name>' is using WSL1.
Docker requires WSL2. Upgrade with:
  wsl.exe --set-version <name> 2
```

### Systemd Not Configured (Docker)
```text
Error: Systemd is not configured in '<name>'.
Docker requires systemd. Add the following to /etc/wsl.conf:

  [boot]
  systemd=true

Then restart the distribution:
  wsl.exe --terminate <name>
```

### Systemd Not Running (Docker)
```text
Error: Systemd is not running in '<name>'.
Restart the distribution to start systemd:
  wsl.exe --terminate <name>
```

### No Default User (Docker)
```text
Error: No default user configured in '<name>'.
Docker setup requires a non-root user to add to the docker group.

Please setup a user first:
  wsl-manager setup-user <name>

Then run setup-docker again.
```

### Docker Already Installed
```text
Error: Docker <version> is already installed in '<name>'.

To verify the installation, run:
  wsl -d <name> docker --version
  wsl -d <name> docker run --rm hello-world
```

---

## Testing Contract

### Unit Test Assertions

For each command, unit tests MUST verify:

1. **Success path**: Command completes with exit code 0 and success message
2. **WSL not installed**: Error message and exit code 1
3. **Invalid parameters**: Error message and exit code 1
4. **Interactive mode**: Prompts displayed, input validated
5. **CI mode**: Prompts skipped, parameters used
6. **Confirmation prompts**: ShouldProcess support for destructive operations

### Integration Test Scenarios

Integration tests MUST verify:

1. **Full workflow**: Create → Update → Clone → Setup user → Setup Docker → Terminate → Remove
2. **Error recovery**: Operations leave system in safe state on failure
3. **State preservation**: Cloning preserves all configurations
4. **Real command execution**: Actual WSL operations succeed
5. **Output verification**: Success messages and error messages match contract

---

## Versioning

**Current Version**: 1.0.0 (initial implementation)

**Compatibility Policy**:
- Commands and parameters MUST remain stable
- Error messages MAY change wording but MUST preserve semantic meaning
- Exit codes MUST NOT change (0 = success, 1 = failure)
- New commands MAY be added without breaking changes

---

---

## Library Function Contracts (Refactoring Addition)

**Added**: 2026-01-14
**Purpose**: Define contracts for refactored internal library functions

### Get-WslDistroList (Extended)

**Synopsis**: Gets installed WSL distributions, optionally with detailed information

**Signature**:
```powershell
function Get-WslDistroList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )
}
```

**Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Detailed` | Switch | No | When specified, returns WslDistroInfo objects instead of strings |

**Output (Default)**:
```powershell
# Returns: string[]
@("Debian", "Ubuntu", "Ubuntu-22.04")
```

**Output (-Detailed)**:
```powershell
# Returns: PSCustomObject[]
@(
    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
    [PSCustomObject]@{ Name = "Ubuntu-22.04"; State = "Stopped"; Version = 1; IsDefault = $false }
)
```

**Behavior**:
- Without `-Detailed`: Calls `wsl --list --quiet`, returns cleaned string array (current behavior)
- With `-Detailed`: Calls `wsl --list --verbose`, parses all fields, returns WslDistroInfo objects
- Throws if WSL is not installed
- Returns empty array if no distributions installed

**Error Conditions**:
- WSL not installed: `throw "WSL is not installed. Please install WSL first."`

---

### Get-WslDistroState (Refactored)

**Synopsis**: Gets the running state of a WSL distribution

**Signature**:
```powershell
function Get-WslDistroState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
}
```

**Output**:
```powershell
# Returns: string - "Running" or "Stopped"
"Running"
```

**Behavior After Refactoring**:
```powershell
# OLD: Directly calls wsl --list --verbose and parses
# NEW: Uses Get-WslDistroList -Detailed
function Get-WslDistroState {
    param([string]$DistroName)

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    $distros = Get-WslDistroList -Detailed
    $distro = $distros | Where-Object { $_.Name -eq $DistroName }

    if (-not $distro) {
        throw "Distribution '$DistroName' does not exist."
    }

    return $distro.State
}
```

**Error Conditions**:
- WSL not installed: `throw "WSL is not installed. Please install WSL first."`
- Distribution not found: `throw "Distribution '$DistroName' does not exist."`

---

### Test-Wsl2Version (Refactored)

**Synopsis**: Tests if a WSL distribution is using WSL2

**Signature**:
```powershell
function Test-Wsl2Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )
}
```

**Output**:
```powershell
# Returns: bool
$true  # if WSL2
$false # if WSL1
```

**Behavior After Refactoring**:
```powershell
# OLD: Directly calls wsl --list --verbose and parses
# NEW: Uses Get-WslDistroList -Detailed
function Test-Wsl2Version {
    param([string]$DistroName)

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    $distros = Get-WslDistroList -Detailed
    $distro = $distros | Where-Object { $_.Name -eq $DistroName }

    if (-not $distro) {
        throw "Distribution '$DistroName' does not exist."
    }

    return $distro.Version -eq 2
}
```

**Error Conditions**:
- WSL not installed: `throw "WSL is not installed. Please install WSL first."`
- Distribution not found: `throw "Distribution '$DistroName' does not exist."`

---

### Backward Compatibility Contract

The refactoring MUST maintain backward compatibility:

| Function | Before | After | Breaking Change? |
|----------|--------|-------|------------------|
| `Get-WslDistroList` | Returns `string[]` | Returns `string[]` (unchanged) | No |
| `Get-WslDistroList -Detailed` | N/A | Returns `PSCustomObject[]` | No (new feature) |
| `Get-WslDistroState` | Returns `string` | Returns `string` (unchanged) | No |
| `Test-Wsl2Version` | Returns `bool` | Returns `bool` (unchanged) | No |

**Guarantees**:
1. All existing callers of `Get-WslDistroList` continue to work
2. All existing callers of `Get-WslDistroState` continue to work
3. All existing callers of `Test-Wsl2Version` continue to work
4. Error messages remain semantically identical
5. Exit codes remain unchanged

---

## Summary

This CLI interface contract defines:

- **9 commands**: list, create, clone, remove, terminate, update, setup-user, setup-docker, interactive menu
- **2 invocation methods**: Interactive mode (default), direct command mode
- **Consistent output patterns**: Success (✓), status (==>), warning (WARNING:), error (Error:)
- **2 exit codes**: 0 (success), 1 (failure)
- **Comprehensive error messages**: 13 distinct error scenarios with remediation steps
- **Testing requirements**: Unit tests for all paths, integration tests for workflows

All commands follow PowerShell conventions (`[CmdletBinding()]`, `SupportsShouldProcess`), environment awareness (interactive vs CI), and fail-fast error handling principles.
