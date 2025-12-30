# WSL-005: Update Distribution

## User Story

**As a** developer using WSL,
**I want** to update packages in my Debian or Ubuntu WSL distributions,
**So that** I can keep my development environment up to date with the latest security patches and package versions.

## Acceptance Criteria

- [x] Running `wsl-manager.ps1 update` without arguments shows interactive menu for distribution selection
- [x] Support selection by number or name from the list
- [x] Running update command executes `apt update && apt upgrade -y` in the selected distribution
- [x] Only Debian and Ubuntu (apt-based) distributions are supported
- [x] Clear error message shown when attempting to update non-Debian/Ubuntu distributions
- [x] If WSL is not installed, an appropriate error message is shown
- [x] If no distributions exist, a warning message is displayed
- [x] Progress and success messages are displayed during and after update
- [x] Interactive menu includes [U] option for update command
- [x] Distribution type is automatically detected via `/etc/os-release`

## Technical Notes

- **Distribution type detection**: Uses `Get-WslDistroType` to read `/etc/os-release` and identify distro family
- **Supported distributions**: Only Debian and Ubuntu (apt package manager)
- **Command execution**: Uses `Invoke-WslDistroCommand` to run commands inside WSL
- Workflow:
  1. Check if WSL is installed using `Test-WslInstalled`
  2. Get list of distributions using `Get-WslDistroList`
  3. Prompt user to select distribution (if not specified)
  4. Detect distribution type using `Get-WslDistroType`
  5. Validate distribution is Debian or Ubuntu
  6. Execute `sudo apt update && apt upgrade -y` via `Invoke-WslDistroCommand`
  7. Display success message
- Uses `Update-WslDistro` function with `SupportsShouldProcess` for confirmation
- Interactive CLI wrapper provided by `Invoke-UpdateDistro`
- Validates distribution exists before attempting update
- Proper error handling for non-supported distributions

### Distribution Type Detection

The system detects distribution types by reading `/etc/os-release`:

```powershell
grep "^ID=" /etc/os-release | cut -d= -f2
```

Supported types:
- **debian**: Debian-based distributions
- **ubuntu**: Ubuntu-based distributions
- **arch**: Arch Linux (not supported for updates)
- **rhel**: RHEL family (Fedora, CentOS, RHEL) (not supported for updates)
- **unknown**: Other distributions (not supported for updates)

### Quote Escaping

Commands are executed via `wsl --distribution <name> -e bash -c "<command>"`:
- Double quotes in commands are escaped: `"` → `\\"`
- Quote removal handled in PowerShell using `.Trim('"')`
- Avoids problematic bash command construction

## Example Usage

```powershell
# Update distribution interactively
.\tools\wsl\wsl-manager.ps1 update

# Expected output:
# Available distributions:
#   1. Debian
#   2. Ubuntu-22.04
#
# Enter number or name of the distribution to update: 1
# Updating WSL distribution 'Debian'...
# [apt update and upgrade output]
# Successfully updated 'Debian'.

# Try to update non-Debian/Ubuntu distribution
.\tools\wsl\wsl-manager.ps1 update

# Select Arch distribution
# Expected output:
# Error: Distribution 'Arch' is not a Debian/Ubuntu distribution.
# Only Debian and Ubuntu distributions are supported for updates.

# Interactive menu
.\tools\wsl\wsl-manager.ps1

# Expected menu includes:
# Commands:
#   [C] Create new distribution
#   [L] Clone distribution
#   [U] Update distribution  <-- New option
#   [R] Remove distribution
#   [Q] Quit
```

## Dependencies

- `tools/pslib/wsl.ps1` - WSL utility library
  - `Update-WslDistro` - Main update function
  - `Get-WslDistroType` - Distribution type detection
  - `Invoke-WslDistroCommand` - Command execution in WSL
- `tools/pslib/utils.ps1` - Common utilities
- `tools/wsl/wsl-manager.ps1` - CLI interface
  - `Invoke-UpdateDistro` - Interactive update workflow
