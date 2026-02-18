# Backlog

## IN PROGRESS

## TODO

### [FEAT-002] Set up Podman as Docker alternative in WSL

**Status**: Open
**Priority**: Medium
**Component**: `tools/pslib/wsl/lib/podman.ps1` (new), `tools/pslib/wsl/scripts/install-podman.sh` (new), `tools/pslib/wsl/wsl-manager.ps1`
**Related**: FEAT-001, Dev Container workflow

**Description**:
Add a `setup-podman` command to wsl-manager that installs and configures rootless Podman in a WSL2 Debian/Ubuntu distribution. Mirrors the existing `setup-docker` pattern exactly.

**Rationale**:
Podman provides a daemonless, rootless container runtime compatible with Docker workflows. It's especially useful for security-conscious environments and can fully replace Docker for Dev Container usage.

**Scope Decisions** (agreed in refinement 2026-02-18):
- **Debian/Ubuntu only** — consistent with `setup-docker`; Fedora/RHEL deferred
- **Mutual exclusion with Docker** — `setup-podman` fails fast if Docker is already installed in the distro
- **Rootless only** — no `-Mode` parameter; rootful mode deferred to a follow-up
- **VS Code integration is documentation-only** — no code touches Windows-side settings

**Implementation** (follows `docker.ps1` / `install-docker.sh` pattern):

**Step 1: `lib/podman.ps1`** — PowerShell library functions
- `Test-WslPodmanInstalled -DistroName` — checks if `podman --version` succeeds
- `Test-WslDockerInstalledForPodman -DistroName` — checks Docker presence (mutual exclusion guard)
- `Install-WslPodman -DistroName [-Username]` — orchestrates the install:
  - Same prerequisite checks as `Install-WslDockerEngine` (WSL installed, distro exists, WSL2, Debian/Ubuntu, default user)
  - Fails fast with clear error if Docker is already installed
  - Ensures systemd and interop are configured (reuse existing `Test-WslSystemdConfigured` / `Test-WslInteropConfigured`)
  - Executes `install-podman.sh` via `Invoke-WslDistroScript`

**Step 2: `scripts/install-podman.sh`** — Bash installation script (idempotent)
- Args: `--distro-id`, `--codename`, `--arch`, `--username` (same interface as `install-docker.sh`)
- Installs `podman` via apt
- Enables rootless Podman socket: `systemctl --user enable --now podman.socket` (as target user)
- Sets `DOCKER_HOST` in `~/.bashrc` pointing to the Podman socket
- Verifies `podman run --rm hello-world` succeeds
- Exit codes: 0 success, 1 prereq failure, 2 install failure, 3 verification failure, 4 argument error

**Step 3: `wsl-manager.ps1`** — wire up the new command
- Add `setup-podman` to `ValidateSet` and `Invoke-WslManager` switch
- Add `Invoke-SetupPodmanInteractive` (mirrors `Invoke-SetupDockerInteractive`)
- Add `[P] Setup Podman` to interactive menu

**Step 4: `docs/wsl-podman-setup.md`** — documentation
- Podman vs Docker comparison
- Rootless benefits and limitations
- VS Code Dev Containers: add `"dev.containers.dockerPath": "podman"` to VS Code settings manually
- DOCKER_HOST usage and socket path
- Troubleshooting

**Acceptance Criteria**:
- [ ] `wsl-manager setup-podman <distro>` command works
- [ ] Interactive menu option `[P] Setup Podman` works
- [ ] Installs Podman on Debian/Ubuntu distributions
- [ ] Fails fast with clear error if Docker is already installed in the distro
- [ ] Configures rootless Podman systemd socket (`podman.socket`)
- [ ] Sets `DOCKER_HOST` env variable in `~/.bashrc`
- [ ] Verifies Podman works (`podman run --rm hello-world`)
- [ ] Idempotent — safe to re-run for repair
- [ ] Requires systemd-enabled distro (error if not configured)
- [ ] Requires non-root default user (error if missing)
- [ ] Clear error messages for all failure paths
- [ ] Documentation in `docs/wsl-podman-setup.md`
- [ ] Unit tests in `lib/podman.Tests.ps1`
- [ ] All existing tests continue to pass

