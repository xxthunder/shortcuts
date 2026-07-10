[← Back to README](../README.md)

# WSL Manager

## Overview

WSL Manager is a PowerShell tool for managing Windows Subsystem for Linux (WSL) distributions. It provides both a **TUI** (Terminal User Interface - a menu-driven interface launched by running the script without arguments) and **CLI** commands for creating, cloning, configuring, and managing WSL distributions - including one-command Docker and Podman setup for development containers.

**Contents:**

- [Quick Start](#quick-start)
- [DevContainer Setup](#devcontainer-setup)
  - [Docker vs Podman](#docker-vs-podman)
  - [DevPods vs VS Code Dev Containers Extension](#devpods-vs-vs-code-dev-containers-extension)
  - [Step 1: Configure WSL Global Settings](#step-1-configure-wsl-global-settings)
  - [Step 2: Install WSL Distribution](#step-2-install-wsl-distribution)
  - [Step 3: Setup User Account](#step-3-setup-user-account)
  - [Step 4: Configure Proxy (Corporate Networks)](#step-4-configure-proxy-corporate-networks)
  - [Step 5: Update Distribution](#step-5-update-distribution)
  - [Step 6: Windows SSH Agent Setup](#step-6-windows-ssh-agent-setup)
  - [Step 7: Git Configuration](#step-7-git-configuration)
  - [Step 8: Clone Distribution (Optional)](#step-8-clone-distribution-optional)
  - [Step 9: Install Container Runtime](#step-9-install-container-runtime)
  - [Step 10: Install Dev Container Client](#step-10-install-dev-container-client)
  - [Step 11: Sync SSH Config](#step-11-sync-ssh-config)
  - [Validation](#validation)
  - [Performance Tips](#performance-tips)
  - [Troubleshooting](#troubleshooting)
- [Commands Reference](#commands-reference)
  - [Install New Distribution](#install-new-distribution)
  - [Clone Distribution](#clone-distribution)
  - [Update Distribution](#update-distribution)
  - [Setup User Account](#setup-user-account)
  - [Setup Proxy](#setup-proxy)
  - [Setup Docker](#setup-docker)
  - [Setup Podman](#setup-podman)
  - [Setup DevPod](#setup-devpod)
  - [Sync SSH Config](#sync-ssh-config)
  - [Configure .wslconfig Defaults](#configure-wslconfig-defaults)
  - [Remove Distribution](#remove-distribution)
  - [Terminate Distribution](#terminate-distribution)
  - [Shutdown WSL](#shutdown-wsl)
- [Technical Reference](#technical-reference)
  - [Module Structure](#module-structure)
  - [Library Usage](#library-usage)
  - [Configuration Files](#configuration-files)
- [Architecture](#architecture)
- [Additional Resources](#additional-resources)

---

## Quick Start

**TUI**: To launch the TUI, search for `wsl-manager` in Keypirinha or Flow Launcher, or launch directly from a PowerShell terminal:

```powershell
.\tools\wsl-manager\wsl-manager.ps1
```

Use arrow keys to navigate, Enter to select, and type to search.

**CLI**: Run commands directly:

```powershell
.\tools\wsl-manager\wsl-manager.ps1 <command> <distro>
```

---

## DevContainer Setup

This section walks you from a fresh Windows machine to running dev containers in WSL, with proper SSH agent forwarding and git configuration. It covers both Docker and Podman as container runtimes, and both DevPods and the VS Code Dev Containers extension as dev container clients.

> **Recommended setup:** **Podman** + **DevPods**. Podman is rootless and daemonless (more secure, lighter footprint). DevPods are IDE-independent; you can use them with VS Code, JetBrains IDEs, or any editor, without being locked into a specific IDE extension.

### Docker vs Podman

Choose one container runtime per distribution. They cannot coexist in the same WSL distribution due to `DOCKER_HOST` conflicts.

| Feature | Docker | Podman (recommended) |
|---------|--------|--------|
| Architecture | Daemon-based (`dockerd`) | Daemonless |
| Root required | Docker daemon runs as root | Fully rootless |
| Systemd integration | Requires `systemctl start docker` | User-level socket activation |
| CLI compatibility | `docker` | `podman` (drop-in compatible) |
| Dev container support | Native | Via `DOCKER_HOST` + socket |
| OCI compliant | Yes | Yes |

**When to use Podman (recommended):**
- Security-conscious environments (no root daemon)
- Minimal resource footprint (no background daemon)
- Rootless container workflows

**When to use Docker:**
- Existing Docker Compose workflows with daemon-dependent features
- Third-party tools that require the Docker daemon socket

### DevPods vs VS Code Dev Containers Extension

| Feature | DevPods (recommended) | VS Code Dev Containers Extension |
|---------|----------|-------------------------------|
| IDE support | Any IDE (VS Code, JetBrains, etc.) | VS Code only |
| Installation | CLI binary in WSL | VS Code extension |
| Configuration | `devpod provider use` | VS Code settings |
| IDE independence | Yes - not tied to any editor | No - requires VS Code |

**When to use DevPods (recommended):**
- You want IDE independence; switch between VS Code and JetBrains freely
- You prefer CLI-driven workflows
- You want a single tool that works across all editors

**When to use VS Code Dev Containers extension:**
- You exclusively use VS Code and want deep IDE integration
- You rely on VS Code-specific dev container features (e.g., settings sync, extension recommendations)

Each step shows equivalent **TUI** and **CLI** instructions; pick whichever you prefer. Each step links to the [Commands Reference](#commands-reference) for full details on what gets configured.

### Step 1: Configure WSL Global Settings

Apply recommended global WSL settings to `%USERPROFILE%\.wslconfig` (pure cgroups v2, mirrored networking, DNS tunneling, auto proxy). The WSL subsystem is automatically shut down after the changes are applied so the new global settings take effect.

- **TUI**: select **Configure .wslconfig defaults**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 configure-wsl`

→ [Configure .wslconfig Defaults](#configure-wslconfig-defaults)

### Step 2: Install WSL Distribution

Ubuntu 24.04 LTS is recommended; long-term support, excellent WSL compatibility, and well-tested Docker/Podman support.

- **TUI**: select **Install new distribution** → select `Ubuntu-24.04` from the list
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 install Ubuntu-24.04`

→ [Install New Distribution](#install-new-distribution)

### Step 3: Setup User Account

Create a non-root user with sudo privileges (required for both Docker and Podman).

> **Tip:** For a local development distro, a simple username like `wsluser` or `vscode` with a matching password (e.g., `wsluser`/`wsluser`) is sufficient.

- **TUI**: select **Setup user account** → select `Ubuntu-24.04`, enter username and password when prompted
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-user Ubuntu-24.04 -Username wsluser -Password wsluser`

→ [Setup User Account](#setup-user-account)

### Step 4: Configure Proxy (Corporate Networks)

If you're behind a corporate proxy, configure proxy settings before updating or installing packages so that APT, Docker, and Podman all route through the proxy. Skip this step if you have direct internet access.

- **TUI**: select **Setup proxy (corporate)** → select `Ubuntu-24.04`, follow proxy detection prompts
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-proxy Ubuntu-24.04`

→ [Setup Proxy](#setup-proxy)

### Step 5: Update Distribution

Update all packages to latest versions.

- **TUI**: select **Update distribution** → select `Ubuntu-24.04`
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 update Ubuntu-24.04`

→ [Update Distribution](#update-distribution)

### Step 6: Windows SSH Agent Setup

These steps are performed on your **Windows host**.

**Enable SSH Agent Service** — *PowerShell as Administrator*:

```powershell
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent
Get-Service ssh-agent                             # verify running
```

**Load your SSH key** — *regular (non-elevated) PowerShell*:

```powershell
ssh-add $env:USERPROFILE\.ssh\id_ed25519          # or id_rsa
ssh-add -l                                        # verify key is loaded
```

> **Why non-elevated for `ssh-add`?** The Windows ssh-agent binds each key to the caller's user SID via DPAPI. Keys added from an elevated shell are not visible from your normal shell, which silently breaks git/DevPod auth.

### Step 7: Git Configuration

**These steps must be performed inside your WSL distribution.**

```bash
wsl --distribution Ubuntu-24.04
```

> **Tip:** You can also open the distribution directly from Keypirinha: search for `Ubuntu-24.04`.

#### Option A: Reuse Windows `.gitconfig` via Symlink (Recommended)

If you already have a working `.gitconfig` in your Windows profile, symlink it into WSL:

```bash
rm -f ~/.gitconfig
ln -s /mnt/c/Users/<your-windows-username>/.gitconfig ~/.gitconfig
git config --global --list                        # verify
```

This reuses your Windows git identity, aliases, and all other settings. Any changes made on either side take effect immediately.

> **Note:** Do **not** set `core.sshCommand = ssh.exe` in your `.gitconfig`. It breaks DevPod and other tools that need Linux-native SSH. Use `sync-ssh-config` (Step 11) to copy your SSH keys into WSL instead.

#### Option B: Configure Git Manually

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
git config --global core.autocrlf input           # prevent line-ending issues
```

### Step 8: Clone Distribution (Optional)

Keep a clean base Ubuntu-24.04 and create a dedicated dev container distribution so you can experiment safely without affecting your base.

- **TUI**: select **Clone distribution** → select `Ubuntu-24.04`, enter target name `ubuntu-devcon`
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 clone Ubuntu-24.04 ubuntu-devcon`

→ [Clone Distribution](#clone-distribution)

### Step 9: Install Container Runtime

Choose **one** of the two options below. Docker and Podman cannot coexist in the same distribution.

#### Option A: Rootless Podman (Recommended)

> **Note:** Pure cgroups v2 is required for rootless Podman. This is already covered by the `kernelCommandLine` setting in Step 1.

- **TUI**: select **Setup Podman** → select `ubuntu-devcon`
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-podman ubuntu-devcon`

→ [Setup Podman](#setup-podman)

#### Option B: Docker

- **TUI**: select **Setup Docker** → select `ubuntu-devcon`
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-docker ubuntu-devcon`

→ [Setup Docker](#setup-docker)

> **Note:** After installation, restart your terminal for docker group membership to take effect.

### Step 10: Install Dev Container Client

Choose **one** of the two options below.

#### Option A: DevPods (Recommended)

DevPods are IDE-independent; they work with VS Code, JetBrains IDEs, or any editor. No IDE extension required.

- **TUI**: select **Setup DevPod** → select `ubuntu-devcon`
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-devpod ubuntu-devcon`

→ [Setup DevPod](#setup-devpod)

After installation, open any project as a dev container:

```bash
wsl --distribution ubuntu-devcon

devpod up <repository-url>
devpod up <repository-url> --ide vscode
devpod up <repository-url> --ide intellij
```

#### Option B: VS Code Dev Containers Extension

If you prefer tight VS Code integration, install these extensions:

```bash
code --install-extension ms-vscode-remote.remote-containers    # dev container support
code --install-extension ms-vscode-remote.remote-wsl           # open WSL folders in VS Code
code --install-extension ms-vscode-remote.remote-ssh           # SSH agent forwarding
```

Then configure via **File → Preferences → Settings** (`Ctrl+,`):

| Setting | Value |
|---------|-------|
| `dev.containers.copyGitConfig` | `true` — copies git config into dev containers |
| `remote.SSH.enableAgentForwarding` | `true` — enables SSH agent forwarding |

<details>
<summary>Equivalent JSON (<code>settings.json</code>)</summary>

```json
{
  "dev.containers.copyGitConfig": true,
  "remote.SSH.enableAgentForwarding": true
}
```

</details>

**Podman-specific settings** (only if you chose Podman in Step 9):

| Setting | Value |
|---------|-------|
| `dev.containers.dockerPath` | `podman` — use `podman` instead of `docker` |
| `dev.containers.mountWaylandSocket` | `false` — avoids WSL2 socket error |

<details>
<summary>Equivalent JSON (<code>settings.json</code>)</summary>

```json
{
  "dev.containers.dockerPath": "podman",
  "dev.containers.mountWaylandSocket": false
}
```

</details>

For rootless Podman, also add `--userns=keep-id` to your `devcontainer.json` to map your host UID into the container (critical for file permissions):

```json
{ "runArgs": ["--userns=keep-id"] }
```

### Step 11: Sync SSH Config

Syncs SSH configuration between Windows and the WSL distribution — copying keys, known_hosts, and SSH config in both directions. If DevPod is installed, it also syncs DevPod SSH config blocks so that Windows-side editors (VS Code, JetBrains) can connect to DevPod containers.

- **TUI**: select **Sync SSH Config** → select distribution
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 sync-ssh-config <distro>`

→ [Sync SSH Config](#sync-ssh-config)

### Validation

#### Common Checks (SSH, Git Identity)

**Test SSH forwarding (inside WSL):**

```bash
# Should authenticate successfully without password prompt
ssh -T git@github.com

# Expected output:
# Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

**Test git identity:**

```bash
git config user.email
# Expected: your.email@example.com
```

#### Docker-Specific Checks

```bash
# Verify Docker is running
docker ps

# Test dev container
# 1. Open a project with a .devcontainer configuration in VS Code
# 2. Press F1 and run "Dev Containers: Reopen in Container"
# 3. Inside the container, test git operations:
git fetch
git config user.name
git config user.email
```

#### Podman-Specific Checks

```bash
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

### Performance Tips

**Store projects in the WSL filesystem, not `/mnt/c/`.**

File operations on `/mnt/c/` (the Windows filesystem) are significantly slower due to the 9P protocol bridge. For best container build and runtime performance, clone your repositories inside the WSL home directory:

```bash
# Good - fast
cd ~ && git clone git@github.com:user/project.git

# Slow - avoid
cd /mnt/c/Users/username/projects && git clone ...
```

### Troubleshooting

#### SSH Agent Not Forwarding

**Symptoms:** `ssh -T git@github.com` asks for password

**Solutions:**

1. **Verify SSH keys are in WSL** (run inside WSL):

```bash
ls -la ~/.ssh/
# Should show your key files (id_ed25519, id_rsa, etc.)
# Private keys should be mode 600, public keys 644
```

2. **Re-run key copy if keys are missing:**

Run `sync-ssh-config` from WSL Manager to copy keys from Windows.

3. **Verify Windows SSH agent is running** (for Windows-side tools):

```powershell
Get-Service ssh-agent
# Should show Status: Running
```

4. **Verify key is loaded in Windows agent:**

```powershell
ssh-add -l
# Should show your key fingerprint
```

#### Git Identity Not Showing

**Symptoms:** Git commits have wrong author

**Solutions:**

1. **Verify global git config:**

```bash
git config --global --list | grep user
# Should show user.name and user.email
```

2. **Verify dev container copies git config**:

Check `.devcontainer/devcontainer.json` includes:

```json
{
  "features": {
    "ghcr.io/devcontainers/features/git:1": {}
  }
}
```

#### Windows Executables Not Working in WSL

**Symptoms:** Commands like `docker.exe` or `code` don't work

**Solutions:**

1. **Verify interop is enabled:**

```bash
cat /etc/wsl.conf | grep -A 2 "\[interop\]"
# Should show:
# [interop]
# enabled=true
# appendWindowsPath=true
```

2. **Verify binfmt.d configuration:**

```bash
cat /etc/binfmt.d/WSLInterop.conf
# Should show: :WSLInterop:M::MZ::/init:PF

sudo systemctl is-active systemd-binfmt
# Should show: active
```

3. **Test kernel registration:**

```bash
cat /proc/sys/fs/binfmt_misc/WSLInterop
# Should show registration details
```

4. **Restart distribution:**

```bash
wsl.exe --terminate Ubuntu-24.04
wsl --distribution Ubuntu-24.04
```

#### Docker/Interop Breaks After Opening WSL Folder in VS Code

**Symptoms:**
- Docker commands fail after opening WSL folder in VS Code: `docker: command not found`
- Windows executables fail: `notepad.exe: cannot execute binary file`
- Error: `/proc/sys/fs/binfmt_misc/WSLInterop` not found

**Cause:** Legacy rc.local configuration that VS Code can overwrite when initializing its WSL server.

**Solution:** Re-run the idempotent Docker setup to migrate to kernel-level binfmt.d configuration:

```powershell
.\tools\wsl-manager\wsl-manager.ps1 setup-docker Ubuntu-24.04
```

This detects existing Docker (no reinstall), migrates from old rc.local to `/etc/binfmt.d/WSLInterop.conf` if needed, and verifies all components.

**Verification:**

```bash
wsl -d Ubuntu-24.04 cat /etc/binfmt.d/WSLInterop.conf
# Expected: :WSLInterop:M::MZ::/init:PF

wsl -d Ubuntu-24.04 docker ps
wsl -d Ubuntu-24.04 notepad.exe
```

#### Dev Container Fails to Start

**Symptoms:** Dev container build fails or times out

**Solutions:**

1. **Verify systemd is running:**

```bash
systemctl --version
```

2. **Verify your container runtime is working:**

```bash
# Docker:
docker ps

# Podman:
podman info
```

3. **Check dev container logs:**

In VS Code, open Output panel (View > Output) and select "Dev Containers"

#### Podman Socket Not Found

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

3. Verify linger is enabled:

```bash
loginctl show-user $(whoami) -p Linger
# If Linger=no:
sudo loginctl enable-linger $(whoami)
```

#### Systemd Race Condition After Restart

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

#### cgroups Warning

**Symptoms:** `podman info` shows `cgroupVersion: v1` or warnings about cgroup controllers

**Solution:** Verify `%USERPROFILE%\.wslconfig` contains the `kernelCommandLine` from [Step 1](#step-1-configure-wsl-global-settings), then restart WSL:

```powershell
.\tools\wsl-manager\wsl-manager.ps1 shutdown
```

#### Mount Propagation Warnings

**Symptoms:** Warnings about mount propagation when running containers

**Solution:** Verify `mount --make-rshared /` is in your wsl.conf boot command:

```bash
grep "mount --make-rshared" /etc/wsl.conf
# Expected: command=mount --make-rshared /
```

If missing, re-run `.\tools\wsl-manager\wsl-manager.ps1 setup-podman <DistroName>` to repair.

#### Docker Already Installed (Mutual Exclusion)

**Symptoms:** `setup-podman` fails with "Docker is already installed"

**Solution:** Podman and Docker cannot coexist in the same distribution due to `DOCKER_HOST` conflicts. Either:
- Use a different distribution for Podman (clone your base distro first)
- Remove Docker first, then install Podman

---

## Commands Reference

### Install New Distribution

Install a new WSL distribution from Microsoft Store or the web.

- **TUI**: select **Install new distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 install <distro>`

This command:
- Fetches available distributions from `wsl.exe --list --online`
- Prompts to select a distribution by number or name (TUI) or uses the provided name (CLI)
- Validates the distribution does not already exist locally
- Installs the distribution via `wsl.exe --install --distribution <name> --no-launch`

### Clone Distribution

Export and re-import a distribution under a new name. The source must be stopped.

- **TUI**: select **Clone distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 clone <distro>`

This command:
- Exports the source distribution to a temporary tar file via `wsl.exe --export`
- Imports the tar file as a new distribution via `wsl.exe --import` into `%USERPROFILE%\wsl\<target>\`
- Cleans up the temporary tar file
- Prompts for the target name (TUI) or accepts it as a second argument (CLI)

### Update Distribution

Update all packages to latest versions (apt-based distributions).

- **TUI**: select **Update distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 update <distro>`

This command:
- Validates the distribution is Debian or Ubuntu based
- Runs `apt-get update && apt-get upgrade -y` inside the distribution
- Runs `apt-get autoremove -y && apt-get autoclean` to free disk space

### Setup User Account

Create a non-root user with sudo privileges and set as default user.

> **Tip:** For a local development distro, a simple username like `wsluser` or `vscode` with a matching password (e.g., `wsluser`/`wsluser`) is sufficient.

- **TUI**: select **Setup user account**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-user <distro>`

This command:
- Creates the user with a home directory
- Adds the user to the sudo group with NOPASSWD
- Configures `/etc/wsl.conf` to set as default user

### Setup Proxy

Configure corporate proxy settings with automatic detection. Auto-detects proxy from PAC/registry, prompts for credentials if needed, and supports DIRECT (no proxy) mode to remove proxy configurations.

- **TUI**: select **Setup proxy (corporate)**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-proxy <distro>`

This command:
- Prompts upfront for setup mode: `[A]uto` (PAC detection), `[M]anual` (enter host:port), or `[R]emove` (tear down)
- Auto mode reads `AutoConfigURL` from Windows Internet Settings and asks for confirmation before proceeding
- Auto → DIRECT collapses to Remove (no proxy needed on this network)
- Auto mode also probes for a running local **px** proxy (see [px Proxy runbook](runbooks/px-proxy.md)). When px is up, you choose between the px endpoint (`http://127.0.0.1:3128`, reachable from WSL via mirrored networking — px authenticates to the corporate proxy via SSPI on the Windows host, so no credentials are stored) and the PAC-detected corporate proxy
- After a corporate proxy URL is resolved, prompts for auth method: `[A]nonymous` (no credentials) or `[B]asic` (username/password embedded in the URL, prefilled with your Windows username)
- Configures `~/.profile` managed block with `http_proxy`, `https_proxy`, `no_proxy` exports
- Configures `/etc/apt/apt.conf.d/99proxy` for APT package manager
- Configures `~/.docker/config.json` proxy settings
- Configures `~/.config/containers/containers.conf` for Podman
- Writes `/etc/wsl-manager/proxy-mode` (`basic`) for mode-aware teardown
- Remove mode deletes all managed proxy configurations and the mode marker
- Is idempotent - safe to run multiple times (overwrites configuration)

### Setup Docker

Install Docker Engine with automatic prerequisite configuration.

- **TUI**: select **Setup Docker**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-docker <distro>`

This command:
- Validates the distribution is Debian or Ubuntu based and running WSL2
- Configures `/etc/wsl.conf` with `[boot] systemd=true`, `[interop] enabled=true`, `[automount] options=metadata`
- Creates `/etc/binfmt.d/WSLInterop.conf` for kernel-level Windows executable interop
- Installs Docker CE, Docker CLI, containerd, Docker Compose, and Docker Buildx
- Adds the default user to the `docker` group for rootless access
- Restarts the distribution to apply changes
- Is idempotent - safe to run multiple times to verify or repair

### Setup Podman

Install rootless Podman as a Docker alternative.

- **TUI**: select **Setup Podman**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-podman <distro>`

This command:
- Validates the distribution is Debian or Ubuntu based and running WSL2
- Configures `/etc/wsl.conf` with `[boot] systemd=true`, `command=mount --make-rshared /`, `[interop] enabled=true`
- Installs `podman`, `slirp4netns` (rootless networking), and `uidmap` (user namespace mapping)
- Enables the rootless Podman socket via `systemctl --user enable --now podman.socket`
- Enables user session persistence via `loginctl enable-linger`
- Sets environment variables in `~/.bashrc` (`XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`, `DOCKER_HOST`)
- Restarts the distribution to apply changes
- Is idempotent - safe to run multiple times to verify or repair

### Setup DevPod

Install the DevPod CLI and configure it to use the detected container engine (Docker or Podman).

- **TUI**: select **Setup DevPod**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-devpod <distro>`

Prerequisites: Docker (`setup-docker`) or Podman (`setup-podman`) must be installed first.

This command:
- Downloads and installs the DevPod CLI binary to `/usr/local/bin/devpod`
- Auto-detects Docker (preferred) or Podman as the container engine
- Configures the detected engine as the DevPod provider via `devpod provider use`
- Creates user configuration in `~/.config/devpod/`
- Restarts the distribution to apply changes
- Is idempotent - safe to re-run

### Sync SSH Config

Sync SSH configuration between Windows and a WSL distribution: copies keys and known_hosts, syncs non-DevPod config from Windows into WSL, and (if DevPod is installed) syncs DevPod SSH config blocks to Windows with adapted ProxyCommand for Windows-side editor access.

- **TUI**: select **Sync SSH Config**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 sync-ssh-config <distro>`

This command:
- Copies all SSH key pairs from `%USERPROFILE%\.ssh\` into the distribution's `~/.ssh/` with correct permissions (`chmod 600` private, `chmod 644` public)
- Copies `known_hosts` and `known_hosts.old` into `~/.ssh/` with `chmod 644`
- Syncs non-DevPod SSH config entries from Windows `~/.ssh/config` into WSL, preserving existing DevPod blocks
- Extracts all `# DevPod Start/End` blocks from WSL `~/.ssh/config`, adapts ProxyCommand to route through `wsl.exe -d <distro>`, and writes them to Windows `%USERPROFILE%\.ssh\config`
- Removes stale DevPod entries from the Windows config that no longer exist in WSL
- Preserves all non-DevPod entries in the Windows SSH config
- Creates timestamped backups before modifying any config file
- Is idempotent - safe to re-run after adding new keys or DevPod workspaces

### Configure .wslconfig Defaults

Apply recommended global WSL settings to `%USERPROFILE%\.wslconfig`.

- **TUI**: select **Configure .wslconfig defaults**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 configure-wsl`

This command:
- Reads existing `%USERPROFILE%\.wslconfig` (if present)
- Merges in recommended defaults without overwriting existing user values:
  - `[wsl2] kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1` (pure cgroups v2)
  - `[wsl2] networkingMode = mirrored` (mirrors Windows network interfaces)
  - `[wsl2] dnsTunneling = true` (routes DNS through Windows)
  - `[wsl2] autoProxy = true` (applies Windows proxy settings)
- For `kernelCommandLine`, appends missing parameters rather than replacing the whole value
- Creates a timestamped backup of the existing file before writing
- Auto-shuts down the WSL subsystem after changes so the new global settings take effect. **This terminates all running distributions, not just one** — `.wslconfig` is a global VM-level setting and a full `wsl --shutdown` is the only way to apply it. Running distributions are listed in a warning before the shutdown.
- Is idempotent - safe to run multiple times (skips the shutdown when nothing changed)

### Remove Distribution

Unregister a distribution (with confirmation prompt in TUI mode).

- **TUI**: select **Remove distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 remove <distro>`

This command:
- Validates the distribution exists; auto-terminates it if running
- Prompts for confirmation before proceeding (TUI shows a Y/N prompt)
- Unregisters the distribution via `wsl.exe --unregister`, permanently deleting all data
- This operation cannot be undone

### Terminate Distribution

Gracefully shut down a running distribution.

- **TUI**: select **Terminate distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 terminate <distro>`

This command:
- Shows only running distributions for selection (TUI) or validates the named distribution is running (CLI)
- Executes `wsl.exe --terminate <name>` to stop the distribution
- Polls `wsl.exe --list --verbose` with retries to verify termination
- Warns if no distributions are currently running

### Shutdown WSL

Shut down the entire WSL subsystem including all running distributions and the WSL2 VM. Use this to apply changes to `%USERPROFILE%\.wslconfig`.

- **TUI**: select **Shutdown WSL**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 shutdown`

This command:
- Lists any running distributions before shutting down (so you know what will be stopped)
- Prompts for confirmation before proceeding
- Executes `wsl.exe --shutdown` to stop all distributions and the WSL2 lightweight VM
- Polls to verify all distributions have stopped
- Is idempotent - safe to run when no distributions are running


---

## Technical Reference

### Module Structure

```
tools/wsl-manager/
├── wsl-manager.ps1            # Entry point (params + bootstrapping)
├── wsl-manager.bat            # Batch wrapper for Keypirinha
├── wsl.Integration.Tests.ps1
├── manager.docker.Integration.Tests.ps1
└── manager.podman.Integration.Tests.ps1

lib/wsl/
├── wsl.ps1                    # Main library (dot-sources all modules)
├── commands.ps1               # CLI dispatch, TUI menu & workflows
├── core.ps1                   # List, get distro info, type detection
├── docker.ps1                 # Docker installation & verification
├── exec.ps1                   # Script execution in WSL
├── install.ps1                # Clone, remove operations
├── ops.ps1                    # Update, state, terminate operations
├── podman.ps1                 # Podman installation & verification
├── proxy.ps1                  # Proxy configuration
├── user.ps1                   # User account creation & configuration
└── scripts/
    ├── install-docker.sh          # Docker Engine installation script
    ├── install-podman.sh          # Rootless Podman installation script
    └── setup-proxy.sh             # Proxy configuration script (env, apt, Docker, Podman)
```

### Library Usage

All WSL Manager functionality is also available as PowerShell functions for scripting.
See `lib/wsl/wsl.ps1` for the full library API.

### Configuration Files

**`/etc/wsl.conf` (managed by automation):**

Docker configuration:
```ini
[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=true

[user]
default=<your-username>
```

Podman configuration:
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

**`/etc/binfmt.d/WSLInterop.conf` (Docker - managed by automation):**

```
:WSLInterop:M::MZ::/init:PF
```

This kernel-level configuration is managed by `systemd-binfmt.service` and is VS Code compatible (prevents interference).

**Podman Socket and Environment Variables:**

Socket path:
```
/run/user/<UID>/podman/podman.sock
```

Environment variables (set in `~/.bashrc`):
```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
```

---

## Architecture

For the planned C4 architecture of the WSL Manager (including Context, Container, and Component diagrams), see:

- [WSL Manager C4 Architecture](architecture/wsl-manager-c4.md)

---

## Additional Resources

- [WSL Configuration Documentation](https://docs.microsoft.com/en-us/windows/wsl/wsl-config)
- [Development Containers Specification](https://containers.dev/)
- [DevPods Documentation](https://devpod.sh/docs)
- [VS Code Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Git Credential Manager Documentation](https://github.com/GitCredentialManager/git-credential-manager)
- [SSH Agent Forwarding](https://developer.github.com/v3/guides/using-ssh-agent-forwarding/)
- [Podman Documentation](https://podman.io/)
- [Podman + WSL2 + Dev Containers Guide](https://github.com/containers/podman/discussions/25607)
- [Rootless Podman](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)

---

**Notes:**
- **Why binfmt.d?** Uses kernel-level configuration managed by `systemd-binfmt.service` instead of late-boot rc.local scripts. This prevents VS Code from interfering with Windows executable interop when opening WSL folders.
- **Why copy SSH keys into WSL?** DevPod and other WSL-native tools need Linux SSH, which cannot access the Windows SSH agent. Copying keys ensures git and DevPod work with Linux-native SSH inside WSL, while the Windows SSH config gets the correct ProxyCommand for connecting from Windows editors.
- **Security consideration:** This setup forwards your SSH agent into containers. Only use with trusted dev container configurations.

---

[← Back to README](../README.md)
