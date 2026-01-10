# WSL-007: Setup Docker

## User Story

**As a** developer using WSL,
**I want** to install Docker Engine in my WSL distribution with a single command,
**So that** I can run containers for development without manual Docker setup.

## Acceptance Criteria

- [x] Docker setup available via CLI command (`wsl-manager.ps1 setup-docker <distroname>`)
- [x] Docker setup available via interactive menu option `[D] Setup Docker`
- [x] Only Ubuntu/Debian (apt-based) distributions supported initially
- [x] Validates WSL2 version (fails if WSL1)
- [x] Requires systemd configured in `/etc/wsl.conf` (prerequisite):

  ```ini
  [boot]
  systemd=true
  ```

- [x] Validates systemd support (fails if not available/enabled)
- [x] Requires default user configured in `/etc/wsl.conf` (prerequisite: wsl-006)
- [x] Auto-detects default user from `/etc/wsl.conf` and adds to `docker` group
- [x] Checks if Docker is already installed (fails with clear message)
- [x] Installs required prerequisites before Docker setup:
  - `ca-certificates` (SSL certificate validation)
  - `curl` (Download tool for GPG keys and scripts)
  - `gnupg` (GPG key verification)
  - `lsb-release` (Distribution information)
  - `wget` (Alternative download tool)
- [x] Installs Docker Engine components:
  - `docker-ce` (Docker Engine)
  - `docker-ce-cli` (Docker CLI)
  - `containerd.io` (Container runtime)
  - `docker-compose-plugin` (Docker Compose v2)
  - `docker-buildx-plugin` (Build capabilities)
- [x] Configures Docker daemon to start with systemd
- [x] Verifies installation comprehensively:
  - `docker --version` (Docker Engine version)
  - `docker compose version` (Compose plugin version)
  - `systemctl status docker` (Service running)
  - `docker run hello-world` (End-to-end test)
- [x] Supports `-Confirm` parameter (SupportsShouldProcess)
- [x] Clear error messages for:
  - Non-Debian/Ubuntu distributions
  - WSL1 distributions
  - Missing systemd support
  - No default user configured
  - Docker already installed
  - Insufficient disk space
  - Network/download failures
- [x] Success message with next steps (re-login for group membership)
- [x] Non-interactive (CI) mode: skip confirmations, fail if prerequisites missing

## Technical Notes

**Prerequisites validation (fail-fast approach):**

```powershell
# 1. Check WSL2 (not WSL1)
wsl -l -v | Select-String $distroName
# Parse VERSION column, must be "2"

# 2. Check systemd support (both installed AND enabled)
wsl --distribution $distroName systemctl --version
# Must exit with code 0 (fails if systemd not running)

# 3. Detect default user (REQUIRED - must be configured via wsl-006 first)
wsl --distribution $distroName cat /etc/wsl.conf | grep -A2 "\[user\]" | grep "default"
# Must return a username, not empty
# If missing, direct user to run: wsl-manager.ps1 setup-user <distroname>

# 4. Check if Docker already installed
wsl --distribution $distroName docker --version
# If exits with 0, Docker exists - fail with message to avoid conflicts

# 5. Check distribution type (Debian/Ubuntu only)
# Use existing Get-WslDistroType function
# Must return "debian" or "ubuntu"
```

**Disk space requirements:**

- Docker Engine installation: ~500MB
- Docker images will consume additional space
- Recommend at least 5GB free space for practical use
- No automated disk space check (relies on apt failures if insufficient)

**Installation workflow (Ubuntu/Debian):**

```bash
# 1. Remove old Docker versions
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# 2. Update and install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release wget

# 3. Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 4. Set up Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Add user to docker group (use detected default user)
sudo usermod -aG docker $USERNAME

# 7. Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# 8. Verify installation comprehensively
# Check Docker Engine version
sudo docker --version

# Check Docker Compose plugin version
sudo docker compose version

# Check Docker service status
sudo systemctl status docker --no-pager

# Run hello-world container (end-to-end test)
sudo docker run hello-world
```

