# Data Model: WSL Manager

**Feature Branch**: `001-wsl-manager`
**Date**: 2026-01-13
**Phase**: 1 - Design Artifacts

## Overview

This document defines the key entities, their attributes, relationships, validation rules, and state transitions for the WSL Manager. The data model is derived from the functional requirements in [spec.md](./spec.md) and design decisions in [research.md](./research.md).

## Entity Definitions

### 1. WSL Distribution

A Linux distribution instance managed by Windows Subsystem for Linux.

**Attributes**:

| Attribute | Type | Description | Source | Validation |
|---|---|---|---|---|
| `Name` | String | Unique distribution identifier | `wsl --list --quiet` | Required, pattern: `^([A-Za-z0-9][A-Za-z0-9_.-]*)$` |
| `State` | Enum | Current running state | `wsl --list --verbose` | `Running` \| `Stopped` |
| `Version` | Integer | WSL version | `wsl --list --verbose` | `1` \| `2` |
| `DistroType` | Enum | Distribution family | `/etc/os-release` (ID field) | `debian` \| `ubuntu` \| `arch` \| `rhel` \| `unknown` |
| `IsDefault` | Boolean | Whether distribution is WSL default | `wsl --list` (asterisk marker) | `true` \| `false` |
| `DefaultUser` | String? | Default login user | `/etc/wsl.conf` [user] section | Optional, null for root-only distros |
| `SystemdEnabled` | Boolean | Whether systemd is configured | `/etc/wsl.conf` [boot] section | `true` \| `false` |
| `SystemdRunning` | Boolean | Whether systemd is actively running | `systemctl --version` exit code | `true` \| `false` |
| `DockerInstalled` | Boolean | Whether Docker Engine is installed | `docker --version` exit code | `true` \| `false` |

**Relationships**:
- **1-to-1** with `InstallationConfiguration` (via `/etc/wsl.conf`)
- **1-to-many** with `UserAccount` (a distribution can have multiple users)
- **1-to-1** with `DockerInstallation` (optional, if Docker is installed)

**Validation Rules**:
- `Name` must be unique across all installed distributions
- `Name` must start with alphanumeric character, may contain dots, underscores, hyphens
- `Version` must be `2` for Docker installation (WSL1 not supported)
- `SystemdEnabled` must be `true` for Docker installation
- `SystemdRunning` must be `true` for Docker installation
- `DistroType` must be `debian` or `ubuntu` for package updates and Docker installation

**State Transitions**:

```text
[Not Installed] --create/install--> [Stopped]
[Not Installed] --clone from [Any]--> [Stopped]
[Stopped] --start (implicit)--> [Running]
[Running] --terminate--> [Stopped]
[Stopped] --update--> [Stopped] (packages updated)
[Stopped] --setup-user--> [Stopped] (user configured, auto-restart)
[Stopped] --setup-docker--> [Stopped] (Docker installed)
[Any] --remove--> [Not Installed]
```

**Invariants**:
- Distribution must be `Stopped` for: clone (source), remove, update operations
- Distribution can be `Running` or `Stopped` for: list, create operations
- Operations that modify `/etc/wsl.conf` require `wsl --terminate` to apply changes

---

### 2. User Account

A Linux user within a WSL distribution, used for non-root operations and Docker access.

**Attributes**:

| Attribute | Type | Description | Source | Validation |
|---|---|---|---|---|
| `Username` | String | Linux username | User input | Required, pattern: `^[a-z_][a-z0-9_-]*$`, max length: 32 |
| `Password` | SecureString | User password | User input (interactive) or parameter (CI) | Required, converted to plain text for `chpasswd` |
| `HomeDirectory` | String | User home directory path | Created via `useradd -m` | `/home/{Username}` |
| `Shell` | String | Default shell | Created via `useradd -s` | `/bin/bash` |
| `SudoAccess` | Boolean | Whether user has sudo privileges | `usermod -aG sudo` | Always `true` |
| `PasswordlessSudo` | Boolean | Whether user can sudo without password | `/etc/sudoers.d/{Username}` | Always `true` (NOPASSWD configured) |
| `IsDefault` | Boolean | Whether user is default login | `/etc/wsl.conf` [user] section | `true` for newly created user |
| `Groups` | String[] | User group memberships | `usermod -aG` | `sudo`, `docker` (if Docker installed) |

