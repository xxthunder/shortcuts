# WSL Podman Setup Guide

This guide describes how to set up rootless Podman in a WSL2 distribution as a Docker alternative for VS Code DevContainer usage.

## Podman vs Docker

| Feature | Docker | Podman |
|---------|--------|--------|
| Architecture | Daemon-based (`dockerd`) | Daemonless |
| Root required | Docker daemon runs as root | Fully rootless |
| Systemd integration | Requires `systemctl start docker` | User-level socket activation |
| CLI compatibility | `docker` | `podman` (drop-in compatible) |
| DevContainer support | Native | Via `DOCKER_HOST` + socket |
| OCI compliant | Yes | Yes |

**When to use Podman:**
- Security-conscious environments (no root daemon)
- Minimal resource footprint (no background daemon)
- Rootless container workflows

**When to use Docker:**
- Existing Docker Compose workflows with daemon-dependent features
- Third-party tools that require the Docker daemon socket

**Mutual exclusion:** `setup-podman` will refuse to install if Docker is already present in the distribution (and vice versa). This avoids `DOCKER_HOST` confusion between the Docker socket and Podman socket.

---

## Quick Start

```powershell
# 1. Create or use an existing Ubuntu/Debian distribution
wsl-manager create Ubuntu

# 2. Setup a non-root user (required)
wsl-manager setup-user Ubuntu

# 3. Install rootless Podman (idempotent — safe to re-run)
wsl-manager setup-podman Ubuntu
```

Or use the interactive menu:

```powershell
wsl-manager
# Select: [P] Setup Podman (rootless, includes systemd/interop)
```

---

## What `setup-podman` Configures

The command is idempotent — safe to run multiple times to verify or repair your installation.

### 1. wsl.conf settings

- `[boot] systemd=true` — enables systemd (required for socket activation)
- `[boot] command=mount --make-rshared /` — prevents rootless container mount propagation warnings
- `[interop] enabled=true, appendWindowsPath=true` — Windows executable access

### 2. Podman packages

- `podman` — container runtime
- `slirp4netns` — rootless networking (user-space network stack)
- `uidmap` — user namespace mapping for rootless containers

### 3. Rootless Podman socket

- `systemctl --user enable --now podman.socket` — socket activation as the default user
- Socket path: `/run/user/$UID/podman/podman.sock`

### 4. User session persistence

- `loginctl enable-linger $USER` — keeps systemd user services alive across sessions

### 5. Environment variables in `~/.bashrc`

- `XDG_RUNTIME_DIR=/run/user/$(id -u)` — systemd user runtime directory
- `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus` — D-Bus session bus
- `DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock` — routes Docker CLI commands to Podman

### 6. Distribution restart

Automatically restarts the distribution to apply wsl.conf changes.

---

## Prerequisites

### cgroups v2 (Recommended)

Rootless Podman works best with cgroups v2. WSL2 may use a hybrid cgroups v1/v2 setup by default. To enable pure cgroups v2, add to `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
```

Then restart WSL:

```powershell
wsl --shutdown
```

**Note:** `setup-podman` will detect and warn if cgroups v2 is not enabled, but will not modify Windows-side files. Podman still works without pure cgroups v2, but some advanced features (resource limits) may be limited.

### Non-root default user

Podman setup requires a non-root default user configured in the distribution. Set one up with:

```powershell
wsl-manager setup-user <DistroName>
```

---

## VS Code Dev Containers Configuration

Podman can serve as the container runtime for VS Code Dev Containers. These settings must be configured manually.

### VS Code Settings (`settings.json`)

```json
{
  "dev.containers.dockerPath": "podman",
  "dev.containers.mountWaylandSocket": false
}
```

- `dockerPath`: Tells VS Code to use `podman` instead of `docker`
- `mountWaylandSocket`: Disables Wayland socket mount (avoids WSL2 socket error)

### devcontainer.json

For rootless Podman, add `--userns=keep-id` to your `devcontainer.json`:

```json
{
  "runArgs": ["--userns=keep-id"]
}
```

This maps your host UID into the container, which is critical for file permissions in rootless mode. Without it, files created in mounted volumes may be owned by a different user.

---

## Verification

After installation, verify everything is working:

```bash
# Start your WSL distribution
wsl --distribution Ubuntu

# Check Podman version
podman --version

# Check Podman socket
ls -la /run/user/$(id -u)/podman/podman.sock

# Check Podman can run containers
podman info
podman run --rm hello-world

# Check DOCKER_HOST routes to Podman
echo $DOCKER_HOST
# Expected: unix:///run/user/<uid>/podman/podman.sock

# Check systemd user services
systemctl --user status podman.socket

# Check linger is enabled
loginctl show-user $(whoami) -p Linger
# Expected: Linger=yes
```

