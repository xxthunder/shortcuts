# WSL Manager

## Overview

WSL Manager is a PowerShell tool for managing Windows Subsystem for Linux (WSL) distributions. It provides both an interactive menu and CLI commands for creating, cloning, configuring, and managing WSL distributions — including one-command Docker and Podman setup for VS Code DevContainer development.

**Launch:**

```powershell
# Interactive menu
wsl-manager

# CLI
wsl-manager <command> <distro>
```

---

## Quick Start

**Interactive mode** — launch and follow the menu:

```powershell
wsl-manager
```

**CLI mode** — run commands directly:

```powershell
wsl-manager update Debian
wsl-manager clone Debian
wsl-manager setup-docker debian-devcon
```

**Library mode** — source and call functions in scripts:

```powershell
. "$PSScriptRoot\tools\pslib\wsl\wsl.ps1"

Get-WslDistroList -Detailed
Copy-WslDistro -SourceName Debian -TargetName MyProject
New-WslUser -DistroName MyProject -Username developer -Password "SecurePass123"
Install-WslDockerEngine -DistroName MyProject
```

---

## Commands

### List Distributions

Show all installed WSL distributions with state and version info.

```powershell
# Interactive: launches the menu with the distro table displayed
wsl-manager

# Library
Get-WslDistroList              # Names only
Get-WslDistroList -Detailed    # Structured objects (name, state, version)
```

### Update Distribution

Update all packages to latest versions (apt-based distributions).

```powershell
wsl-manager update Debian
```

### Clone Distribution

Export and re-import a distribution under a new name. The source must be stopped.

```powershell
wsl-manager clone Debian
# Or via library
Copy-WslDistro -SourceName Debian -TargetName debian-devcon
```

### Remove Distribution

Unregister a distribution (with confirmation prompt in interactive mode).

```powershell
wsl-manager remove debian-devcon
```

### Terminate Distribution

Gracefully shut down a running distribution.

```powershell
wsl-manager terminate debian-devcon
```

### Setup User Account

Create a non-root user with sudo privileges and set as default user.

```powershell
wsl-manager setup-user debian-devcon
# Or via library
New-WslUser -DistroName debian-devcon -Username vscode -Password "YourPassword"
```

This command:
- Creates the user with a home directory
- Adds the user to the sudo group with NOPASSWD
- Configures `/etc/wsl.conf` to set as default user

### Setup Proxy

Configure corporate proxy settings (reads `$Env:HTTPS_PROXY` and `$Env:NO_PROXY`).

```powershell
wsl-manager setup-proxy debian-devcon
```

