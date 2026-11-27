<#
.DESCRIPTION
    WSL Podman management functions for checking Podman in distributions.
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
