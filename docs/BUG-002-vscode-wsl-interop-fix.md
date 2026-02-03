# BUG-002: Fix VS Code WSL Interop Interference

**Status**: Open
**Priority**: High
**Component**: `tools/pslib/wsl/scripts/install-docker.sh`, `tools/pslib/wsl/lib/docker.ps1`
**Created**: 2026-02-03
**Branch**: `feature/wsl-devcontainer-prep`

---

## Problem Summary

The setup-docker implementation uses `/etc/rc.local` to register WSL Windows executable interop (`echo :WSLInterop:M::MZ::/init:PF > /proc/sys/fs/binfmt_misc/register`). This is a "late-boot" script that VS Code's server can overwrite when opening WSL folders, breaking Docker and Windows `.exe` calls.

**Root Cause**: VS Code tries to manage the WSL environment and may re-initialize interop settings after rc.local runs, creating a race condition.

**Solution**: Replace rc.local approach with kernel-level `/etc/binfmt.d/WSLInterop.conf` configuration managed by `systemd-binfmt.service`. This is a core system service that VS Code respects and won't interfere with.

---

## Symptoms

1. Docker commands work immediately after `wsl-manager setup-docker`
2. Opening WSL folder in VS Code breaks Docker: `docker: command not found` or `cannot execute: required file not found`
3. Windows executables fail: `notepad.exe: cannot execute binary file`
4. Interop registration missing: `/proc/sys/fs/binfmt_misc/WSLInterop` doesn't exist
5. VS Code terminal shows: `WARNING: Failed to load binfmt_misc`

---

## Technical Background

### Current Implementation (rc.local)

**File**: `tools/pslib/wsl/scripts/install-docker.sh` (lines 121-148)

```bash
setup_rc_local() {
    # Creates /etc/rc.local with interop registration
    # Creates systemd override for rc-local.service
    # Enables rc-local.service
}
```

**Problems**:
- Late-boot execution (runs after systemd initialization)
- VS Code can overwrite/reset interop settings
- Race condition between rc-local and VS Code server
- Fragile: depends on systemd service ordering

### Proposed Implementation (binfmt.d)

**File**: `/etc/binfmt.d/WSLInterop.conf`

```
:WSLInterop:M::MZ::/init:PF
```

**Benefits**:
- Kernel-level configuration (early boot)
- Managed by `systemd-binfmt.service` (core system service)
- VS Code respects kernel configuration
- Standard systemd approach (used by other distributions)
- No race conditions

### Why VS Code Respects binfmt.d

VS Code's WSL server:
1. **Respects kernel configuration**: binfmt.d is loaded by kernel at boot
2. **Doesn't override systemd-binfmt**: Core system service, not user-managed
3. **Interop already registered**: By the time VS Code starts, kernel has configuration
4. **Standard approach**: Other WSL distributions use binfmt.d (Ubuntu, etc.)

---

## Implementation Approach

### 1. Replace rc.local with binfmt.d in Bash Script

**File**: `tools/pslib/wsl/scripts/install-docker.sh`

**Changes**:

**Remove** (lines 121-148):
- Entire `setup_rc_local()` function
- Function call: `setup_rc_local || { ... }`

**Add** (insert at line 121):

```bash
# 8.5. Configure WSL interop via binfmt.d (Docker/VS Code compatibility)
log_info "Configuring WSL interop via binfmt.d..."
setup_binfmt_interop() {
    # Create binfmt.d directory if it doesn't exist
    mkdir -p /etc/binfmt.d

    # Check if WSLInterop.conf already exists
    if [ -f /etc/binfmt.d/WSLInterop.conf ]; then
        log_info "WSLInterop.conf already exists, verifying content..."

        # Verify it has the correct content
        if grep -q ":WSLInterop:M::MZ::/init:PF" /etc/binfmt.d/WSLInterop.conf; then
            log_info "WSLInterop.conf is already correctly configured"
        else
            log_info "WSLInterop.conf exists but has different content, updating..."
            echo ":WSLInterop:M::MZ::/init:PF" > /etc/binfmt.d/WSLInterop.conf
        fi
    else
        log_info "Creating WSLInterop.conf..."
        echo ":WSLInterop:M::MZ::/init:PF" > /etc/binfmt.d/WSLInterop.conf
    fi

    # Restart systemd-binfmt to apply changes
    if pidof systemd > /dev/null; then
        systemctl restart systemd-binfmt
    fi
}
setup_binfmt_interop || { log_error "Failed to configure WSL interop via binfmt.d"; exit 3; }
```

