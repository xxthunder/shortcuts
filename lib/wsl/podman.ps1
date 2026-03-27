<#
.DESCRIPTION
    WSL Podman management functions for installing and checking rootless Podman in distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

function Test-WslPodmanInstalled {
    <#
    .SYNOPSIS
        Checks if Podman is installed in a WSL distribution.

    .DESCRIPTION
        Tests whether Podman is installed in a WSL distribution by attempting
        to run 'podman --version'. Returns $true if Podman is installed and
        the command succeeds, $false if Podman is not installed or the command fails.

    .PARAMETER DistroName
        The name of the WSL distribution to check.

    .OUTPUTS
        System.Boolean
        Returns $true if Podman is installed, $false otherwise.

    .EXAMPLE
        if (Test-WslPodmanInstalled -DistroName "Debian") {
            Write-Host "Podman is already installed"
        } else {
            Write-Host "Podman is not installed"
        }

    .NOTES
        This function is used to prevent attempting to install Podman when it's
        already present in the distribution.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    # Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

    # Try to run podman --version
    try {
        $output = Invoke-WslDistroCommand -DistroName $DistroName -Command "podman --version" -StopAtError $false -PrintCommand $false -PassThru

        # If command succeeded and returned output, Podman is installed
        if (-not [string]::IsNullOrWhiteSpace($output)) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        # podman not found or command failed
        return $false
    }
}

