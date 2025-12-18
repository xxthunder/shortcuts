# WSL-000: Interactive Mode

## User Story

**As a** developer using WSL,
**I want** to run wsl-manager without arguments and get an interactive menu,
**So that** I can easily discover and execute available commands without memorizing syntax.

## Acceptance Criteria

- [x] Running `wsl-manager.ps1` without arguments enters interactive mode
- [x] Interactive mode displays a list of installed WSL distributions
- [x] A menu of available commands is shown (create, remove, exit)
- [x] User can select a command by letter (C, R, Q)
- [x] All distribution selections support selection by number or name
- [x] After executing a command, the menu is shown again (loop)
- [x] User can exit the interactive mode by selecting "exit" or pressing Ctrl+C
- [x] If WSL is not installed, an appropriate error message is shown
- [x] In CI environment, interactive mode is skipped with a helpful message
- [x] All commands executed are printed before execution for transparency

## Technical Notes

- Use `Read-Host` for user input
- Use `Write-Host` with colors for better UX
- Check `Test-RunningInCIorTestEnvironment` to skip in CI
- Command-line arguments should bypass interactive mode
- Follow project PowerShell guidelines
- All WSL commands use `Invoke-CommandLine` with `PrintCommand=$true` (default) to display executed commands for transparency and debugging

## Example Usage

```powershell
# Start interactive mode
.\tools\wsl\wsl-manager.ps1

# Expected output:
# ============================================
# WSL Manager
# ============================================
#
# Installed Distributions:
#   1. Debian
#   2. Ubuntu
#   3. MyProject
#
# Commands:
#   [C] Create new Debian distribution
#   [R] Remove distribution
#   [Q] Quit
#
# Select command: _

# After selecting 'C':
# Enter name for new distribution: MyNewProject
# Creating WSL distribution 'MyNewProject' based on Debian...
# Successfully created 'MyNewProject'.
#
# Press Enter to continue ...
```

## Dependencies

- `tools/pslib/wsl.ps1` - WSL utility library
- `tools/pslib/utils.ps1` - Common utilities

## Priority

This is the default entry point, so it should be implemented alongside or before the individual command stories.
