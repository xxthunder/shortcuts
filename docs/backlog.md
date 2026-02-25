# Backlog

## IN PROGRESS

### [CHORE-002] Backlog refinement

**Status**: Ongoing
**Priority**: —

**Description**:
Ongoing backlog refinement — create, review, clarify, and update user stories. Add research findings, scope decisions, acceptance criteria, and implementation details as needed. This item is never completed; all refinement commits reference this ID.

---

## DONE

### [FEAT-002] ✅ COMPLETED - Set up Podman as Docker alternative in WSL

**Status**: **Completed** (2026-02-24) | **Branch**: `feature/feat-002-podman-wsl`
**Priority**: Medium
**Component**: `tools/pslib/wsl/lib/podman.ps1` (new), `tools/pslib/wsl/scripts/install-podman.sh` (new), `tools/pslib/wsl/wsl-manager.ps1`
**Related**: FEAT-001, Dev Container workflow

**Description**:
Add a `setup-podman` command to wsl-manager that installs and configures rootless Podman in a WSL2 Debian/Ubuntu distribution. Mirrors the existing `setup-docker` pattern exactly.

**Rationale**:
Podman provides a daemonless, rootless container runtime compatible with Docker workflows. It's especially useful for security-conscious environments and can fully replace Docker for Dev Container usage.

**Scope Decisions** (agreed in refinement 2026-02-18, updated 2026-02-23):
- **Debian/Ubuntu only** — consistent with `setup-docker`; Fedora/RHEL deferred
- **Mutual exclusion with Docker** — `setup-podman` fails fast if Docker is already installed in the distro (UX choice — they can technically coexist but `DOCKER_HOST` confusion is not worth it)
- **Rootless only** — no `-Mode` parameter; rootful mode deferred to a follow-up
- **VS Code integration is documentation-only** — no code touches Windows-side settings
- **cgroups v2 is documentation-only** — requires Windows-side `.wslconfig` change, script should detect and warn but not modify Windows files

**Implementation** (follows `docker.ps1` / `install-docker.sh` pattern):

**Step 1: `lib/podman.ps1`** — PowerShell library functions ✅ **DONE**
- `Test-WslPodmanInstalled -DistroName` — checks if `podman --version` succeeds
- `Install-WslPodman -DistroName [-Username]` — orchestrates the install:
  - Same prerequisite checks as `Install-WslDockerEngine` (WSL installed, distro exists, WSL2, Debian/Ubuntu, default user)
  - Calls `Test-WslDockerInstalled` directly for mutual exclusion (no separate wrapper needed — `wsl.ps1` dot-sources both `docker.ps1` and `podman.ps1`)
  - Ensures systemd and interop are configured (reuses existing `Test-WslSystemdConfigured` / `Test-WslInteropConfigured`)
  - Configures `mount --make-rshared /` in wsl.conf `[boot] command` (required for rootless containers to avoid mount propagation warnings)
  - Executes `install-podman.sh` via `Invoke-WslDistroScript`
- 42 Pester unit tests in `podman.Tests.ps1` (all passing)

**Step 2: `scripts/install-podman.sh`** — Bash installation script (idempotent) ✅ **DONE**
- Args: `--distro-id`, `--codename`, `--arch`, `--username` (same interface as `install-docker.sh`)
- Installs `podman`, `slirp4netns`, and `uidmap` via apt (rootless networking + user namespace mapping)
- Enables `loginctl enable-linger $USERNAME` (keeps systemd user services alive across sessions)
- Sets `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS` in `~/.bashrc` (WSL2 systemd session reliability)
- Enables rootless Podman socket: `systemctl --user enable --now podman.socket` (as target user, NOT root)
- Sets `DOCKER_HOST` in `~/.bashrc` pointing to the Podman socket
- Checks cgroups v2 status and emits a warning if not using pure cgroups v2 (with instructions for `.wslconfig`)
- Verifies `podman --version`, socket exists, and `podman info` succeeds as target user
- Exit codes: 0 success, 1 prereq failure, 2 install failure, 3 verification failure, 4 argument error

**Step 3: `wsl-manager.ps1`** — wire up the new command ✅ **DONE**
- Add `setup-podman` to `ValidateSet` and `Invoke-WslManager` switch
- Add `Invoke-SetupPodmanInteractive` (mirrors `Invoke-SetupDockerInteractive`)
- Add `[P] Setup Podman` to interactive menu

