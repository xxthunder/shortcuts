<#
.DESCRIPTION
    Utility methods for WSL (Windows Subsystem for Linux) operations.
#>

# Source dependencies
. "$PSScriptRoot\utils.ps1"

function Test-WslInstalled {
    <#
    .SYNOPSIS
        Checks if WSL (Windows Subsystem for Linux) is installed.

    .DESCRIPTION
        Tests whether the wsl.exe command is available on the system,
        indicating that WSL is installed.

    .OUTPUTS
        System.Boolean
        Returns $true if WSL is installed, $false otherwise.

    .EXAMPLE
        if (Test-WslInstalled) {
            Write-Host "WSL is available"
        }
    #>
    try {
        $wslCommand = Get-Command -Name "wsl" -ErrorAction SilentlyContinue
        return $null -ne $wslCommand
    }
    catch {
        return $false
    }
}

function Install-WslDebian {
    <#
    .SYNOPSIS
        Installs the Debian distribution for WSL.

    .DESCRIPTION
        Installs Debian as a WSL distribution using the 'wsl --install -d Debian' command.
        Requires WSL to be installed on the system.

    .EXAMPLE
        Install-WslDebian

    .NOTES
        Requires administrator privileges for first-time WSL distribution installation.
    #>
    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    Invoke-CommandLine -CommandLine "wsl --install -d Debian"
}

function Get-WslDistroList {
    <#
    .SYNOPSIS
        Gets a list of installed WSL distributions.

    .DESCRIPTION
        Returns an array of names of all WSL distributions installed on the system.
        Requires WSL to be installed.

    .OUTPUTS
        System.String[]
        An array of distribution names, or an empty array if none are installed.

    .EXAMPLE
        $distros = Get-WslDistroList
        $distros | ForEach-Object { Write-Host "Found: $_" }
    #>
    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    $distros = wsl --list --quiet | ForEach-Object {
        # Clean up WSL output: remove null chars (UTF-16), carriage returns, and trim whitespace
        $_.Trim() -replace '\x00', '' -replace '\r', ''
    } | Where-Object { $_ -ne "" }

    if ($null -eq $distros) {
        return @()
    }

    return $distros
}