**Functions:**

- `Install-WslDockerEngine` - Library function in `wsl.ps1`
  - Parameters:
    - `-DistroName` (required): Name of WSL distribution
    - `-Username` (optional): User to add to docker group (auto-detected from wsl.conf if not provided)
    - `-Confirm` (optional): Prompt for confirmation before installation (default: $true)
  - Uses `[CmdletBinding(SupportsShouldProcess)]` for -Confirm support
  - Validation: WSL2, systemd, distro type, default user exists, Docker not already installed
  - Installation: Full Docker Engine setup
  - Returns: Success/failure status
- `Invoke-SetupDocker` - CLI wrapper in `wsl-manager.ps1`
  - Interactive prompts for distribution selection
  - Calls `Install-WslDockerEngine`
  - Passes `-Confirm:$false` for non-interactive flow
  - Displays progress and results

**Helper functions needed:**

- `Get-WslDefaultUser` - Read default user from `/etc/wsl.conf`
  - Returns username string or `$null` if not configured
  - Reads `[user]` section, extracts `default=<username>`
- `Test-WslSystemd` - Check if systemd is available and running
  - Runs `systemctl --version` in distribution
  - Returns `$true` if systemd is operational, `$false` otherwise
- `Test-Wsl2Version` - Validate distribution is using WSL2 (not WSL1)
  - Parses `wsl -l -v` output
  - Returns `$true` for WSL2, `$false` for WSL1
- `Test-WslDockerInstalled` - Check if Docker is already installed
  - Runs `docker --version` in distribution
  - Returns `$true` if Docker exists, `$false` otherwise

**Error handling:**

- **Pre-installation validation** (fail-fast with actionable errors):
  - WSL not installed → Direct to WSL installation docs
  - Distribution doesn't exist → Show available distributions
  - WSL1 detected → Provide `wsl --set-version` command
  - Systemd not available → Provide wsl.conf configuration instructions
  - No default user → Direct to `wsl-manager.ps1 setup-user <distroname>`
  - Docker already installed → Suggest uninstall or skip setup
  - Not Debian/Ubuntu → List supported distributions
- **During installation**:
  - Network failures → Suggest checking connectivity, provide manual steps
  - apt errors → Display full error, suggest checking package availability
  - GPG key failures → Verify network access to download.docker.com
- **Post-installation**:
  - Service won't start → Check systemd status, provide troubleshooting steps
  - hello-world fails → Verify service running, check Docker daemon logs
- **CI mode**: All errors fail immediately without prompts, clear error messages for automation logs

**Confirmation workflow (SupportsShouldProcess):**

- Function uses `[CmdletBinding(SupportsShouldProcess)]`
- Default behavior: Prompts for confirmation before installation
- Confirmation message includes:
  - Distribution name
  - What will be installed
  - Approximate disk space required (~500MB)
- Skip confirmation with `-Confirm:$false` (useful for automation)
- Interactive CLI wrapper (`Invoke-SetupDocker`) uses `-Confirm:$false` for streamlined UX
- CI mode: Automatically passes `-Confirm:$false`

**User group membership:**

- Adding user to `docker` group requires re-login to take effect
- Inform user they need to exit and re-enter WSL:

  ```powershell
  wsl --terminate <distroname>
  wsl --distribution <distroname>
  ```

- Test command: `docker ps` (should work without sudo after re-login)

## Example Usage