**Relationships**:
- **Many-to-1** with `WSL Distribution` (users belong to one distribution)
- **Many-to-1** with `DockerInstallation` (user is added to docker group if Docker installed)

**Validation Rules**:
- `Username` must be lowercase only (Linux standard)
- `Username` must start with lowercase letter or underscore
- `Username` may contain lowercase letters, digits, underscores, hyphens
- `Username` maximum length: 32 characters
- `Password` must be non-empty (no blank passwords allowed)
- Cannot create user with name that already exists in distribution

**Lifecycle**:

```text
[Not Created] --setup-user--> [Created, Configured]
  1. Create user with home directory (useradd -m -s /bin/bash)
  2. Set password (echo 'user:pass' | chpasswd)
  3. Add to sudo group (usermod -aG sudo)
  4. Configure NOPASSWD (echo 'user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/user)
  5. Set as default in /etc/wsl.conf ([user] default=user)
  6. Restart distribution (wsl --terminate)
```

**Security Considerations**:
- NOPASSWD sudo is configured for development convenience
- Security warning displayed once during user creation (FR-029)
- Plain-text password required for `chpasswd` (PowerShell constraint)
- Password cleared from memory after use

---

### 3. Docker Installation

Docker Engine installation within a WSL distribution, enabling containerization.

**Attributes**:

| Attribute | Type | Description | Source | Validation |
|---|---|---|---|---|
| `Version` | String | Docker Engine version | `docker --version` output | Semantic version format |
| `ServiceStatus` | Enum | Docker daemon status | `systemctl status docker` | `running` \| `stopped` \| `failed` |
| `ServiceEnabled` | Boolean | Whether Docker starts on boot | `systemctl is-enabled docker` | `true` \| `false` |
| `UserAccess` | String[] | Users in docker group | Docker group membership | Includes default user |
| `RepositoryConfigured` | Boolean | Whether Docker apt repo is added | `/etc/apt/sources.list.d/docker.list` | `true` after installation |
| `GPGKeyInstalled` | Boolean | Whether Docker GPG key is trusted | `/etc/apt/keyrings/docker.asc` | `true` after installation |

**Relationships**:
- **1-to-1** with `WSL Distribution` (Docker installed in one distribution)
- **1-to-many** with `UserAccount` (multiple users can have docker group access)

**Validation Rules**:
- Docker installation requires `WSL Distribution.Version == 2` (WSL2 only)
- Docker installation requires `WSL Distribution.SystemdEnabled == true`
- Docker installation requires `WSL Distribution.SystemdRunning == true`
- Docker installation requires `WSL Distribution.DistroType in [debian, ubuntu]`
- Docker installation requires `WSL Distribution.DefaultUser != null`
- Docker must NOT already be installed (check `docker --version` fails)

**Installation Steps**:

