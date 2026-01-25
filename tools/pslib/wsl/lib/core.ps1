<#
.DESCRIPTION
    Core WSL utility functions for checking WSL installation status, listing distributions,
    querying distribution state, detecting distribution types and versions.
#>

# Source dependencies
. "$PSScriptRoot\..\..\utils\utils.ps1"

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

function Get-WslDistroList {
    <#
    .SYNOPSIS
        Gets a list of installed WSL distributions.

    .DESCRIPTION
        Returns an array of names of all WSL distributions installed on the system.
        When -Detailed is specified, returns structured objects with Name, State, Version, and IsDefault fields.
        Requires WSL to be installed.

    .PARAMETER Detailed
        When specified, returns PSCustomObject array with detailed information (Name, State, Version, IsDefault)
        instead of just distribution names. Uses wsl --list --verbose output.

    .OUTPUTS
        System.String[]
        An array of distribution names, or an empty array if none are installed.

        PSCustomObject[] (when -Detailed specified)
        Array of objects with Name, State, Version, IsDefault properties.

    .EXAMPLE
        $distros = Get-WslDistroList
        $distros | ForEach-Object { Write-Host "Found: $_" }

    .EXAMPLE
        $distros = Get-WslDistroList -Detailed
        $distros | Where-Object { $_.State -eq 'Running' } | ForEach-Object { Write-Host "$($_.Name) is running" }

    .EXAMPLE
        # Find all WSL2 distributions
        Get-WslDistroList -Detailed | Where-Object { $_.Version -eq 2 }

    .EXAMPLE
        # Get the default distribution
        Get-WslDistroList -Detailed | Where-Object { $_.IsDefault }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Detailed
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    if ($Detailed) {
        # Get verbose output with state and version information
        $output = wsl.exe --list --verbose 2>&1
        $lines = $output -split "`n"
        $results = @()

        foreach ($line in $lines) {
            # Clean up line: remove null chars (UTF-16), carriage returns, trim whitespace
            $cleanLine = $line -replace '\x00', '' -replace '\r', ''
            $cleanLine = $cleanLine.Trim()

            # Skip empty lines
            if ([string]::IsNullOrWhiteSpace($cleanLine)) {
                continue
            }

            # Skip header lines (contain NAME, STATE, VERSION, NOM, ÉTAT, STATUS keywords)
            if ($cleanLine -match '\bNAME\b|\bSTATE\b|\bVERSION\b|\bNOM\b|\bÉTAT\b|\bSTATUS\b') {
                continue
            }

            # Check for default marker (asterisk at start)
            $isDefault = $cleanLine.StartsWith('*')

            # Remove leading asterisk if present
            $workingLine = $cleanLine -replace '^\*\s*', ''
            $workingLine = $workingLine.Trim()

            # Split by whitespace into fields
            $fields = $workingLine -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            # We expect at least 3 fields: Name, State, Version
            if ($fields.Count -lt 3) {
                continue
            }

            # Handle multi-word state values (e.g., "Wird ausgeführt", "En cours d'exécution")
            # Version is always the last field, Name is the first, State is everything in between
            $name = $fields[0]
            $version = [int]$fields[-1]
            $stateValue = ($fields[1..($fields.Count - 2)]) -join ' '

            # Normalize state to Running/Stopped
            $runningPatterns = @('Running', 'Wird', 'ausgeführt', 'cours', 'exécution', 'Ausführen')
            $isRunning = $false
            foreach ($pattern in $runningPatterns) {
                if ($stateValue -match $pattern) {
                    $isRunning = $true
                    break
                }
            }

            $state = if ($isRunning) { 'Running' } else { 'Stopped' }

            $results += [PSCustomObject]@{
                Name      = $name
                State     = $state
                Version   = $version
                IsDefault = $isDefault
            }
        }

        # Always return an array (even if empty)
        return @($results)
    }
    else {
        # Original behavior: return string array of names
        $distros = wsl.exe --list --quiet | ForEach-Object {
            # Clean up WSL output: remove null chars (UTF-16), carriage returns, and trim whitespace
            $_.Trim() -replace '\x00', '' -replace '\r', ''
        } | Where-Object { $_ -ne "" }

        if ($null -eq $distros) {
            return @()
        }

        return $distros
    }
}

