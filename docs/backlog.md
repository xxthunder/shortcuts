# Shortcuts - Backlog

**Version**: 1.0.0 | **Created**: 2026-01-29

This document contains the detailed backlog of tasks, improvements, and bug fixes for the Shortcuts project.

---

## Active Items

### Bugs

*No active bugs*


## Backlog Items

### Enhancements

#### [FEAT-002] Set up Podman as Docker alternative in WSL

**Status**: Open
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Related**: FEAT-001, Dev Container workflow

**Description**:
Add functionality to install and configure Podman as a Docker alternative in WSL distributions. This includes rootless Podman setup, Docker CLI compatibility, and VS Code Dev Containers integration.

**Rationale**:
Podman provides a daemonless, rootless container runtime that's compatible with Docker workflows. It's especially useful for security-conscious environments and can fully replace Docker for Dev Container usage.

**Implementation Steps**:

**Step 1: Install Podman**
- Detect distribution type (Ubuntu, Debian, Fedora, etc.)
- Install Podman using appropriate package manager
- Verify installation and version

**Step 2: Configure Rootless Podman**
- Enable user namespaces if needed
- Set up rootless Podman configuration
- Start Podman socket service:
  ```bash
  systemctl --user enable --now podman.socket
  ```
- Configure socket path for Docker compatibility

**Step 3: Docker CLI Compatibility**
- Create Docker CLI alias/symlink to Podman:
  ```bash
  sudo ln -s /usr/bin/podman /usr/local/bin/docker
  ```
- Or configure shell alias: `alias docker=podman`
- Set `DOCKER_HOST` environment variable for socket access

**Step 4: VS Code Dev Containers Integration**
- Configure Podman socket for VS Code access
- Set up Docker context if needed
- Update `~/.docker/config.json` or equivalent
- Document any VS Code settings required

**Step 5: Documentation**
- Create/update `docs/wsl-podman-setup.md` with:
  - Podman vs Docker comparison
  - Rootless benefits and limitations
  - Troubleshooting common issues
  - Performance considerations
  - Migration guide from Docker

**Acceptance Criteria**:
- [ ] New command in wsl-manager (e.g., `wsl-manager setup-podman <distro>`)
- [ ] Detects and installs Podman for supported distributions
- [ ] Configures rootless Podman with systemd socket
- [ ] Sets up Docker CLI compatibility
- [ ] Verifies Podman works with simple container test
- [ ] VS Code Dev Containers can use Podman
- [ ] Option to choose between rootless and rootful modes
- [ ] Clear error messages if prerequisites missing
- [ ] Documentation in `docs/wsl-podman-setup.md`
- [ ] Unit tests for configuration logic
- [ ] Integration test on fresh WSL distro
- [ ] Handles case where Docker is already installed

**Technical Notes**:
- Ubuntu 20.10+ has native Podman packages
- Earlier versions may need third-party PPAs
- Rootless mode requires systemd and user namespaces
- Some containers may require rootful mode (privileged operations)
- Socket path typically: `unix:///run/user/$UID/podman/podman.sock`
- VS Code may need `"dev.containers.dockerPath": "podman"` setting

**Dependencies**:
- WSL 2
- Systemd-enabled distribution
- User namespace support (for rootless)
- Sudo access for installation

**Related Documentation**:
- https://podman.io/
- https://code.visualstudio.com/docs/devcontainers/containers

### Technical Debt

*No items yet*

### Documentation

*No items yet*

---

## Completed Items

### [BUG-002] ✅ COMPLETED - VS Code WSL Interop Interference Fixed

**Status**: **Completed** (2026-02-03) | **Branch**: `feature/wsl-devcontainer-prep`
**Priority**: High
**Component**: `tools/pslib/wsl/scripts/install-docker.sh`, `tools/pslib/wsl/lib/docker.ps1`

**Problem**:
VS Code's WSL server could overwrite Docker's rc.local-based Windows executable interop configuration, breaking Docker commands and `.exe` execution.