---

## Git and SSH Configuration

Once your WSL distribution is set up with Podman, you'll want git and SSH working for repository access. Since `setup-podman` enables WSL interop (`[interop] enabled=true`), you can reuse your Windows git and SSH configuration directly.

### Reuse Windows `.gitconfig` via Symlink

Instead of duplicating git settings, symlink your Windows `.gitconfig`:

```bash
ln -s /mnt/c/Users/<your-windows-username>/.gitconfig ~/.gitconfig
git config --global --list   # verify
```

### Reuse Windows SSH Keys via `ssh.exe`

Ensure your `.gitconfig` (Windows or symlinked) contains:

```ini
[core]
    sshCommand = ssh.exe
```

If not, add it:

```bash
git config --global core.sshCommand "ssh.exe"
```

With interop enabled, this tells git to use the **Windows OpenSSH client**, which means:

- **SSH keys** in `%USERPROFILE%\.ssh\` are used automatically — no need to copy keys into WSL.
- **SSH config** (`%USERPROFILE%\.ssh\config`) with host aliases, proxy settings, etc. is shared.
- The **Windows SSH Agent** handles authentication, so keys loaded via `ssh-add` on Windows work inside WSL.

**Verify:**

```bash
ssh.exe -T git@github.com
# Expected: Hi <username>! You've successfully authenticated...
```

For the full DevContainer setup workflow (SSH agent, VS Code settings, validation), see [WSL DevContainer Setup Guide](wsl-devcontainer-setup.md).

---

## Performance

**Store projects in the WSL filesystem, not `/mnt/c/`.**

File operations on `/mnt/c/` (the Windows filesystem) are significantly slower due to the 9P protocol bridge. For best container build and runtime performance, clone your repositories inside the WSL home directory:

```bash
# Good — fast
cd ~ && git clone git@github.com:user/project.git

# Slow — avoid
cd /mnt/c/Users/username/projects && git clone ...
```

---

## Troubleshooting

### Podman socket not found

**Symptoms:** `podman` commands hang or fail with socket errors

**Solutions:**

1. Verify the socket exists:

```bash
ls -la /run/user/$(id -u)/podman/podman.sock
```

2. Check the socket service:

```bash
systemctl --user status podman.socket
# If inactive:
systemctl --user enable --now podman.socket
```

3. Verify linger is enabled (keeps user services alive):

```bash
loginctl show-user $(whoami) -p Linger
# If Linger=no:
sudo loginctl enable-linger $(whoami)
```

### Systemd race condition after restart

**Symptoms:** `systemctl --user` fails with "Failed to connect to bus" right after `wsl --distribution`

**Solution:** Wait a few seconds for systemd to finish initializing, then retry:

```bash
sleep 2 && systemctl --user status podman.socket
```

Or check if `XDG_RUNTIME_DIR` is set:

```bash
echo $XDG_RUNTIME_DIR
# Expected: /run/user/<uid>
# If empty, source .bashrc:
source ~/.bashrc
```

### cgroups warning

**Symptoms:** `podman info` shows `cgroupVersion: v1` or warnings about cgroup controllers

**Solution:** Enable pure cgroups v2 in `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
```

Then restart WSL: `wsl --shutdown`

### Mount propagation warnings

**Symptoms:** Warnings about mount propagation when running containers

**Solution:** Verify `mount --make-rshared /` is in your wsl.conf boot command:

```bash
grep "mount --make-rshared" /etc/wsl.conf
# Expected: command=mount --make-rshared /
```

If missing, re-run `wsl-manager setup-podman <DistroName>` to repair.

### Docker is already installed

**Symptoms:** `setup-podman` fails with "Docker is already installed"

**Solution:** Podman and Docker cannot coexist in the same distribution due to `DOCKER_HOST` conflicts. Either:
- Use a different distribution for Podman (clone your base distro first)
- Remove Docker first, then install Podman

---

## Reference

### WSL Manager Functions

- `Install-WslPodman -DistroName <name>`: Installs rootless Podman and configures all prerequisites
- `Test-WslPodmanInstalled -DistroName <name>`: Returns `$true` if Podman is installed

### Socket path

```
/run/user/<UID>/podman/podman.sock
```

### Environment variables (set in `~/.bashrc`)

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
```

### wsl.conf sections (managed by automation)

```ini
[boot]
command=mount --make-rshared /
systemd=true

[interop]
appendWindowsPath=true
enabled=true

[user]
default=<your-username>
```

---

## Additional Resources

- [Podman Documentation](https://podman.io/)
- [VS Code Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Podman + WSL2 + Dev Containers Guide](https://github.com/containers/podman/discussions/25607)
- [Rootless Podman](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
