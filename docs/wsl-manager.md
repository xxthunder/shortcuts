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
  - [Step 4: Install Corporate Root CA (TLS Inspection)](#step-4-install-corporate-root-ca-tls-inspection)
  - [Step 5: Configure Proxy (Corporate Networks)](#step-5-configure-proxy-corporate-networks)
  - [Step 6: Update Distribution](#step-6-update-distribution)
  - [Step 7: Windows SSH Agent Setup](#step-7-windows-ssh-agent-setup)
  - [Step 8: Git Configuration](#step-8-git-configuration)
  - [Step 9: Clone Distribution (Optional)](#step-9-clone-distribution-optional)
  - [Step 10: Set Up the Dev Stack](#step-10-set-up-the-dev-stack)
  - [Step 11: Choose a Dev Container Client](#step-11-choose-a-dev-container-client)
  - [Step 12: Sync SSH Config](#step-12-sync-ssh-config)
  - [Validation](#validation)
  - [Performance Tips](#performance-tips)
  - [Troubleshooting](#troubleshooting)
- [Commands Reference](#commands-reference)
  - [Start distribution](#start-distribution)
  - [Stop distribution](#stop-distribution)
  - [Install new distribution](#install-new-distribution)
  - [Clone distribution](#clone-distribution)
  - [Update distribution](#update-distribution)
  - [Remove distribution](#remove-distribution)
  - [Setup user account](#setup-user-account)
  - [Setup dev stack (Ansible)](#setup-dev-stack-ansible)
  - [Sync SSH config](#sync-ssh-config)
  - [Setup CA certificates (corporate)](#setup-ca-certificates-corporate)
  - [Setup proxy (corporate)](#setup-proxy-corporate)
  - [Update WSL](#update-wsl)
  - [Shutdown WSL](#shutdown-wsl)
  - [Configure .wslconfig defaults](#configure-wslconfig-defaults)
  - [Refresh list](#refresh-list)
- [Technical Reference](#technical-reference)
  - [Module Structure](#module-structure)
  - [Library Usage](#library-usage)
  - [Configuration Files](#configuration-files)
- [Architecture](#architecture)
- [Additional Resources](#additional-resources)

---

## Quick Start

**TUI**: To launch the TUI, search for `wsl-manager` in Keypirinha, or launch directly from a PowerShell terminal:

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

> **Recommended setup:** **Podman** + **DevPods**. Podman is rootless and daemonless (more secure, lighter footprint), and it is the default of `setup-dev-stack`. DevPods are IDE-independent; you can use them with VS Code, JetBrains IDEs, or any editor, without being locked into a specific IDE extension.

### Docker vs Podman

Choose one container runtime per distribution. They cannot coexist in the same WSL distribution due to `DOCKER_HOST` conflicts; `setup-dev-stack` refuses the second one before it runs Ansible. Docker is available on Debian only; Podman works on Debian and Ubuntu.

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

Apply recommended global WSL settings to `%USERPROFILE%\.wslconfig` (pure cgroups v2, mirrored networking, DNS tunneling, `autoProxy` turned off). The WSL subsystem is automatically shut down after the changes are applied so the new global settings take effect.

- **TUI**: select **Configure .wslconfig defaults**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 configure-wsl`

→ [Configure .wslconfig defaults](#configure-wslconfig-defaults)

### Step 2: Install WSL Distribution

Ubuntu 24.04 LTS is recommended; long-term support, excellent WSL compatibility, and well-tested Docker/Podman support.

- **TUI**: select **Install new distribution** → select `Ubuntu-24.04` from the list
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 install Ubuntu-24.04`

→ [Install new distribution](#install-new-distribution)

### Step 3: Setup User Account

Create a non-root user with passwordless sudo (required for `setup-dev-stack`, which runs Ansible with `sudo` and no password prompt).

> **Tip:** For a local development distro, a simple username like `wsluser` or `vscode` with a matching password (e.g., `wsluser`/`wsluser`) is sufficient.

- **TUI**: select **Setup user account** → select `Ubuntu-24.04`, enter username and password when prompted
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-user Ubuntu-24.04 -Username wsluser -Password wsluser`

→ [Setup user account](#setup-user-account)

### Step 4: Install Corporate Root CA (TLS Inspection)

If your corporate network inspects TLS, install the corporate root certificate authority (CA) into the distribution before configuring the proxy, so that HTTPS works through px. Podman containers get the bundle and the CA variables through a drop-in (see [Setup CA certificates (corporate)](#setup-ca-certificates-corporate)). The certificates come from the Windows certificate store, where the corporate root CA is already trusted. Skip this step if your network does not inspect TLS.

- **TUI**: select **Setup CA certificates (corporate)** → select `Ubuntu-24.04` → **Install** → **Auto**, press Enter for `https://www.google.com`, add intranet sites such as git or Jira when asked for another URL, check the listed roots and confirm
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-ca Ubuntu-24.04 -Url https://www.google.com,https://git.example.corp`, or by name with `-Subject '*Contoso*'` (Manual)

→ [Setup CA certificates (corporate)](#setup-ca-certificates-corporate)

### Step 5: Configure Proxy (Corporate Networks)

If you're behind a corporate proxy, configure proxy settings before updating or installing packages so that APT, Docker, Podman and the dev-stack setup all route through the proxy. Skip this step if you have direct internet access.

- **TUI**: select **Setup proxy (corporate)** → select `Ubuntu-24.04`, follow proxy detection prompts
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-proxy Ubuntu-24.04`

→ [Setup proxy (corporate)](#setup-proxy-corporate)

### Step 6: Update Distribution

Update all packages to latest versions.

- **TUI**: select **Update distribution** → select `Ubuntu-24.04`
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 update Ubuntu-24.04`

→ [Update distribution](#update-distribution)

### Step 7: Windows SSH Agent Setup

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

### Step 8: Git Configuration

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

> **Note:** Do **not** set `core.sshCommand = ssh.exe` in your `.gitconfig`. It breaks DevPod and other tools that need Linux-native SSH. Use `sync-ssh-config` (Step 12) to copy your SSH keys into WSL instead.

#### Option B: Configure Git Manually

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
git config --global core.autocrlf input           # prevent line-ending issues
```

### Step 9: Clone Distribution (Optional)

Keep a clean base Ubuntu-24.04 and create a dedicated dev container distribution so you can experiment safely without affecting your base.

- **TUI**: select **Clone distribution** → select `Ubuntu-24.04`, enter target name `ubuntu-devcon`
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 clone Ubuntu-24.04 ubuntu-devcon`

→ [Clone distribution](#clone-distribution)

### Step 10: Set Up the Dev Stack

One command installs the container runtime and DevPod. Run it after the user, CA and proxy steps (Steps 3 to 5): the dev-stack role is cloned from GitHub, and apt needs the corporate CA and the proxy before the first package.

Choose **one** container runtime. Docker and Podman cannot coexist in the same distribution.

#### Option A: Rootless Podman (Recommended)

> **Note:** Pure cgroups v2 is required for rootless Podman. This is already covered by the `kernelCommandLine` setting in Step 1.

- **TUI**: select **Setup dev stack (Ansible)** → select `ubuntu-devcon` → choose **podman**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-dev-stack ubuntu-devcon`

#### Option B: Docker (Debian only)

- **TUI**: select **Setup dev stack (Ansible)** → select a Debian distribution → choose **docker**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-dev-stack <debian-distro> -Runtime docker`

Add `-ClaudeCode` to install Claude Code in the same run.

→ [Setup dev stack (Ansible)](#setup-dev-stack-ansible)

> **Note:** After installation, restart your terminal for docker group membership to take effect.

### Step 11: Choose a Dev Container Client

Choose **one** of the two options below. The dev stack of Step 10 has already installed DevPod; Option B needs only the VS Code extensions.

#### Option A: DevPods (Recommended)

DevPods are IDE-independent; they work with VS Code, JetBrains IDEs, or any editor. No IDE extension required. `setup-dev-stack` installs the DevPod CLI and selects its `docker` provider.

Open any project as a dev container:

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

**Podman-specific settings** (only if you chose Podman in Step 10):

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

### Step 12: Sync SSH Config

Syncs SSH configuration between Windows and the WSL distribution — copying keys, known_hosts, and SSH config in both directions. If DevPod is installed, it also syncs DevPod SSH config blocks so that Windows-side editors (VS Code, JetBrains) can connect to DevPod containers.

- **TUI**: select **Sync SSH config** → select distribution
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 sync-ssh-config <distro>`

→ [Sync SSH config](#sync-ssh-config)

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

1. **Verify interop is not switched off:**

`setup-dev-stack` writes only `[boot] systemd=true` (and for Podman `command=mount --make-rshared /`) to `/etc/wsl.conf`; it writes no `[interop]` section. WSL enables interop by default, so a missing section is fine. Check that nothing set it to `false`:

```bash
grep -A 2 "\[interop\]" /etc/wsl.conf
# Either no output, or: enabled=true
```

2. **Verify binfmt.d configuration:**

```bash
cat /etc/binfmt.d/WSLInterop.conf
# Should show: :WSLInterop:M::MZ::/init:PF
```

On WSL 3.0, `systemctl is-active systemd-binfmt` shows `failed`. That is expected: WSL mounts `/proc/sys/fs/binfmt_misc/status` read-only, so the unit cannot flush the existing rules and exits with an error, but it still applies `/etc/binfmt.d/WSLInterop.conf`. The kernel registration in the next step is what counts.

3. **Test kernel registration:**

```bash
cat /proc/sys/fs/binfmt_misc/WSLInterop
# First line should show: enabled
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

**Solution:** Re-run the idempotent dev-stack setup. It runs `setup-binfmt-interop.sh`, which writes the kernel-level binfmt.d configuration again:

```powershell
.\tools\wsl-manager\wsl-manager.ps1 setup-dev-stack Ubuntu-24.04
```

Pass the same `-Runtime` as before. The script creates `/etc/binfmt.d/WSLInterop.conf` if it is missing or wrong and applies it with `systemd-binfmt`; a re-run converges without changes.

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

#### Dev-Stack Role Download Fails

**Symptoms:** `setup-dev-stack` stops at "Failed to install the dev_stack role" (exit code 3), or apt fails in the step before it (exit code 2)

**Cause:** The role is cloned from `https://github.com/xxthunder/ansible-role-dev-stack.git`, and the playbook downloads further files, so the distribution needs GitHub and the package sources through the corporate proxy.

**Solution:** Run [Setup CA certificates (corporate)](#setup-ca-certificates-corporate) and [Setup proxy (corporate)](#setup-proxy-corporate) first, then run `setup-dev-stack` again. A failure of the playbook itself (exit code 5) shows the failed Ansible task in the error output above the message; the progress of the other tasks is not shown.

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
# If empty, start a new login shell: the dev-stack role exports XDG_RUNTIME_DIR,
# DBUS_SESSION_BUS_ADDRESS and DOCKER_HOST in ~/.profile and ~/.zprofile
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

If missing, re-run `.\tools\wsl-manager\wsl-manager.ps1 setup-dev-stack <DistroName>` to repair.

#### Docker Already Installed (Mutual Exclusion)

**Symptoms:** `setup-dev-stack` fails with "Docker is already installed" (or "Podman is already installed" with `-Runtime docker`) before Ansible starts

**Solution:** Podman and Docker cannot coexist in the same distribution due to `DOCKER_HOST` conflicts. Either:
- Use a different distribution for the second runtime (clone your base distro first)
- Remove the installed runtime first, then run `setup-dev-stack` again

---

## Commands Reference

### Start distribution

Open an interactive shell in an installed distribution, next to the manager rather than in place of it.

- **TUI**: select **Start distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 shell <distro>`

This command:
- Prompts to pick a distribution (TUI) or uses the provided name (CLI); the manager returns to the menu immediately, without a "Press Enter to continue" pause
- Inside Windows Terminal (`WT_SESSION` is set): opens a new tab in the same window via `wt.exe -w 0 new-tab`
- Elsewhere (a classic console, or a script): opens a new console window via `Start-Process wsl.exe`
- The shell runs as the distribution's default user in its home directory (`wsl.exe --distribution <name> --cd ~`); a stopped distribution is started on the way
- The command does not wait for the shell to exit. It waits about one second after spawning the tab or window so that the menu's next redraw usually already shows the distribution as `Running`; if it still shows `Stopped`, use [Refresh list](#refresh-list)

### Stop distribution

Gracefully shut down a running distribution.

- **TUI**: select **Stop distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 terminate <distro>`

This command:
- Shows only running distributions for selection (TUI) or validates the named distribution is running (CLI)
- TUI: asks `Terminate distribution '<name>'. Continue? [y/N]` with **No** as the Enter default; CLI with `<distro>`: no prompt
- Executes `wsl.exe --terminate <name>` to stop the distribution
- Polls `wsl.exe --list --verbose` with retries to verify termination
- Warns if no distributions are currently running

### Install new distribution

Install a new WSL distribution from Microsoft Store or the web.

- **TUI**: select **Install new distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 install <distro>`

This command:
- Fetches available distributions from `wsl.exe --list --online`
- Prompts to pick a distribution from an arrow-key list with type-to-search (TUI; the last entry, **Back to main menu**, cancels) or uses the provided name (CLI)
- Validates the distribution does not already exist locally
- Installs the distribution via `wsl.exe --install --distribution <name> --no-launch`

### Clone distribution

Export and re-import a distribution under a new name. The source must be stopped.

- **TUI**: select **Clone distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 clone <distro>`

This command:
- Exports the source distribution to a temporary tar file via `wsl.exe --export`
- Imports the tar file as a new distribution via `wsl.exe --import` into `%USERPROFILE%\wsl\<target>\`
- Cleans up the temporary tar file
- Prompts for the target name (TUI) or accepts it as a second argument (CLI)

### Update distribution

Update all packages to latest versions (apt-based distributions).

- **TUI**: select **Update distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 update <distro>`

This command:
- Validates the distribution is Debian or Ubuntu based
- Runs `apt-get update && apt-get upgrade -y` inside the distribution
- Runs `apt-get autoremove -y && apt-get autoclean` to free disk space

### Remove distribution

Unregister a distribution. The TUI asks for confirmation; the CLI form with a name does not.

- **TUI**: select **Remove distribution**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 remove <distro>`

This command:
- Validates the distribution exists; auto-terminates it if running
- TUI: asks `Remove distribution '<name>' and all its data. Continue? [y/N]` (capital = Enter default, as everywhere in this repo); Enter or `n` cancels and returns to the menu. CLI with `<distro>`: no prompt, so scripts stay non-interactive
- Unregisters the distribution via `wsl.exe --unregister`, permanently deleting all data
- This operation cannot be undone

### Setup user account

Create a non-root user with sudo privileges and set as default user.

> **Tip:** For a local development distro, a simple username like `wsluser` or `vscode` with a matching password (e.g., `wsluser`/`wsluser`) is sufficient.

- **TUI**: select **Setup user account**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-user <distro>`

This command:
- Creates the user with a home directory
- Adds the user to the sudo group with NOPASSWD
- Configures `/etc/wsl.conf` to set as default user

### Setup dev stack (Ansible)

Apply the [`dev-stack` Ansible role](https://github.com/xxthunder/ansible-role-dev-stack) to a distribution: the container runtime, DevPod and the developer tools. It replaces the former `setup-docker`, `setup-podman` and `setup-devpod` commands.

- **TUI**: select **Setup dev stack (Ansible)** → select the distribution → choose the runtime (**podman** or **docker**) → answer whether to install Claude Code
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-dev-stack <distro> [-Runtime podman|docker] [-ClaudeCode]`

Prerequisites: run [Setup user account](#setup-user-account) first (the run needs the passwordless sudo it sets up). Behind a corporate proxy run [Setup CA certificates (corporate)](#setup-ca-certificates-corporate) and [Setup proxy (corporate)](#setup-proxy-corporate) first as well, because the role is cloned from GitHub. The order for a dev container distribution is `setup-user`, `setup-ca`, `setup-proxy`, `setup-dev-stack`.

Parameters:
- `-Runtime`: `podman` (default, rootless) or `docker`. Docker is available on Debian only; Ubuntu with `-Runtime docker` is refused
- `-ClaudeCode`: also installs Claude Code

This command:
- Validates the distribution is Debian or Ubuntu based and running WSL2, and that it has a default user (`setup-user` creates it)
- Refuses to run when the other container runtime is installed (Docker and Podman cannot coexist); this check runs before Ansible
- Configures `/etc/wsl.conf` with `[boot] systemd=true`, and for Podman `command=mount --make-rshared /`; restarts the distribution when it changed the file
- Writes `/etc/binfmt.d/WSLInterop.conf` for kernel-level Windows executable interop (`setup-binfmt-interop.sh`)
- Installs `ansible-core` and `git` with apt, clones the role at the pinned version into the user's Ansible roles directory, and runs the playbook `lib/wsl/ansible/dev-stack.yml` against the distribution itself
- Passes the proxy variables of the calling shell on to the playbook, so downloads follow the proxy set up by `setup-proxy`
- Terminates the distribution at the end so the changes apply on the next start
- Is idempotent - safe to run multiple times, and a rerun after a version bump takes the new role version

The role installs in a WSL distribution:
- **Distribution upgrade**: `apt dist-upgrade` brings the whole distribution current, not only the dev stack packages
- **Base packages**: `ca-certificates`, `tmux`, `git-lfs` and `curl`
- **Container runtime**: rootless Podman by default (with `podman-docker`, `slirp4netns` and `uidmap`; the user's `podman.socket` with linger; `DOCKER_HOST` in `~/.profile` and `~/.zprofile`), or Docker Engine on Debian with the user in the `docker` group
- **DevPod**: the CLI, and wsl-manager then adds and selects its `docker` provider
- **uv** and **gh**
- **zsh** with oh-my-zsh as the login shell
- **Claude Code**, only with `-ClaudeCode`

The role is pinned to the tag in `lib/wsl/ansible/requirements.yml` (`v1.8.0` at the time of writing). A new role release is a version bump there; the next run of the command takes it in.

#### Distributions set up by the former commands

A distribution set up with `setup-docker`, `setup-podman` or `setup-devpod` runs `setup-dev-stack` as follows:
- **Docker on Debian**: the command removes the former Docker apt source `/etc/apt/sources.list.d/docker.list` and its key `/etc/apt/keyrings/docker.gpg` before it installs anything, and logs that. The role writes its own source for the same repository, and apt refuses both together. Only a source that carries `signed-by=/etc/apt/keyrings/docker.gpg` is removed
- **Docker on Ubuntu**: `-Runtime docker` is refused on Ubuntu, and `-Runtime podman` is refused because Docker is installed (coexistence). Such a distribution cannot move to the role. Install a new distribution and run the setup there
- **Podman**: `-Runtime podman` runs as usual. `~/.profile` then holds a second `DOCKER_HOST` block next to the former one; it is harmless. `-Runtime docker` is refused because Podman is installed

wsl-manager keeps these parts of the setup for itself: the corporate CA and the proxy (`setup-ca`, `setup-proxy`), `/etc/wsl.conf` (systemd, and for Podman the boot command), and the `WSLInterop` binfmt.d rule.

### Sync SSH config

Sync SSH configuration between Windows and a WSL distribution: copies keys and known_hosts, syncs non-DevPod config from Windows into WSL, and (if DevPod is installed) syncs DevPod SSH config blocks to Windows with adapted ProxyCommand for Windows-side editor access.

- **TUI**: select **Sync SSH config**
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

### Setup CA certificates (corporate)

Install the corporate root certificate authorities (CAs) from the Windows certificate store into a distribution's system trust store, or remove them again. Behind a proxy that inspects TLS, HTTPS from the distribution fails with certificate errors until the corporate root CA is trusted there; intranet sites signed by an internal PKI need its root as well.

- **TUI**: select **Setup CA certificates (corporate)**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-ca <distro> -Url <url>[,<url>...]` (Auto) or `-Subject '<pattern>'` (Manual) to install, `.\tools\wsl-manager\wsl-manager.ps1 setup-ca <distro> -Remove` to remove

This command:
- **Auto** finds the roots by URL: it sends a HEAD request to each HTTPS site through the system proxy (including PAC, with your Windows logon), or directly where PAC says so, and takes the root of the certificate chain Windows builds for it. Behind TLS inspection that is the corporate root CA for any external site; for an intranet site it is the root of the internal PKI. The TUI offers `https://www.google.com` as the default, asks for further URLs, and lists every root once; a bare host name gets `https://`
- **Manual** finds the roots by name: it selects the certificates in `Cert:\LocalMachine\Root` whose subject matches a PowerShell wildcard such as `*Contoso*`; without wildcards, only an exactly equal subject matches. It fails without changing the distribution when nothing matches, and asks you to narrow a pattern that matches too many certificates
- Installs only roots that are in `Cert:\LocalMachine\Root` and have not expired. A root the machine does not trust is an error for that URL; a public site outside TLS inspection has a public root, which needs no install
- In the TUI, asks for Install or Remove, then for Auto or Manual, lists the roots and asks for confirmation (`[Y/n]`, Enter installs; Remove asks `[y/N]`); on the CLI, `-Url`, `-Subject` and `-Remove` run without a prompt, and more than one of them is an error
- Writes each certificate as `/usr/local/share/ca-certificates/wsl-manager-<thumbprint>.crt` and runs `update-ca-certificates`, which rebuilds `/etc/ssl/certs/ca-certificates.crt`: the bundle that [Setup proxy (corporate)](#setup-proxy-corporate) points uv, Node, pip and Go at
- Writes `/etc/containers/containers.conf.d/wsl-manager-ca.conf`. It mounts the bundle read-only at `/etc/wsl-manager/ca-certificates.crt` in every Podman container and points `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS` and `PIP_CERT` there, because images trust their own bundle, not the distribution's. The mount does not use the image's own path, so the image can still rebuild its own bundle (`update-ca-certificates`). The cost: a tool that reads only the system bundle and ignores the variables does not trust the proxy. The drop-in adds to your own lists in `containers.conf` instead of replacing them
- Adds to the managed certificates rather than replacing them, so Auto can run for several sites one after another; every run removes managed certificates that have expired, which is how a rotated root CA leaves
- Remove deletes all `wsl-manager-*.crt` files and the container drop-in, and rebuilds the bundle; certificates installed any other way are never touched
- A CA that was installed by hand before stays where it is and is then trusted twice, which does no harm. Remove the old copy so that wsl-manager manages the CA alone and **Remove** really takes it out: `sudo rm /usr/local/share/ca-certificates/<old file>.crt && sudo update-ca-certificates`
- Requires the `ca-certificates` package in the distribution (it brings `openssl`) and, for a non-root default user, sudo rights (see [Setup user account](#setup-user-account))
- Leaves the distribution running: the rebuilt bundle applies to the next TLS connection
- Is idempotent - safe to run multiple times

### Setup proxy (corporate)

Configure corporate proxy settings with automatic detection. Auto-detects proxy from PAC/registry, prompts for credentials if needed, and supports DIRECT (no proxy) mode to remove proxy configurations.

- **TUI**: select **Setup proxy (corporate)**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 setup-proxy <distro>`

This command:
- Prompts upfront for setup mode: `[A]uto` (PAC detection), `[M]anual` (enter host:port), or `[R]emove` (tear down); pressing Enter selects Auto
- Auto mode reads `AutoConfigURL` from Windows Internet Settings and asks for confirmation before proceeding
- Auto → DIRECT collapses to Remove (no proxy needed on this network)
- Auto mode also probes for a running local **px** proxy (see [px-proxy](runbooks/px-proxy.md)). When px is up, you choose between the px endpoint (`http://127.0.0.1:3128`, reachable from WSL via mirrored networking; px authenticates to the corporate proxy via SSPI on the Windows host, so no credentials are stored) and the PAC-detected corporate proxy
- After a corporate proxy URL is resolved, prompts for auth method: `[A]nonymous` (no credentials) or `[B]asic` (username/password embedded in the URL, prefilled with your Windows username)
- Writes proxy exports (`http_proxy`, `https_proxy`, `no_proxy`, and their uppercase variants) to a managed file `/etc/profile.d/wsl-manager-proxy.sh`, and sources it from `/etc/zsh/zshenv` so both bash and zsh pick them up on a normal WSL launch; legacy `~/.profile`, `~/.bashrc`, and `/etc/environment` blocks are migrated away
- Points tools that ship their own CA bundle (uv, Node, pip/requests, Go) at the system trust store via `SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, `REQUESTS_CA_BUNDLE`, and `PIP_CERT` so corporate TLS inspection works
- Configures `/etc/apt/apt.conf.d/99proxy` for APT package manager
- Configures `~/.docker/config.json` proxy settings
- Configures `~/.config/containers/containers.conf` for Podman
- When the proxy is on loopback (px), writes `~/.config/containers/containers.conf.d/wsl-manager-proxy.conf`
  - A container's loopback is its own, so the file makes pasta forward the container's `127.0.0.1:<port>` to the distribution's loopback
  - Containers keep their own network, so `-p` works as before
  - With a proxy elsewhere, the file is deleted
- Writes `/etc/wsl-manager/proxy-mode` (`basic`) for mode-aware teardown
- Remove mode deletes all managed proxy configurations and the mode marker
- Is idempotent - safe to run multiple times (overwrites configuration)

### Update WSL

Update WSL itself to the latest release. This is not **Update distribution**, which updates the packages inside a distribution.

- **TUI**: select **Update WSL**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 update-wsl`

This command:
- Shows the installed WSL version and asks for confirmation, with **No** as the default. Because `update-wsl` takes no distribution name, the CLI form asks too; only CI/test environments skip the prompt
- Executes `wsl.exe --update`
- Reports the version before and after, or that WSL is already up to date
- Does not shut WSL down: running distributions use the new version after [Shutdown WSL](#shutdown-wsl), which stops them
- Ends with an error when the update fails, naming the likely causes: missing rights, WSL managed by IT (Microsoft Store or Intune), or no network

A new WSL release can break a setup that worked before, as WSL 3.0 did for the former `setup-docker` (SC-063). Older releases are available from the [WSL releases on GitHub](https://github.com/microsoft/WSL/releases).


---

### Shutdown WSL

Shut down the entire WSL subsystem including all running distributions and the WSL2 VM. Use this to apply changes to `%USERPROFILE%\.wslconfig`.

- **TUI**: select **Shutdown WSL**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 shutdown`

This command:
- Asks for confirmation, naming the running distributions that will be stopped, with **No** as the default. Because `shutdown` takes no distribution name, the CLI form asks too; only CI/test environments skip the prompt
- Executes `wsl.exe --shutdown` to stop all distributions and the WSL2 lightweight VM
- Polls to verify all distributions have stopped
- Is idempotent - safe to run when no distributions are running


---

### Configure .wslconfig defaults

Apply recommended global WSL settings to `%USERPROFILE%\.wslconfig`.

- **TUI**: select **Configure .wslconfig defaults**
- **CLI**: `.\tools\wsl-manager\wsl-manager.ps1 configure-wsl`

This command:
- Reads existing `%USERPROFILE%\.wslconfig` (if present)
- Merges in recommended defaults: missing keys are added and existing user values are kept, except `autoProxy`, which is always overwritten with `false`:
  - `[wsl2] kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1` (pure cgroups v2)
  - `[wsl2] networkingMode = mirrored` (mirrors Windows network interfaces)
  - `[wsl2] dnsTunneling = true` (routes DNS through Windows)
  - `[wsl2] autoProxy = false` (Windows' `autoProxy` would inject the corporate proxy into every WSL shell and bypass px, so tools fail with `407`; see [Using px from WSL](runbooks/px-proxy.md#using-px-from-wsl))
- For `kernelCommandLine`, appends missing parameters rather than replacing the whole value
- Creates a timestamped backup of the existing file before writing
- Auto-shuts down the WSL subsystem after changes so the new global settings take effect. **This terminates all running distributions, not just one** — `.wslconfig` is a global VM-level setting and a full `wsl --shutdown` is the only way to apply it. Running distributions are listed in a warning before the shutdown.
- Is idempotent - safe to run multiple times (skips the shutdown when nothing changed)

---

### Refresh list

Redraw the distribution table above the menu with the current state.

- **TUI**: select **Refresh list**
- **CLI**: not needed; `.\tools\wsl-manager\wsl-manager.ps1 list` always fetches fresh data

The table is fetched once each time the menu is drawn and is not updated while the menu waits for your choice, so it can lag behind reality: a distribution started from the menu may still show `Stopped` for a moment, and anything that changes state outside the manager (exiting a distribution's shell, `wsl --shutdown` in another terminal, WSL's idle timeout) is not reflected until the next redraw. **Refresh list** redraws immediately, without the "Press Enter to continue" pause.

The table lists each distribution with its state, its architecture and a `*` for the default. Its title is the version of WSL itself, e.g. `WSL 3.0.1.0`, or `WSL (version unknown)` when `wsl --version` cannot be read. The `Arch` column is the architecture of the distribution from `wsl --list --verbose`: `1` or `2`. The two numbers are independent; WSL 3.0 still runs distributions on architecture `2`.

## Technical Reference

### Module Structure

```
tools/wsl-manager/
├── wsl-manager.ps1            # Entry point (params + bootstrapping); sources lib/wsl/manager.ps1
└── wsl-manager.bat            # Batch wrapper for Keypirinha

lib/wsl/
├── wsl.ps1                    # Library facade (dot-sources all feature modules below)
├── manager.ps1                # Orchestration: CLI dispatch + TUI menu
├── commands.ps1               # Action functions for each command
├── spectre.ps1                # PwshSpectreConsole loader for the TUI
├── core.ps1                   # WSL/distro checks: list, state, type detection, terminate
├── install.ps1                # Discover available distros, install new instances
├── ops.ps1                    # Remove, copy, update, shutdown, .wslconfig defaults
├── wsl-conf.ps1               # Per-distro /etc/wsl.conf read/merge/write
├── user.ps1                   # User account creation & configuration
├── exec.ps1                   # Script execution in WSL
├── docker.ps1                 # Docker installed check
├── podman.ps1                 # Podman installed check
├── dev-stack.ps1              # Dev-stack setup: wsl.conf, binfmt, hand-off to the Ansible role
├── ssh.ps1                    # SSH key/config sync between Windows and WSL
├── proxy.ps1                  # Proxy configuration
├── ca.ps1                     # Corporate root CA install/remove from the Windows certificate store
├── ansible/
│   ├── requirements.yml           # Pins the dev-stack role (git tag)
│   └── dev-stack.yml              # Playbook that applies the role to the distribution itself
└── scripts/
    ├── setup-dev-stack.sh         # Installs ansible-core and git, fetches the role, runs the playbook
    ├── setup-binfmt-interop.sh    # Registers the WSLInterop binfmt.d rule
    ├── setup-ca.sh                # Corporate root CA files and trust store rebuild (update-ca-certificates)
    ├── setup-proxy.sh             # Proxy configuration (env, apt, Docker, Podman)
    └── sync-ssh-config.sh         # SSH config sync between Windows host and WSL
```

Each module has a co-located `*.Tests.ps1` unit test (omitted above). Integration tests (`wsl.Integration.Tests.ps1`, `manager.Integration.Tests.ps1`, `manager.devstack.Integration.Tests.ps1`) live alongside the modules in `lib/wsl/`.

### Library Usage

All WSL Manager functionality is also available as PowerShell functions for scripting.
See `lib/wsl/wsl.ps1` for the full library API.

### Configuration Files

**`/etc/wsl.conf` (managed by automation):**

Docker configuration:
```ini
[boot]
systemd=true

[user]
default=<your-username>
```

Podman configuration:
```ini
[boot]
command=mount --make-rshared /
systemd=true

[user]
default=<your-username>
```

**`/etc/binfmt.d/WSLInterop.conf` (managed by automation):**

```
:WSLInterop:M::MZ::/init:PF
```

This kernel-level configuration is applied by `systemd-binfmt.service` at boot and is VS Code compatible (prevents interference). `setup-binfmt-interop.sh` (run by `setup-dev-stack`) applies the file directly with `systemd-binfmt`, without restarting the unit. On WSL 3.0 the unit shows `failed` although it applies the file (see Troubleshooting).

**Podman Socket and Environment Variables:**

Socket path:
```
/run/user/<UID>/podman/podman.sock
```

Environment variables (set by the dev-stack role in `~/.profile` and `~/.zprofile`):
```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock
```

---

## Architecture

WSL Manager is part of the C4 model of the whole repository in Structurizr DSL: system context, containers, an overview of its components and one component view per user goal. See:

- [Architecture model (C4, Structurizr)](architecture/README.md)

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
