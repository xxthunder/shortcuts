# Shortcuts - Backlog

**Version**: 1.0.0 | **Created**: 2026-01-29

This document contains the detailed backlog of tasks, improvements, and bug fixes for the Shortcuts project.

---

## Active Items

### Bugs

#### [BUG-001] WSL Manager fails when no distributions are installed

**Status**: Open
**Priority**: High
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Affected Commit**: `1bbca8a`

**Description**:
When no WSL distributions are installed, `wsl-manager` crashes with a type conversion error:

```
✗ Cannot convert value "distributions." to type "System.Int32".
Error: "The input string 'distributions.' was not in a correct format."
```

**Expected Behavior**:
- Should gracefully handle the case when no distributions exist
- Display a user-friendly message (e.g., "No WSL distributions found")
- Provide guidance on how to install distributions

**Root Cause**:
Likely attempting to parse distribution count or ID from WSL output when the output format differs for zero distributions.

**Acceptance Criteria**:
- [ ] No error when running `wsl-manager` with zero distributions installed
- [ ] Clear message indicating no distributions are available
- [ ] Proper exit handling (exit gracefully or prompt for installation)
- [ ] Unit test covering zero-distribution scenario
- [ ] Integration test validated on system with no WSL distros

---

## Backlog Items

### Enhancements

#### [FEAT-001] Prepare WSL distro for VS Code Dev Container usage

**Status**: Open
**Priority**: Medium
**Component**: `tools/pslib/wsl/wsl-manager.ps1`
**Related**: Dev Container workflow

**Description**:
Add functionality to `wsl-manager` to prepare a WSL distribution for optimal VS Code Dev Container usage. This includes configuring interop settings, systemd compatibility, and providing git configuration guidance.

**Rationale**:
Dev Containers require proper Windows-WSL interop and systemd support. Automating this setup reduces manual configuration and ensures consistent development environments.

**Implementation Steps**:

**Step 1: Configure WSL Interop**
- Add/update `[interop]` section in `/etc/wsl.conf`:
  ```ini
  [interop]
  enabled = true
  appendWindowsPath = true
  ```
- Ensure proper permissions and backup existing config

**Step 2: Permanent Systemd Interop Fix**
- Apply binfmt configuration for WSL interop with systemd:
  ```bash
  echo ':WSLInterop:M::MZ::/init:PF' | sudo tee /etc/binfmt.d/wsl.conf
  ```
- Verify persistence across WSL restarts

**Step 3: Git Configuration Documentation**
- Create `docs/wsl-devcontainer-setup.md` with:
  - Git credential helper configuration
  - User name/email setup inside containers
  - SSH key handling between Windows/WSL/containers
  - Line ending configuration (core.autocrlf)
  - Best practices for .gitconfig placement

**Acceptance Criteria**:
- [ ] New command/option in wsl-manager (e.g., `wsl-manager prepare-devcontainer <distro>`)
- [ ] Safely modifies /etc/wsl.conf with proper backup
- [ ] Applies binfmt.d fix correctly
- [ ] Detects and skips if already configured
- [ ] Clear success/error messages for each step
- [ ] Documentation created in `docs/wsl-devcontainer-setup.md`
- [ ] Unit tests for configuration logic
- [ ] Integration test on fresh WSL distro
- [ ] User prompted before making changes (interactive mode)
- [ ] Non-interactive mode for automation (CI/scripting)

**Technical Notes**:
- Requires sudo access inside WSL distro
- May require WSL restart (`wsl --terminate <distro>`) after wsl.conf changes
- Should validate systemd is enabled in the distro
- Consider checking Windows VSCode + Dev Containers extension presence

**Dependencies**:
- WSL 2
- Systemd-enabled distribution
- Sudo access in target distro

---

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

*Items will be moved here when completed*

---

## Notes

- Use format `[TYPE-###]` for item IDs (e.g., `BUG-001`, `FEAT-001`, `DEBT-001`)
- Link to commits, files, and line numbers where relevant
- Keep items actionable with clear acceptance criteria
