# Quickstart Guide: WSL Manager

**Feature Branch**: `001-wsl-manager`
**Date**: 2026-01-13
**Phase**: 1 - Design Artifacts

## What is WSL Manager?

WSL Manager is a PowerShell-based CLI tool that simplifies managing Windows Subsystem for Linux (WSL) distributions. It provides an interactive menu interface and direct command-line operations for creating, cloning, configuring, updating, terminating, and removing WSL distributions.

**Key Features**:
- ✅ Interactive menu for easy command discovery
- ✅ Create WSL distributions from Microsoft Store
- ✅ Clone existing distributions for project-specific environments
- ✅ Set up user accounts with sudo privileges
- ✅ Install Docker Engine with one command
- ✅ Update packages in Debian/Ubuntu distributions
- ✅ Terminate running distributions
- ✅ Remove unused distributions to free disk space

---

## Prerequisites

Before using WSL Manager, ensure you have:

1. **Windows 10 version 2004 or later** (or Windows 11)
2. **WSL installed and enabled**
   - Check: Run `wsl --version` in PowerShell
   - Install: Run `wsl --install` as Administrator
3. **PowerShell 5.1 or later** (included in Windows 10/11)
4. **Internet connection** (for creating distributions and installing Docker)

---

## Quick Start

### Option 1: Interactive Mode (Recommended for Beginners)

**Step 1**: Open PowerShell and navigate to the project directory

```powershell
cd C:\path\to\shortcuts
```

**Step 2**: Launch WSL Manager without arguments

```powershell
.\tools\pslib\wsl\wsl-manager.ps1
# OR
wsl-manager  # If .bat wrapper is in PATH
```

**Step 3**: You'll see an interactive menu

```text
=== Installed WSL Distributions ===
1. Debian
2. Ubuntu-22.04

Available commands:
  [I] Install new distribution
  [C] Clone existing distribution
  [U] Update distribution packages
  [S] Setup user account
  [D] Setup Docker Engine
  [T] Terminate running distribution
  [R] Remove distribution
  [Q] Quit

Enter your choice: _
```

**Step 4**: Select a command by typing its letter (e.g., `I` for Install)

**Step 5**: Follow the prompts to complete your task

---

### Option 2: Direct Command Mode (For Scripting and Automation)

Run specific commands directly without the interactive menu:

```powershell
# List all installed distributions
wsl-manager list

# Create a new distribution
wsl-manager create Debian

# Clone a distribution
wsl-manager clone Debian MyProject

# Update packages
wsl-manager update Debian

# Setup a user account
wsl-manager setup-user Debian developer mypassword

# Install Docker Engine
wsl-manager setup-docker Debian -Confirm:$false

# Terminate a running distribution
wsl-manager terminate Debian

# Remove a distribution
wsl-manager remove MyProject -Confirm:$false
```

---

## Common Workflows

### Workflow 1: Create a Fresh Debian Environment

**Goal**: Set up a new Debian distribution with a user account and Docker

**Steps**:

```powershell
# 1. Create the distribution
wsl-manager create Debian

# 2. Setup a user account
wsl-manager setup-user Debian
# Follow prompts to enter username and password

# 3. Install Docker Engine
wsl-manager setup-docker Debian
# Confirm installation when prompted

# 4. Verify Docker installation
wsl -d Debian docker run --rm hello-world
```

**Result**: A fully configured Debian environment with Docker ready to use

---

### Workflow 2: Clone a Distribution for a New Project

**Goal**: Create a project-specific environment based on an existing template

**Steps**:

```powershell
# 1. Ensure the source distribution is stopped
wsl-manager terminate Debian

# 2. Clone the distribution
wsl-manager clone Debian MyProject

# 3. Verify the clone
wsl-manager list
# Should show both Debian and MyProject

# 4. Start using the clone
wsl -d MyProject
```

**Result**: An independent copy of Debian named MyProject with all configurations preserved

---

### Workflow 3: Maintain and Clean Up Distributions

**Goal**: Keep distributions up to date and remove unused ones

**Steps**:

```powershell
# 1. Update packages in Debian
wsl-manager update Debian

# 2. Update packages in Ubuntu
wsl-manager update Ubuntu-22.04

# 3. List all distributions
wsl-manager list

# 4. Remove an old project distribution
wsl-manager remove OldProject
# Confirm removal when prompted
```

