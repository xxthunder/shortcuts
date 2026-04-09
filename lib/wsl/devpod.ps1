<#
.DESCRIPTION
    WSL DevPod management functions for installing and checking DevPod CLI in distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

function Test-WslDevPodInstalled {
    <#
    .SYNOPSIS
        Checks if DevPod is installed in a WSL distribution.

    .DESCRIPTION
        Tests whether DevPod CLI is installed in a WSL distribution by attempting
        to run 'devpod version'. Returns $true if DevPod is installed and
        the command succeeds, $false if DevPod is not installed or the command fails.

    .PARAMETER DistroName
        The name of the WSL distribution to check.

    .OUTPUTS
        System.Boolean
        Returns $true if DevPod is installed, $false otherwise.

    .EXAMPLE
        if (Test-WslDevPodInstalled -DistroName "Debian") {
            Write-Host "DevPod is already installed"
        } else {
            Write-Host "DevPod is not installed"
        }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    # Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

    # Try to run devpod version
    try {
        $output = Invoke-WslDistroCommand -DistroName $DistroName -Command "devpod version" -StopAtError $false -PrintCommand $false -PassThru

        # If command succeeded and returned output, DevPod is installed
        if (-not [string]::IsNullOrWhiteSpace($output)) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        # devpod not found or command failed
        return $false
    }
}

function Install-WslDevPod {
    <#
    .SYNOPSIS
        Installs DevPod CLI in a WSL distribution and configures the container provider.

    .DESCRIPTION
        Installs or repairs the DevPod CLI in a WSL distribution. This function is
        idempotent and safe to run multiple times - it will skip installation if
        DevPod is already present and repair any missing configuration.

        Automatically detects the container engine (Docker preferred, Podman as fallback)
        and configures it as the DevPod provider.

        Prerequisites:
        - Docker or Podman must be installed in the distribution
        - Default user configured in /etc/wsl.conf (or Username parameter provided)

    .PARAMETER DistroName
        The name of the WSL distribution to install DevPod in.

    .PARAMETER Username
        Optional username for DevPod provider configuration. If not provided, the default
        user from /etc/wsl.conf will be used.

    .OUTPUTS
        System.Boolean
        Returns $true if installation succeeds, $false otherwise.

    .EXAMPLE
        Install-WslDevPod -DistroName "Debian"
        Installs DevPod in Debian using the default user from wsl.conf.

    .EXAMPLE
        Install-WslDevPod -DistroName "Debian" -Confirm:$false
        Installs DevPod in Debian, skipping confirmation prompt.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory = $false)]
        [string]$Username
    )

    # Trim input
    if ($Username) {
        $Username = $Username.Trim()
    }

    # Prerequisite validation - fail-fast approach

    # 1. Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

    # 2. Detect or validate username
    if (-not $Username) {
        $Username = Get-WslDefaultUser -DistroName $DistroName
        if (-not $Username) {
            throw @"
No default user configured in '$DistroName'.
DevPod setup requires a non-root user for provider configuration.

Please setup a user first:
  .\tools\wsl\wsl-manager.ps1 setup-user $DistroName

Then run setup-devpod again.
"@
        }
    }

    # 3. Detect container engine (Docker preferred, Podman as fallback)
    $dockerInstalled = Test-WslDockerInstalled -DistroName $DistroName
    $podmanInstalled = Test-WslPodmanInstalled -DistroName $DistroName

    if (-not $dockerInstalled -and -not $podmanInstalled) {
        throw @"
No container engine found in '$DistroName'.
DevPod requires Docker or Podman to be installed.

Please install a container engine first:
  .\tools\wsl\wsl-manager.ps1 setup-docker $DistroName
  .\tools\wsl\wsl-manager.ps1 setup-podman $DistroName

Then run setup-devpod again.
"@
    }

    $engine = if ($dockerInstalled) { "docker" } else { "podman" }

    # 4. Check DevPod installation status (informational only - bash script is idempotent)
    $devpodAlreadyInstalled = Test-WslDevPodInstalled -DistroName $DistroName
    if ($devpodAlreadyInstalled) {
        Write-Information "DevPod is already installed in '$DistroName'. Verifying configuration..."
    }

    # SupportsShouldProcess - prompt for confirmation
    if (-not $PSCmdlet.ShouldProcess(
            "DevPod CLI installation in '$DistroName'",
            "Install DevPod CLI and configure $engine provider",
            "Confirm DevPod Installation"
        )) {
        return $false
    }

    Write-Information "Installing DevPod CLI in '$DistroName' (engine: $engine) ..."

    try {
        # Execute bash installation script
        $scriptPath = Join-Path $PSScriptRoot "scripts\install-devpod.sh"

        $scriptArgs = @(
            "--engine=$engine",
            "--username=$Username"
        )

        $exitCode = Invoke-WslDistroScript -ScriptPath $scriptPath -DistroName $DistroName -Arguments $scriptArgs -StopAtError $false -PrintCommand $false

        # Parse exit code and provide user-friendly errors
        switch ($exitCode) {
            0 {
                Write-Information ""
                if ($devpodAlreadyInstalled) {
                    Write-Information "Successfully verified DevPod configuration in '$DistroName'."
                    Write-Information ""
                    Write-Information "DevPod was already installed. Configuration has been verified and any missing components have been repaired."
                } else {
                    Write-Information "Successfully installed DevPod CLI in '$DistroName'."
                }
                Write-Information ""
                Write-Information "Terminating '$DistroName' to apply changes..."
                Stop-WslDistro -Name $DistroName -Confirm:$false | Out-Null
                Write-Information ""
                Write-Information "Next steps:"
                Write-Information "  1. Start the distribution:"
                Write-Information "       wsl.exe --distribution $DistroName"
                Write-Information "  2. Test DevPod:"
                Write-Information "       devpod provider list"
                Write-Information "       devpod up <repository-url>"
                return $true
            }
            1 {
                throw "Prerequisite check failed. Ensure script has root access."
            }
            2 {
                throw "Installation failed. Check curl/download or provider configuration."
            }
            3 {
                throw "Verification failed. DevPod installed but provider configuration failed."
            }
            4 {
                throw "Argument error. Required parameters missing."
            }
            5 {
                throw "No container engine found in distribution. Install Docker or Podman first."
            }
            default {
                throw "DevPod installation failed with exit code: $exitCode"
            }
        }
    }
    catch {
        Write-Error "DevPod installation failed: $_"
        return $false
    }
}