**Replace verification** (lines 164-168):

```bash
# Verify binfmt.d configuration exists
if [ ! -f /etc/binfmt.d/WSLInterop.conf ]; then
    log_error "WSLInterop.conf not found in /etc/binfmt.d"
    exit 3
fi

# Verify WSLInterop is registered in kernel
if pidof systemd > /dev/null; then
    if [ ! -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        log_error "WSLInterop not registered in binfmt_misc"
        exit 3
    fi

    # Verify systemd-binfmt service is active
    if ! systemctl is-active --quiet systemd-binfmt; then
        log_error "systemd-binfmt service is not active"
        exit 3
    fi
fi
```

---

### 2. Add Repair Function for Migration

**File**: `tools/pslib/wsl/lib/docker.ps1` (after line 325)

**Function**: `Repair-WslInteropConfiguration`

**Purpose**: Migrate existing installations from rc.local to binfmt.d

**Signature**:
```powershell
function Repair-WslInteropConfiguration {
    <#
    .SYNOPSIS
        Repairs WSL interop configuration by migrating from rc.local to binfmt.d

    .DESCRIPTION
        Removes old rc.local-based interop configuration and replaces with kernel-level
        binfmt.d configuration. Fixes VS Code interference with Docker and Windows executables.

    .PARAMETER DistroName
        Name of the WSL distribution to repair

    .PARAMETER Confirm
        Prompt for confirmation before making changes (default: true)

    .EXAMPLE
        Repair-WslInteropConfiguration -DistroName "Debian"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DistroName,

        [Parameter(Mandatory = $false)]
        [bool]$Confirm = $true
    )

    # Implementation details:
    # 1. Check if old rc.local configuration exists
    # 2. Remove /etc/rc.local
    # 3. Remove /etc/systemd/system/rc-local.service.d/override.conf
    # 4. Disable rc-local.service if enabled
    # 5. Create /etc/binfmt.d/WSLInterop.conf
    # 6. Restart systemd-binfmt
    # 7. Verify kernel registration
    # 8. Return success/failure
}
```

**Key Implementation Details**:
- Use bash heredoc to create repair script
- Save to temp file in WSL distribution
- Execute via `Invoke-WslDistroScript`
- Provide clear feedback about changes
- Handle errors gracefully
- Return boolean for success/failure

---

### 3. Update Integration Tests (TDD Approach)

**File**: `tools/pslib/wsl/wsl-manager.Integration.Tests.ps1`

**Test 1: Replace rc.local test** (lines 619-655):

```powershell
It "Should configure binfmt.d for WSL interop (not rc.local)" {
    Write-Host "`n==> TEST: Verifying binfmt.d configuration in $script:customDistroName ..." -ForegroundColor Magenta

    # Verify /etc/binfmt.d/WSLInterop.conf exists
    $binfmtConfExists = Invoke-WslDistroCommand -DistroName $script:customDistroName `
        -Command "test -f /etc/binfmt.d/WSLInterop.conf && echo 'exists'" -PrintCommand $false -PassThru -StopAtError $false
    $binfmtConfExists.Trim() | Should -Be "exists"

    # Verify content matches expected configuration
    $binfmtContent = Invoke-WslDistroCommand -DistroName $script:customDistroName `
        -Command "cat /etc/binfmt.d/WSLInterop.conf" -PrintCommand $false -PassThru
    $binfmtContent | Should -Match ":WSLInterop:M::MZ::/init:PF"

    # Verify kernel registration exists
    $interopRegistered = Invoke-WslDistroCommand -DistroName $script:customDistroName `
        -Command "test -e /proc/sys/fs/binfmt_misc/WSLInterop && echo 'registered'" -PrintCommand $false -PassThru -StopAtError $false
    $interopRegistered.Trim() | Should -Be "registered"

    # Verify systemd-binfmt service is active
    $binfmtServiceActive = Invoke-WslDistroCommand -DistroName $script:customDistroName `
        -Command "systemctl is-active systemd-binfmt" -PrintCommand $false -PassThru -StopAtError $false
    $binfmtServiceActive.Trim() | Should -Be "active"

    # Verify rc.local does NOT exist (cleanup verification)
    $rcLocalExists = Invoke-WslDistroCommand -DistroName $script:customDistroName `
        -Command "test -f /etc/rc.local && echo 'exists' || echo 'not-found'" -PrintCommand $false -PassThru -StopAtError $false
    $rcLocalExists.Trim() | Should -Be "not-found"
}
```