```powershell
# Setup Docker on existing distribution (via direct command)
.\tools\wsl\wsl-manager.ps1 setup-docker Ubuntu-22.04

# Expected output:
# Validating prerequisites for 'Ubuntu-22.04'...
#   ✓ WSL2 detected
#   ✓ Systemd available
#   ✓ Docker not already installed
#   ✓ Default user: developer
#   ✓ Disk space available
#
# Installing Docker Engine...
#   → Removing old Docker versions
#   → Installing prerequisites
#   → Adding Docker GPG key
#   → Configuring Docker repository
#   → Installing Docker packages
#   → Adding user 'developer' to docker group
#   → Enabling Docker service
#   → Starting Docker service
#
# Verifying installation...
#   ✓ Docker Engine: 24.0.7
#   ✓ Docker Compose: v2.23.3
#   ✓ Docker service: active (running)
#   ✓ Hello-world test: passed
#
# Successfully installed Docker in 'Ubuntu-22.04'.
#
# Next steps:
#   1. Restart the distribution to apply group membership:
#        wsl --terminate Ubuntu-22.04
#        wsl --distribution Ubuntu-22.04
#   2. Test Docker (should work without sudo):
#        docker ps
#        docker run hello-world

# Interactive menu
.\tools\wsl\wsl-manager.ps1
# Select: [D] Setup Docker
# Then select distribution from list

# Error: WSL1 distribution
.\tools\wsl\wsl-manager.ps1 setup-docker OldDebian
# Error: Distribution 'OldDebian' is using WSL1.
# Docker requires WSL2. Upgrade with:
#   wsl --set-version OldDebian 2

# Error: No systemd
.\tools\wsl\wsl-manager.ps1 setup-docker CustomDistro
# Error: Distribution 'CustomDistro' does not support systemd.
# Docker Engine requires systemd for service management.
# Enable systemd in /etc/wsl.conf:
#   [boot]
#   systemd=true

# Error: Not Debian/Ubuntu
.\tools\wsl\wsl-manager.ps1 setup-docker Arch
# Error: Distribution 'Arch' is not a Debian/Ubuntu distribution.
# Only Debian and Ubuntu distributions are currently supported for Docker setup.

# Error: Docker already installed
.\tools\wsl\wsl-manager.ps1 setup-docker Ubuntu-22.04
# Error: Docker is already installed in 'Ubuntu-22.04'.
# Current version: Docker version 24.0.7, build afdd53b
#
# To reinstall Docker:
#   1. Uninstall existing Docker:
#        wsl --distribution Ubuntu-22.04 sudo apt-get remove docker-ce docker-ce-cli containerd.io
#   2. Run setup-docker again
#
# Or verify your installation with:
#   docker --version
#   docker compose version

# Error: No default user configured
.\tools\wsl\wsl-manager.ps1 setup-docker Debian
# Error: No default user configured in 'Debian'.
# Docker setup requires a non-root user to add to the docker group.
#
# Please setup a user first:
#   .\tools\wsl\wsl-manager.ps1 setup-user Debian
#
# Then run setup-docker again.

# With -Confirm parameter (prompts for confirmation)
.\tools\wsl\wsl-manager.ps1 setup-docker Ubuntu-22.04
# Confirm
# Are you sure you want to install Docker Engine in 'Ubuntu-22.04'?
# This will install Docker CE, Docker Compose, and related packages (~500MB).
# [Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"):

# Skip confirmation (for automation)
Install-WslDockerEngine -DistroName "Ubuntu-22.04" -Confirm:$false
```

## Security Considerations

- **Docker group membership**: Users in `docker` group have root-equivalent access
- This is acceptable for development environments
- Production: Consider rootless Docker or stricter access controls
- GPG key verification: Official Docker GPG key validated during installation

## Dependencies

**Prerequisites:**

- **wsl-006 (Setup User)**: Distribution must have a default user configured in `/etc/wsl.conf`
  - User created via `wsl-manager.ps1 setup-user <distroname>`
  - User must have sudo privileges (configured in wsl-006)
  - This user will be added to the docker group

**Code dependencies:**

- `tools/pslib/wsl/wsl.ps1` - WSL utility library
  - `Install-WslDockerEngine` - Main Docker installation function (new)
  - `Get-WslDistroType` - Distribution type detection (existing)
  - `Get-WslDefaultUser` - Read default user from wsl.conf (new helper)
  - `Test-WslSystemd` - Check systemd availability (new helper)
  - `Test-Wsl2Version` - Check WSL2 vs WSL1 (new helper)
  - `Test-WslDockerInstalled` - Check if Docker exists (new helper)
  - `Invoke-WslDistroCommand` - Command execution in WSL (existing)
