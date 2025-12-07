# WSL-004: Create Debian Distribution with Custom Name

## User Story

**As a** developer using WSL,
**I want** to create a new Debian-based WSL distribution with a custom name,
**So that** I can have multiple isolated Debian environments for different projects.

## Acceptance Criteria

- [ ] Running `wsl-manager.ps1 create <name>` creates a new Debian-based distribution
- [ ] The distribution is created with the specified custom name
- [ ] If a distribution with that name already exists, an appropriate error message is shown
- [ ] If WSL is not installed, an appropriate error message is shown
- [ ] If Debian base is not available, it is installed first
- [ ] Success message is displayed after creation
- [ ] The new distribution appears in `wsl-manager.ps1 list`

## Technical Notes

- WSL allows exporting and importing distributions to create copies
- Workflow:
  1. Ensure Debian base distribution exists (install if needed)
  2. Export Debian to a temporary tar file
  3. Import the tar file with the custom name
  4. Clean up temporary files
- Use `wsl --export` and `wsl --import` commands
- Default install location: `%USERPROFILE%\wsl\<name>`
- Follow project PowerShell guidelines

## Example Usage

```powershell
# Create a new Debian distribution with custom name
.\tools\wsl\wsl-manager.ps1 create MyProject

# Expected output:
# Creating WSL distribution 'MyProject' based on Debian...
# Exporting Debian base...
# Importing as 'MyProject'...
# Successfully created 'MyProject'.
#
# To start: wsl -d MyProject

# Create with custom install location
.\tools\wsl\wsl-manager.ps1 create MyProject -InstallPath "D:\WSL\MyProject"
```

## Dependencies

- `tools/pslib/wsl.ps1` - WSL utility library
- `tools/pslib/utils.ps1` - Common utilities
- Debian distribution (will be installed if not present)