**Solution Implemented**:
Replaced rc.local with kernel-level `/etc/binfmt.d/WSLInterop.conf` configuration managed by `systemd-binfmt.service`. This is a core system service that loads before VS Code and cannot be overridden.

**Implementation**:
- ✅ Modified `install-docker.sh` to use binfmt.d instead of rc.local
- ✅ Added automatic migration from old rc.local configuration
- ✅ Made Docker installation fully idempotent (safe to re-run for repair)
- ✅ Updated integration tests to verify binfmt.d configuration
- ✅ Removed separate "Fix interop" menu option (now part of idempotent Docker setup)
- ✅ All 569 unit tests + 31 integration tests passing

**Repair/Verification**:
Users can verify or repair their Docker installation by simply re-running:
```powershell
wsl-manager setup-docker <distro-name>
```

The idempotent Docker setup will:
- Detect if binfmt.d is already configured (skip if present)
- Migrate from old rc.local to binfmt.d if needed
- Verify all components are working correctly

**Files Modified**:
- `tools/pslib/wsl/scripts/install-docker.sh` - binfmt.d implementation
- `tools/pslib/wsl/lib/docker.ps1` - idempotent wrapper
- `tools/pslib/wsl/wsl-manager.ps1` - simplified menu
- Integration tests - binfmt.d verification

**Commits**:
- `a82c3f1` + `5debe4e` + `ec504ff` - feat(wsl): implement Docker installation with binfmt.d interop and idempotent setup

**Documentation**:
- See `docs/BUG-002-vscode-wsl-interop-fix.md` for technical details
- See `docs/wsl-devcontainer-setup.md` for full setup workflow

---

### [FEAT-001] ✅ COMPLETED - DevContainer Prep → Docker Prerequisites

**Status**: **Completed** (2026-02-02) | **Branch**: `feature/wsl-devcontainer-prep` → PR #18
**Original**: Completed (2026-01-30) | **Refactored**: (2026-01-31) | **Documentation**: (2026-02-02)
**Priority**: Medium
**Component**: `tools/pslib/wsl/lib/docker.ps1`, `tools/pslib/wsl/scripts/install-docker.sh`
**Related**: Docker installation, Dev Container workflow

**Rationale**:
Systemd and Windows interop are Docker prerequisites, not DevContainer-specific.
Consolidated into `Install-WslDockerEngine` for clearer workflow - users just install Docker
and get everything they need automatically.

**Description**:
Originally added standalone DevContainer preparation functionality. Refactored to consolidate
systemd/interop configuration into Docker installation since these are Docker prerequisites.
Completed with comprehensive end-to-end documentation.

**Implementation**:

**Systemd/Interop Configuration**:
- Integrated into `Install-WslDockerEngine` in `docker.ps1`
- Automatically configures if `Test-WslSystemdConfigured` or `Test-WslInteropConfigured` returns false
- Uses `Set-WslConf` function for safe wsl.conf management
- Preserves existing default user configuration
- Restarts distribution after wsl.conf changes

**RC.local Fix**:
- Applied in `install-docker.sh` bash script during Docker installation
- Creates `/etc/systemd/system/rc-local.service.d/override.conf`
- Creates `/etc/rc.local` with binfmt_misc registration
- Enables and starts rc-local.service
- Verification added to check service is enabled

**Essential Packages**:
- Added wget, htop to prerequisite packages (alongside ca-certificates, curl, gnupg)
- Required for VS Code DevContainer usage

**Documentation** (Comprehensive):
- **README.md**: Added "WSL Development Setup" section with quick start and links
- **docs/wsl-devcontainer-setup.md**: Complete 8-step workflow:
  1. Install Debian (Microsoft Store or `wsl --install`)
  2. Update distribution (`wsl-manager update`)
  3. Clone (optional) for isolated environments (`wsl-manager clone`)
  4. Setup user with sudo (`wsl-manager setup-user`)
  5. Install Docker (automated systemd/interop/rc.local/packages via `wsl-manager setup-docker`)
  6. Windows SSH Agent configuration (manual)
  7. Git configuration inside WSL (manual)
  8. VS Code settings (manual)
