# Contract: install-docker.sh

**Version**: 1.0
**Date**: 2026-01-14
**Status**: DRAFT

## Purpose

The `install-docker.sh` script encapsulates the logic for installing Docker Engine on a Debian/Ubuntu-based WSL distribution. It is designed to be transferred to the target distribution and executed via `bash`.

## Interface

### Execution

```bash
sudo bash install-docker.sh --distro-id=<id> --codename=<name> --arch=<arch> --username=<user>
```

### Arguments

| Argument | Description | Example | required |
|----------|-------------|---------|----------|
| `--distro-id` | Distribution ID from `/etc/os-release` | `ubuntu` | Yes |
| `--codename` | Distribution codename from `/etc/os-release` | `jammy` | Yes |
| `--arch` | System architecture from `dpkg --print-architecture` | `amd64` | Yes |
| `--username` | Non-root username to add to `docker` group | `developer` | Yes |

### Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| `0` | Success | Docker installed and service started successfully |
| `1` | Prerequisite Failure | Script not run as root, or unsupported distribution |
| `4` | Argument Error | Missing required arguments |
| `2` | Installation Failure | `apt-get` failed, key download failed, or repo setup failed |
| `3` | Verification Failure | `docker --version` failed or service failed to start |

## Logic Flow

1. **Validation**
   - Check if running as root (required for installation)
   - Parse arguments
   - Verify all required arguments are present

2. **Clean State**
   - Remove conflicting packages (`docker.io`, `docker-doc`, etc.)
   - Ignore "package not found" errors during removal

3. **Prerequisites**
   - Update `apt` package index
   - Install dependencies: `ca-certificates`, `curl`, `gnupg`

4. **GPG Key Setup**
   - Create keyrings directory: `/etc/apt/keyrings` (mode 0755)
   - Download Docker GPG key to `/etc/apt/keyrings/docker.gpg`
   - Set permissions: `a+r` on key file

5. **Repository Setup**
   - Construct source line: `deb [arch=<arch> signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/<distro-id> <codename> stable`
   - Write to `/etc/apt/sources.list.d/docker.list`

6. **Installation**
   - Update `apt` package index (to pick up new repo)
   - Install packages: `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`

7. **User Configuration**
   - Create `docker` group (if not exists)
   - Add specified user to `docker` group: `usermod -aG docker <username>`

8. **Service/Systemd**
   - Enable `docker.service`
   - Enable `containerd.service`
   - Start `docker` service

9. **Verification**
   - Run `docker --version`
   - Check service status (systemctl is-active)

## Output

- The script should write informative status messages to STDOUT.
- Error details should be written to STDERR.
- Colors may be used for status (Green) and errors (Red) if supported/detected, but plain text is acceptable.
