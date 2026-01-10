# WSL-002: Remove WSL Distribution

## User Story

**As a** developer using WSL,
**I want** to remove an existing WSL distribution,
**So that** I can clean up unused distributions and free disk space.

## Acceptance Criteria

- [x] Running `wsl-manager.ps1 remove` prompts for distribution selection (by number or name) and unregisters it
- [x] User is prompted for confirmation before removal (using PowerShell ShouldProcess)
- [x] If the distribution does not exist, an appropriate error message is shown
- [x] If WSL is not installed, an appropriate error message is shown
- [x] Success message is displayed after removal
- [x] The `-Confirm:$false` flag skips the confirmation prompt

## Technical Notes

- Use `wsl --unregister <name>` to remove distributions
- Verify distribution exists before attempting removal
- In CI environment, skip confirmation prompt
- Follow project PowerShell guidelines

## Example Usage

```powershell
# Remove a distribution interactively
.\tools\wsl\wsl-manager.ps1 remove

# Expected output:
# Available distributions:
#   1. Debian
#   2. MyDebian
#
# Enter the name of the distribution to remove: MyDebian
#
# Confirm
# Are you sure you want to perform this action?
# Performing the operation "Remove WSL distribution" on target "MyDebian".
# [Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): Y
# Removing WSL distribution 'MyDebian'...
# Successfully removed 'MyDebian'.
```

## Dependencies

- `tools/pslib/wsl/wsl.ps1` - WSL utility library
- `tools/pslib/utils/utils.ps1` - Common utilities (Get-UserConfirmation)