```text
Prerequisites Validation (8 checks):
  1. WSL installed
  2. Distribution exists
  3. WSL2 (not WSL1)
  4. Systemd configured in /etc/wsl.conf
  5. Systemd running (systemctl --version)
  6. Debian or Ubuntu (not Arch/RHEL)
  7. Default user exists
  8. Docker not already installed

Installation Sequence:
  1. Update apt package index (apt-get update)
  2. Install prerequisites (ca-certificates, curl)
  3. Create keyrings directory (install -m 0755 -d /etc/apt/keyrings)
  4. Download Docker GPG key (curl -fsSL ... -o /etc/apt/keyrings/docker.asc)
  5. Set GPG key permissions (chmod a+r)
  6. Add Docker repository (echo "deb [arch=...] ..." > /etc/apt/sources.list.d/docker.list)
  7. Update package index again (apt-get update)
  8. Install Docker packages (apt-get install docker-ce docker-ce-cli containerd.io ...)
  9. Enable Docker service (systemctl enable docker)
 10. Start Docker service (systemctl start docker)
 11. Add default user to docker group (usermod -aG docker $USER)

Post-Installation Verification:
  1. Check Docker version (docker --version)
  2. Check service status (systemctl status docker --no-pager)
  3. Run hello-world container (docker run --rm hello-world)
```

**Error Scenarios**:
- **WSL1**: "Docker requires WSL2. Upgrade with: wsl.exe --set-version {Name} 2"
- **No systemd**: "Docker requires systemd. Configure /etc/wsl.conf with [boot] systemd=true"
- **Systemd not running**: "Systemd is not running. Restart distribution with: wsl.exe --terminate {Name}"
- **Wrong distro type**: "Docker setup only supports Debian and Ubuntu distributions"
- **No default user**: "Docker requires a non-root user. Run: setup-user {Name}"
- **Already installed**: "Docker {Version} is already installed"

---

### 4. Distribution Type

Classification of WSL distributions by package manager family and system characteristics.

**Attributes**:

| Attribute | Type | Description | Source | Values |
|---|---|---|---|---|
| `Type` | Enum | Distribution family identifier | `/etc/os-release` ID field | `debian`, `ubuntu`, `arch`, `rhel`, `unknown` |
| `PackageManager` | String | Default package manager | Derived from Type | `apt` (debian/ubuntu), `pacman` (arch), `yum`/`dnf` (rhel) |
| `UpdateSupported` | Boolean | Whether `Update-WslDistro` supports this type | Hardcoded logic | `true` for debian/ubuntu, `false` otherwise |
| `DockerSupported` | Boolean | Whether `Install-WslDockerEngine` supports this type | Hardcoded logic | `true` for debian/ubuntu, `false` otherwise |

**Detection Logic**:

```bash
# Read /etc/os-release file
cat /etc/os-release

# Parse ID field
ID=ubuntu        → Type: ubuntu
ID=debian        → Type: debian
ID=arch          → Type: arch
ID=rhel          → Type: rhel
ID=fedora        → Type: rhel (family)
ID=centos        → Type: rhel (family)
ID=<other>       → Type: unknown
```

**Type Characteristics**:

| Type | Package Manager | Update Command | Docker Support |
|---|---|---|---|
| `debian` | `apt` | `apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean` | ✅ Yes |
| `ubuntu` | `apt` | `apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean` | ✅ Yes |
| `arch` | `pacman` | Not implemented | ❌ No |
| `rhel` | `yum`/`dnf` | Not implemented | ❌ No |
| `unknown` | Unknown | Not implemented | ❌ No |

---

### 5. Installation Configuration

WSL distribution settings stored in `/etc/wsl.conf`, controlling boot behavior and default user.

**Attributes**:

| Attribute | Type | Description | File Location | Example |
|---|---|---|---|---|
| `DefaultUser` | String? | Default login user | `[user]` section, `default` key | `default=developer` |
| `SystemdEnabled` | Boolean | Whether to start systemd | `[boot]` section, `systemd` key | `systemd=true` |

**File Format** (`/etc/wsl.conf`):

```ini
[user]
default=developer

[boot]
systemd=true
```

**Parsing Strategy**:

```powershell
# Manual INI parsing (no third-party libraries)
$section = $null
foreach ($line in $content) {
    if ($line -match '^\[(\w+)\]') {
        $section = $matches[1]
    } elseif ($section -eq 'user' -and $line -match '^default\s*=\s*(.+)') {
        $defaultUser = $matches[1].Trim()
    } elseif ($section -eq 'boot' -and $line -match '^systemd\s*=\s*(true|false)') {
        $systemdEnabled = $matches[1] -eq 'true'
    }
}
```