function Install-WslPodman {
    <#
    .SYNOPSIS
        Installs rootless Podman in a WSL distribution.

    .DESCRIPTION
        Installs or repairs rootless Podman in a WSL2 distribution. This function is
        idempotent and safe to run multiple times - it will skip installation if
        Podman is already present and repair any missing configuration.

        Automatically configures systemd, Windows interop, and the boot command
        for rootless Podman (mount --make-rshared /) if not already configured.

        Prerequisites:
        - WSL2 (not WSL1)
        - Debian or Ubuntu distribution
        - Default user configured in /etc/wsl.conf (or Username parameter provided)
        - Docker must NOT be installed (mutual exclusion)

        Note: This function is idempotent. Running it multiple times is safe and will:
        - Skip Podman installation if already present
        - Verify Podman service is running
        - Repair configuration if needed

    .PARAMETER DistroName
        The name of the WSL distribution to install Podman in.

    .PARAMETER Username
        Optional username for Podman configuration. If not provided, the default
        user from /etc/wsl.conf will be used.

    .OUTPUTS
        System.Boolean
        Returns $true if installation succeeds, $false otherwise.

    .EXAMPLE
        Install-WslPodman -DistroName "Debian"
        Installs rootless Podman in Debian using the default user from wsl.conf.

    .EXAMPLE
        Install-WslPodman -DistroName "Ubuntu-22.04" -Username "developer" -Confirm:$false
        Installs rootless Podman in Ubuntu-22.04 for user 'developer', skips confirmation.

    .EXAMPLE
        Install-WslPodman -DistroName "Debian" -Confirm:$false
        Repairs or verifies Podman installation in Debian (safe to re-run).

    .NOTES
        This function requires sudo privileges in the WSL distribution.
        Unlike Docker, rootless Podman does not require a distribution restart
        after installation - no group membership changes are needed.
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

    # 3. Check WSL2 (not WSL1)
    if (-not (Test-Wsl2Version -DistroName $DistroName)) {
        throw @"
Distribution '$DistroName' is using WSL1.
Podman requires WSL2. Upgrade with:
  wsl.exe --set-version $DistroName 2
"@
    }

    # 4. Check distribution type (Debian/Ubuntu only)
    $distroType = Get-WslDistroType -DistroName $DistroName
    if ($distroType -notin @("debian", "ubuntu")) {
        throw "Distribution '$DistroName' is not a Debian or Ubuntu distribution (detected: $distroType). Only Debian and Ubuntu distributions are currently supported for Podman setup."
    }

    # 5. Detect or validate username
    if (-not $Username) {
        $Username = Get-WslDefaultUser -DistroName $DistroName
        if (-not $Username) {
            throw @"
No default user configured in '$DistroName'.
Podman setup requires a non-root user for rootless operation.

Please setup a user first:
  .\tools\wsl\wsl-manager.ps1 setup-user $DistroName

Then run setup-podman again.
"@
        }
    }

    # 6. Mutual exclusion: Docker must not be installed
    $dockerInstalled = Test-WslDockerInstalled -DistroName $DistroName
    if ($dockerInstalled) {
        throw @"
Docker is already installed in '$DistroName'.
Podman and Docker cannot coexist in the same distribution.

To use Podman, first remove Docker, or use a separate WSL distribution.
"@
    }

    # 7. Check Podman installation status (informational only - bash script is idempotent)
    $podmanAlreadyInstalled = Test-WslPodmanInstalled -DistroName $DistroName
    if ($podmanAlreadyInstalled) {
        Write-Information "Podman is already installed in '$DistroName'. Verifying configuration..."
    }

    # Configure systemd, interop, automount, and boot command if not already configured
    $systemdConfigured = Test-WslSystemdConfigured -DistroName $DistroName
    $interopConfigured = Test-WslInteropConfigured -DistroName $DistroName
    $automountConfigured = Test-WslAutomountConfigured -DistroName $DistroName

    if (-not $systemdConfigured -or -not $interopConfigured -or -not $automountConfigured) {
        $configItems = @()
        if (-not $systemdConfigured) {
            $configItems += "systemd"
        }
        if (-not $interopConfigured) {
            $configItems += "Windows interop"
        }
        if (-not $automountConfigured) {
            $configItems += "automount defaults"
        }
        Write-Information "Configuring $($configItems -join ' and ') (Podman prerequisites)..."

        # Get existing default user if configured
        $existingUser = Get-WslDefaultUser -DistroName $DistroName

        # Build wsl.conf sections
        $sections = @{}

        # Always add boot command for rootless Podman; add systemd only if not yet configured
        $sections.boot = @{
            command = "mount --make-rshared /"
        }
        if (-not $systemdConfigured) {
            $sections.boot.systemd = "true"
        }

        # Add interop section if not configured
        if (-not $interopConfigured) {
            $sections.interop = @{
                enabled           = "true"
                appendWindowsPath = "true"
            }
        }

        # Add automount section if not configured
        if (-not $automountConfigured) {
            $sections.automount = @{
                _comment = 'wsl-manager: sensible DrvFs permissions (chmod/chown support, default umask)'
                options  = 'metadata,umask=022'
            }
        }

        # Preserve existing default user
        if ($existingUser) {
            $sections.user = @{default = $existingUser}
        }

        # Configure wsl.conf
        Set-WslConf -DistroName $DistroName -Sections $sections -Confirm:$false | Out-Null

        Write-Information "Restarting distribution to apply changes..."
        Invoke-CommandLine -Command "wsl.exe --terminate $DistroName" -StopAtError $false -PrintCommand $false | Out-Null
        Start-Sleep -Seconds 2
    }
    else {
        # Systemd already configured - ensure boot command is set for rootless Podman
        # Get existing default user if configured
        $existingUser = Get-WslDefaultUser -DistroName $DistroName

        $sections = @{}
        $sections.boot = @{
            command = "mount --make-rshared /"
        }

        # Preserve existing default user
        if ($existingUser) {
            $sections.user = @{default = $existingUser}
        }

        Write-Information "Configuring boot command for rootless Podman..."
        Set-WslConf -DistroName $DistroName -Sections $sections -Confirm:$false | Out-Null

        Write-Information "Restarting distribution to apply changes..."
        Invoke-CommandLine -Command "wsl.exe --terminate $DistroName" -StopAtError $false -PrintCommand $false | Out-Null
        Start-Sleep -Seconds 2
    }

    # SupportsShouldProcess - prompt for confirmation
    if (-not $PSCmdlet.ShouldProcess(
            "Rootless Podman installation in '$DistroName'",
            "Install rootless Podman and related packages",
            "Confirm Podman Installation"
        )) {
        return $false
    }

    Write-Information "Installing rootless Podman in '$DistroName' ..."

    # Podman installation workflow

    try {
        # Detect distribution parameters for the bash script
        Write-Information "Detecting distribution parameters..."
        $getDistroInfoCmd = ". /etc/os-release && echo `$ID && echo `$VERSION_CODENAME && dpkg --print-architecture"
        $distroInfo = Invoke-WslDistroCommand -DistroName $DistroName -Command $getDistroInfoCmd -PrintCommand $false -PassThru
        if ([string]::IsNullOrWhiteSpace($distroInfo)) {
            throw "Failed to detect distribution information"
        }

        $infoLines = $distroInfo -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($infoLines.Count -lt 3) {
            throw "Failed to parse distribution information"
        }

        $distroId = $infoLines[0].Trim().ToLower()
        $distroCodename = $infoLines[1].Trim()
        $arch = $infoLines[2].Trim()

        Write-Information "  Distribution: $distroId"
        Write-Information "  Codename: $distroCodename"
        Write-Information "  Architecture: $arch"
        Write-Information ""

        # Execute bash installation script
        Write-Information "Executing Podman installation script..."
        $scriptPath = Join-Path $PSScriptRoot "scripts\install-podman.sh"

        $scriptArgs = @(
            "--distro-id=$distroId",
            "--codename=$distroCodename",
            "--arch=$arch",
            "--username=$Username"
        )

        $exitCode = Invoke-WslDistroScript -ScriptPath $scriptPath -DistroName $DistroName -Arguments $scriptArgs -StopAtError $false -PrintCommand $false

        # Parse exit code and provide user-friendly errors
        switch ($exitCode) {
            0 {
                Write-Information ""
                if ($podmanAlreadyInstalled) {
                    Write-Information "Successfully verified Podman configuration in '$DistroName'."
                    Write-Information ""
                    Write-Information "Podman was already installed. Configuration has been verified and any missing components have been repaired."
                } else {
                    Write-Information "Successfully installed rootless Podman in '$DistroName'."
                }
                Write-Information ""
                Write-Information "Terminating '$DistroName' to apply changes..."
                Stop-WslDistro -Name $DistroName -Confirm:$false | Out-Null
                Write-Information ""
                Write-Information "Next steps:"
                Write-Information "  1. Start the distribution:"
                Write-Information "       wsl.exe --distribution $DistroName"
                Write-Information "  2. Test Podman (should work without sudo):"
                Write-Information "       podman ps"
                Write-Information "       podman run hello-world"
                return $true
            }
            1 {
                throw "Prerequisite check failed. Ensure distribution is Debian/Ubuntu and script has root access."
            }
            2 {
                throw "Installation failed. Check apt-get or repository setup."
            }
            3 {
                throw "Verification failed. Podman installed but service failed to start or podman --version failed."
            }
            4 {
                throw "Argument error. Required distribution parameters missing."
            }
            default {
                throw "Podman installation failed with exit code: $exitCode"
            }
        }
    }
    catch {
        Write-Error "Podman installation failed: $_"
        return $false
    }
}