**Technical Notes**:
- Socket path: `unix:///run/user/$UID/podman/podman.sock`
- `DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock` in `~/.bashrc`
- `systemctl --user` commands must run as the target user, not root (use `sudo -u $USER systemctl --user ...` or `su - $USER -c ...`)
- Ubuntu 22.04+ and Debian 11+ have native Podman packages; no PPA needed for these versions
- VS Code setting (manual): `"dev.containers.dockerPath": "podman"`

**Dependencies**:
- WSL2
- Systemd-enabled distribution (configured by `Install-WslDockerEngine` or manually)
- Non-root default user (same as Docker setup)
- Sudo access for apt installation

**Related Documentation**:
- https://podman.io/
- https://code.visualstudio.com/docs/devcontainers/containers

### Technical Debt

### [REFACT-001] Add `-Name` parameter to `Invoke-UpdateDistro` and `Invoke-RemoveDistro`

**Status**: Open
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Blocks**: REFACT-003

**Description**:
`Invoke-UpdateDistro` and `Invoke-RemoveDistro` have no parameters — they are purely interactive, always calling `Read-Host` to prompt for a distribution name. This prevents non-interactive invocation (tests, scripts, CI).

Add an optional `-Name` parameter to both functions, following the existing pattern in `Invoke-TerminateDistro`. When `-Name` is provided, skip the `Read-Host` prompt and proceed directly with the named distribution. Update `Invoke-WslManager` to pass `$Name` through for the `"update"` and `"remove"` commands.

**Implementation**:
1. Add `[string]$Name = ""` parameter to `Invoke-UpdateDistro`; skip `Read-Host` when non-empty
2. Repeat for `Invoke-RemoveDistro`
3. Update `Invoke-WslManager` switch: `"update"` → `Invoke-UpdateDistro -Name $Name`, `"remove"` → `Invoke-RemoveDistro -Name $Name`
4. Update unit tests in `wsl-manager.Tests.ps1` to cover both interactive and non-interactive paths

**Acceptance Criteria**:
- [ ] `Invoke-WslManager -Command "update" -Name "Debian"` updates without prompting
- [ ] `Invoke-WslManager -Command "remove" -Name "debian-test"` removes without prompting
- [ ] When `-Name` is omitted, interactive behaviour (Read-Host prompt) is unchanged
- [ ] Unit tests cover both non-interactive (name provided) and interactive paths
- [ ] All existing tests continue to pass

---

### [REFACT-002] Fix `Invoke-SetupUser` CI guard scope and add explicit parameters

**Status**: Open
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Blocks**: REFACT-003

**Description**:
`Invoke-SetupUser` places the `Test-RunningInCIorTestEnvironment` guard at the top of the function, causing it to return early whenever running under Pester — even if username and password are passed programmatically. The guard should only block the interactive `Read-Host` prompts, not the call to `New-WslUser`.

Add optional `-Username` and `-Password` parameters. When both are supplied, skip the prompts entirely. Move the CI guard to protect only the `Read-Host` block.

**Implementation**:
1. Add `[string]$Username = ""` and `[string]$Password = ""` parameters to `Invoke-SetupUser`
2. When both are non-empty, skip `Read-Host` prompts and call `New-WslUser` directly
3. Move `Test-RunningInCIorTestEnvironment` guard to protect only the prompt block, not the whole function
4. Update `Invoke-WslManager` to accept and forward `-Username`/`-Password` for the `"setup-user"` command
5. Update unit tests in `wsl-manager.Tests.ps1`

**Acceptance Criteria**:
- [ ] `Invoke-SetupUser -DistroName "debian-test" -Username "testuser" -Password "pass"` works under Pester
- [ ] When `-Username`/`-Password` are omitted, interactive behaviour (Read-Host prompts) is unchanged
- [ ] CI guard blocks interactive prompts in test environment but does not short-circuit when params are provided
- [ ] Unit tests cover both non-interactive (params provided) and interactive paths
- [ ] All existing tests continue to pass

---

### [REFACT-003] Refactor wsl-manager integration tests to call wsl-manager functions

