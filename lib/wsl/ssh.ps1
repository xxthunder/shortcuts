<#
.DESCRIPTION
    WSL SSH configuration sync functions for copying keys and config between Windows and WSL distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

function Invoke-WslSyncSshConfig {
    <#
    .SYNOPSIS
        Syncs SSH keys and config between Windows and a WSL distribution.

    .DESCRIPTION
        Copies all SSH key pairs from the Windows user's .ssh directory into the WSL
        distribution's ~/.ssh/ with correct permissions, syncs non-DevPod SSH config
        entries from Windows into WSL, and syncs DevPod SSH config blocks from WSL to
        the Windows SSH config with adapted ProxyCommand for Windows-side editor access
        (VS Code, JetBrains).

        This function is idempotent - safe to run multiple times.

        Prerequisites:
        - Distribution must exist

    .PARAMETER DistroName
        The name of the WSL distribution to sync SSH config for.

    .OUTPUTS
        System.Boolean
        Returns $true if setup succeeds, $false otherwise.

    .EXAMPLE
        Invoke-WslSyncSshConfig -DistroName "Debian"
        Copies SSH keys and syncs SSH config for Debian.

    .EXAMPLE
        Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false
        Runs without confirmation prompt.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    # Prerequisite validation - fail-fast approach

    # 1. Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

    # SupportsShouldProcess - prompt for confirmation
    if (-not $PSCmdlet.ShouldProcess(
            "SSH config sync for '$DistroName'",
            "Copy SSH keys and sync SSH config",
            "Confirm SSH Config Sync"
        )) {
        return $false
    }

    # Resolve Windows .ssh directory path
    $windowsSshDir = Join-Path $env:USERPROFILE ".ssh"
    # Convert to WSL mount path: C:\Users\... -> /mnt/c/Users/...
    $driveLetter = $windowsSshDir.Substring(0, 1).ToLower()
    $wslSshDir = $windowsSshDir -replace "^[${driveLetter}$($driveLetter.ToUpper())]:", "/mnt/${driveLetter}"
    $wslSshDir = $wslSshDir.Replace('\', '/')

    try {
        $scriptPath = Join-Path $PSScriptRoot "scripts\sync-ssh-config.sh"

        $scriptArgs = @(
            "--ssh-target-dir=$wslSshDir",
            "--distro-name=$DistroName"
        )

        $exitCode = Invoke-WslDistroScript -ScriptPath $scriptPath -DistroName $DistroName -Arguments $scriptArgs -StopAtError $false -PrintCommand $false

        switch ($exitCode) {
            0 {
                return $true
            }
            1 {
                throw "No SSH keys found in '$windowsSshDir'. Ensure you have SSH keys generated."
            }
            2 {
                throw "Config sync failed. Check file permissions on '$windowsSshDir\config'."
            }
            4 {
                throw "Argument error. Required parameters missing."
            }
            default {
                throw "SSH config sync failed with exit code: $exitCode"
            }
        }
    }
    catch {
        Write-Error "SSH config sync failed: $_"
        return $false
    }
}
