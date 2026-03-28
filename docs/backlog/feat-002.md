# [FEAT-002] ✅ COMPLETED - Set up Podman as Docker alternative in WSL

**Status**: Completed (2026-02-24)
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
- Pester unit tests in `podman.Tests.ps1`

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
- [x] Documentation in `docs/wsl-manager.md` (unified guide)
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