**Status**: Open
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`
**Blocked by**: REFACT-001, REFACT-002

**Description**:
The integration test mixes subprocess invocations of `wsl-manager.ps1` with direct pslib calls, bypassing wsl-manager's own workflow functions (`Invoke-UpdateDistro`, `Invoke-CloneDistro`, `Invoke-SetupUser`) entirely. The test should exercise wsl-manager's public surface.

Refactor the tests to dot-source `wsl-manager.ps1` and call its functions in-process. Replace subprocess calls and direct pslib calls for every operation that has a wsl-manager wrapper. Operations without a wsl-manager wrapper (`Invoke-WslDistroScript`, `Install-WslDockerEngine`, etc.) should remain on pslib.

**Changes**:
- `BeforeAll`: dot-source `wsl-manager.ps1` in addition to `wsl.ps1`
- `Create Distribution`: `& $wslManagerPath create ...` → `Invoke-WslManager -Command "create" -Name ...`
- `Update Base Distribution`: `Update-WslDistro` (pslib) → `Invoke-WslManager -Command "update" -Name ...`
- `Clone Distribution`: `Copy-WslDistro` (pslib) → `Invoke-WslManager -Command "clone" -Name ... -TargetName ...`
- `Setup User`: `New-WslUser` (pslib) → `Invoke-WslManager -Command "setup-user" ...` with explicit params (REFACT-002)
- `List Distributions`: `& $wslManagerPath list` → `Show-WslDistroList`
- `Terminate Distribution`: `& $wslManagerPath terminate ...` → `Invoke-WslManager -Command "terminate" -Name ...`
- Remove `$script:wslManagerPath` and all subprocess invocations
- `Script Execution` and `Docker Setup` contexts: **keep pslib** — no wsl-manager wrapper exists for those

**Acceptance Criteria**:
- [ ] No subprocess calls (`& $script:wslManagerPath`) remain in the test file
- [ ] No direct pslib calls for operations that have a wsl-manager wrapper
- [ ] `Invoke-UpdateDistro`, `Invoke-CloneDistro`, `Invoke-SetupUser` are exercised by the integration tests
- [ ] `Script Execution` and `Docker Setup` contexts retain their direct pslib calls unchanged
- [ ] Output assertions updated to match in-process output (no null-char stripping or stream merging workarounds)
- [ ] All integration tests pass end-to-end

### Documentation

*No items yet*

---

## DONE

### [FEAT-004] ✅ COMPLETED - Replace Bootstrap with Self-Contained install.ps1

**Status**: **Completed** (2026-02-11) | **Branch**: `feature/feat-004-self-contained-install`
**Priority**: Medium
**Component**: `bin/install.ps1`, `scoop_mandatory.json`, `scoop_optional.json`
**Type**: Feature / Refactoring
**Absorbs**: DEBT-001 (Bootstrap removal)

**Description**:
Replaced external `avengineers/bootstrap` dependency with a self-contained `install.ps1`. Two modes (remote via `irm | iex`, local via `-InPlace`), mandatory/optional tool split, dot-sourceable functions.

**Implementation**:
- Rewrote `bin/install.ps1` with remote/local mode detection via `$PSScriptRoot`
- Created `scoop_mandatory.json` (keypirinha + extras bucket)
- Created `scoop_optional.json` (pwsh, windows-terminal, ditto, winmerge, sysinternals, vscode, autohotkey)
- Removed `scoopfile.json` and all `avengineers/bootstrap` references
- Exposed functions: `Install-Scoop`, `Install-ScoopDependency`, `Install-Git`, `Install-MandatoryToolset`, `Install-OptionalToolset`
- 45 unit tests covering all functions, dot-source support, JSON validation
- Removed `.bootstrap` from `.gitignore`

---

### [FEAT-003] ✅ COMPLETED - Add Flow Launcher as Standalone Optional Tool

**Status**: **Completed** (2026-02-10) | **Branch**: `feature/feat-003-flow-launcher`
**Priority**: Medium
**Component**: `tools/flow-launcher/`

**Description**:
Flow Launcher offered as a standalone optional tool alongside the default Keypirinha launcher. Originally implemented as a full migration (`7104fe9`), rescoped to keep Keypirinha as default and provide Flow Launcher independently.

**Implementation**:
- ✅ Reverted Keypirinha-to-Flow-Launcher migration (restored all default Keypirinha references)
- ✅ Created `tools/flow-launcher/install-flow-launcher.ps1` - standalone installer (TDD, 17 tests)
- ✅ Created `tools/flow-launcher/install-flow-launcher.bat` wrapper
- ✅ `configure-program-plugin.ps1` + tests (584 tests) - configures Program plugin
- ✅ Program plugin scans `shortcuts/` (root) and `shortcuts_private/`
- ✅ Updated `docs/flow-launcher-setup.md` for standalone usage

---

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
- Do NOT list commit hashes in backlog entries — the backlog is part of the commit itself, so hashes are circular and go stale after squash/rebase