**Step 4: `docs/wsl-podman-setup.md`** — documentation ✅ **DONE**
- Podman vs Docker comparison
- Rootless benefits and limitations
- Prerequisites: cgroups v2 setup (`.wslconfig` kernel command line)
- VS Code Dev Containers configuration:
  - `"dev.containers.dockerPath": "podman"` (manual VS Code setting)
  - `"dev.containers.mountWaylandSocket": false` (avoids WSL2 socket error)
  - `--userns=keep-id` in `devcontainer.json` `runArgs` (critical for rootless file permissions)
- DOCKER_HOST usage and socket path
- Performance note: store projects in WSL filesystem, not `/mnt/c/`
- Troubleshooting (WSL systemd race condition, cgroups, socket issues)

**Acceptance Criteria**:
- [x] `wsl-manager setup-podman <distro>` command works
- [x] Interactive menu option `[P] Setup Podman` works
- [x] Installs Podman and slirp4netns on Debian/Ubuntu distributions
- [x] Fails fast with clear error if Docker is already installed in the distro
- [x] Configures rootless Podman systemd socket (`podman.socket`)
- [x] Enables `loginctl enable-linger` for persistent user services
- [x] Sets `XDG_RUNTIME_DIR` and `DBUS_SESSION_BUS_ADDRESS` in `~/.bashrc`
- [x] Configures `mount --make-rshared /` via wsl.conf boot command
- [x] Sets `DOCKER_HOST` env variable in `~/.bashrc`
- [x] Warns if cgroups v2 is not enabled (with `.wslconfig` instructions)
- [x] Verifies Podman works (`podman info` + socket exists)
- [x] Idempotent — safe to re-run for repair
- [x] Requires systemd-enabled distro (error if not configured)
- [x] Requires non-root default user (error if missing)
- [x] Clear error messages for all failure paths
- [x] Documentation in `docs/wsl-podman-setup.md`
- [x] Unit tests in `lib/podman.Tests.ps1`
- [x] All existing tests continue to pass

**Technical Notes**:
- Socket path: `unix:///run/user/$UID/podman/podman.sock`
- `DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock` in `~/.bashrc`
- `XDG_RUNTIME_DIR=/run/user/$(id -u)` in `~/.bashrc`
- `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus` in `~/.bashrc`
- `systemctl --user` commands must run as the target user, not root (use `sudo -u $USER systemctl --user ...` or `su - $USER -c ...`)
- `loginctl enable-linger $USER` requires root — run before switching to target user
- `mount --make-rshared /` in `[boot] command=` — prevents rootless container mount propagation warnings
- Ubuntu 22.04+ and Debian 11+ have native Podman packages; no PPA needed
- Debian 12: podman 4.3.1, Ubuntu 24.04: podman 4.9.3 — both sufficient for Dev Containers
- cgroups v2: requires `.wslconfig` `kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1` (Windows-side, documentation-only)
- VS Code setting (manual): `"dev.containers.dockerPath": "podman"`
- VS Code setting (manual): `"dev.containers.mountWaylandSocket": false`
- `devcontainer.json` (manual): `"runArgs": ["--userns=keep-id"]` for rootless file permission mapping

**Dependencies**:
- WSL2
- Systemd-enabled distribution (configured by `Install-WslDockerEngine` or manually)
- Non-root default user (same as Docker setup)
- Sudo access for apt installation
- cgroups v2 recommended (`.wslconfig` — documented, warned if missing)

**Related Documentation**:
- https://podman.io/
- https://code.visualstudio.com/docs/devcontainers/containers
- https://github.com/containers/podman/discussions/25607 (WSL2 + Dev Containers comprehensive guide)

## TODO

### [FEAT-006] Stop action functions from reprinting distro table in interactive mode

**Status**: Open
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Depends on**: REFACT-006

**Summary**:
As a WSL manager user, I want the interactive menu to show the distro table only once so that I can select a distribution without being confused by redundant or inconsistently numbered lists.

