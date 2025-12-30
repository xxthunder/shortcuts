# WSL-003: Create Distribution

## User Story

**As a** developer using WSL,
**I want** to create a WSL distribution,
**So that** I can have an isolated Linux environment for my projects.

## Acceptance Criteria

- [x] Running `wsl-manager.ps1 create <name>` creates a distribution when name is available online
- [x] Supported distributions are determined dynamically via `wsl --list --online`
- [x] If the distribution name is not available, show available options from `wsl --list --online`
- [x] If the distribution already exists, an appropriate error message is shown
- [x] If WSL is not installed, an appropriate error message is shown
- [x] Success message is displayed after creation
- [x] The new distribution appears in `wsl-manager.ps1 list`
- [x] Distribution is created without prompting for login or initial user creation
- [x] Support for all Ubuntu LTS versions (Ubuntu-20.04, Ubuntu-22.04, Ubuntu-24.04)
- [x] Support for any distribution returned by `wsl --list --online`

## Technical Notes

- **Dynamic distribution support**: Query `wsl --list --online` to get available distributions
- **No hardcoded list**: Support any distribution that WSL makes available
- Workflow:
  1. Check if WSL is installed using `Test-WslInstalled`
  2. Query available distributions using `wsl --list --online`
  3. Validate the requested distribution is in the available list
  4. Install the distribution using `wsl --install --distribution <name> --no-launch`
- The `--no-launch` flag prevents automatic launch and user creation prompts
- Parse `wsl --list --online` output to extract distribution names
- Handle encoding issues in WSL output (UTF-16 or similar)
- Follow project PowerShell guidelines and use `Invoke-CommandLine`

### Language Independence

**Critical**: WSL output is localized and varies by system language:

- Headers like "NAME" / "FRIENDLY NAME" will be in the system language
- Example: German system shows "NAME" / "FRIENDLY NAME" in German

**Solution approaches:**

1. **Set English locale** before running WSL commands:

   ```powershell
   $env:LC_ALL = "en_US.UTF-8"
   wsl --list --online
   ```

2. **Parse by pattern** instead of headers:
   - Distribution names are alphanumeric with hyphens/underscores
   - Skip header lines (first 2-3 lines)
   - Extract first column values that match pattern: `^[A-Za-z0-9_.-]+$`
3. **Column-based parsing**:
   - First column contains distribution names (language-independent)
   - Skip lines until a line with valid distribution name pattern appears

**Recommended**: Use approach #1 (set locale) as primary method, with #2 (pattern parsing) as fallback for robustness.

## Example Usage

```powershell
# Create generic Debian distribution
.\tools\wsl\wsl-manager.ps1 create Debian

# Expected output:
# Creating WSL distribution 'Debian' ...
# Successfully created 'Debian'.
# To start: wsl --distribution Debian

# Create Ubuntu 22.04 LTS
.\tools\wsl\wsl-manager.ps1 create Ubuntu-22.04

# Expected output:
# Creating WSL distribution 'Ubuntu-22.04' ...
# Successfully created 'Ubuntu-22.04'.
# To start: wsl --distribution Ubuntu-22.04

# Create with invalid distribution name
.\tools\wsl\wsl-manager.ps1 create InvalidDistro

# Expected output:
# Error: Distribution 'InvalidDistro' is not available.
# Available distributions:
#   - Debian
#   - Ubuntu
#   - Ubuntu-20.04
#   - Ubuntu-22.04
#   - Ubuntu-24.04
#   - kali-linux
#   - archlinux
#   (... and more)
#
# Run 'wsl --list --online' to see all available distributions.
```

## Dependencies

- `tools/pslib/wsl.ps1` - WSL utility library
- `tools/pslib/utils.ps1` - Common utilities
