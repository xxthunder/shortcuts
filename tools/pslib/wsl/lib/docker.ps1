<#
.DESCRIPTION
    WSL Docker management functions for installing and checking Docker Engine in distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\..\utils\utils.ps1"

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

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Trim input
    $DistroName = $DistroName.Trim()

    # Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        throw "Distribution '$DistroName' does not exist."
    }

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
        Installs Docker Engine, Docker CLI, containerd, Docker Compose plugin,
        and Docker Buildx plugin in a WSL2 distribution. Performs comprehensive
        prerequisite validation and post-installation verification.

        Prerequisites:
        - WSL2 (not WSL1)
        - systemd enabled and running
        - Debian or Ubuntu distribution
        - Default user configured in /etc/wsl.conf (or Username parameter provided)
        - Docker not already installed

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
    $DistroName = $DistroName.Trim()
    if ($Username) {
        $Username = $Username.Trim()
    }

    # Prerequisite validation - fail-fast approach

    # 1. Check WSL is installed
    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first. See: https://docs.microsoft.com/en-us/windows/wsl/install"
    }

    # 2. Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        $availableDistros = $distros -join ", "
        throw "Distribution '$DistroName' does not exist. Available distributions: $availableDistros"
    }

    # 3. Check WSL2 (not WSL1)
    if (-not (Test-Wsl2Version -DistroName $DistroName)) {
        throw @"
Distribution '$DistroName' is using WSL1.
Docker requires WSL2. Upgrade with:
  wsl.exe --set-version $DistroName 2
"@
    }

    # 4. Check systemd configuration in wsl.conf
    if (-not (Test-WslSystemdConfigured -DistroName $DistroName)) {
        throw @"
Distribution '$DistroName' does not have systemd configured in /etc/wsl.conf.
Docker Engine requires systemd for service management.

Add the following to /etc/wsl.conf:
  [boot]
  systemd=true

Then restart the distribution:
  wsl.exe --terminate $DistroName
  wsl.exe --distribution $DistroName
"@
    }

    # 5. Check systemd is running
    if (-not (Test-WslSystemd -DistroName $DistroName)) {
        throw @"
Distribution '$DistroName' does not have systemd running.
Docker Engine requires systemd for service management.

This may mean systemd failed to start. Check the following:
  1. Verify systemd is configured in /etc/wsl.conf (see previous step)
  2. Restart the distribution:
       wsl.exe --terminate $DistroName
       wsl.exe --distribution $DistroName
  3. Check systemd status:
       wsl.exe --distribution $DistroName systemctl --version
"@
    }

    # 6. Check distribution type (Debian/Ubuntu only)
    $distroType = Get-WslDistroType -DistroName $DistroName
    if ($distroType -notin @("debian", "ubuntu")) {
        throw "Distribution '$DistroName' is not a Debian or Ubuntu distribution (detected: $distroType). Only Debian and Ubuntu distributions are currently supported for Docker setup."
    }

    # 7. Detect or validate username
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

    # 8. Check if Docker already installed
    if (Test-WslDockerInstalled -DistroName $DistroName) {
        throw @"
Docker is already installed in '$DistroName'.

To reinstall Docker:
  1. Uninstall existing Docker:
       wsl.exe --distribution $DistroName sudo apt-get remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  2. Run setup-docker again

Or verify your installation with:
  docker --version
  docker compose version
"@
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
        $scriptPath = Join-Path $PSScriptRoot "..\scripts\install-docker.sh"

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
                Write-Information "Successfully installed Docker in '$DistroName'."
                Write-Information ""
                Write-Information "Next steps:"
                Write-Information "  1. Restart the distribution to apply group membership:"
                Write-Information "       wsl.exe --terminate $DistroName"
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
        Write-Error "Docker installation failed: $_"
        return $false
    }
}
