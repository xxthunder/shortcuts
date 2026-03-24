<#
.DESCRIPTION
    WSL Docker management functions for installing and checking Docker Engine in distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

function Test-WslDockerInstalled {
    <#
    .SYNOPSIS
        Checks if Docker is installed in a WSL distribution.

    .DESCRIPTION
        Tests whether Docker is installed in a WSL distribution by attempting
        to run 'docker --version'. Returns $true if Docker is installed and
        the command succeeds, $false if Docker is not installed or the command fails.

    .PARAMETER DistroName
        The name of the WSL distribution to check.

    .OUTPUTS
        System.Boolean
        Returns $true if Docker is installed, $false otherwise.

    .EXAMPLE
        if (Test-WslDockerInstalled -DistroName "Debian") {
            Write-Host "Docker is already installed"
        } else {
            Write-Host "Docker is not installed"
        }

    .NOTES
        This function is used to prevent attempting to install Docker when it's
        already present in the distribution.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    # Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

    # Try to run docker --version
    try {
        $output = Invoke-WslDistroCommand -DistroName $DistroName -Command "docker --version" -StopAtError $false -PrintCommand $false -PassThru

        # If command succeeded and returned output, Docker is installed
        if (-not [string]::IsNullOrWhiteSpace($output)) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        # docker not found or command failed
        return $false
    }
}

function Install-WslDockerEngine {
    <#
    .SYNOPSIS
        Installs Docker Engine in a WSL distribution.

    .DESCRIPTION
        Installs or repairs Docker Engine in a WSL2 distribution. This function is
        idempotent and safe to run multiple times - it will skip installation if
        Docker is already present and repair any missing configuration.

        Automatically configures systemd and Windows interop if not already configured.

        Prerequisites:
        - WSL2 (not WSL1)
        - Debian or Ubuntu distribution
        - Default user configured in /etc/wsl.conf (or Username parameter provided)

        Note: This function is idempotent. Running it multiple times is safe and will:
        - Skip Docker installation if already present
        - Ensure user is in docker group
        - Verify Docker service is running
        - Repair binfmt.d configuration if needed

    .PARAMETER DistroName
        The name of the WSL distribution to install Docker in.

    .PARAMETER Username
        Optional username to add to the docker group. If not provided, the default
        user from /etc/wsl.conf will be used.

    .OUTPUTS
        System.Boolean
        Returns $true if installation succeeds, $false otherwise.

    .EXAMPLE
        Install-WslDockerEngine -DistroName "Debian"
        Installs Docker Engine in Debian using the default user from wsl.conf.

    .EXAMPLE
        Install-WslDockerEngine -DistroName "Ubuntu-22.04" -Username "developer" -Confirm:$false
        Installs Docker Engine in Ubuntu-22.04, adds user 'developer' to docker group, skips confirmation.

    .EXAMPLE
        Install-WslDockerEngine -DistroName "Debian" -Confirm:$false
        Repairs or verifies Docker installation in Debian (safe to re-run).

    .NOTES
        This function requires sudo privileges in the WSL distribution.
        After installation, the user must restart the distribution for group membership to take effect:
          wsl.exe --terminate <DistroName>
          wsl.exe --distribution <DistroName>
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
Docker requires WSL2. Upgrade with:
  wsl.exe --set-version $DistroName 2
"@
    }

    # 4. Check distribution type (Debian/Ubuntu only)
    $distroType = Get-WslDistroType -DistroName $DistroName
    if ($distroType -notin @("debian", "ubuntu")) {
        throw "Distribution '$DistroName' is not a Debian or Ubuntu distribution (detected: $distroType). Only Debian and Ubuntu distributions are currently supported for Docker setup."
    }

    # 5. Detect or validate username
    if (-not $Username) {
        $Username = Get-WslDefaultUser -DistroName $DistroName
        if (-not $Username) {
            throw @"
No default user configured in '$DistroName'.
Docker setup requires a non-root user to add to the docker group.

Please setup a user first:
  .\tools\wsl\wsl-manager.ps1 setup-user $DistroName

Then run setup-docker again.
"@
        }
    }

    # 6. Check Docker installation status (informational only - bash script is idempotent)
    $dockerAlreadyInstalled = Test-WslDockerInstalled -DistroName $DistroName
    if ($dockerAlreadyInstalled) {
        Write-Information "Docker is already installed in '$DistroName'. Verifying configuration..."
    }

    # Configure systemd, interop, and automount if not already configured
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
        Write-Information "Configuring $($configItems -join ' and ') (Docker prerequisites)..."

        # Get existing default user if configured
        $existingUser = Get-WslDefaultUser -DistroName $DistroName

        # Build wsl.conf sections
        $sections = @{}

        # Add boot section if systemd not configured
        if (-not $systemdConfigured) {
            $sections.boot = @{systemd = "true"}
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
            $sections.automount = @{options = 'metadata,umask=022'}
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

    # SupportsShouldProcess - prompt for confirmation
    if (-not $PSCmdlet.ShouldProcess(
            "Docker Engine installation in '$DistroName'",
            "Install Docker CE, Docker Compose, and related packages (~500MB)",
            "Confirm Docker Installation"
        )) {
        return $false
    }

    Write-Information "Installing Docker Engine in '$DistroName' ..."

    # Docker installation workflow

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
        Write-Information "Executing Docker installation script..."
        $scriptPath = Join-Path $PSScriptRoot "scripts\install-docker.sh"

        $scriptArgs = @(
            "--distro-id=$distroId",
            "--codename=$distroCodename",
            "--arch=$arch",
            "--username=$Username"
        )

        $exitCode = Invoke-WslDistroScript -ScriptPath $scriptPath -DistroName $DistroName -Arguments $scriptArgs -StopAtError $false -PrintCommand $false -AsRoot $true

        # Parse exit code and provide user-friendly errors
        switch ($exitCode) {
            0 {
                Write-Information ""
                if ($dockerAlreadyInstalled) {
                    Write-Information "Successfully verified Docker configuration in '$DistroName'."
                    Write-Information ""
                    Write-Information "Docker was already installed. Configuration has been verified and any missing components have been repaired."
                } else {
                    Write-Information "Successfully installed Docker in '$DistroName'."
                }
                Write-Information ""
                Write-Information "Terminating '$DistroName' to apply changes..."
                Stop-WslDistro -Name $DistroName -Confirm:$false | Out-Null
                Write-Information ""
                Write-Information "Next steps:"
                Write-Information "  1. Start the distribution:"
                Write-Information "       wsl.exe --distribution $DistroName"
                Write-Information "  2. Test Docker (should work without sudo):"
                Write-Information "       docker ps"
                Write-Information "       docker run hello-world"
                return $true
            }
            1 {
                throw "Prerequisite check failed. Ensure distribution is Debian/Ubuntu and script has root access."
            }
            2 {
                throw "Installation failed. Check apt-get, GPG key download, or repository setup."
            }
            3 {
                throw "Verification failed. Docker installed but service failed to start or docker --version failed."
            }
            4 {
                throw "Argument error. Required distribution parameters missing."
            }
            default {
                throw "Docker installation failed with exit code: $exitCode"
            }
        }
    }
    catch {
        throw "Docker installation failed: $_"
    }
}