**Description**:
In interactive mode, `Show-InteractiveMenu` already displays the numbered distro table via `Show-WslDistroList`. When the user selects an action (e.g., Update, Remove, Terminate), the action function (`Invoke-UpdateDistro`, `Invoke-RemoveDistro`, `Invoke-TerminateDistro`, `Invoke-SetupUserInteractive`, `Invoke-SetupDockerInteractive`, `Invoke-SetupPodmanInteractive`, `Invoke-CloneDistro`) re-fetches and reprints its own distro table before prompting for a selection. This is redundant and confusing — especially for `Invoke-TerminateDistro`, which filters to running distros only, producing different numbering than the main menu table.

**Current behavior**:
1. Main menu shows: `1. Debian (Stopped) / 2. Ubuntu (Running) / 3. Fedora (Running)`
2. User selects `[T] Terminate`
3. Terminate shows: `1. Ubuntu (Running) / 2. Fedora (Running)` — Debian gone, numbering shifted
4. User remembers Fedora as `3` from the main menu, but now it's `2`

**Scope decisions**:
- `Invoke-WslManager` fetches the distro list once and passes it to all action functions via a mandatory `-Distros` parameter — applies to both CLI and interactive mode
- In interactive mode: `Show-InteractiveMenu` displays the table; action functions skip reprinting it; numbering stays consistent
- In CLI mode: action functions receive the list from `Invoke-WslManager` but may still print it if needed for standalone context
- `Invoke-TerminateDistro` uses the full list with consistent numbering and validates that the selected distro is running (clear error if not, instead of silently filtering)
- Removes 7 redundant `Get-WslDistroList -Detailed` calls from action functions (only `Invoke-WslManager` fetches)

**Acceptance Criteria**:
- [ ] Action functions do not reprint the distro table when invoked from interactive mode
- [ ] Numbering stays consistent with the main menu table
- [ ] `Invoke-TerminateDistro` handles non-running selection gracefully (error message instead of silent filter)
- [ ] CLI mode (`wsl-manager <command> <name>`) behavior unchanged
- [ ] Unit tests updated
- [ ] All existing tests continue to pass

---

### [REFACT-007] Consolidate documentation and make all docs reachable from README

**Status**: Open
**Priority**: Low
**Component**: `README.md`, `docs/`

**Summary**:
As a user or contributor, I want to discover all project documentation from the README so that I don't have to browse the `docs/` folder to find relevant guides.

**Description**:
The README currently links to only 2 of 8 docs files (`wsl-devcontainer-setup.md`, `wsl-manager.md`). The remaining files — including user-facing guides (`flow-launcher-setup.md`, `wsl-podman-setup.md`), development resources (`roadmap.md`, `backlog.md`, `development-principles.md`), and `input.md` — are unreachable from the README. Additionally, `BUG-002-vscode-wsl-interop-fix.md` is a standalone technical deep-dive for a bug that's already fully documented in the backlog; its content should be folded into the backlog entry or linked from there, not kept as a separate orphan file.

**Scope decisions**:
- Add a documentation index to the README linking all docs files, organized by audience (user guides vs. development/contributing)
- Fold `BUG-002-vscode-wsl-interop-fix.md` content into the backlog entry and remove the standalone file
- No new documentation to write — just link and consolidate what exists

**Acceptance Criteria**:
- [ ] All docs files reachable from README (directly or via a documentation section)
- [ ] User-facing guides and development docs clearly separated
- [ ] `BUG-002-vscode-wsl-interop-fix.md` content consolidated into backlog entry and standalone file removed
- [ ] No dead links

---

### [REFACT-006] Move argument validation from Invoke-WslManager switch into action functions