**Test 2: Add repair function test** (after Docker tests, ~line 720):

```powershell
It "Should repair interop configuration from rc.local to binfmt.d" {
    Write-Host "`n==> TEST: Testing Repair-WslInteropConfiguration ..." -ForegroundColor Magenta

    # Simulate old configuration by creating rc.local
    Invoke-WslDistroCommand -DistroName $script:customDistroName `
        -Command "sudo bash -c 'echo ""#!/bin/sh"" > /etc/rc.local && echo ""echo :WSLInterop:M::MZ::/init:PF > /proc/sys/fs/binfmt_misc/register"" >> /etc/rc.local && chmod +x /etc/rc.local'" `
        -PrintCommand $false -StopAtError $false | Out-Null

    # Run repair function
    $result = Repair-WslInteropConfiguration -DistroName $script:customDistroName -Confirm:$false
    $result | Should -Be $true

    # Verify rc.local is removed
    $rcLocalAfter = Invoke-WslDistroCommand -DistroName $script:customDistroName `
        -Command "test -f /etc/rc.local && echo 'exists' || echo 'not-found'" -PrintCommand $false -PassThru -StopAtError $false
    $rcLocalAfter.Trim() | Should -Be "not-found"

    # Verify binfmt.d configuration exists
    $binfmtExists = Invoke-WslDistroCommand -DistroName $script:customDistroName `
        -Command "test -f /etc/binfmt.d/WSLInterop.conf && echo 'exists'" -PrintCommand $false -PassThru -StopAtError $false
    $binfmtExists.Trim() | Should -Be "exists"
}
```

---

### 4. Add CLI/Interactive Support

**File**: `tools/pslib/wsl/wsl-manager.ps1`

**Changes**:

1. **Interactive menu option** (add to main menu):
   ```
   [R] Repair Interop (fix VS Code interference)
   ```

2. **CLI command**:
   ```powershell
   wsl-manager repair-interop <distro-name>
   ```

3. **Wrapper function**:
   ```powershell
   function Invoke-RepairInterop {
       param([string]$DistroName)

       Write-Host "Repairing WSL interop configuration..." -ForegroundColor Cyan
       $result = Repair-WslInteropConfiguration -DistroName $DistroName

       if ($result) {
           Write-Host "✓ Interop configuration repaired successfully" -ForegroundColor Green
           Write-Host "  - Removed old rc.local configuration" -ForegroundColor White
           Write-Host "  - Created kernel-level binfmt.d configuration" -ForegroundColor White
           Write-Host "  - VS Code will no longer interfere with Docker" -ForegroundColor White
       } else {
           Write-Host "✗ Failed to repair interop configuration" -ForegroundColor Red
       }
   }
   ```

---

### 5. Update Documentation

#### File: `docs/wsl-devcontainer-setup.md`

**Section to update** (~line 121): "Automated Configuration Details"

Replace:
```
- **RC.local fix**: Configures `/etc/rc.local` to register Windows executable interop
```

With:
```
- **Kernel-level interop**: Configures `/etc/binfmt.d/WSLInterop.conf` for VS Code compatibility
```

**Add troubleshooting section** (new section after step 8):

```markdown
## Troubleshooting

### VS Code Breaks Docker After Opening WSL Folder

**Symptoms**:
- Docker commands fail: `docker: command not found`
- Windows executables fail: `notepad.exe: cannot execute binary file`
- Error: `/proc/sys/fs/binfmt_misc/WSLInterop` not found

**Cause**: Legacy rc.local configuration that VS Code can overwrite.

**Solution**: Run the repair command to migrate to kernel-level configuration:

```powershell
.\tools\pslib\wsl\wsl-manager.ps1 repair-interop Debian
```

**Verification**:
```bash
# Check binfmt.d configuration exists
wsl -d Debian cat /etc/binfmt.d/WSLInterop.conf

# Verify kernel registration
wsl -d Debian ls /proc/sys/fs/binfmt_misc/WSLInterop

# Test Docker works
wsl -d Debian docker ps

# Test Windows executable works
wsl -d Debian notepad.exe
```

