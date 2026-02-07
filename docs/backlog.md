# Backlog

## IN PROGRESS

## TODO

### [FEAT-003] Migrate from Keypirinha to Flow Launcher

**Status**: Open
**Priority**: High
**Component**: `links/`, `bin/install.ps1`, `README.md`, documentation
**Type**: Major Refactoring / Modernization

**Description**:
Replace Keypirinha launcher integration with Flow Launcher, a modern, actively maintained alternative with better plugin ecosystem and ongoing Windows 11+ support.

**Rationale**:
- **Keypirinha is abandoned**: Last update in 2021, no development since 2020
- **Risk mitigation**: Unmaintained software poses security and compatibility risks
- **Future-proof**: Flow Launcher has active development and community
- **Better extensibility**: Modern plugin system with built-in plugin store
- **Industry recommendation**: Flow Launcher is the #1 recommended Keypirinha alternative

**Current State**:
- Shortcuts defined as `.url` files in `links/` directory
- README instructions reference Keypirinha catalog refresh
- Installation assumes Keypirinha is installed
- Works but no guarantee of future Windows compatibility

**Proposed Solution**:

**Phase 1: Research & Planning**
1. Install Flow Launcher and explore integration options
2. Determine how to replicate `.url` file functionality
3. Identify Flow Launcher's equivalent to Keypirinha's catalog system
4. Document migration strategy for existing shortcuts

**Phase 2: Implementation**
1. Update `bin/install.ps1`:
   - Remove Keypirinha from `scoopfile.json` (if present)
   - Add Flow Launcher installation (via Scoop or direct install)
   - Add Flow Launcher configuration setup
2. Migrate shortcuts from `links/`:
   - Convert `.url` files to Flow Launcher format
   - Test each shortcut works in Flow Launcher
   - Consider: Keep `links/` structure or move to Flow Launcher plugins?
3. Create Flow Launcher configuration:
   - Set up default hotkeys
   - Configure plugin settings
   - Add custom shortcuts/commands

**Phase 3: Documentation**
1. Update `README.md`:
   - Replace Keypirinha references with Flow Launcher
   - Update installation instructions
   - Update usage guide (hotkeys, catalog refresh → plugin refresh)
2. Add `docs/flow-launcher-setup.md`:
   - Detailed setup guide
   - Migration guide for existing Keypirinha users
   - Troubleshooting common issues
3. Update all references in other documentation

**Phase 4: Cleanup**
1. Remove Keypirinha-specific code and configurations
2. Archive old `.url` files (or remove if migrated)
3. Update CI/testing if needed

**Acceptance Criteria**:
- [ ] Flow Launcher installed via `bin/install.ps1`
- [ ] All existing shortcuts work in Flow Launcher
- [ ] No Keypirinha references in code or documentation
- [ ] `README.md` updated with Flow Launcher instructions
- [ ] `docs/flow-launcher-setup.md` created with setup guide
- [ ] Migration tested on fresh Windows installation
- [ ] User can trigger shortcuts with same/better UX than Keypirinha
- [ ] Clear migration path for existing users documented
- [ ] All tests pass after migration

**Technical Notes**:
- Flow Launcher installation:
  - Available via Scoop: `scoop install extras/flow-launcher`
  - Or direct download: https://www.flowlauncher.com/
- Flow Launcher uses JSON-based plugin system
- Default hotkey: Alt+Space (configurable)
- Plugin API documentation: https://www.flowlauncher.com/docs/
- May need to create custom Flow Launcher plugin for project-specific shortcuts

**Migration Impact**:
- **Breaking change for existing users**: They must install Flow Launcher
- **Documentation update required**: All user-facing docs need updates
- **Testing effort**: Verify all shortcuts work in new launcher
- **Opportunity**: Can leverage Flow Launcher's richer plugin ecosystem

**Risks**:
- Flow Launcher may have different behavior/limitations
- Custom shortcuts might require plugin development
- Users must manually uninstall Keypirinha (document this)
- Learning curve for users familiar with Keypirinha

**Dependencies**:
- Flow Launcher availability via Scoop or direct download
- Windows 10/11 (Flow Launcher requirement)

**Related Resources**:
- https://www.flowlauncher.com/
- https://github.com/Flow-Launcher/Flow.Launcher
- https://alternativeto.net/software/keypirinha/ (alternatives comparison)

---

### [FEAT-004] Refactor install.ps1 with Mandatory/Optional Tools and Idempotent Functions

**Status**: Open
**Priority**: Medium
**Component**: `scoopfile.json`, `bin/install.ps1`, `.bootstrap/bootstrap.ps1`
**Type**: Feature / Refactoring
**Related**: DEBT-001 (Bootstrap removal), FEAT-003 (Flow Launcher)

**Description**:
Refactor `install.ps1` into a dot-sourceable, self-complete script with idempotent functions. Split tools into mandatory (minimal essential) and optional (recommended) sets. Enable both standalone execution and function reuse via wrappers/Flow Launcher.