**Status**: Open
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`

**Summary**:
As a WSL manager user, I want action commands to prompt me for missing arguments so that I don't have to remember the exact CLI syntax to use a command.

**Description**:
The `Invoke-WslManager` switch block inconsistently handles missing arguments like `$Name`. Some commands pass arguments through and let the action function prompt (e.g., `remove`, `update`), some branch to separate `*Interactive` functions (e.g., `setup-docker`, `setup-podman`, `terminate`), and one hard-fails with `exit 1` (e.g., `repair-interop`). Each action function should own its argument validation: accept what's given, prompt for what's missing. This eliminates the `IsNullOrWhiteSpace` checks in the switch, removes the need for separate `*Interactive` wrapper functions, and makes every command usable without arguments.

**Current inconsistencies** in `Invoke-WslManager` switch:
- `remove`, `update`, `clone` — pass `$Name` through; action functions prompt if missing
- `setup-docker`, `setup-podman`, `terminate` — check `$Name` in switch, branch to `*Interactive` vs non-Interactive function
- `repair-interop` — checks `$Name`, hard-fails with `exit 1` if missing
- `setup-user` — passes through; function handles it internally

**Scope decisions**:
- Each action function checks its own required arguments and prompts via `Read-Host` when missing
- `Invoke-WslManager` switch becomes a simple pass-through dispatcher — no `IsNullOrWhiteSpace` checks
- Separate `*Interactive` wrapper functions (`Invoke-SetupDockerInteractive`, `Invoke-SetupPodmanInteractive`) are merged into their non-Interactive counterparts
- `repair-interop` prompts for distro name instead of hard-failing

**Acceptance Criteria**:
- [ ] All `IsNullOrWhiteSpace` checks removed from `Invoke-WslManager` switch
- [ ] Each action function prompts for missing required arguments
- [ ] `Invoke-SetupDockerInteractive` and `Invoke-SetupPodmanInteractive` merged into `Invoke-SetupDocker` and `Invoke-SetupPodman`
- [ ] `repair-interop` prompts for distro name when not provided
- [ ] CLI mode with all arguments provided behaves unchanged (no prompts)
- [ ] Unit tests updated
- [ ] All existing tests continue to pass

---

### [FEAT-005] Scoop Update Helper Script

**Status**: Open
**Priority**: Low
**Component**: `tools/scoop/update-scoop.ps1` (new), `tools/scoop/update-scoop.bat` (new), `tools/scoop/update-scoop.Tests.ps1` (new)

**Description**:
Interactive helper script to update installed Scoop packages. Launched via Keypirinha or FlowLauncher (`.bat` wrapper). Always runs `scoop update` first to refresh Scoop and bucket info, then asks the user whether to update all packages or specific ones. For specific packages, shows a numbered list of installed packages for selection.

**Behavior**:
1. Run `scoop update` (refresh Scoop itself + bucket info)
2. Prompt: "Update [A]ll packages or [S]pecific packages?"
3. **All**: Run `scoop update *`
4. **Specific**: List installed packages (numbered), user selects by number(s), run `scoop update <selected>`

**Implementation** (follows `tools/flow-launcher/` pattern):
- Standalone executable script with `Set-StrictMode`, sources `pslib/utils/utils.ps1`
- Uses `Invoke-CommandLine` for all Scoop commands
- Uses `Write-Status` / `Write-Success` / `Write-ErrorMsg` for output
- CI/test environment awareness via `Test-RunningInCIorTestEnvironment`
- `.bat` wrapper for launcher integration

**Acceptance Criteria**:
- [ ] `update-scoop.ps1` script created in `tools/scoop/`
- [ ] `.bat` wrapper created for Keypirinha/FlowLauncher launch
- [ ] Runs `scoop update` to refresh Scoop before updating packages
- [ ] Prompts user to choose "all" or "specific" update mode
- [ ] "All" mode runs `scoop update *`
- [ ] "Specific" mode shows numbered list of installed packages
- [ ] User can select one or more packages by number
- [ ] Uses `Invoke-CommandLine` for all external commands
- [ ] Clear status/success/error output
- [ ] Unit tests with mocked Scoop commands
- [ ] All existing tests continue to pass

### Technical Debt

*No items yet*

### Documentation

*No items yet*

---

### [REFACT-005] ✅ COMPLETED - Extract `Assert-WslDistroExists` guard to replace inline distro validation (DRY)

**Status**: **Completed** (2026-02-24) | **Branch**: `feature/feat-002-podman-wsl`
**Priority**: Medium
**Component**: `tools/pslib/wsl/` (7 source files, 7 test files)
**Related**: REFACT-004 (same pattern — entry-point guard extraction)

**Description**:
Extracted throwing `Assert-WslDistroExists` and `Assert-WslDistroNotExists` guard functions into `core.ps1` and replaced 22 inline distro-existence validation patterns (trim + `Get-WslDistroList` + `-notin` + throw) across 7 source files. Also absorbed `.Trim()` into `Test-WslDistroExists`. Error messages now consistently include the list of installed distributions. Following the `Assert-Wsl2Installed` pattern from REFACT-004.

**Acceptance Criteria**:
- [x] `Test-WslDistroExists` absorbs `.Trim()` internally
- [x] New `Assert-WslDistroExists` function with unit tests (4 tests)
- [x] New `Assert-WslDistroNotExists` function with unit tests (3 tests)
- [x] All 22 inline distro-existence checks replaced (including the 2 enhanced-message sites and the inverse check)
- [x] Redundant `$DistroName.Trim()` / `$Name.Trim()` calls removed where they only served the validation
- [x] `Test-WslDistroExists` (boolean) remains available for non-throwing use
- [x] Error message always includes installed distros list: `"Distribution '<name>' does not exist. Installed distributions: <list>"`
- [x] All 745 tests pass (mock updates only, no behavior change)
- [x] No change in user-facing behavior

---

### [REFACT-004] ✅ COMPLETED - Remove redundant `Test-WslInstalled` guard checks (DRY)

**Status**: **Completed** (2026-02-24) | **Branch**: `feature/feat-002-podman-wsl`
**Priority**: Medium
**Component**: `tools/pslib/wsl/` (8 source files, 8 test files)

**Description**:
Removed 32 redundant `Test-WslInstalled` guard blocks from 8 source files and ~250 `Mock Test-WslInstalled { $true }` boilerplate lines from 8 test files. WSL 2 availability is now validated once at the `Invoke-WslManager` entry point via a new `Assert-Wsl2Installed` function. This also upgraded the check from WSL 1 detection to WSL 2 detection (`wsl --version` only exists in the WSL 2 store app).

**Acceptance Criteria**:
- [x] New `Assert-Wsl2Installed` function that throws if WSL 2 is not installed
- [x] `Invoke-WslManager` calls the assertion once before dispatching
- [x] All 32 `if (-not (Test-WslInstalled))` guard blocks removed from individual functions
- [x] 23 "When WSL is not installed" test contexts deleted from test files
- [x] ~250 `Mock Test-WslInstalled { $true }` lines removed from remaining test contexts
- [x] Mocks preserved in `Test-WslInstalled` and `Assert-Wsl2Installed` test describes
- [x] `Test-WslInstalled` (the boolean check) remains available for non-throwing use cases
- [x] All 737 tests pass (down from 764 — 27 removed tests were redundant guard tests)
- [x] No change in user-facing behavior

---

### [BUG-004] ✅ COMPLETED - Flaky integration test for terminating already-stopped distribution

**Status**: **Completed** (2026-02-22) | **Branch**: `refinement`
**Priority**: Low
**Component**: `tools/pslib/wsl/wsl-manager.docker.Integration.Tests.ps1`

**Description**:
The "Should handle terminating an already stopped distribution gracefully" integration test was flaky. It asserted the output matched `"No running"`, which is the early-exit message from `Invoke-TerminateDistro` when zero distros are running. However, when other WSL distros happened to be running on the machine, the code took a different path through `Stop-WslDistro`, which emits `"Distribution '<name>' is not running."` — failing the regex match.

**Fix**: Replaced the brittle message assertion with two robust checks: (1) the operation does not throw, and (2) the distribution remains in `Stopped` state. This validates the actual contract (graceful no-op) regardless of other running distros.

**Acceptance Criteria**:
- [x] Test no longer depends on specific warning message text
- [x] Test asserts no exception is thrown (graceful handling)
- [x] Test asserts distribution remains in Stopped state
- [x] Test passes regardless of other running WSL distributions

---

### [CHORE-001] ✅ COMPLETED - Move reusable skills to global ~/.claude/skills

**Status**: **Completed** (2026-02-22) | **Branch**: `refinement`
**Priority**: Low
**Component**: `.claude/skills/`

**Description**:
Moved refinement, retrospective, and skill-creator skills to a dedicated git repo (`xxthunder/my-agentic-skills`) and configured them globally via `~/.claude/skills/`. Generalized project-specific references in refinement and retrospective skills. Removed project-level copies.

**Acceptance Criteria**:
- [x] Global skills repo created and pushed to GitHub
- [x] Generalized refinement and retrospective skills (removed project-specific references)
- [x] skill-creator copied as-is (already generic)
- [x] Project-level copies removed

---

### [CI-003] ✅ COMPLETED - Normalize JaCoCo XML paths for Codecov coverage

**Status**: **Completed** (2026-02-21) | **Branch**: `feature/ci-003-normalize-jacoco-xml`
**Priority**: Low
**Component**: `test/bin/testrunner.ps1`, `test/bin/testrunner.Tests.ps1`

**Description**:
Codecov could not display line-by-line coverage because Pester's JaCoCo XML embeds a common-parent-leaf prefix (e.g., `shortcuts/`) in package names and full relative paths in sourcefile names. Codecov constructs paths as `<package>/<sourcefile>`, producing doubled paths like `shortcuts/bin/bin/install.ps1`. Added `ConvertTo-RelativeJaCoCoXml` to strip the prefix and reduce sourcefile names to bare filenames. Also added `Import-XmlWithoutDtd` helper to handle JaCoCo's DOCTYPE declaration under strict mode.

**Acceptance Criteria**:
- [x] `ConvertTo-RelativeJaCoCoXml` helper function added to `testrunner.ps1`
- [x] Strips common-parent-leaf prefix from `package` `name` attributes
- [x] Strips common-parent-leaf prefix from `class` `name` attributes
- [x] Reduces `sourcefile` `name` to bare filename
- [x] Reduces `class` `sourcefilename` to bare filename
- [x] Handles single and multiple packages
- [x] File is saved as valid XML
- [x] Unit tests in `testrunner.Tests.ps1` (7 tests)
- [x] All existing tests continue to pass (715 total)

---

### [CI-002] ✅ COMPLETED - Normalize JUnit XML paths for Codecov Test Analytics

**Status**: **Completed** (2026-02-21) | **Branch**: `feature/ci-001-normalize-junit-xml`
**Priority**: Low
**Component**: `test/bin/testrunner.ps1`, `test/bin/testrunner.Tests.ps1` (new)

**Description**:
Codecov's test-results-parser cannot properly process Pester's JUnit XML output because Pester embeds absolute Windows paths (with backslashes and drive letters) into `testsuite name/package`, `testcase classname`, and `testcase name` attributes. Added `ConvertTo-RelativeJUnitXml` helper to post-process the JUnit XML after Pester generates it, stripping the repo root prefix and converting backslashes to forward slashes.

**Acceptance Criteria**:
- [x] `ConvertTo-RelativeJUnitXml` helper function added to `testrunner.ps1`
- [x] Strips repo root from `testsuite` `name` and `package` attributes
- [x] Strips repo root from `testcase` `classname` and `name` attributes
- [x] Converts backslashes to forward slashes in all normalized attributes
- [x] Preserves non-path content in attributes (e.g., `.Shall not have deviations`)
- [x] Handles trailing backslash on repo root (with and without)
- [x] File is saved as valid XML
- [x] Unit tests in `testrunner.Tests.ps1` (8 tests)
- [x] All existing tests continue to pass (708 total)

---

### [CI-001] ✅ COMPLETED - Upload code coverage and test results to Codecov

**Status**: **Completed** (2026-02-21) | **Branch**: `feature/ci-codecov-upload`
**Priority**: Low
**Component**: `.github/workflows/test.yml`

**Description**:
Added Codecov upload steps to the CI workflow. Coverage data (JaCoCo XML) and test results (JUnit XML) from Pester test runs are now reported to codecov.io, enabling coverage tracking and Test Analytics (flaky test detection, failure rates, PR comments).

**Acceptance Criteria**:
- [x] Coverage XML is uploaded to Codecov after each CI run
- [x] JUnit XML test results are uploaded to Codecov after each CI run
- [x] Both PS7 and PS5 matrix entries upload with distinct flags
- [x] Upload failures fail the build (`fail_ci_if_error: true`)
- [x] Uses `CODECOV_TOKEN` secret for authentication

---

### [REFACT-003] ✅ COMPLETED - Refactor wsl-manager integration tests to call wsl-manager functions

**Status**: **Completed** (2026-02-21) | **Branch**: `feature/refact-001-002-003`
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.docker.Integration.Tests.ps1`