- `tools/pslib/utils/utils.ps1` - Common utilities
  - `Test-RunningInCIorTestEnvironment` - CI/test environment detection (existing)
- `tools/pslib/wsl/wsl-manager.ps1` - CLI interface
  - `Invoke-SetupDocker` - Interactive Docker setup workflow (new)

## Implementation Tasks

### Phase 1: Helper Functions (TDD Approach)

- [x] Write tests for `Get-WslDefaultUser` helper function
- [x] Implement `Get-WslDefaultUser` in `tools/pslib/wsl/wsl.ps1`
- [x] Write tests for `Test-WslSystemd` helper function
- [x] Implement `Test-WslSystemd` in `tools/pslib/wsl/wsl.ps1`
- [x] Write tests for `Test-Wsl2Version` helper function
- [x] Implement `Test-Wsl2Version` in `tools/pslib/wsl/wsl.ps1`
- [x] Write tests for `Test-WslDockerInstalled` helper function
- [x] Implement `Test-WslDockerInstalled` in `tools/pslib/wsl/wsl.ps1`
- [x] Run unit tests for all helper functions and verify they pass

### Phase 2: Main Installation Function

- [x] Write tests for `Install-WslDockerEngine` main function
- [x] Implement `Install-WslDockerEngine` with prerequisite validation
- [x] Implement Docker installation workflow in `Install-WslDockerEngine`
- [x] Implement post-installation verification in `Install-WslDockerEngine`
- [x] Run unit tests for `Install-WslDockerEngine` and verify they pass

### Phase 3: CLI Integration

- [x] Implement `Invoke-SetupDocker` CLI wrapper in `wsl-manager.ps1`
- [x] Add `setup-docker` command to `wsl-manager.ps1` switch statement
- [x] Add `[D] Setup Docker` option to interactive menu in `wsl-manager.ps1`

### Phase 4: Testing & Documentation

- [x] Run full unit test suite and ensure all tests pass
- [x] Perform manual integration testing with real WSL distribution
- [x] Update acceptance criteria checkboxes in this document

### TDD Workflow (per function)

```bash
# 1. Write test (RED)
# Edit: tools/pslib/wsl.Tests.ps1

# 2. Run test - should FAIL
pwsh -File ".\test\bin\test.ps1" -Unit

# 3. Implement function (GREEN)
# Edit: tools/pslib/wsl/wsl.ps1

# 4. Run test - should PASS
pwsh -File ".\test\bin\test.ps1" -Unit

# 5. Refactor if needed (REFACTOR)

# 6. Commit together
git add tools/pslib/wsl/wsl.ps1 tools/pslib/wsl.Tests.ps1
git commit -m "feat: add function-name"
```

### Integration Testing Checklist

Test with real WSL distributions to verify:

- [x] Fresh Ubuntu-22.04 (happy path) - full installation works
- [x] Distribution without default user - error message directs to setup-user
- [x] WSL1 distribution - error message provides upgrade command
- [x] Distribution without systemd - error message shows wsl.conf configuration
- [x] Docker already installed - error message shows current version and uninstall steps
- [x] Non-Debian/Ubuntu distribution - error message lists supported distros
- [x] Confirmation prompt works correctly (with `-Confirm` parameter)
- [x] CI mode skips confirmations (`-Confirm:$false`)

## Future Enhancements (out of scope for wsl-007)

- Support for Arch Linux (pacman)
- Support for RHEL/Fedora (dnf/yum)
- Optional: Install Docker Desktop integration instead
- Optional: Configure Docker daemon settings (bridge network, storage driver)
- Optional: Install additional tools (docker-scan, dive, etc.)
- Optional: Setup Docker Compose standalone (v1) for backwards compatibility