**Rationale**:
- **Minimal mandatory set**: Only essential tools (lessmsi, 7zip, innounp, dark, git, Flow Launcher)
- **User choice**: Optional tools can be installed on demand
- **Reusability**: Dot-source install.ps1 to call functions from wrappers/Flow Launcher
- **Idempotency**: Functions can be re-run safely for repair/updates
- **Self-complete**: No external dependencies (works via `Invoke-RestMethod`)

**Design Requirements**:

**1. Self-Complete Script**
- No dependencies on other files (can be downloaded and run standalone)
- Must work when invoked via:
  ```powershell
  Invoke-RestMethod https://raw.githubusercontent.com/.../install.ps1 | Invoke-Expression
  ```

**2. Dot-Sourceable Architecture**
- Can be dot-sourced to expose functions:
  ```powershell
  . .\install.ps1
  Install-Scoop
  Install-MandatoryTools
  Install-OptionalTools
  ```
- Wrapper scripts and Flow Launcher can call individual functions

**3. Idempotent Functions**
- All functions safe to re-run (check state before acting)
- Example: `Install-Scoop` checks if already installed before installing
- Example: `Install-MandatoryTools` skips already-installed tools

**Tool Categorization**:

**Mandatory (scoop_mandatory.json)**:
- `lessmsi` - MSI extraction
- `7zip` - Archive handling
- `innounp` - Inno Setup extraction
- `dark` - WiX toolset
- `git` - Version control (essential)
- `flow-launcher` - Launcher integration (from extras bucket)

**Optional (scoop_optional.json)**:
- Everything else currently in `scoopfile.json`

**Proposed Solution**:

**Phase 1: Extract and Consolidate Functions**
1. Move `Install-Scoop` from `.bootstrap/bootstrap.ps1` to `install.ps1`
2. Make `Install-Scoop` idempotent:
   ```powershell
   function Install-Scoop {
       if (Get-Command scoop -ErrorAction SilentlyContinue) {
           Write-Information "Scoop already installed, skipping"
           return
       }
       # Install scoop logic
   }
   ```
3. Create idempotent functions:
   - `Install-Scoop`
   - `Install-MandatoryTools`
   - `Install-OptionalTools`
   - `Test-ScoopInstalled` (helper)

**Phase 2: Create Tool Definition Files**
1. Create `scoop_mandatory.json`:
   ```json
   {
     "buckets": [
       { "Name": "extras" }
     ],
     "apps": [
       { "Name": "lessmsi" },
       { "Name": "7zip" },
       { "Name": "innounp" },
       { "Name": "dark" },
       { "Name": "git" },
       { "Name": "flow-launcher", "Source": "extras" }
     ]
   }
   ```
2. Create `scoop_optional.json` with remaining tools

**Phase 3: Implement install.ps1 Structure**
```powershell
#Requires -Version 5.1

# Self-complete, dot-sourceable installation script
# Can be invoked standalone or dot-sourced for function reuse

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# === Helper Functions ===

function Test-ScoopInstalled {
    return $null -ne (Get-Command scoop -ErrorAction SilentlyContinue)
}

function Test-RunningInCIorTestEnvironment {
    # Inline implementation (self-complete requirement)
    return $null -ne $env:CI
}

# === Core Functions ===

function Install-Scoop {
    [CmdletBinding()]
    param()

    if (Test-ScoopInstalled) {
        Write-Information "Scoop already installed"
        return
    }

    if (Test-RunningInCIorTestEnvironment) {
        # Auto-install in CI
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    } else {
        # Interactive prompt
        $response = Read-Host "Scoop is not installed. Install it now? (Y/N)"
        if ($response -match '^[Yy]') {
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        } else {
            Write-Error "Scoop is required. Exiting."
            exit 1
        }
    }
}

function Install-MandatoryTools {
    [CmdletBinding()]
    param()

    if (-not (Test-ScoopInstalled)) {
        Write-Error "Scoop must be installed first"
        exit 1
    }

    $mandatoryJson = Join-Path $PSScriptRoot "scoop_mandatory.json"
    if (Test-Path $mandatoryJson) {
        Write-Information "Installing mandatory tools..."
        scoop import $mandatoryJson
    } else {
        Write-Warning "scoop_mandatory.json not found, skipping"
    }
}

function Install-OptionalTools {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    if (-not (Test-ScoopInstalled)) {
        Write-Error "Scoop must be installed first"
        exit 1
    }

    $optionalJson = Join-Path $PSScriptRoot "scoop_optional.json"
    if (-not (Test-Path $optionalJson)) {
        Write-Warning "scoop_optional.json not found, skipping"
        return
    }

    if ($Force) {
        Write-Information "Installing optional tools..."
        scoop import $optionalJson
        return
    }

    if (Test-RunningInCIorTestEnvironment) {
        Write-Information "CI mode: skipping optional tools"
        return
    }

    $response = Read-Host "Install recommended optional tools? (Y/N)"
    if ($response -match '^[Yy]') {
        scoop import $optionalJson
    }
}

# === Main Execution (only when NOT dot-sourced) ===

# Detect if script is being dot-sourced
$isSourced = $MyInvocation.InvocationName -eq '.' -or $MyInvocation.Line -eq ''

if (-not $isSourced) {
    # Standalone execution
    try {
        Install-Scoop
        Install-MandatoryTools
        Install-OptionalTools
        Write-Host "Installation complete!" -ForegroundColor Green
    } catch {
        Write-Error "Installation failed: $_"
        exit 1
    }
}
```