**Description**:
Refactored integration tests to dot-source `wsl-manager.ps1` and call `Invoke-WslManager` in-process instead of subprocess invocations. All operations with a wsl-manager wrapper now route through the public API. BeforeAll/AfterAll retain pslib calls for setup/teardown. Script Execution and Docker Setup contexts retain direct pslib calls (no wsl-manager wrapper exists).

**Acceptance Criteria**:
- [x] No subprocess calls (`& $script:wslManagerPath`) remain in the test file
- [x] No direct pslib calls for operations that have a wsl-manager wrapper (including State Validation)
- [x] `Invoke-UpdateDistro`, `Invoke-CloneDistro`, `Invoke-SetupUser` are exercised indirectly via `Invoke-WslManager` routing
- [x] `Script Execution` and `Docker Setup` contexts retain their direct pslib calls unchanged
- [x] BeforeAll/AfterAll retain pslib calls for setup/teardown
- [x] Output assertions updated to match in-process output (no null-char stripping or stream merging workarounds)
- [x] All integration tests pass end-to-end

---

### [BUG-003] ✅ COMPLETED - UTF-8 BOM in integration test bash scripts causes shebang error

**Status**: **Completed** (2026-02-20) | **Branch**: `feature/feat-002-podman-wsl`
**Priority**: Low
**Component**: `tools/pslib/wsl/wsl-manager.docker.Integration.Tests.ps1`

