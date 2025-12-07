# WSL-003: Create Distribution

## User Story

**As a** developer using WSL,
**I want** to create a WSL distribution,
**So that** I can have an isolated Linux environment for my projects.

## Acceptance Criteria

- [x] Running `wsl-manager.ps1 create <name>` creates a distribution when name is supported.
- [x] Supported distributions are: Ubuntu, Debian
- [x] If the distribution already exists, an appropriate error message is shown
- [x] If WSL is not installed, an appropriate error message is shown
- [x] Success message is displayed after creation
- [x] The new distribution appears in `wsl-manager.ps1 list`
- [x] Distribution is created without prompting for login or initial user creation

## Technical Notes

- WSL supports multiple distributions, including Ubuntu and Debian
- Workflow:
  1. Check if WSL is installed
  2. Check if the requested distribution is supported
  3. Install the distribution using `wsl --install -d <name> --no-launch`
- The `--no-launch` flag prevents automatic launch and user creation prompts
- Use `wsl --list --online` to verify supported distributions
- Follow project PowerShell guidelines

## Example Usage

```powershell
# Create a new distribution
.\tools\wsl\wsl-manager.ps1 create Debian

# Expected output:
# Creating WSL distribution 'Debian' ...
# Successfully created 'Debian'.
#
# To start: wsl -d Debian

```

## Dependencies

- `tools/pslib/wsl.ps1` - WSL utility library
- `tools/pslib/utils.ps1` - Common utilities