function Invoke-WslSyncSshConfig {
    <#
    .SYNOPSIS
        Copies Windows SSH keys into a WSL distribution and syncs DevPod SSH config.

    .DESCRIPTION
        Copies all SSH key pairs from the Windows user's .ssh directory into the WSL
        distribution's ~/.ssh/ with correct permissions, then syncs DevPod SSH config
        blocks from WSL to the Windows SSH config with adapted ProxyCommand for
        Windows-side editor access (VS Code, JetBrains).

        This function is idempotent - safe to run multiple times.

        Prerequisites:
        - Distribution must exist
        - DevPod must be installed in the distribution

    .PARAMETER DistroName
        The name of the WSL distribution to set up SSH for.

    .OUTPUTS
        System.Boolean
        Returns $true if setup succeeds, $false otherwise.

    .EXAMPLE
        Invoke-WslSyncSshConfig -DistroName "Debian"
        Copies SSH keys and syncs DevPod config for Debian.

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

    # 2. Validate DevPod is installed
    $devpodInstalled = Test-WslDevPodInstalled -DistroName $DistroName
    if (-not $devpodInstalled) {
        throw @"
DevPod is not installed in '$DistroName'.
SSH setup requires DevPod to be installed first.

Please install DevPod first:
  .\tools\wsl-manager\wsl-manager.ps1 setup-devpod $DistroName

Then run sync-ssh-config again.
"@
    }

    # SupportsShouldProcess - prompt for confirmation
    if (-not $PSCmdlet.ShouldProcess(
            "SSH config sync for '$DistroName'",
            "Copy SSH keys and sync SSH config with adapted DevPod blocks",
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