**Result**: Updated distributions and freed disk space from removed distributions

---

## Command Reference

### List Distributions

**Command**: `wsl-manager list`

**What it does**: Shows all installed WSL distributions

**When to use**: Check what distributions you have before creating, cloning, or removing

---

### Create Distribution

**Command**: `wsl-manager create [name]`

**What it does**: Installs a new WSL distribution from Microsoft Store

**When to use**: Need a fresh Linux environment for a project

**Available distributions**:
- Debian
- Ubuntu
- Ubuntu-20.04
- Ubuntu-22.04
- Ubuntu-24.04
- And more (run `wsl --list --online` to see all)

**Example**:
```powershell
wsl-manager create Debian
wsl-manager create Ubuntu-22.04
```

---

### Clone Distribution

**Command**: `wsl-manager clone <source> <target>`

**What it does**: Creates an exact copy of an existing distribution with a new name

**When to use**: Need multiple environments based on the same configuration (e.g., one per project)

**Important**: Source distribution must be stopped (not running)

**Example**:
```powershell
wsl-manager clone Debian ProjectA
wsl-manager clone Debian ProjectB
```

---

### Remove Distribution

**Command**: `wsl-manager remove <name> [-Confirm:$false]`

**What it does**: Unregisters and deletes a WSL distribution

**When to use**: Free disk space by removing distributions you no longer need

**Important**: This is destructive - all data in the distribution will be lost

**Example**:
```powershell
wsl-manager remove OldProject
wsl-manager remove TestEnv -Confirm:$false  # Skip confirmation
```

---

### Terminate Distribution

**Command**: `wsl-manager terminate <name>`

**What it does**: Stops a running WSL distribution

**When to use**: Before cloning, removing, or updating a distribution

**Example**:
```powershell
wsl-manager terminate Debian
wsl-manager terminate Ubuntu-22.04
```

---

### Update Distribution

**Command**: `wsl-manager update <name>`

**What it does**: Updates all packages in a Debian or Ubuntu distribution

**When to use**: Keep your distribution up to date with security patches and package updates

**Supported**: Debian and Ubuntu only

**Important**: Distribution must be stopped (not running)

**Example**:
```powershell
wsl-manager update Debian
wsl-manager update Ubuntu-22.04
```

---

### Setup User Account

**Command**: `wsl-manager setup-user <distribution> [username] [password]`

**What it does**: Creates a user account with sudo privileges and sets it as default

**When to use**: After creating a fresh distribution, before installing Docker

**Features**:
- Home directory created automatically
- Sudo access with NOPASSWD (convenient for development)
- Set as default login user
- Required for Docker installation

**Example**:
```powershell
# Interactive (prompts for username and password)
wsl-manager setup-user Debian

# Direct (for scripting)
wsl-manager setup-user Debian developer mypassword
```

---

### Setup Docker Engine

**Command**: `wsl-manager setup-docker <distribution> [-Confirm:$false]`

**What it does**: Installs Docker Engine with all dependencies and configuration

**When to use**: Need to run containers in your WSL distribution

**Prerequisites**:
- WSL2 (not WSL1)
- Systemd enabled and running
- Debian or Ubuntu distribution
- Default user account configured

**Example**:
```powershell
# Interactive (asks for confirmation)
wsl-manager setup-docker Debian

# Direct (for scripting)
wsl-manager setup-docker Debian -Confirm:$false
```

---

## Troubleshooting

### "WSL is not installed"

**Problem**: WSL feature is not enabled on your Windows system

**Solution**:
```powershell
# Run as Administrator
wsl --install
# Restart your computer
```

---

### "Distribution is running. Please stop it first"

**Problem**: Operation requires the distribution to be stopped

**Solution**:
```powershell
# Terminate the distribution
wsl-manager terminate <name>
# OR
wsl --terminate <name>

# Then retry your operation
```

---

### "Docker requires WSL2. Upgrade with: wsl.exe --set-version <name> 2"

**Problem**: Distribution is using WSL1, but Docker requires WSL2

