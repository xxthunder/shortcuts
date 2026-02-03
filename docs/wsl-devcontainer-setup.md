# WSL DevContainer Setup Guide

This guide describes how to prepare a WSL distribution for VS Code DevContainer usage with proper SSH agent forwarding and git configuration.

## Overview

Setting up WSL for VS Code DevContainers requires:
1. **WSL Distribution** (install and prepare)
2. **User Account** (create non-root user with sudo)
3. **Docker Engine** (automated systemd/interop/packages)
4. **Windows SSH Agent** (manual setup on Windows)
5. **Git Configuration** (manual setup inside WSL)
6. **VS Code Settings** (manual configuration)

---

## Complete Workflow

### Step 1: Install WSL Distribution

Install Debian (or Ubuntu) from Microsoft Store or command line:

```powershell
# Via Microsoft Store
# Search for "Debian" and click Install

# Or via command line (requires admin PowerShell)
wsl --install -d Debian
```

After installation, launch Debian once to complete initial setup (create root password).

### Step 2: Update Distribution

Update all packages to latest versions:

```powershell
# Via WSL Manager
wsl-manager
# Select: [U] Update distribution

# Or direct command
wsl-manager update Debian
```

This runs `apt-get update && apt-get upgrade -y` inside the distribution.

### Step 3: Clone Distribution (Optional)

If you want to keep a clean base Debian and create a dedicated DevContainer distribution:

```powershell
# Via WSL Manager
wsl-manager
# Select: [C] Clone distribution

# Or direct command
Copy-WslDistro -SourceName Debian -TargetName debian-devcon
```

**Why clone?** This lets you:
- Keep a pristine Debian base for other projects
- Quickly create new environments from the base
- Safely experiment without affecting your base distribution

### Step 4: Setup User Account

Create a non-root user with sudo privileges:

```powershell
# Via WSL Manager
wsl-manager
# Select: [S] Setup user account

# Or direct command
New-WslUser -DistroName debian-devcon -Username vscode -Password "YourPassword"
```

**Important**: Docker setup requires a non-root user. This command:
- Creates user with home directory
- Adds user to sudo group with NOPASSWD
- Configures `/etc/wsl.conf` to set as default user

### Step 5: Install Docker (Automated)

Install Docker Engine with automatic prerequisite configuration:

```powershell
# Via WSL Manager
wsl-manager
# Select: [D] Setup/Repair Docker (idempotent, includes systemd/interop)

# Or direct command
Install-WslDockerEngine -DistroName debian-devcon
```

**What this does automatically:**
- Configures systemd and Windows interop in `/etc/wsl.conf`
- Configures kernel-level interop via binfmt.d (VS Code compatible)
- Installs Docker CE, Docker Compose, and prerequisite packages
- Adds your user to the docker group
- Restarts the distribution

**Note**: This setup is idempotent - safe to run multiple times to verify or repair your installation. After installation, you must restart your terminal for docker group membership to take effect.

### Steps 6-8: Manual Configuration

Continue with the manual steps below for SSH agent, git config, and VS Code settings.

---

## Automated Configuration Details

Docker installation automatically configures all prerequisites:

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

---

## Manual Configuration Steps

---

## Manual Configuration Steps

### Step 6: Windows SSH Agent Setup

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

**Test SSH agent is working:**

```powershell
# Should show your key fingerprint
ssh-add -l
```

---

---

### Step 7: Git Configuration

**These steps must be performed inside your WSL distribution.**

**Start your WSL distribution:**

```bash
# Use your distribution name (Debian, debian-devcon, etc.)
wsl --distribution debian-devcon
```

**Configure git identity:**

```bash
# Set your name and email
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**Configure SSH command to use Windows SSH agent:**

```bash
# Use ssh.exe from Windows for git operations
git config --global core.sshCommand "ssh.exe"
```

**Configure credential helper:**

```bash
# Use Git Credential Manager from Windows
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
```

**Configure line endings:**

```bash
# Prevent line ending conversion issues
git config --global core.autocrlf input
```

**Verify configuration:**

```bash
# Check all settings
git config --global --list
```

---

---

### Step 8: VS Code Settings

**Configure DevContainer settings in VS Code.**

**Configure DevContainer settings in VS Code:**

Open your VS Code `settings.json` (File > Preferences > Settings > Open Settings (JSON)) and add:

```json
{
  "dev.containers.copyGitConfig": true,
  "remote.SSH.enableAgentForwarding": true
}
```

**What these do:**

- `dev.containers.copyGitConfig`: Copies your git configuration into DevContainers
- `remote.SSH.enableAgentForwarding`: Enables SSH agent forwarding for remote connections

---

---

## Validation

**Verify everything is working correctly.**

**Test SSH forwarding (Inside WSL):**

```bash
# Should authenticate successfully without password prompt
ssh -T git@github.com