function Get-WslDistroState {
    <#
    .SYNOPSIS
        Gets the current running state of a WSL distribution.

    .DESCRIPTION
        Queries wsl.exe --list --verbose to determine if a distribution is Running or Stopped.
        Handles localized output using pattern matching for different languages.

    .PARAMETER DistroName
        The name of the WSL distribution to check.

    .OUTPUTS
        System.String
        Returns 'Running' or 'Stopped'

    .EXAMPLE
        $state = Get-WslDistroState -DistroName "Debian"
        if ($state -eq 'Running') {
            Write-Host "Debian is currently running"
        }

    .EXAMPLE
        Get-WslDistroState -DistroName "Ubuntu-22.04"
        Returns: 'Running' or 'Stopped'

    .NOTES
        Supports localized WSL output (English, German, French, etc.) using pattern matching.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        throw "Distribution '$DistroName' does not exist."
    }

    # Get verbose list output - call wsl.exe directly to capture output
    # (Invoke-CommandLine doesn't return captured output)
    # Refactored to use Get-WslDistroList -Detailed for centralization (Work Item #5)

    $distros = Get-WslDistroList -Detailed
    $distro = $distros | Where-Object { $_.Name -eq $DistroName }

    if (-not $distro) {
        # Double check if it exists but wasn't parsed correctly (should not happen with new parser)
        # Or if Get-WslDistroList (simple) found it but -Detailed didn't (state issue)
        throw "Unable to determine state for distribution '$DistroName'."
    }

    return $distro.State
}

function Test-WslDistroRunning {
    <#
    .SYNOPSIS
        Tests if a WSL distribution is currently running.

    .DESCRIPTION
        Checks if the specified WSL distribution is in a Running state.
        This is a convenience wrapper around Get-WslDistroState.

    .PARAMETER DistroName
        The name of the WSL distribution to check.

    .OUTPUTS
        System.Boolean
        Returns $true if the distribution is running, $false if stopped.

    .EXAMPLE
        if (Test-WslDistroRunning -DistroName "Debian") {
            Write-Host "Debian is running, will terminate before clone"
        }

    .EXAMPLE
        Test-WslDistroRunning -DistroName "Ubuntu-22.04"
        Returns: $true or $false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        throw "Distribution '$DistroName' does not exist."
    }

    $state = Get-WslDistroState -DistroName $DistroName
    return $state -eq 'Running'
}

function Get-WslDistroType {
    <#
    .SYNOPSIS
        Detects the type of a WSL distribution.

    .DESCRIPTION
        Reads /etc/os-release to determine the distribution family (Debian, Ubuntu, Arch, RHEL, etc.).
        Returns a normalized distribution type string.

    .PARAMETER DistroName
        The name of the WSL distribution to detect.

    .OUTPUTS
        System.String
        Returns one of: "debian", "ubuntu", "arch", "rhel", or "unknown"

    .EXAMPLE
        $type = Get-WslDistroType -DistroName "Debian"
        if ($type -in @("debian", "ubuntu")) {
            Write-Host "This is a Debian-based distribution"
        }

    .EXAMPLE
        Get-WslDistroType -DistroName "Ubuntu-22.04"
        Returns: "ubuntu"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        throw "Distribution '$DistroName' does not exist."
    }

    # Warm up the distro (ensure it's started and file system is accessible)
    # This is especially important for freshly imported/cloned distributions
    Invoke-WslDistroCommand -DistroName $DistroName -Command "echo warmup" -PrintCommand $false -StopAtError $false -Silent $true

    # Read ID field from /etc/os-release using simpler command without complex quoting
    $command = 'cat /etc/os-release | grep ^ID= | head -1 | cut -d= -f2'
    $result = Invoke-WslDistroCommand -DistroName $DistroName -Command $command -PrintCommand $false -StopAtError $false -PassThru

    # Clean up output (trim whitespace, remove quotes, convert to lowercase)
    if ([string]::IsNullOrWhiteSpace($result)) {
        $distroId = "unknown"
    }
    else {
        $distroId = $result.Trim().Trim('"').ToLower()
    }

    # Map distribution ID to family
    $distroType = switch -Regex ($distroId) {
        "^debian$" { "debian" }
        "^ubuntu$" { "ubuntu" }
        "^arch.*" { "arch" }
        "^(rhel|centos|fedora)$" { "rhel" }
        default { "unknown" }
    }

    return $distroType
}

