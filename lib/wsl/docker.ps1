<#
.DESCRIPTION
    WSL Docker management functions for checking Docker Engine in distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

function Test-WslDockerInstalled {
    <#
    .SYNOPSIS
        Checks if Docker is installed in a WSL distribution.

    .DESCRIPTION
        Tests whether Docker is installed in a WSL distribution by attempting
        to run 'docker --version'. Returns $true only if the output reports
        'Docker version'. Returns $false if Docker is not installed, the command
        fails, or the output is empty. The 'docker' wrapper of the podman-docker
        package prints 'podman version ...' and does not count as Docker.

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
        already present in the distribution. A Podman setup installs podman-docker,
        whose 'docker' wrapper must not block a later Docker installation check.
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

        # Only real Docker prints 'Docker version'; the podman-docker wrapper prints 'podman version'
        if (($output -join "`n") -match 'Docker version') {
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
