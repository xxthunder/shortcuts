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

function Get-WslAvailableDistro {
    <#
    .SYNOPSIS
        Gets a list of available WSL distributions that can be installed.

    .DESCRIPTION
        Queries 'wsl --list --online' to get available distributions.
        Uses language-independent parsing to work on systems with any locale.
        Sets LC_ALL environment variable to ensure consistent output format.

    .OUTPUTS
        System.String[]
        An array of distribution names that can be installed.

    .EXAMPLE
        $available = Get-WslAvailableDistro
        $available | ForEach-Object { Write-Host "Available: $_" }

    .NOTES
        Uses pattern-based parsing to handle localized WSL output.
        Distribution names are alphanumeric with hyphens, underscores, and dots.
    #>
    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    try {
        # Set locale to English for consistent output (primary approach)
        $originalLcAll = $env:LC_ALL
        $env:LC_ALL = "en_US.UTF-8"

        # Get available distributions
        $output = wsl --list --online 2>&1

        # Restore original locale
        if ($null -ne $originalLcAll) {
            $env:LC_ALL = $originalLcAll
        }
        else {
            Remove-Item Env:\LC_ALL -ErrorAction SilentlyContinue
        }

        # Parse output using pattern matching (language-independent fallback)
        # Distribution names match pattern: alphanumeric, hyphens, underscores, dots
        $distros = @()
        $lines = $output -split "`n"

        foreach ($line in $lines) {
            # Clean up line: remove null chars, carriage returns, trim whitespace
            $cleanLine = $line -replace '\x00', '' -replace '\r', '' | ForEach-Object { $_.Trim() }

            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($cleanLine)) {
                continue
            }

            # Extract first word that matches distribution name pattern
            if ($cleanLine -match '^([A-Za-z0-9][A-Za-z0-9_.-]*)\s') {
                $distroName = $matches[1]

                # Skip header-like lines (containing common header words)
                $headerKeywords = @('NAME', 'FRIENDLY', 'INSTALL', 'LIST', 'VALID', 'AVAILABLE')
                $isHeader = $false
                foreach ($keyword in $headerKeywords) {
                    if ($cleanLine -match $keyword) {
                        $isHeader = $true
                        break
                    }
                }

                if (-not $isHeader) {
                    $distros += $distroName
                }
            }
        }

        return $distros
    }
    catch {
        throw "Failed to retrieve available distributions: $_"
    }
}

function New-WslDistro {
    <#
    .SYNOPSIS
        Creates a new WSL distribution.

    .DESCRIPTION
        Installs a new WSL distribution using the 'wsl --install -d' command.
        Supports any distribution available through 'wsl --list --online'.
        Dynamically validates against available distributions.
        Requires WSL to be installed on the system.

    .PARAMETER Name
        The name of the distribution to create (e.g., Ubuntu-22.04, Debian, kali-linux).
        Must match one of the distributions returned by 'wsl --list --online'.

    .EXAMPLE
        New-WslDistro -Name "Debian"

    .EXAMPLE
        New-WslDistro -Name "Ubuntu-22.04"

    .EXAMPLE
        New-WslDistro -Name "kali-linux"

    .NOTES
        Requires administrator privileges for first-time WSL distribution installation.
        Uses dynamic distribution discovery for maximum compatibility.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Trim the name to handle any whitespace issues
    $Name = $Name.Trim()

    # Get available distributions dynamically
    $availableDistros = Get-WslAvailableDistro

    # Validate distribution name against available distributions
    if ($Name -notin $availableDistros) {
        $errorMsg = "Distribution '$Name' is not available.`n`n"
        $errorMsg += "Available distributions:`n"
        foreach ($distro in $availableDistros) {
            $errorMsg += "  - $distro`n"
        }
        $errorMsg += "`nRun 'wsl --list --online' to see all available distributions."
        throw $errorMsg
    }

    # Check if distribution already exists
    $installedDistros = Get-WslDistroList
    if ($Name -in $installedDistros) {
        throw "Distribution '$Name' already exists."
    }

    if ($PSCmdlet.ShouldProcess($Name, "Create WSL distribution")) {
        Write-Output "Creating WSL distribution '$Name'..."
        Invoke-CommandLine -CommandLine "wsl --install -d $Name --no-launch"
        Write-Output "Successfully created '$Name'."
        Write-Output ""
        Write-Output "To start: wsl -d $Name"
    }
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

function Remove-WslDistro {
    <#
    .SYNOPSIS
        Removes an existing WSL distribution.

    .DESCRIPTION
        Unregisters a WSL distribution using the 'wsl --unregister' command.
        Requires WSL to be installed and the distribution to exist.

    .PARAMETER Name
        The name of the distribution to remove.

    .EXAMPLE
        Remove-WslDistro -Name "MyDebian"

    .EXAMPLE
        Remove-WslDistro -Name "MyDebian" -Confirm:$false

    .NOTES
        This operation cannot be undone and will delete all data in the distribution.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Check if distribution exists
    $distros = Get-WslDistroList
    if ($Name -notin $distros) {
        throw "Distribution '$Name' does not exist."
    }

    # Ask for confirmation using ShouldProcess
    if ($PSCmdlet.ShouldProcess($Name, "Remove WSL distribution")) {
        Write-Output "Removing WSL distribution '$Name'..."
        Invoke-CommandLine -CommandLine "wsl --unregister $Name"
        Write-Output "Successfully removed '$Name'."
    }
    else {
        Write-Output "Removal cancelled."
    }
}
