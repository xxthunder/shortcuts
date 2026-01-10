# WSL-001: List WSL Distributions

## User Story

**As a** developer using WSL,
**I want** to see a list of all installed WSL distributions,
**So that** I can quickly identify which distributions are available on my system.

## Acceptance Criteria

- [x] Running `wsl-manager.ps1 list` displays all installed WSL distributions
- [x] Each distribution shows its name
- [x] The output is clear and readable
- [x] If no distributions are installed, a helpful message is displayed
- [x] If WSL is not installed, an appropriate error message is shown

## Technical Notes

- Use `Get-WslDistroList` from `tools/pslib/wsl/wsl.ps1`
- Handle UTF-16 encoding issues in WSL output
- Follow project PowerShell guidelines

## Example Usage

```powershell
# List all distributions
.\tools\wsl\wsl-manager.ps1 list

# Expected output:
# Installed WSL Distributions:
# - Debian
# - Ubuntu
# - Alpine
```

## Dependencies

- `tools/pslib/wsl/wsl.ps1` - WSL utility library
- `tools/pslib/utils/utils.ps1` - Common utilities
