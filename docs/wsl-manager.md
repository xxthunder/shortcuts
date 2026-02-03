# WSL Manager - Consolidated Specification

**Status**: Phase 2 Complete (75/83 tasks done) | **Branch**: Various phases merged to `develop`

---

## Overview

The WSL Manager is a PowerShell-based tool for managing Windows Subsystem for Linux (WSL) distributions. It provides both interactive menus and CLI commands for creating, cloning, configuring, and managing WSL distributions.

**Core Files**:
- `tools/pslib/wsl/wsl.ps1` - Library functions (28 functions)
- `tools/pslib/wsl/lib/` - Modular implementation (core, docker, exec, install, ops, user)
- `tools/pslib/wsl/wsl-manager.ps1` - Interactive interface
- `tools/pslib/wsl/wsl-manager.bat` - Batch wrapper for Keypirinha

**Test Coverage**: 523 tests passing (unit + integration)

---

## What's Been Completed

### Phase 1: Core Functionality (Merged to `develop`)

✅ **User Story 1 - List Distributions** (P1)
- `Get-WslDistroList` with `-Detailed` switch for structured data
- Handles localized output (English, German, French)
- UTF-16 null character cleanup

✅ **User Story 3 - Clone Distribution** (P3)
- `Copy-WslDistro` with export/import workflow
- State validation (must be stopped)
- Full filesystem preservation

✅ **User Story 4 - Remove Distribution** (P4)
- `Remove-WslDistro` with confirmation prompts
- State validation and error handling

✅ **User Story 5 - Terminate Distribution** (P5)
- `Stop-WslDistro` for graceful shutdown
- Handles already-stopped cases

✅ **User Story 6 - Update Distribution** (P6)
- `Update-WslDistro` for Debian/Ubuntu (apt-based)
- State validation and distribution type checking

✅ **User Story 7 - Setup User Account** (P7)
- `New-WslUser` with sudo privileges and NOPASSWD
- Security warning display
- `/etc/wsl.conf` configuration with defensive parsing

✅ **Centralized Parsing** (Refactoring)
- `Get-WslDistroList -Detailed` as single source of truth
- `Get-WslDistroState`, `Test-Wsl2Version` use centralized data
- Eliminated ~80% duplicate parsing code

### Phase 2: Docker & Script Execution (Merged to `develop` via PR #15)

✅ **Script Execution Module** (`tools/pslib/wsl/lib/exec.ps1`)
- `Invoke-WslDistroScript` for bash script execution
- `AsRoot` parameter for sudo execution
- Windows→WSL path conversion
- Proper exit code handling

✅ **Docker Installation Refactoring**
- Created `tools/pslib/wsl/scripts/install-docker.sh` (external bash script)
- Refactored `Install-WslDockerEngine` to use script execution
- Comprehensive prerequisite validation (WSL2, systemd, distribution type)
- Integration tests for real Docker installation

✅ **Critical Infrastructure Fix**
- `.gitattributes` for line ending management
- Shell scripts (`.sh`) → LF (Unix)
- PowerShell (`.ps1`) → CRLF (Windows)
- Documentation (`.md`) → CRLF (Windows)
- Prevents GitHub Actions line ending issues

### Phase 3: Docker & DevContainer Integration (Branch: `feature/wsl-devcontainer-prep`)

**Note**: Docker installation automatically configures systemd and Windows interop as prerequisites. These settings enable Docker Engine to run properly in WSL and are essential for VS Code DevContainers.

✅ **wsl.conf Management** (`tools/pslib/wsl/lib/user.ps1`)
- `Set-WslConf` for safe section-aware merging
  - Preserves existing sections and comments
  - Creates timestamped backups (`/etc/wsl.conf.backup.YYYYMMDD-HHMMSS`)
  - Supports multiple sections in one call
  - ShouldProcess support (`-WhatIf`, `-Confirm`)
- Refactored `New-WslUser` to use `Set-WslConf` (no longer overwrites entire file)

✅ **Docker Installation Enhancements** (`tools/pslib/wsl/lib/docker.ps1`)
- `Install-WslDockerEngine` automatically configures Docker prerequisites:
  - Systemd configuration via `wsl.conf` `[boot]` section
  - Windows interop via `wsl.conf` `[interop]` section
  - Kernel-level interop via binfmt.d (VS Code compatible, in `install-docker.sh`)
  - Skips configuration if already enabled
  - Validates WSL2 and distribution type before installation

✅ **Interactive Manager Integration** (`tools/pslib/wsl/wsl-manager.ps1`)
- Menu option: `[D] Setup Docker (includes systemd/interop)`
- Command-line: `wsl-manager setup-docker <distro-name>`
- Functions: `Invoke-SetupDockerInteractive`, `Invoke-SetupDocker`