After running repair, close and reopen VS Code to ensure changes take effect.
```

#### File: `docs/wsl-manager.md`

**Line ~94**: Replace "RC.local fix" with:

```
- Kernel-level interop via binfmt.d (VS Code compatible)
```

#### File: `docs/backlog.md`

See section below for complete BUG-002 entry.

---

## Verification Strategy

### Automated Testing

```bash
# Run integration tests
pwsh -File ".\test\bin\testrunner.ps1" -Integration
```

**Expected results**:
- Docker installation creates `/etc/binfmt.d/WSLInterop.conf`
- rc.local does NOT exist
- Kernel registration in `/proc/sys/fs/binfmt_misc/WSLInterop`
- systemd-binfmt service is active
- Repair function migrates from old to new approach

### Manual Testing

#### Test Plan A: Fresh Installation

```bash
# 1. Create fresh Debian distribution
wsl --install -d Debian

# 2. Setup user and install Docker
.\tools\pslib\wsl\wsl-manager.ps1 setup-user Debian
.\tools\pslib\wsl\wsl-manager.ps1 setup-docker Debian

# 3. Verify binfmt.d configuration
wsl -d Debian bash -c "cat /etc/binfmt.d/WSLInterop.conf"
wsl -d Debian bash -c "ls /proc/sys/fs/binfmt_misc/WSLInterop"

# 4. Verify rc.local NOT present
wsl -d Debian bash -c "ls /etc/rc.local 2>&1"  # Should fail

# 5. Test Docker and Windows executables
wsl -d Debian docker ps
wsl -d Debian notepad.exe

# 6. Open in VS Code and wait 30 seconds
code --folder-uri "vscode-remote://wsl+Debian/home/developer"

# 7. Verify interop still working after VS Code loads
wsl -d Debian bash -c "ls /proc/sys/fs/binfmt_misc/WSLInterop"
wsl -d Debian docker ps
wsl -d Debian notepad.exe

# Success: All commands work, no errors
```

#### Test Plan B: Migration from Old Installation

```bash
# 1. Run repair on distribution with old rc.local setup
.\tools\pslib\wsl\wsl-manager.ps1 repair-interop Debian

# 2. Verify rc.local removed
wsl -d Debian bash -c "ls /etc/rc.local 2>&1"  # Should fail

# 3. Verify binfmt.d created
wsl -d Debian bash -c "cat /etc/binfmt.d/WSLInterop.conf"

# 4. Test Docker and Windows executables work
wsl -d Debian docker ps
wsl -d Debian notepad.exe

# 5. Open in VS Code and verify persistence (same as Test Plan A step 6-7)
```

---

## Edge Cases Handled

1. **Idempotency**: Running setup-docker or repair multiple times is safe
2. **Already configured**: Script checks if binfmt.d config exists before creating
3. **No systemd**: Skips service restart if systemd not running
4. **Old installation**: Repair function provides migration path
5. **VS Code running**: Kernel registration updates immediately, but close/reopen VS Code recommended
6. **Partial migration**: Repair removes all rc.local artifacts before creating binfmt.d

---

## Success Criteria

- [ ] New Docker installations use binfmt.d (not rc.local)
- [ ] Integration tests verify binfmt.d configuration
- [ ] VS Code no longer breaks Docker/Windows executables
- [ ] Repair function available for migrating existing installations
- [ ] Documentation updated with troubleshooting steps
- [ ] All tests pass on both PowerShell 5.1 and 7.x
- [ ] Manual testing confirms VS Code compatibility

---

## Implementation Order (Commits)

Following TDD approach:

1. **test(wsl): update integration tests to expect binfmt.d (RED)**
   - Replace rc.local test with binfmt.d test
   - Add repair function test
   - Tests FAIL at this stage

2. **fix(wsl): replace rc.local with binfmt.d in install-docker.sh (GREEN)**
   - Remove rc.local setup and verification
   - Add binfmt.d setup and verification
   - Integration tests PASS

3. **feat(wsl): add Repair-WslInteropConfiguration function (GREEN)**
   - Add repair function to docker.ps1
   - Repair test PASSES

4. **feat(wsl): add repair-interop command to wsl-manager**
   - Add interactive menu option
   - Add CLI command handler
   - Add wrapper function

5. **docs(wsl): update documentation for binfmt.d approach**
   - Update wsl-devcontainer-setup.md
   - Update wsl-manager.md
   - Update backlog.md

---

## Related Issues

- **FEAT-001**: Docker installation prerequisites (completed)
- **GitHub Issue**: [To be created] VS Code WSL interop interference

---

## References

- systemd-binfmt documentation: https://www.freedesktop.org/software/systemd/man/systemd-binfmt.service.html
- binfmt_misc kernel documentation: https://docs.kernel.org/admin-guide/binfmt-misc.html
- VS Code WSL documentation: https://code.visualstudio.com/docs/remote/wsl