See [VS Code DevContainer Setup](#vs-code-devcontainer-setup) for the full walkthrough.

### Setup Docker

Install Docker Engine with automatic prerequisite configuration.

```powershell
wsl-manager setup-docker debian-devcon
```

See [VS Code DevContainer Setup](#vs-code-devcontainer-setup) for the full walkthrough.

### Setup Podman (Rootless)

Install rootless Podman as a Docker alternative.

```powershell
wsl-manager setup-podman debian-devcon
```

See [VS Code DevContainer Setup](#vs-code-devcontainer-setup) for the full walkthrough.

---

## VS Code DevContainer Setup

This section walks you from a fresh Windows machine to running VS Code DevContainers in WSL, with proper SSH agent forwarding and git configuration. It covers both Docker and Podman as container runtimes.

### Docker vs Podman

Choose one container runtime per distribution. They cannot coexist in the same WSL distribution due to `DOCKER_HOST` conflicts.

| Feature | Docker | Podman |
|---------|--------|--------|
| Architecture | Daemon-based (`dockerd`) | Daemonless |
| Root required | Docker daemon runs as root | Fully rootless |
| Systemd integration | Requires `systemctl start docker` | User-level socket activation |
| CLI compatibility | `docker` | `podman` (drop-in compatible) |
| DevContainer support | Native | Via `DOCKER_HOST` + socket |
| OCI compliant | Yes | Yes |

**When to use Docker:**
- Existing Docker Compose workflows with daemon-dependent features
- Third-party tools that require the Docker daemon socket

**When to use Podman:**
- Security-conscious environments (no root daemon)
- Minimal resource footprint (no background daemon)
- Rootless container workflows

### Step-by-Step Walkthrough

#### Step 1: Install WSL Distribution

Install Debian (or Ubuntu) from Microsoft Store or command line:

```powershell
# Via Microsoft Store — search for "Debian" and click Install

# Or via command line (requires admin PowerShell)
wsl --install -d Debian
```

After installation, launch Debian once to complete initial setup (create root password).

#### Step 2: Update Distribution

```powershell
wsl-manager update Debian
```

This runs `apt-get update && apt-get upgrade -y` inside the distribution.

#### Step 3: Clone Distribution (Optional)

If you want to keep a clean base Debian and create a dedicated DevContainer distribution:

```powershell
wsl-manager clone Debian
# Or via library
Copy-WslDistro -SourceName Debian -TargetName debian-devcon
```

**Why clone?** Keep a pristine base for other projects, quickly create new environments, safely experiment without affecting your base.

#### Step 4: Setup User Account

Create a non-root user with sudo privileges (required for both Docker and Podman):

```powershell
wsl-manager setup-user debian-devcon
# Or via library
New-WslUser -DistroName debian-devcon -Username vscode -Password "YourPassword"
```

#### Step 5: Configure Proxy (Corporate Networks)

If you're behind a corporate proxy, configure proxy settings before installing container runtimes. This ensures `apt`, Docker, and Podman all route through the proxy.

**Prerequisite:** Set proxy environment variables in your PowerShell session first:

```powershell
# If you have a setProxy.ps1 script:
setProxy.ps1 -askForCreds

# Or set manually:
$Env:HTTPS_PROXY = "http://your-proxy:8080"
$Env:NO_PROXY = "localhost,127.0.0.1,*.internal.corp"
```

Then run:

```powershell
wsl-manager setup-proxy debian-devcon
```

**What this configures automatically:**

1. **`~/.bashrc` managed block** — exports `http_proxy`, `https_proxy`, `HTTP_PROXY`, `HTTPS_PROXY`, `no_proxy`, `NO_PROXY`
2. **`/etc/apt/apt.conf.d/99proxy`** — `Acquire::http::Proxy` and `Acquire::https::Proxy`
3. **`~/.docker/config.json`** — `proxies.default` with `httpProxy`, `httpsProxy`, `noProxy`
4. **`~/.config/containers/containers.conf`** — `[engine] env` with proxy variables

**Note:** This setup is idempotent — safe to run multiple times (overwrites configuration). If `$Env:NO_PROXY` is not set, defaults to `localhost,127.0.0.1`.

#### Step 6: Install Container Runtime

Choose **one** of the two options below. Docker and Podman cannot coexist in the same distribution.

##### Option A: Docker

```powershell
wsl-manager setup-docker debian-devcon
```

**What this configures automatically:**

1. **wsl.conf settings:**
   - `[boot]` section: `systemd=true` (enables systemd for Docker)
   - `[interop]` section: `enabled=true`, `appendWindowsPath=true` (Windows executable access)
   - Preserves existing `[user]` section if configured

2. **Kernel-level interop via binfmt.d (VS Code compatible):**
   - Creates `/etc/binfmt.d/WSLInterop.conf` with Windows executable registration
   - Managed by `systemd-binfmt.service` (core system service)
   - VS Code respects kernel configuration, preventing interference

3. **Docker Engine packages:**
   - Docker CE, Docker CLI, containerd
   - Docker Compose plugin, Docker Buildx plugin
   - Prerequisite packages: ca-certificates, curl, gnupg, wget, htop

4. **Distribution restart:**
   - Automatically restarts the distribution to apply wsl.conf changes

**Note**: This setup is idempotent — safe to run multiple times to verify or repair your installation. After installation, you must restart your terminal for docker group membership to take effect.

##### Option B: Rootless Podman

###### Prerequisites: cgroups v2 (Recommended)

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

###### Install Podman

```powershell
wsl-manager setup-podman debian-devcon
```

**What this configures automatically:**

1. **wsl.conf settings:**
   - `[boot] systemd=true` — enables systemd (required for socket activation)
   - `[boot] command=mount --make-rshared /` — prevents rootless container mount propagation warnings
   - `[interop] enabled=true, appendWindowsPath=true` — Windows executable access

2. **Podman packages:**
   - `podman` — container runtime
   - `slirp4netns` — rootless networking (user-space network stack)
   - `uidmap` — user namespace mapping for rootless containers

3. **Rootless Podman socket:**
   - `systemctl --user enable --now podman.socket` — socket activation as the default user
   - Socket path: `/run/user/$UID/podman/podman.sock`

4. **User session persistence:**
   - `loginctl enable-linger $USER` — keeps systemd user services alive across sessions

5. **Environment variables in `~/.bashrc`:**
   - `XDG_RUNTIME_DIR=/run/user/$(id -u)` — systemd user runtime directory
   - `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus` — D-Bus session bus
   - `DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock` — routes Docker CLI commands to Podman

6. **Distribution restart:**
   - Automatically restarts the distribution to apply wsl.conf changes

**Note**: This setup is idempotent — safe to run multiple times to verify or repair your installation.

#### Step 7: Windows SSH Agent Setup

**These steps must be performed on your Windows host (PowerShell as Administrator).**

**Enable SSH Agent Service (PowerShell as Administrator):**

```powershell
# Set SSH Agent to start automatically
Set-Service ssh-agent -StartupType Automatic

# Start the SSH agent service
Start-Service ssh-agent

# Verify it's running
Get-Service ssh-agent
```

**Load your SSH key into Windows SSH Agent:**

```powershell
# Add your SSH key (adjust path if needed)
ssh-add ~\.ssh\id_ed25519

# Or for RSA keys
ssh-add ~\.ssh\id_rsa

# Verify key is loaded
ssh-add -l
```

#### Step 8: Git Configuration

**These steps must be performed inside your WSL distribution.**

```bash
wsl --distribution debian-devcon
```

##### Option A: Reuse Windows `.gitconfig` via Symlink (Recommended)

If you already have a working `.gitconfig` in your Windows profile, symlink it into WSL:

```bash
# Remove any existing .gitconfig in WSL (back up first if needed)
rm -f ~/.gitconfig

# Symlink to Windows .gitconfig
ln -s /mnt/c/Users/<your-windows-username>/.gitconfig ~/.gitconfig

# Verify
git config --global --list
```

This reuses your Windows git identity, aliases, and all other settings. Any changes made on either side take effect immediately.

**Important:** Your Windows `.gitconfig` must include the SSH command setting for SSH key reuse (see below). If it doesn't, add it:

```bash
git config --global core.sshCommand "ssh.exe"
```

##### Option B: Configure Git Manually

```bash
# Set your name and email
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Use ssh.exe from Windows for git operations (see explanation below)
git config --global core.sshCommand "ssh.exe"

# Use Git Credential Manager from Windows
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"

# Prevent line ending conversion issues
git config --global core.autocrlf input
```

##### Why `core.sshCommand = ssh.exe`?

With WSL interop enabled (`[interop] enabled=true` in `/etc/wsl.conf`), WSL can execute Windows binaries directly. Setting `core.sshCommand` to `ssh.exe` tells git to use the **Windows OpenSSH client** instead of the Linux one. This means:

- **SSH keys** stored in `%USERPROFILE%\.ssh\` are reused automatically — no need to copy or manage keys inside each WSL distribution.
- **SSH config** (`%USERPROFILE%\.ssh\config`) with host aliases, proxy settings, etc. is reused as well.
- The **Windows SSH Agent** handles key authentication, so keys loaded via `ssh-add` on Windows are available to git inside WSL.

**Prerequisite:** WSL interop must be enabled (the automated Docker/Podman setup handles this).

#### Step 9: VS Code Settings

Open your VS Code `settings.json` (File > Preferences > Settings > Open Settings (JSON)) and add the settings for your chosen runtime.

##### Common Settings (Both Runtimes)

```json
{
  "dev.containers.copyGitConfig": true,
  "remote.SSH.enableAgentForwarding": true
}
```

- `dev.containers.copyGitConfig`: Copies your git configuration into DevContainers
- `remote.SSH.enableAgentForwarding`: Enables SSH agent forwarding for remote connections

##### Podman-Specific Settings

If you chose Podman, also add:

```json
{
  "dev.containers.dockerPath": "podman",
  "dev.containers.mountWaylandSocket": false
}
```

- `dev.containers.dockerPath`: Tells VS Code to use `podman` instead of `docker`
- `dev.containers.mountWaylandSocket`: Disables Wayland socket mount (avoids WSL2 socket error)

Additionally, for rootless Podman, add `--userns=keep-id` to your `devcontainer.json`:

```json
{
  "runArgs": ["--userns=keep-id"]
}
```

This maps your host UID into the container, which is critical for file permissions in rootless mode.

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

# Test DevContainer
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
# Good — fast
cd ~ && git clone git@github.com:user/project.git

# Slow — avoid
cd /mnt/c/Users/username/projects && git clone ...
```

### Troubleshooting

#### SSH Agent Not Forwarding

**Symptoms:** `ssh -T git@github.com` asks for password

**Solutions:**

1. **Verify Windows SSH agent is running:**

```powershell
Get-Service ssh-agent
# Should show Status: Running
```

2. **Verify key is loaded:**

```powershell
ssh-add -l
# Should show your key fingerprint
```

3. **Verify git SSH command:**

```bash
git config --global core.sshCommand
# Should show: ssh.exe
```

4. **Test direct SSH.exe:**

```bash
ssh.exe -T git@github.com
# Should authenticate successfully
```

#### Git Identity Not Showing

**Symptoms:** Git commits have wrong author

**Solutions:**

1. **Verify global git config:**

```bash
git config --global --list | grep user
# Should show user.name and user.email
```

2. **Verify DevContainer copies git config:**

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
wsl.exe --terminate Debian
wsl --distribution Debian
```

#### VS Code Breaks Docker After Opening WSL Folder

**Symptoms:**
- Docker commands fail after opening WSL folder in VS Code: `docker: command not found`
- Windows executables fail: `notepad.exe: cannot execute binary file`
- Error: `/proc/sys/fs/binfmt_misc/WSLInterop` not found

**Cause:** Legacy rc.local configuration that VS Code can overwrite when initializing its WSL server.

**Solution:** Re-run the idempotent Docker setup to migrate to kernel-level binfmt.d configuration:

```powershell
wsl-manager setup-docker Debian
```

This detects existing Docker (no reinstall), migrates from old rc.local to `/etc/binfmt.d/WSLInterop.conf` if needed, and verifies all components.

**Verification:**

```bash
wsl -d Debian cat /etc/binfmt.d/WSLInterop.conf
# Expected: :WSLInterop:M::MZ::/init:PF

wsl -d Debian docker ps
wsl -d Debian notepad.exe
```

#### DevContainer Fails to Start

**Symptoms:** DevContainer build fails or times out

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

3. **Check DevContainer logs:**

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

**Solution:** Enable pure cgroups v2 in `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
```

Then restart WSL: `wsl --shutdown`

#### Mount Propagation Warnings

**Symptoms:** Warnings about mount propagation when running containers

**Solution:** Verify `mount --make-rshared /` is in your wsl.conf boot command:

```bash
grep "mount --make-rshared" /etc/wsl.conf
# Expected: command=mount --make-rshared /
```

If missing, re-run `wsl-manager setup-podman <DistroName>` to repair.

#### Docker Already Installed (Mutual Exclusion)

**Symptoms:** `setup-podman` fails with "Docker is already installed"

**Solution:** Podman and Docker cannot coexist in the same distribution due to `DOCKER_HOST` conflicts. Either:
- Use a different distribution for Podman (clone your base distro first)
- Remove Docker first, then install Podman

---

## Technical Reference

### Module Structure

```
tools/pslib/wsl/
├── wsl.ps1                    # Main library (dot-sources lib/*.ps1)
├── wsl-manager.ps1            # Interactive interface
├── wsl-manager.bat            # Batch wrapper for Keypirinha
├── lib/
│   ├── core.ps1               # List, get distro info, type detection
│   ├── docker.ps1             # Docker installation & verification
│   ├── exec.ps1               # Script execution in WSL
│   ├── install.ps1            # Clone, remove operations
│   ├── ops.ps1                # Update, state, terminate operations
│   ├── podman.ps1             # Podman installation & verification
│   ├── proxy.ps1              # Proxy configuration
│   └── user.ps1               # User account creation & configuration
├── scripts/
│   ├── install-docker.sh      # Docker Engine installation script
│   ├── install-podman.sh      # Rootless Podman installation script
│   └── setup-proxy.sh         # Proxy configuration script
└── tests/
    ├── wsl.Tests.ps1
    ├── wsl.Integration.Tests.ps1
    ├── wsl-manager.Tests.ps1
    ├── wsl-manager.docker.Integration.Tests.ps1
    └── wsl-manager.podman.Integration.Tests.ps1
```

### All Implemented Functions

**Distribution Information** (`lib/core.ps1`):
- `Get-WslDistroList [-Detailed]` — List distributions
- `Get-WslDistroType -DistroName` — Detect distro type (debian, ubuntu, arch, etc.)
- `Get-WslDistroState -DistroName` — Get state (Running/Stopped)
- `Test-WslDistroRunning -DistroName` — Check if running
- `Test-Wsl2Version -DistroName` — Check if WSL2
- `Test-WslSystemdConfigured -DistroName` — Check systemd in wsl.conf
- `Test-WslSystemd -DistroName` — Check if systemd is running

**Distribution Operations** (`lib/ops.ps1`, `lib/install.ps1`):
- `Copy-WslDistro -SourceName -TargetName` — Clone distribution
- `Remove-WslDistro -Name` — Unregister distribution
- `Stop-WslDistro -Name` — Terminate distribution
- `Update-WslDistro -Name` — Update packages (apt-based)

**User Management** (`lib/user.ps1`):
- `New-WslUser -DistroName -Username -Password` — Create user with sudo
- `Get-WslDefaultUser -DistroName` — Get default user from wsl.conf
- `Set-WslConf` — Safely merge wsl.conf sections (preserves existing config, creates timestamped backups)

**Docker** (`lib/docker.ps1`):
- `Install-WslDockerEngine -DistroName [-Username]` — Install Docker with automatic prerequisite configuration
- `Test-WslDockerInstalled -DistroName` — Check Docker installation

**Proxy** (`lib/proxy.ps1`):
- `Install-WslProxy -DistroName [-ProxyUrl] [-NoProxy]` — Configure proxy settings (reads `$Env:HTTPS_PROXY` / `$Env:NO_PROXY`)

**Podman** (`lib/podman.ps1`):
- `Install-WslPodman -DistroName [-Username]` — Install rootless Podman with automatic prerequisite configuration
- `Test-WslPodmanInstalled -DistroName` — Check Podman installation

**Script Execution** (`lib/exec.ps1`):
- `Invoke-WslDistroCommand -DistroName -Command` — Run command
- `Invoke-WslDistroScript -DistroName -ScriptPath [-Arguments] [-AsRoot]` — Run bash script

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

**`/etc/binfmt.d/WSLInterop.conf` (Docker — managed by automation):**

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

## Additional Resources

- [WSL Configuration Documentation](https://docs.microsoft.com/en-us/windows/wsl/wsl-config)
- [VS Code DevContainers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Git Credential Manager Documentation](https://github.com/GitCredentialManager/git-credential-manager)
- [SSH Agent Forwarding](https://developer.github.com/v3/guides/using-ssh-agent-forwarding/)
- [Podman Documentation](https://podman.io/)
- [Podman + WSL2 + Dev Containers Guide](https://github.com/containers/podman/discussions/25607)
- [Rootless Podman](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)

---

**Notes:**
- **Why binfmt.d?** Uses kernel-level configuration managed by `systemd-binfmt.service` instead of late-boot rc.local scripts. This prevents VS Code from interfering with Windows executable interop when opening WSL folders.
- **Why ssh.exe?** Using `ssh.exe` from Windows allows git operations inside WSL to leverage the Windows SSH agent, enabling seamless SSH key forwarding without managing keys inside each WSL distribution.
- **Security consideration:** This setup forwards your SSH agent into containers. Only use with trusted DevContainer configurations.