**Description**:
The "Script Execution" integration tests wrote temporary bash scripts using `[System.Text.Encoding]::UTF8`, which in .NET includes a BOM (`EF BB BF`). Bash cannot parse a BOM before the shebang, producing: `/mnt/c/.../script.sh: line 1: ﻿#!/bin/bash: No such file or directory`. Tests still passed because bash continued past the failed shebang, but the error message was misleading.

**Fix**: Replaced with `New-Object System.Text.UTF8Encoding($false)` (BOM-less UTF-8) in both test script writers.

---

### [REFACT-002] ✅ COMPLETED - Fix `Invoke-SetupUser` CI guard scope and add explicit parameters

**Status**: **Completed** (2026-02-20) | **Branch**: `feature/feat-002-podman-wsl`
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Blocks**: REFACT-003

**Description**:
Added optional `-Username` and `-Password` parameters to `Invoke-SetupUser`. Moved the `Test-RunningInCIorTestEnvironment` guard to wrap only the prompting block, so programmatic calls with explicit parameters work even under Pester. `Invoke-WslManager` passes both params through for the `"setup-user"` command.

**Acceptance Criteria**:
- [x] `Invoke-SetupUser -DistroName "debian-test" -Username "testuser" -Password "pass"` calls `New-WslUser` without prompting, even under Pester
- [x] `Invoke-WslManager -Command "setup-user" -Name "debian-test" -Username "testuser" -Password "pass"` passes both params through
- [x] When `-Username`/`-Password` are omitted, interactive behaviour is unchanged
- [x] CI guard fires when prompting is needed but is bypassed when both params are provided
- [x] Unit tests cover both non-interactive and interactive paths
- [x] All existing tests continue to pass

