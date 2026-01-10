# WSL-004: Clone WSL Distribution with Custom Name

## User Story

**As a** developer using WSL,
**I want** to clone an existing WSL distribution with a custom name,
**So that** I can have multiple isolated environments based on any of my installed distributions for different projects.

## Acceptance Criteria

- [x] Running `wsl-manager.ps1 clone <source> <name>` creates a copy of an existing distribution
- [x] The new distribution is created with the specified custom name
- [x] Any installed WSL distribution can be used as the source
- [x] If the source distribution doesn't exist, an appropriate error message is shown
- [x] If a distribution with the target name already exists, an appropriate error message is shown
- [x] If WSL is not installed, an appropriate error message is shown
- [x] Success message is displayed after cloning
- [x] The new distribution appears in `wsl-manager.ps1 list`
- [x] The cloned distribution is independent (changes don't affect the source)

## Technical Notes

- WSL allows exporting and importing distributions to create copies
- Workflow:
  1. Verify source distribution exists
  2. Verify target name is available
  3. Export source distribution to a temporary tar file
  4. Import the tar file with the custom name
  5. Clean up temporary files
- Use `wsl --export` and `wsl --import` commands
- Default install location: `%USERPROFILE%\wsl\<name>`
- The export/import process creates a full copy at the filesystem level
- Follow project PowerShell guidelines

## Example Usage

```powershell
# Clone an existing Debian distribution
.\tools\wsl\wsl-manager.ps1 clone Debian MyProject

# Expected output:
# Cloning WSL distribution 'Debian' to 'MyProject'...
# Exporting 'Debian'...
# Importing as 'MyProject'...
# Successfully cloned 'Debian' to 'MyProject'.
#
# To start: wsl --distribution MyProject

# Clone with custom install location
.\tools\wsl\wsl-manager.ps1 clone Ubuntu-22.04 ProjectX -InstallPath "D:\WSL\ProjectX"

# Clone any installed distribution
.\tools\wsl\wsl-manager.ps1 clone kali-linux PenTestEnv
```

## Dependencies

- `tools/pslib/wsl/wsl.ps1` - WSL utility library
- `tools/pslib/utils/utils.ps1` - Common utilities
- Source WSL distribution must be installed and available