**Modification Strategy**:

```powershell
# Read existing content
$content = Invoke-WslDistroCommand -Name $Name -Command "cat /etc/wsl.conf" -PassThru

# Modify sections
# ... parse and update ...

# Write back to file
$command = "cat > /etc/wsl.conf << 'EOF'`n$newContent`nEOF"
Invoke-WslDistroCommand -Name $Name -Command $command

# Restart distribution to apply changes
wsl.exe --terminate $Name
```

**Validation**:
- File must be valid INI format
- `default` user in `[user]` section must exist in `/etc/passwd`
- `systemd` value in `[boot]` section must be `true` or `false`

---

## Entity Relationships Diagram

```text
┌─────────────────────────────┐
│   WSL Distribution          │
│  - Name (PK)                │
│  - State                    │
│  - Version                  │
│  - DistroType               │
│  - IsDefault                │
│  - DefaultUser              │
│  - SystemdEnabled           │
│  - SystemdRunning           │
│  - DockerInstalled          │
└──────────┬──────────────────┘
           │
           │ 1
           │
           │ has
           │
           │ 1
           ▼
┌─────────────────────────────┐
│ InstallationConfiguration   │
│  - DefaultUser              │
│  - SystemdEnabled           │
│  (stored in /etc/wsl.conf)  │
└─────────────────────────────┘

           │ 1
           │
           │ has
           │
           │ many
           ▼
┌─────────────────────────────┐
│      User Account           │
│  - Username (PK within dist)│
│  - Password (SecureString)  │
│  - HomeDirectory            │
│  - Shell                    │
│  - SudoAccess               │
│  - PasswordlessSudo         │
│  - IsDefault                │
│  - Groups[]                 │
└──────────┬──────────────────┘
           │
           │ many
           │
           │ member of
           │
           │ 1?
           ▼
┌─────────────────────────────┐
│   Docker Installation       │
│  - Version                  │
│  - ServiceStatus            │
│  - ServiceEnabled           │
│  - UserAccess[]             │
│  - RepositoryConfigured     │
│  - GPGKeyInstalled          │
└─────────────────────────────┘

┌─────────────────────────────┐
│    Distribution Type        │
│  - Type (Enum)              │
│  - PackageManager           │
│  - UpdateSupported          │
│  - DockerSupported          │
│  (metadata, not persisted)  │
└─────────────────────────────┘
        ▲
        │ categorizes
        │
     ┌──┴──┐
     │ WSL │
     │Dist.│
     └─────┘
```

## State Machine: WSL Distribution Lifecycle

```text
                    ┌─────────────────┐
                    │  Not Installed  │
                    └────────┬────────┘
                             │
                 ┌───────────┴───────────┐
                 │                       │
            create/install            clone from
                 │                    existing
                 │                       │
                 ▼                       ▼
            ┌─────────────────────────────┐
            │        Stopped              │◄─────┐
            │  (default after creation)   │      │
            └────────┬────────────────────┘      │
                     │                           │
         ┌───────────┼───────────────┐           │
         │           │               │           │
      start      terminate       remove      terminate
    (implicit)       │               │       (after ops)
         │           │               │           │
         ▼           │               ▼           │
    ┌─────────┐     │         ┌──────────┐      │
    │ Running │─────┘         │ Removed  │      │
    │         │               │(destroyed│      │
    └─────────┘               └──────────┘      │
         │                                       │
         │ operations requiring stopped state:   │
         │   - update (packages)                 │
         │   - clone (source distribution)       │
         │   - remove                            │
         └───────────────────────────────────────┘
```

## Validation Rules Summary

### Cross-Entity Validation