function Test-Wsl2Version {
    <#
    .SYNOPSIS
        Checks if a WSL distribution is using WSL2 (not WSL1).

    .DESCRIPTION
        Validates that a WSL distribution is running on WSL2 by parsing the
        output of 'wsl.exe --list --verbose' and checking the VERSION column. Returns $true
        for WSL2 distributions, $false for WSL1 distributions.

    .PARAMETER DistroName
        The name of the WSL distribution to check.

    .OUTPUTS
        System.Boolean
        Returns $true if the distribution is WSL2, $false if WSL1.

    .EXAMPLE
        if (Test-Wsl2Version -DistroName "Debian") {
            Write-Host "Distribution is WSL2"
        } else {
            Write-Host "Distribution is WSL1 - upgrade with: wsl.exe --set-version Debian 2"
        }

    .NOTES
        Docker requires WSL2. Distributions can be upgraded from WSL1 to WSL2 using:
        wsl.exe --set-version <DistroName> 2
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

    # Get WSL version list - Refactored to use Get-WslDistroList -Detailed
    $distros = Get-WslDistroList -Detailed
    $distro = $distros | Where-Object { $_.Name -eq $DistroName }

    if (-not $distro) {
        # Distribution not found in output (shouldn't happen since we validated existence)
        return $false
    }

    return $distro.Version -eq 2
}

function Test-WslSystemd {
    <#
    .SYNOPSIS
        Checks if systemd is available and running in a WSL distribution.

    .DESCRIPTION
        Tests whether systemd is operational in a WSL distribution by attempting
        to run 'systemctl --version'. Returns $true if systemd is running,
        $false if systemd is not available, not installed, or not enabled in wsl.conf.

    .PARAMETER DistroName
        The name of the WSL distribution to check.

    .OUTPUTS
        System.Boolean
        Returns $true if systemd is operational, $false otherwise.

    .EXAMPLE
        if (Test-WslSystemd -DistroName "Debian") {
            Write-Host "Systemd is available"
        } else {
            Write-Host "Systemd is not available - enable it in /etc/wsl.conf"
        }

    .NOTES
        Systemd must be enabled in /etc/wsl.conf with:
        [boot]
        systemd=true

        The distribution must be restarted after enabling systemd.
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

    # Try to run systemctl --version
    try {
        $output = Invoke-WslDistroCommand -DistroName $DistroName -Command "systemctl --version" -StopAtError $false -PrintCommand $false -PassThru

        # If command succeeded and returned output, systemd is available
        if (-not [string]::IsNullOrWhiteSpace($output)) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        # systemctl not found or systemd not running
        return $false
    }
}

function Stop-WslDistro {
    <#
    .SYNOPSIS
        Terminates a running WSL distribution.

    .DESCRIPTION
        Stops a running WSL distribution using wsl.exe --terminate.
        If the distribution is already stopped, displays an informational message.
        Supports ShouldProcess for -WhatIf and -Confirm parameters.

    .PARAMETER Name
        The name of the WSL distribution to terminate.

    .EXAMPLE
        Stop-WslDistro -Name "Debian"
        Terminates the Debian distribution after confirmation.

    .EXAMPLE
        Stop-WslDistro -Name "Ubuntu-22.04" -Confirm:$false
        Terminates Ubuntu 22.04 without prompting for confirmation.

    .EXAMPLE
        Stop-WslDistro -Name "Debian" -WhatIf
        Shows what would happen without actually terminating.

    .NOTES
        This function is safe to call on already-stopped distributions.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Trim name
    $Name = $Name.Trim()

    # Validate not empty after trim
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Distribution name cannot be empty or whitespace."
    }

    # Check if distribution exists
    $distros = Get-WslDistroList
    if ($Name -notin $distros) {
        throw "Distribution '$Name' does not exist."
    }

    # Check if distribution is running
    $isRunning = Test-WslDistroRunning -DistroName $Name

    if (-not $isRunning) {
        Write-Information "Distribution '$Name' is not running."
        return
    }

    # Terminate the distribution
    if ($PSCmdlet.ShouldProcess($Name, "Terminate WSL distribution")) {
        Invoke-CommandLine -CommandLine "wsl.exe --terminate $Name" -StopAtError $true -PrintCommand $false
        Write-Information "✓ Successfully terminated distribution '$Name'"
    }
}