**Solution**:
```powershell
# Upgrade to WSL2
wsl --set-version <name> 2

# Set WSL2 as default for future distributions
wsl --set-default-version 2
```

---

### "Systemd is not configured"

**Problem**: Docker requires systemd, but it's not enabled in `/etc/wsl.conf`

**Solution**:
```powershell
# Option 1: Edit /etc/wsl.conf manually
wsl -d <name>
sudo nano /etc/wsl.conf
# Add:
#   [boot]
#   systemd=true
# Save and exit

# Option 2: Use command-line
wsl -d <name> sudo bash -c 'echo -e "[boot]\nsystemd=true" > /etc/wsl.conf'

# Restart distribution
wsl --terminate <name>
```

---

### "Invalid username. Must be lowercase..."

**Problem**: Username contains uppercase letters or invalid characters

**Solution**:
```text
Valid username rules:
- Must be lowercase only
- Must start with a letter or underscore
- May contain letters, digits, underscores, hyphens
- Maximum 32 characters

Examples:
  ✅ developer
  ✅ john_doe
  ✅ user123
  ❌ Developer (uppercase)
  ❌ john.doe (dots not allowed in some contexts)
  ❌ 123user (starts with digit)
```

---

### "Distribution '<name>' already exists"

**Problem**: Trying to create or clone to a name that's already in use

**Solution**:
```powershell
# Check existing distributions
wsl-manager list

# Use a different name
wsl-manager clone Debian MyProject2  # Instead of MyProject
```

---

## Tips and Best Practices

### 1. Use Cloning for Project Environments

Instead of creating a new distribution for each project, create one "template" distribution with all your tools installed, then clone it for each project.

```powershell
# Create and configure a template
wsl-manager create Debian
wsl-manager setup-user Debian developer mypassword
wsl-manager setup-docker Debian

# Clone for each project
wsl-manager clone Debian ProjectA
wsl-manager clone Debian ProjectB
wsl-manager clone Debian ProjectC
```

**Benefits**:
- Faster setup (clone takes minutes vs. full setup)
- Consistent environments across projects
- Easy to update template and re-clone

---

### 2. Always Terminate Before Clone/Remove/Update

Many operations require the distribution to be stopped. Get in the habit of terminating first:

```powershell
# Always terminate before these operations
wsl-manager terminate Debian
wsl-manager clone Debian MyProject
```

---

### 3. Use `-Confirm:$false` for Automation

When scripting or running in CI/CD pipelines, skip confirmation prompts:

```powershell
# In scripts
wsl-manager remove TestEnv -Confirm:$false
wsl-manager setup-docker Debian -Confirm:$false
```

---

### 4. Update Regularly

Keep your distributions up to date with security patches:

```powershell
# Weekly maintenance
wsl-manager update Debian
wsl-manager update Ubuntu-22.04
```

---

### 5. Clean Up Unused Distributions

Free disk space by removing distributions you no longer need:

```powershell
# List all distributions
wsl-manager list

# Remove old ones
wsl-manager remove OldProject
```

---

## Next Steps

Now that you're familiar with WSL Manager, explore:

1. **[CLI Interface Contract](./contracts/cli-interface.md)** - Complete command reference with all parameters and outputs
2. **[Data Model](./data-model.md)** - Understanding WSL distribution entities and state transitions
3. **[Research Document](./research.md)** - Design decisions and architectural patterns
4. **[Feature Specification](./spec.md)** - Complete functional requirements and user stories

---

## Getting Help

### Interactive Mode Help

Run without arguments to see the interactive menu:
```powershell
wsl-manager
```

### Command-Line Help

Get help for specific functions:
```powershell
Get-Help New-WslDistro -Full
Get-Help Copy-WslDistro -Full
Get-Help Install-WslDockerEngine -Full
```

### Official WSL Documentation

- [Microsoft WSL Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [Docker on WSL2 Documentation](https://docs.docker.com/desktop/wsl/)

---

## Feedback and Issues

If you encounter issues or have suggestions:

1. Check the troubleshooting section above
2. Review error messages carefully - they include remediation steps
3. Consult the [Feature Specification](./spec.md) for expected behavior
4. Report issues via the project's issue tracking system

---

**Happy WSL Managing!** 🐧