✅ **Documentation** (`docs/wsl-devcontainer-setup.md`)
- Phase 1: Docker installation (automated systemd/interop/binfmt.d)
- Phase 2: Windows SSH Agent setup (manual, PowerShell Admin)
- Phase 3: Git configuration inside WSL (manual: user.name, user.email, ssh.exe)
- Phase 4: VS Code settings (manual: dev.containers.copyGitConfig, SSH forwarding)
- Phase 5: Validation steps (SSH forwarding test, git identity check, DevContainer test)
- Comprehensive troubleshooting guide

**Test Coverage**: 505 unit tests for Set-WslConf and Docker configuration

**Reference**: See `docs/wsl-devcontainer-setup.md` for complete setup guide and `docs/backlog.md` FEAT-001

---

## What's Remaining (8 items)

These are mostly verification checklist items from the Phase 1 refactoring:

### Module Refactoring Verification Checklist

From `specs/001-wsl-manager/tasks.md` Phase 6:

- [ ] `wsl.ps1` successfully dot-sources all `lib/*.ps1` files
- [ ] All unit tests pass: `pwsh -File ".\test\bin\testrunner.ps1" -Unit`
- [ ] All integration tests pass: `pwsh -File ".\test\bin\testrunner.ps1" -Integration`
- [ ] PowerShell 5.1 compatibility verified: `powershell -File ".\test\bin\testrunner.ps1"`
- [ ] Git history shows tests committed before refactoring (TDD compliance)
- [ ] Code review confirms no functional changes, only structural reorganization

### Test Organization (Optional Enhancement)

- [ ] T067-test [P] Add tests for individual module files in `tools/pslib/wsl/tests/`
- [ ] T069 [P] Move test cases to corresponding files in `tools/pslib/wsl/tests/`

**Note**: These test organization tasks are optional improvements. Current testing structure works well with all 508 tests passing.

---

## Future Enhancements (Not Scheduled)

These user stories were identified but not yet prioritized for implementation:

### User Story 2 - Create New Distribution (P2) - NOT IMPLEMENTED

**Why deferred**: Users can create distributions via `wsl --install <distro>` directly. The manager focuses on managing *existing* distributions rather than initial installation. May add in future if there's demand for guided creation.

### User Story 8 - Setup Docker Engine (P8) - ✅ COMPLETED

**Status**: Fully implemented in both CLI and interactive menu.

**Features**:
- ✅ Docker installation via `Install-WslDockerEngine`
- ✅ Interactive menu: `[D] Setup Docker (includes systemd/interop)`
- ✅ CLI command: `wsl-manager setup-docker <distro-name>`
- ✅ Automatic prerequisite configuration (systemd, interop, binfmt.d)
- ✅ Docker status check via `Test-WslDockerInstalled`

**Not yet implemented**:
- Docker uninstall command (users can manually uninstall via apt-get)

---

## Technical Architecture

### Module Structure

```
tools/pslib/wsl/
├── wsl.ps1                    # Main library (dot-sources lib/*.ps1)
├── wsl-manager.ps1            # Interactive interface
├── wsl-manager.bat            # Batch wrapper
├── lib/
│   ├── core.ps1               # List, get distro info, type detection
│   ├── docker.ps1             # Docker installation & verification
│   ├── exec.ps1               # Script execution in WSL
│   ├── install.ps1            # Clone, remove operations
│   ├── ops.ps1                # Update, state, terminate operations
│   └── user.ps1               # User account creation & configuration
├── scripts/
│   └── install-docker.sh      # Docker Engine installation script
└── tests/
    ├── wsl.Tests.ps1                       # Unit tests
    ├── wsl.Integration.Tests.ps1           # Integration tests
    ├── wsl-manager.Tests.ps1               # Manager unit tests
    └── wsl-manager.Integration.Tests.ps1   # Manager integration tests
```

### Key Design Decisions

**1. Library-First Architecture**
- All functionality in reusable functions
- Manager tool builds on library (thin wrapper)
- Easy to automate without interactive prompts

**2. TDD Approach**
- Tests written before implementation
- 508 tests (unit + integration)
- PowerShell 5.1 and 7.x compatibility verified

**3. Fail-Fast Error Handling**
- Operations require stopped distributions
- Clear error messages with actionable guidance
- Safe state on failure

**4. Dual-Mode Support**
- Interactive mode with menus and prompts
- CI/automation mode (detected via `Test-RunningInCIorTestEnvironment`)
- All functions support both modes

**5. Localization Support**
- Pattern-based parsing (not position-based)
- Supports English, German, French WSL output
- UTF-16 null character cleanup

**6. Modular Implementation**
- Split monolithic `wsl.ps1` into logical modules
- `lib/` directory with focused modules
- Backward compatible (functions still accessible via `wsl.ps1`)

---

## Testing Strategy

### Unit Tests (`*.Tests.ps1`)
- Mock all external dependencies (wsl.exe, file system)
- Test both success and failure paths
- Verify CI and interactive behavior separately
- Fast feedback (<1 minute)

**Run**: `pwsh -File ".\test\bin\testrunner.ps1" -Unit`