| Operation | Preconditions | Validation |
|---|---|---|
| **Create Distribution** | WSL installed | Name unique, available via `wsl --list --online` |
| **Clone Distribution** | WSL installed, source exists | Source stopped, target name unique |
| **Remove Distribution** | WSL installed, distribution exists | Distribution stopped (optional enforcement) |
| **Update Distribution** | WSL installed, distribution exists | Distribution stopped, type is debian/ubuntu |
| **Terminate Distribution** | WSL installed, distribution exists | Distribution is running |
| **Setup User** | WSL installed, distribution exists | Username valid, not already exists |
| **Setup Docker** | WSL installed, distribution exists | WSL2, systemd configured and running, debian/ubuntu, default user exists, Docker not installed, distribution stopped |

### Input Validation Patterns

```powershell
# Distribution name validation
if ($Name -notmatch '^([A-Za-z0-9][A-Za-z0-9_.-]*)$') {
    throw "Invalid distribution name. Must start with alphanumeric and contain only letters, digits, dots, underscores, hyphens."
}

# Username validation
if ($Username -cnotmatch '^[a-z_][a-z0-9_-]*$') {
    throw "Invalid username. Must be lowercase, start with letter or underscore, contain only letters, digits, underscores, hyphens."
}

if ($Username.Length -gt 32) {
    throw "Username too long. Maximum length is 32 characters."
}

# Distribution existence validation
$distros = Get-WslDistroList
if ($Name -notin $distros) {
    throw "Distribution '$Name' does not exist."
}

# Distribution uniqueness validation
if ($Name -in $distros) {
    throw "Distribution '$Name' already exists."
}

# Distribution running state validation
$state = Get-WslDistroState -Name $Name
if ($state -eq 'Running') {
    throw "Distribution '$Name' is running. Stop it first with: wsl --terminate $Name"
}
```

## Data Sources & Access Patterns

### External Data Sources

| Data Source | Access Method | Parsing Strategy | Encoding |
|---|---|---|---|
| `wsl --list --quiet` | `Invoke-CommandLine` | Line-by-line, trim, clean UTF-16 nulls | UTF-16LE |
| `wsl --list --verbose` | `Invoke-CommandLine` | Pattern-based, skip headers | UTF-16LE |
| `wsl --list --online` | `Invoke-CommandLine` | Pattern-based, skip headers | UTF-16LE |
| `/etc/os-release` | `Invoke-WslDistroCommand` | Key-value parsing (`ID=value`) | UTF-8 |
| `/etc/wsl.conf` | `Invoke-WslDistroCommand` | Manual INI parsing | UTF-8 |
| `systemctl --version` | `Invoke-WslDistroCommand` | Exit code only | UTF-8 |
| `docker --version` | `Invoke-WslDistroCommand` | Exit code + version string | UTF-8 |

### Access Patterns

**Read-Heavy Operations** (frequent):
- List distributions: `Get-WslDistroList` (called by every interactive menu display)
- Check distribution type: `Get-WslDistroType` (called before update/Docker operations)
- Check running state: `Get-WslDistroState` (needed implementation)

**Write Operations** (infrequent):
- Create distribution: `New-WslDistro` (minutes to complete)
- Clone distribution: `Copy-WslDistro` (minutes to complete, creates temp tar file)
- Remove distribution: `Remove-WslDistro` (seconds to complete)
- Update packages: `Update-WslDistro` (minutes to complete)
- Setup user: `New-WslUser` (seconds to complete, modifies /etc files)
- Setup Docker: `Install-WslDockerEngine` (minutes to complete, downloads packages)

**Caching Strategy**:
- No explicit caching implemented (operations are infrequent)
- State is always fetched fresh from WSL to ensure accuracy
- Distribution list refreshed on each menu display

---

## WslDistroInfo: Detailed Distribution Information (Refactoring Addition)

**Added**: 2026-01-14
**Purpose**: Centralize all distribution information in a single data structure returned by `Get-WslDistroList -Detailed`

