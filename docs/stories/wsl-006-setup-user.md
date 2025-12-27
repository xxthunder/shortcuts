# WSL-006: Setup User Account

## User Story

**As a** developer using WSL,
**I want** to create a default user account with sudo privileges in my WSL distribution,
**So that** I can work with a non-root user that has proper permissions and doesn't require password for sudo.

## Acceptance Criteria

- [x] User setup available via CLI command (`wsl-manager.ps1 setup-user <distroname>`)
- [x] User setup available via interactive menu option
- [x] User is prompted for username and password interactively
- [x] Username validation follows Linux standards:
  - Must start with lowercase letter or underscore
  - Can only contain lowercase letters, numbers, underscores, and hyphens
  - Maximum 32 characters
  - Case-sensitive validation
- [x] Password can be entered securely (hidden input)
- [x] Created user has a home directory (`/home/<username>`)
- [x] User is added to sudo group
- [x] Sudo configured with NOPASSWD (no password required for sudo commands)
- [x] User is set as default user in `/etc/wsl.conf`
- [x] Success message displays with instructions to restart distribution
- [x] Non-interactive (CI) mode skips user creation prompt
- [x] If user already exists, appropriate error message is shown
- [x] Function supports both SecureString and plain text passwords for flexibility

## Technical Notes

- **User creation workflow**: Standalone command invoked separately after distribution creation
- **Functions**:
  - `New-WslUser` - Library function for user creation with full configuration
  - `Invoke-SetupUser` - CLI wrapper for interactive user setup
  - `Invoke-SetupUserInteractive` - Interactive menu handler that prompts for distribution selection
- User creation steps:
  1. Validate username pattern and length
  2. Check if user already exists via `id -u <username>`
  3. Create user: `sudo useradd -m -s /bin/bash <username>`
  4. Set password: `echo "<username>:<password>" | sudo chpasswd`
  5. Add to sudo group: `sudo usermod -aG sudo <username>`
  6. Configure NOPASSWD: Create `/etc/sudoers.d/<username>` with `<username> ALL=(ALL) NOPASSWD:ALL`
  7. Set default user: Create `/etc/wsl.conf` with `[user]` and `default=<username>`
  8. Instruct user to restart: `wsl --terminate <distroname>`
- Password handling:
  - Interactive: Use `Read-Host -AsSecureString` for secure input
  - Function accepts both `SecureString` and plain text for flexibility
  - Plain text only used internally for `chpasswd` command
- Uses `SupportsShouldProcess` for confirmation support
- Commands executed via `Invoke-WslDistroCommand` with `PrintCommand=$false` for sensitive operations

### Username Validation

Linux username requirements (POSIX standard):

- **Pattern**: `^[a-z_][a-z0-9_-]*$`
- Must start with lowercase letter or underscore
- Can contain: lowercase letters (a-z), numbers (0-9), underscore (_), hyphen (-)
- Cannot contain: uppercase letters, spaces, special characters
- Maximum length: 32 characters

**Important**: Use `-cnotmatch` operator for case-sensitive regex matching in PowerShell (default `-notmatch` is case-insensitive).

### Sudoers Configuration

Create `/etc/sudoers.d/<username>` with proper permissions:

```bash
echo "<username> ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/<username> > /dev/null
sudo chmod 0440 /etc/sudoers.d/<username>
```

Permissions must be 0440 (read-only for owner and group) for security.

### WSL Configuration

Create or update `/etc/wsl.conf`:

```ini
[user]
default=<username>
```

After updating wsl.conf, the distribution must be restarted:

```powershell
wsl --terminate <distroname>
```

## Example Usage

```powershell
# 1. Create new distribution first
.\tools\wsl\wsl-manager.ps1 create Debian
# Creating WSL distribution 'Debian' ...
# Successfully created 'Debian'.
# To start: wsl -d Debian

# 2. Setup user account separately (via direct command)
.\tools\wsl\wsl-manager.ps1 setup-user Debian
# Enter username: john
# Enter password: ********
#
# Creating user 'john' in distribution 'Debian'...
# Successfully created user 'john' in 'Debian'.
#
# To apply the default user change, restart the distribution with:
#   wsl --terminate Debian

# Alternative: Use interactive menu
.\tools\wsl\wsl-manager.ps1
# Select: [S] Setup user account
# Then select distribution from list

# Direct library function usage
$securePass = Read-Host -AsSecureString -Prompt "Enter password"
New-WslUser -DistroName "Debian" -Username "developer" -Password $securePass -Confirm:$false

# With plain text password (for automation)
New-WslUser -DistroName "Ubuntu" -Username "builduser" -Password "temppass123" -Confirm:$false

# Invalid username examples
New-WslUser -DistroName "Debian" -Username "JohnDoe" -Password "pass"
# Error: Invalid username 'JohnDoe'. Username must start with a lowercase letter...

New-WslUser -DistroName "Debian" -Username "user@domain" -Password "pass"
# Error: Invalid username 'user@domain'. Username must start with a lowercase letter...

New-WslUser -DistroName "Debian" -Username "averylongusernamethatexceedsthirtytwocharacters" -Password "pass"
# Error: Username 'averylongusernamethatexceedsthirtytwocharacters' is too long. Maximum length is 32 characters.
```

## Security Considerations

- **Password handling**:
  - Use `Read-Host -AsSecureString` for interactive input
  - SecureString converted to plain text only when needed for `chpasswd`
  - Password not printed in command output (`PrintCommand=$false`)
- **Sudoers file**:
  - Proper permissions (0440) enforced
  - Individual file per user in `/etc/sudoers.d/`
  - NOPASSWD for convenience in development environments
- **PSScriptAnalyzer suppressions**:
  - `PSAvoidUsingUsernameAndPasswordParams`: Function supports both SecureString and plain text
  - `PSAvoidUsingPlainTextForPassword`: Intentional for flexibility, SecureString properly handled

## Dependencies

- `tools/pslib/wsl.ps1` - WSL utility library
  - `New-WslUser` - Main user creation function
  - `Invoke-WslDistroCommand` - Command execution in WSL
- `tools/pslib/utils.ps1` - Common utilities
  - `Test-RunningInCIorTestEnvironment` - CI/test environment detection
- `tools/wsl/wsl-manager.ps1` - CLI interface
  - `Invoke-SetupUser` - Interactive user setup workflow for specified distribution
  - `Invoke-SetupUserInteractive` - Interactive menu handler with distribution selection