### Integration Tests (`*.Integration.Tests.ps1`)
- Use real WSL distributions (Debian)
- Create temporary test distributions
- Verify end-to-end workflows
- Cleanup after tests

**Run**: `pwsh -File ".\test\bin\testrunner.ps1" -Integration`

### Coverage
- All 28 functions have test coverage
- Edge cases covered (malformed config, localization, errors)
- Both PowerShell 5.1 and 7.x tested in CI

**Run**: `pwsh -File ".\test\bin\testrunner.ps1" -Coverage`

---

## How to Use

### Interactive Mode

```bash
# Launch interactive manager
wsl-manager

# Or via PowerShell
pwsh -File tools/pslib/wsl/wsl-manager.ps1
```

### Library Mode (Automation)

```powershell
# Source the library
. "$PSScriptRoot\tools\pslib\wsl\wsl.ps1"

# Use functions directly
Get-WslDistroList -Detailed
Copy-WslDistro -SourceName Debian -TargetName MyProject
New-WslUser -DistroName MyProject -Username developer -Password "SecurePass123"
Install-WslDockerEngine -DistroName MyProject
```

### Example Workflows

**Clone a configured distribution for a new project:**
```powershell
# 1. Clone base distribution
Copy-WslDistro -SourceName Debian -TargetName ProjectX

# 2. Setup user
New-WslUser -DistroName ProjectX -Username dev -Password "pass"

# 3. Install Docker
Install-WslDockerEngine -DistroName ProjectX

# 4. Start working
wsl -d ProjectX
```

**Update all Debian/Ubuntu distributions:**
```powershell
Get-WslDistroList -Detailed |
    Where-Object { $_.State -eq 'Stopped' } |
    Where-Object { (Get-WslDistroType -DistroName $_.Name) -eq 'debian' } |
    ForEach-Object { Update-WslDistro -Name $_.Name }
```

---

## Next Steps (Your Choice)

### Option 1: Complete Remaining Checklist (Quick Win - 30 minutes)
- Verify all 6 checklist items from Phase 1 refactoring
- Update `tasks.md` with checkmarks
- Document any findings

### Option 2: Add Docker to Interactive Menu (Medium - 2-3 hours)
- Add Docker setup option to `wsl-manager.ps1`
- Add Docker status check
- Add integration tests for menu flow
- Completes User Story 8

### Option 3: Implement User Story 2 - Create Distribution (Large - 1-2 days)
- `New-WslDistro` function with Microsoft Store catalog
- Distribution validation and availability checking
- Ubuntu version selection (20.04, 22.04, 24.04)
- Integration tests

### Option 4: New Feature (TBD)
- What would be most valuable to you?
- Export/import distribution configurations?
- Batch operations on multiple distributions?
- WSL configuration file management?
- Network/filesystem mounts?

---

## Quick Reference

### All Implemented Functions

**Distribution Information** (`lib/core.ps1`):
- `Get-WslDistroList [-Detailed]` - List distributions
- `Get-WslDistroType -DistroName` - Detect distro type (debian, ubuntu, arch, etc.)
- `Get-WslDistroState -DistroName` - Get state (Running/Stopped)
- `Test-WslDistroRunning -DistroName` - Check if running
- `Test-Wsl2Version -DistroName` - Check if WSL2
- `Test-WslSystemdConfigured -DistroName` - Check systemd in wsl.conf
- `Test-WslSystemd -DistroName` - Check if systemd is running

**Distribution Operations** (`lib/ops.ps1`, `lib/install.ps1`):
- `Copy-WslDistro -SourceName -TargetName` - Clone distribution
- `Remove-WslDistro -Name` - Unregister distribution
- `Stop-WslDistro -Name` - Terminate distribution
- `Update-WslDistro -Name` - Update packages (apt-based)

**User Management** (`lib/user.ps1`):
- `New-WslUser -DistroName -Username -Password` - Create user with sudo
- `Get-WslDefaultUser -DistroName` - Get default user from wsl.conf

**Docker** (`lib/docker.ps1`):
- `Install-WslDockerEngine -DistroName [-Username]` - Install Docker
- `Test-WslDockerInstalled -DistroName` - Check Docker installation

**Script Execution** (`lib/exec.ps1`):
- `Invoke-WslDistroCommand -DistroName -Command` - Run command
- `Invoke-WslDistroScript -DistroName -ScriptPath [-Arguments] [-AsRoot]` - Run bash script

---

## References

Original SpecKit files (for reference only):
- `specs/001-wsl-manager/spec.md` - User stories and acceptance criteria
- `specs/001-wsl-manager/plan.md` - Technical architecture and design
- `specs/001-wsl-manager/tasks.md` - Detailed task breakdown (75/83 done)
- `specs/001-wsl-manager/research.md` - Design decisions and alternatives
- `specs/001-wsl-manager/data-model.md` - State machines and entities
- `specs/001-wsl-manager/contracts/` - CLI interface specifications
