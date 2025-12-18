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
        [ValidateNotNullOrEmpty()]
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
        [ValidateNotNullOrEmpty()]
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

function Copy-WslDistro {
    <#
    .SYNOPSIS
        Clones an existing WSL distribution with a new name.

    .DESCRIPTION
        Creates a copy of an existing WSL distribution by exporting it to a tar file
        and importing it with a new name. This creates an independent copy at the
        filesystem level.

    .PARAMETER SourceName
        The name of the source distribution to clone.

    .PARAMETER TargetName
        The name for the new cloned distribution.

    .PARAMETER InstallPath
        Optional custom installation path for the cloned distribution.
        If not specified, defaults to %USERPROFILE%\wsl\<TargetName>.

    .EXAMPLE
        Copy-WslDistro -SourceName "Debian" -TargetName "MyProject"

    .EXAMPLE
        Copy-WslDistro -SourceName "Ubuntu-22.04" -TargetName "ProjectX" -InstallPath "D:\WSL\ProjectX"

    .NOTES
        Requires WSL to be installed on the system.
        The cloned distribution is completely independent of the source.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetName,

        [Parameter(Mandatory = $false)]
        [string]$InstallPath = ""
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Trim names to handle whitespace
    $SourceName = $SourceName.Trim()
    $TargetName = $TargetName.Trim()

    # Check if source distribution exists
    $distros = Get-WslDistroList
    if ($SourceName -notin $distros) {
        throw "Source distribution '$SourceName' does not exist."
    }

    # Check if target name already exists
    if ($TargetName -in $distros) {
        throw "Distribution '$TargetName' already exists."
    }

    # Set default install path if not provided
    if ([string]::IsNullOrWhiteSpace($InstallPath)) {
        $InstallPath = Join-Path $env:USERPROFILE "wsl\$TargetName"
    }

    # Create temp tar file path
    $tempTarFile = Join-Path $env:TEMP "wsl-clone-$([Guid]::NewGuid().ToString()).tar"

    if ($PSCmdlet.ShouldProcess($SourceName, "Clone WSL distribution to $TargetName")) {
        try {
            Write-Output "Cloning WSL distribution '$SourceName' to '$TargetName'..."

            # Create install directory if it doesn't exist
            if (-not (Test-Path $InstallPath)) {
                New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
            }

            # Export source distribution
            Write-Output "Exporting '$SourceName'..."
            Invoke-CommandLine -CommandLine "wsl --export $SourceName `"$tempTarFile`""

            # Import as new distribution
            Write-Output "Importing as '$TargetName'..."
            Invoke-CommandLine -CommandLine "wsl --import $TargetName `"$InstallPath`" `"$tempTarFile`""

            Write-Output "Successfully cloned '$SourceName' to '$TargetName'."
            Write-Output ""
            Write-Output "To start: wsl -d $TargetName"
        }
        finally {
            # Clean up temp file
            if (Test-Path $tempTarFile) {
                Remove-Item -Path $tempTarFile -Force
            }
        }
    }
}

function Invoke-WslDistroCommand {
    <#
    .SYNOPSIS
        Executes a command inside a WSL distribution.

    .DESCRIPTION
        Runs a command within a specified WSL distribution using bash.
        Provides consistent error handling and output capture.

    .PARAMETER DistroName
        The name of the WSL distribution in which to execute the command.

    .PARAMETER Command
        The command to execute inside the distribution.

    .PARAMETER StopAtError
        If $true (default), throws an error when the command fails (non-zero exit code).
        If $false, continues execution and returns the output.

    .PARAMETER PrintCommand
        If $true (default), prints the command being executed.
        If $false, executes silently without printing the command.

    .OUTPUTS
        System.String
        Returns the command output.

    .EXAMPLE
        Invoke-WslDistroCommand -DistroName "Debian" -Command "echo hello"
        Executes "echo hello" inside the Debian distribution.

    .EXAMPLE
        Invoke-WslDistroCommand -DistroName "Ubuntu" -Command "apt update" -PrintCommand $false
        Updates package lists silently without printing the command.

    .EXAMPLE
        $output = Invoke-WslDistroCommand -DistroName "Debian" -Command 'grep "^ID=" /etc/os-release'
        Captures the output of a command for further processing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [bool]$StopAtError = $true,

        [Parameter(Mandatory = $false)]
        [bool]$PrintCommand = $true
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        throw "Distribution '$DistroName' does not exist."
    }

    # Escape double quotes in the command (need to double the backslash for proper escaping)
    $escapedCommand = $Command -replace '"', '\\"'

    # Build the WSL command
    $wslCommand = "wsl -d $DistroName -e bash -c `"$escapedCommand`""

    # Execute the command
    $result = Invoke-CommandLine -CommandLine $wslCommand -StopAtError $StopAtError -PrintCommand $PrintCommand

    return $result
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

    # Read ID field from /etc/os-release
    $command = 'grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d \"'
    $result = Invoke-WslDistroCommand -DistroName $DistroName -Command $command -PrintCommand $false -StopAtError $false

    # Clean up output (trim whitespace, remove quotes, convert to lowercase)
    $distroId = $result.Trim().Trim('"').ToLower()

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

function Update-WslDistro {
    <#
    .SYNOPSIS
        Updates packages in a Debian/Ubuntu WSL distribution.

    .DESCRIPTION
        Runs apt update and apt upgrade in a Debian or Ubuntu distribution.
        Only supports Debian and Ubuntu distributions.

    .PARAMETER Name
        The name of the WSL distribution to update.

    .EXAMPLE
        Update-WslDistro -Name "Debian"
        Updates all packages in the Debian distribution.

    .EXAMPLE
        Update-WslDistro -Name "Ubuntu-22.04" -Confirm:$false
        Updates Ubuntu 22.04 without prompting for confirmation.

    .NOTES
        This function only works with Debian and Ubuntu distributions.
        For other distributions, you must use the appropriate package manager manually.
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

    # Check if distribution exists
    $distros = Get-WslDistroList
    if ($Name -notin $distros) {
        throw "Distribution '$Name' does not exist."
    }

    # Detect distribution type
    $distroType = Get-WslDistroType -DistroName $Name

    # Validate it's Debian or Ubuntu
    if ($distroType -notin @("debian", "ubuntu")) {
        throw "Distribution '$Name' is not a Debian/Ubuntu distribution. Only Debian and Ubuntu distributions are supported for updates."
    }

    if ($PSCmdlet.ShouldProcess($Name, "Update WSL distribution packages")) {
        Write-Output "Updating WSL distribution '$Name'..."

        # Execute apt update && apt upgrade
        $updateCommand = "sudo apt update && sudo apt upgrade -y"
        Invoke-WslDistroCommand -DistroName $Name -Command $updateCommand

        Write-Output "Successfully updated '$Name'."
    }
}