# Expected output:
# Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

**Test git identity:**

```bash
# Should show your configured email
git config user.email

# Expected output:
# your.email@example.com
```

**Test DevContainer:**

1. Open a project with a `.devcontainer` configuration in VS Code
2. Press `F1` and run "Dev Containers: Reopen in Container"
3. Wait for container to build and start
4. Inside the container, test git operations:

```bash
# Should authenticate via Windows SSH agent
git fetch

# Should show correct identity
git config user.name
git config user.email
```

---

## Troubleshooting

### SSH Agent Not Forwarding

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

### Git Identity Not Showing

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

### Windows Executables Not Working in WSL

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

### DevContainer Fails to Start

**Symptoms:** DevContainer build fails or times out

**Solutions:**

1. **Verify systemd is running:**

```bash
systemctl --version
# Should show systemd version
```

2. **Verify Docker is installed and running (if using Docker DevContainers):**

```bash
docker ps
# Should list containers (or show empty list if none running)
```

3. **Check DevContainer logs:**

In VS Code, open Output panel (View > Output) and select "Dev Containers"

### VS Code Breaks Docker After Opening WSL Folder

**Symptoms:**
- Docker commands fail after opening WSL folder in VS Code: `docker: command not found`
- Windows executables fail: `notepad.exe: cannot execute binary file`
- Error: `/proc/sys/fs/binfmt_misc/WSLInterop` not found
- VS Code terminal shows: `WARNING: Failed to load binfmt_misc`

**Cause:** Legacy rc.local configuration that VS Code can overwrite when initializing its WSL server.

**Solution:** Re-run the idempotent Docker setup to migrate to kernel-level binfmt.d configuration:

```powershell
# From Windows PowerShell/Command Prompt:
wsl-manager setup-docker Debian
```

Or using the interactive menu:
```powershell
wsl-manager
# Select: [D] Setup/Repair Docker (idempotent, includes systemd/interop)
```

**What this does:**
- Detects existing Docker installation (no reinstall)
- Migrates from old rc.local to `/etc/binfmt.d/WSLInterop.conf` if needed
- Verifies all components are configured correctly
- VS Code respects kernel configuration (no more interference)

**Note:** This is safe to run on already-working installations - it will verify and repair without breaking anything.

**Verification:**
```bash
# Check binfmt.d configuration exists
wsl -d Debian cat /etc/binfmt.d/WSLInterop.conf
# Expected: :WSLInterop:M::MZ::/init:PF

# Verify kernel registration
wsl -d Debian ls /proc/sys/fs/binfmt_misc/WSLInterop
# Should exist

# Test Docker works
wsl -d Debian docker ps

# Test Windows executable works
wsl -d Debian notepad.exe
```

**After repair:**
- Close and reopen VS Code if it's currently open with a WSL folder
- Changes take effect immediately, but VS Code may need restart

---

## Reference

### WSL Manager Functions

- `Install-WslDockerEngine`: Installs Docker and configures prerequisites
  - Automatically enables systemd and Windows interop
  - Configures kernel-level interop via binfmt.d
  - Installs Docker packages and adds user to docker group
  - Restarts distribution

- `Set-WslConf`: Safely merges wsl.conf sections (used internally)
  - Preserves existing configuration
  - Creates timestamped backups before modification
  - Supports multiple sections in one call

### Manual Configuration Files

**`/etc/wsl.conf` (managed by automation):**

```ini
[boot]
systemd=true

[interop]
enabled=true
appendWindowsPath=true

[user]
default=<your-username>
```

**`/etc/binfmt.d/WSLInterop.conf` (managed by automation):**

```
:WSLInterop:M::MZ::/init:PF
```

This kernel-level configuration is managed by `systemd-binfmt.service` and is VS Code compatible (prevents interference).

---

## Additional Resources

- [WSL Configuration Documentation](https://docs.microsoft.com/en-us/windows/wsl/wsl-config)
- [VS Code DevContainers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Git Credential Manager Documentation](https://github.com/GitCredentialManager/git-credential-manager)
- [SSH Agent Forwarding](https://developer.github.com/v3/guides/using-ssh-agent-forwarding/)

---

## Notes

- **Why binfmt.d?** Uses kernel-level configuration managed by `systemd-binfmt.service` instead of late-boot rc.local scripts. This prevents VS Code from interfering with Windows executable interop when opening WSL folders.

- **Why ssh.exe?** Using `ssh.exe` from Windows allows git operations inside WSL to leverage the Windows SSH agent, enabling seamless SSH key forwarding without managing keys inside each WSL distribution.

- **Security consideration:** This setup forwards your SSH agent into containers. Only use with trusted DevContainer configurations.