**Phase 4: Enable Wrapper Usage**
Example wrapper script:
```powershell
# tools/install-optional.ps1
. "$PSScriptRoot\..\bin\install.ps1"
Install-OptionalTools -Force
```

Example Flow Launcher integration:
```powershell
. "C:\Path\To\bin\install.ps1"
Install-Scoop  # Repair/verify Scoop installation
```

**Phase 5: Update Dependencies**
1. Coordinate with DEBT-001: Remove `.bootstrap/` entirely after migrating `Install-Scoop`
2. Coordinate with FEAT-003: Ensure `flow-launcher` in mandatory tools

**Acceptance Criteria**:
- [ ] `Install-Scoop` function extracted from bootstrap.ps1 to install.ps1
- [ ] All functions are idempotent (safe to re-run)
- [ ] `install.ps1` is self-complete (no external file dependencies)
- [ ] `install.ps1` can be dot-sourced without executing main logic
- [ ] `scoop_mandatory.json` contains only: lessmsi, 7zip, innounp, dark, git, flow-launcher
- [ ] `scoop_optional.json` contains all other tools
- [ ] Works via `Invoke-RestMethod` (standalone remote execution)
- [ ] Works when dot-sourced by wrapper scripts
- [ ] Interactive prompts in interactive mode
- [ ] Non-interactive behavior in CI mode
- [ ] Clear success/error messages
- [ ] All tests pass
- [ ] Documentation updated

**Technical Notes**:
- **Self-complete requirement**: All helper functions must be inline (can't source utils.ps1)
- **Dot-source detection**: Check `$MyInvocation.InvocationName -eq '.'`
- **Idempotency pattern**: Always check state before acting
- **Flow Launcher bucket**: `scoop bucket add extras` (if not already added)
- **Remote invocation**: `irm https://raw.github.com/.../install.ps1 | iex`

**Testing Requirements**:
- Unit tests for each function (Install-Scoop, Install-MandatoryTools, Install-OptionalTools)
- Test idempotency (running functions multiple times)
- Test dot-sourcing (functions accessible without execution)
- Test standalone execution
- Test CI/interactive modes

**Migration Path**:
1. Implement new install.ps1 structure
2. Test thoroughly (both standalone and dot-sourced)
3. Remove bootstrap.ps1 (DEBT-001)
4. Update all documentation

---

### [FEAT-002] Set up Podman as Docker alternative in WSL

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

### [DEBT-001] Remove Bootstrap System Dependency from install.ps1

**Status**: Open
**Priority**: Medium
**Component**: `bin/install.ps1`, `.bootstrap/` directory
**Type**: Refactoring / Technical Debt

**Description**:
Simplify the installation process by removing the `.bootstrap` system dependency and replacing it with a straightforward Scoop availability check.

**Current Problem**:
- `.bootstrap` system adds unnecessary complexity
- More suited for Python projects than PowerShell/Windows tooling
- Obscures the simple requirement: Scoop must be installed

**Proposed Solution**:
Replace bootstrap system with direct Scoop check in `install.ps1`:
1. Check if `scoop` command is available
2. If not found, ask user: "Scoop is not installed. Install it now? (Y/N)"
3. If Yes: Install Scoop using default method from https://scoop.sh/
4. If No: Exit gracefully with helpful message
5. Once Scoop is available: Install tools via `scoop import scoopfile.json`

**Acceptance Criteria**:
- [ ] Remove dependency on `.bootstrap/` directory
- [ ] Delete `.bootstrap/` directory entirely
- [ ] Add Scoop availability check to `install.ps1`
- [ ] Interactive prompt asking user to install Scoop if missing
- [ ] Automatic Scoop installation if user confirms
- [ ] Graceful exit with helpful message if user declines
- [ ] Install tools via `scoop import scoopfile.json` after Scoop is available
- [ ] Update documentation to reflect simplified installation
- [ ] All tests pass after refactoring

**Technical Notes**:
- Current Scoop check: `Get-Command scoop -ErrorAction SilentlyContinue`
- Default Scoop installation (from scoop.sh):
  ```powershell
  irm get.scoop.sh | iex
  ```
- Tool installation: `scoop import scoopfile.json`
- Must handle CI/non-interactive environments properly

### Documentation

*No items yet*

---

## DONE

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
- Keep items actionable with clear acceptance criteria