### Data Structure Definition

```powershell
[PSCustomObject]@{
    Name      = [string]    # Distribution name (e.g., "Debian", "Ubuntu-22.04")
    State     = [string]    # Normalized state: "Running" or "Stopped"
    Version   = [int]       # WSL version: 1 or 2
    IsDefault = [bool]      # True if this is the default distribution (asterisk marker)
}
```

### Field Specifications

| Field | Type | Source | Description | Example |
|-------|------|--------|-------------|---------|
| `Name` | `string` | Column 1 of `wsl --list --verbose` | Unique distribution identifier | `"Ubuntu-22.04"` |
| `State` | `string` | Column 2 of `wsl --list --verbose` | Normalized to "Running" or "Stopped" | `"Running"` |
| `Version` | `int` | Column 3 of `wsl --list --verbose` | WSL version number | `2` |
| `IsDefault` | `bool` | Asterisk marker (*) in `wsl --list --verbose` | Default distribution flag | `$true` |

### State Normalization

The `State` field is normalized from localized WSL output to one of two values:

| Normalized Value | Patterns Matched |
|------------------|------------------|
| `"Running"` | `Running`, `Wird ausgeführt`, `En cours d'exécution`, `Wird`, `ausgeführt`, `cours`, `exécution`, `Ausführen` |
| `"Stopped"` | Everything else (default fallback) |

### Usage Examples

```powershell
# Get simple list (backward compatible)
$names = Get-WslDistroList
# Returns: @("Debian", "Ubuntu", "Ubuntu-22.04")

# Get detailed information
$distros = Get-WslDistroList -Detailed
# Returns: @(
#   [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
#   [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
#   [PSCustomObject]@{ Name = "Ubuntu-22.04"; State = "Stopped"; Version = 1; IsDefault = $false }
# )

# Find running distributions
$running = Get-WslDistroList -Detailed | Where-Object { $_.State -eq 'Running' }

# Find WSL2 distributions
$wsl2 = Get-WslDistroList -Detailed | Where-Object { $_.Version -eq 2 }

# Get default distribution
$default = Get-WslDistroList -Detailed | Where-Object { $_.IsDefault }
```

### Consumers of WslDistroInfo

After refactoring, the following functions will consume `Get-WslDistroList -Detailed`:

| Function | Current Implementation | After Refactoring |
|----------|------------------------|-------------------|
| `Get-WslDistroState` | Calls `wsl --list --verbose` directly | Uses `Get-WslDistroList -Detailed` |
| `Test-WslDistroRunning` | Calls `Get-WslDistroState` | Uses `Get-WslDistroList -Detailed` (optional optimization) |
| `Test-Wsl2Version` | Calls `wsl --list --verbose` directly | Uses `Get-WslDistroList -Detailed` |

### Benefits of Centralization

1. **Single WSL call**: One call provides all information vs. multiple calls
2. **Consistent parsing**: One implementation for null-char/localization handling
3. **Better performance**: Cached result can be reused in single operation
4. **Easier maintenance**: Bug fixes and improvements in one place
5. **Richer data**: `IsDefault` field now available (previously discarded)

---

## Summary

This data model defines 5 core entities:

1. **WSL Distribution** - The primary entity representing a Linux distribution
2. **User Account** - Linux users within distributions
3. **Docker Installation** - Docker Engine configuration
4. **Distribution Type** - Classification metadata
5. **Installation Configuration** - `/etc/wsl.conf` settings

Key design principles:
- **Fail-fast validation** - All preconditions checked before operations
- **State safety** - Operations require appropriate state (stopped for destructive ops)
- **No persistent storage** - All state retrieved from WSL and Linux filesystem
- **Manual parsing** - No third-party libraries, pattern-based parsing for localization
- **Atomic operations** - WSL handles atomicity, PowerShell orchestrates workflows