---

### [REFACT-001] ✅ COMPLETED - Add `-Selection` parameter to `Invoke-UpdateDistro` and `Invoke-RemoveDistro`

**Status**: **Completed** (2026-02-20) | **Branch**: `feature/feat-002-podman-wsl`
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Blocks**: REFACT-003

**Description**:
`Invoke-UpdateDistro` and `Invoke-RemoveDistro` had no parameters — they were purely interactive, always calling `Read-Host`. Added an optional `-Selection` parameter to both functions. When `-Selection` is provided, `Read-Host` is skipped; all other logic (list display, number/name resolution, validation) runs in both cases — single code path. `Invoke-WslManager` passes `$Name` as `-Selection` for the `"update"` and `"remove"` commands.

**Acceptance Criteria**:
- [x] `Invoke-RemoveDistro -Selection "debian-test"` removes without prompting
- [x] `Invoke-UpdateDistro -Selection "Debian"` updates without prompting
- [x] `Invoke-WslManager -Command "remove" -Name "debian-test"` passes `$Name` as `-Selection`
- [x] `Invoke-WslManager -Command "update" -Name "Debian"` passes `$Name` as `-Selection`
- [x] When `-Selection` is omitted, interactive behaviour (Read-Host prompt) is unchanged
- [x] Unit tests cover both non-interactive (selection provided) and interactive paths
- [x] All existing tests continue to pass

---

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