- **docs/wsl-manager.md**: Updated to reflect actual implementation status
  - Phase 3 describes Docker integration (removed outdated DevContainer prep references)
  - User Story 8 marked as "COMPLETED" (Docker setup in interactive menu)

**Functions Removed** (Consolidated):
- ❌ `Initialize-WslDevContainer` - functionality moved to Docker installation
- ❌ `Invoke-PrepareDevContainerInteractive` - removed from wsl-manager
- ❌ `Invoke-PrepareDevContainer` - removed from wsl-manager
- ✅ `Set-WslConf` - **kept** as general-purpose utility in `user.ps1`

**Acceptance Criteria**:
- [x] Systemd/interop automatically configured during Docker installation
- [x] RC.local fix applied in bash script during Docker installation
- [x] Essential packages (wget, htop) included for VS Code
- [x] Safely modifies /etc/wsl.conf (via Set-WslConf with backups)
- [x] Skips configuration if systemd/interop already configured
- [x] Clear success/error messages
- [x] Complete end-to-end documentation (8-step workflow)
- [x] README.md links to WSL documentation
- [x] wsl-manager.md reflects actual implementation
- [x] Unit tests updated (520 tests passing)
- [x] Old DevContainer prep code removed (cleaner codebase)
- [x] Users just run `wsl-manager setup-docker` and get everything

**Test Coverage**:
- 520 unit tests passing (PowerShell 7.x)
- 31 integration tests passing
- Tests for: Set-WslConf, Docker systemd/interop config, rc.local fix
- Pre-commit hook validation enabled

**Commits**:
- `d6e8a58` - feat(wsl): add Set-WslConf and Initialize-WslDevContainer functions
- `a88782e` - docs(wsl): add comprehensive WSL DevContainer setup guide
- `1a1ffc8` - feat(wsl): add DevContainer preparation to wsl-manager interactive menu
- `aeff01d` - feat(wsl): configure systemd and interop automatically in Docker installation
- `f9f25d4` - feat(wsl): add rc.local fix for Windows executable interop in Docker installation
- `adf01f5` - refactor(wsl): remove standalone DevContainer preparation functionality
- `2dbc043` - docs(wsl): complete FEAT-001 with comprehensive DevContainer workflow documentation

---

### [BUG-001] WSL Manager fails when no distributions are installed

**Status**: Completed
**Priority**: High
**Component**: `tools/pslib/wsl/lib/core.ps1`
**Affected Commit**: `1bbca8a`
**Fixed In**: Next commit

**Description**:
When no WSL distributions are installed, `wsl-manager` crashed with a type conversion error when parsing WSL verbose output that contained informational messages instead of distribution entries.

**Root Cause**:
The parser in `Get-WslDistroList -Detailed` attempted to convert the last field of every non-header line to an integer (the VERSION field). When WSL outputs informational messages like "No distributions found", the parser tried to convert non-numeric text to `[int]`, causing the crash.

**Solution**:
Added validation using `[int]::TryParse()` before attempting to convert the version field. Lines that don't have a valid numeric version are now skipped, allowing the function to gracefully handle informational messages and return an empty array.

**Changes**:
- Modified `Get-WslDistroList` in `tools/pslib/wsl/lib/core.ps1:116-130` to validate version field before parsing
- Added 2 new test cases in `tools/pslib/wsl/lib/core.Tests.ps1` to cover edge cases with no distributions

**Acceptance Criteria Met**:
- [x] No error when running `wsl-manager` with zero distributions installed
- [x] Clear message indicating no distributions are available
- [x] Proper exit handling (gracefully returns empty array)
- [x] Unit tests covering zero-distribution scenario
- [x] All 492 tests pass

---

## Notes

- Use format `[TYPE-###]` for item IDs (e.g., `BUG-001`, `FEAT-001`, `DEBT-001`)
- Link to commits, files, and line numbers where relevant
- Keep items actionable with clear acceptance criteria
