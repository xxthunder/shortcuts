<#
.DESCRIPTION
    Utility methods for WSL (Windows Subsystem for Linux) operations.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

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
        Queries 'wsl.exe --list --online' to get available distributions.
        Uses language-independent parsing to work on systems with any locale.

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
        # Get available distributions
        $output = wsl.exe --list --online 2>&1

        # Parse output using pattern matching (language-independent)
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
        Installs a new WSL distribution using the 'wsl.exe --install -d' command.
        Supports any distribution available through 'wsl.exe --list --online'.
        Dynamically validates against available distributions.
        Requires WSL to be installed on the system.

    .PARAMETER Name
        The name of the distribution to create (e.g., Ubuntu-22.04, Debian, kali-linux).
        Must match one of the distributions returned by 'wsl.exe --list --online'.

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
        $errorMsg += "`nRun 'wsl.exe --list --online' to see all available distributions."
        throw $errorMsg
    }

    # Check if distribution already exists
    $installedDistros = Get-WslDistroList
    if ($Name -in $installedDistros) {
        throw "Distribution '$Name' already exists."
    }

    if ($PSCmdlet.ShouldProcess($Name, "Create WSL distribution")) {
        Write-Output "Creating WSL distribution '$Name' ..."
        Invoke-CommandLine -CommandLine "wsl.exe --install --distribution $Name --no-launch"
        Write-Output "Successfully created '$Name'."
        Write-Output ""
        Write-Output "To start: wsl.exe --distribution $Name"
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

function Remove-WslDistro {
    <#
    .SYNOPSIS
        Removes an existing WSL distribution.

    .DESCRIPTION
        Unregisters a WSL distribution using the 'wsl.exe --unregister' command.
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

    # Check if distribution is running (must be stopped for removal)
    if (Test-WslDistroRunning -DistroName $Name) {
        throw "Distribution '$Name' is running. Stop it first with: wsl --terminate $Name"
    }

    # Ask for confirmation using ShouldProcess
    if ($PSCmdlet.ShouldProcess($Name, "Remove WSL distribution")) {
        Write-Output "Removing WSL distribution '$Name' ..."
        Invoke-CommandLine -CommandLine "wsl.exe --unregister $Name"
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

    # Check if source distribution is running (must be stopped for export)
    if (Test-WslDistroRunning -DistroName $SourceName) {
        throw "Distribution '$SourceName' is running. Stop it first with: wsl --terminate $SourceName"
    }

    # Set default install path if not provided
    if ([string]::IsNullOrWhiteSpace($InstallPath)) {
        $InstallPath = Join-Path $env:USERPROFILE "wsl\$TargetName"
    }

    # Create temp tar file path
    $tempTarFile = Join-Path $env:TEMP "wsl-clone-$([Guid]::NewGuid().ToString()).tar"

    if ($PSCmdlet.ShouldProcess($SourceName, "Clone WSL distribution to $TargetName")) {
        try {
            Write-Output "Cloning WSL distribution '$SourceName' to '$TargetName' ..."

            # Create install directory if it doesn't exist
            if (-not (Test-Path $InstallPath)) {
                New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
            }

            # Export source distribution
            Write-Output "Exporting '$SourceName' ..."
            Invoke-CommandLine -CommandLine "wsl.exe --export $SourceName `"$tempTarFile`""

            # Import as new distribution
            Write-Output "Importing as '$TargetName' ..."
            Invoke-CommandLine -CommandLine "wsl.exe --import $TargetName `"$InstallPath`" `"$tempTarFile`""

            Write-Output "Successfully cloned '$SourceName' to '$TargetName'."
            Write-Output ""
            Write-Output "To start: wsl.exe --distribution $TargetName"
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
        Provides consistent error handling. By default, output flows to the console
        in real-time. Use -PassThru to capture and return the output as a string.

    .PARAMETER DistroName
        The name of the WSL distribution in which to execute the command.

    .PARAMETER Command
        The command to execute inside the distribution.

    .PARAMETER StopAtError
        If $true (default), throws an error when the command fails (non-zero exit code).
        If $false, continues execution.

    .PARAMETER PrintCommand
        If $true (default), prints the command being executed.
        If $false, executes silently without printing the command.

    .PARAMETER Silent
        If $true, suppresses command output display.
        If $false (default), displays output in real-time.

    .PARAMETER PassThru
        If specified, captures and returns the command output as a string.
        If not specified (default), output flows to console in real-time.

    .OUTPUTS
        System.String (only when -PassThru is specified)
        Returns the command output as a joined string when -PassThru is used.

    .EXAMPLE
        Invoke-WslDistroCommand -DistroName "Debian" -Command "apt update"
        Executes "apt update" with real-time console output.

    .EXAMPLE
        Invoke-WslDistroCommand -DistroName "Ubuntu" -Command "apt update" -PrintCommand $false
        Updates package lists without printing the command, output flows to console.

    .EXAMPLE
        $output = Invoke-WslDistroCommand -DistroName "Debian" -Command 'grep "^ID=" /etc/os-release' -PassThru
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
        [bool]$PrintCommand = $true,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        throw "Distribution '$DistroName' does not exist."
    }

    # Escape double quotes for bash and dollar signs for PowerShell
    # We use double quotes around the command to allow bash variable expansion (e.g., $ID from /etc/os-release)
    # But we need to escape $ for PowerShell so it doesn't try to expand bash variables
    $escapedCommand = $Command.Replace('"', '\"').Replace('$', '`$')

    # Build the WSL command using expandable string with backtick-escaped command
    # The backticks in $escapedCommand will protect bash variables from PowerShell expansion
    $wslCommand = "wsl.exe --distribution $DistroName --exec bash -c `"$escapedCommand`""

    # Execute the command - capture output only if -PassThru is specified
    if ($PassThru) {
        $capturedOutput = Invoke-CommandLine -CommandLine $wslCommand -StopAtError $StopAtError -PrintCommand $PrintCommand -Silent $Silent

        # Return captured output as a joined string
        if ($capturedOutput) {
            return ($capturedOutput -join "`n")
        }
    }
    else {
        # Let output flow to console in real-time, don't return it
        Invoke-CommandLine -CommandLine $wslCommand -StopAtError $StopAtError -PrintCommand $PrintCommand -Silent $Silent
    }
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

    # Check if distribution is running (must be stopped for update)
    if (Test-WslDistroRunning -DistroName $Name) {
        throw "Distribution '$Name' is running. Stop it first with: wsl --terminate $Name"
    }

    # Detect distribution type
    $distroType = Get-WslDistroType -DistroName $Name

    # Validate it's Debian or Ubuntu
    if ($distroType -notin @("debian", "ubuntu")) {
        throw "Distribution '$Name' is not a Debian/Ubuntu distribution. Only Debian and Ubuntu distributions are supported for updates."
    }

    if ($PSCmdlet.ShouldProcess($Name, "Update WSL distribution packages")) {
        Write-Output "Updating WSL distribution '$Name' ..."

        # Execute apt update, upgrade, autoremove, and autoclean
        $updateCommand = "sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean"
        Invoke-WslDistroCommand -DistroName $Name -Command $updateCommand

        Write-Output "Successfully updated '$Name'."
    }
}

function New-WslUser {
    <#
    .SYNOPSIS
        Creates a new user in a WSL distribution with sudo privileges.

    .DESCRIPTION
        Creates a new user account in a WSL distribution with the following configuration:
        - Creates user with home directory
        - Sets user password
        - Adds user to sudo group
        - Configures passwordless sudo (NOPASSWD)
        - Sets user as default user in wsl.conf

        After creation, the distribution must be restarted with 'wsl.exe --terminate <DistroName>'
        for the default user change to take effect.

    .PARAMETER DistroName
        The name of the WSL distribution where the user will be created.

    .PARAMETER Username
        The username to create. Must start with a lowercase letter or underscore,
        contain only lowercase letters, numbers, underscores, and hyphens,
        and be 32 characters or less.

    .PARAMETER Password
        The password for the new user. Can be a plain text string or SecureString.

    .EXAMPLE
        New-WslUser -DistroName "Debian" -Username "john" -Password "mypassword"
        Creates a user named 'john' in the Debian distribution.

    .EXAMPLE
        $securePass = Read-Host -AsSecureString -Prompt "Enter password"
        New-WslUser -DistroName "Ubuntu" -Username "developer" -Password $securePass -Confirm:$false
        Creates a user with a securely entered password without confirmation prompt.

    .NOTES
        The distribution must be restarted after user creation:
        wsl.exe --terminate <DistroName>
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Function accepts both SecureString and plain text for flexibility. SecureString is handled internally.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Password parameter accepts both SecureString and String. SecureString is properly converted internally.')]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Password
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Trim inputs
    $DistroName = $DistroName.Trim()
    $Username = $Username.Trim()

    # Validate username pattern BEFORE checking distribution (must start with lowercase letter or underscore, contain only lowercase, numbers, underscore, hyphen)
    # Use -cnotmatch for case-sensitive matching
    if ($Username -cnotmatch '^[a-z_][a-z0-9_-]*$') {
        throw "Invalid username '$Username'. Username must start with a lowercase letter or underscore and contain only lowercase letters, numbers, underscores, and hyphens."
    }

    # Validate username length (max 32 characters)
    if ($Username.Length -gt 32) {
        throw "Username '$Username' is too long. Maximum length is 32 characters."
    }

    # Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        throw "Distribution '$DistroName' does not exist."
    }

    # Convert SecureString to plain text if needed
    $plainPassword = if ($Password -is [SecureString]) {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    else {
        $Password
    }

    if ($PSCmdlet.ShouldProcess("$Username in $DistroName", "Create WSL user")) {
        # Check if user already exists
        $checkUserCmd = "id -u $Username 2>/dev/null"
        $userExists = Invoke-WslDistroCommand -DistroName $DistroName -Command $checkUserCmd -PrintCommand $false -StopAtError $false -PassThru

        if (-not [string]::IsNullOrWhiteSpace($userExists)) {
            throw "User '$Username' already exists in distribution '$DistroName'."
        }

        Write-Output "User '$Username' does not exist in distribution '$DistroName'. Creating user ..."

        # Step 1: Create user with home directory
        $createUserCmd = "sudo useradd -m -s /bin/bash $Username"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $createUserCmd

        # Step 2: Set password
        # Use single quotes in bash to avoid escaping issues across PowerShell versions
        $setPasswordCmd = "echo '${Username}:${plainPassword}' | sudo chpasswd"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $setPasswordCmd -PrintCommand $false -Silent $true

        # Step 3: Add user to sudo group
        $addSudoCmd = "sudo usermod -aG sudo $Username"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $addSudoCmd

        # Step 4: Configure NOPASSWD in sudoers.d
        # Use single quotes around echo content to avoid PowerShell interpretation issues
        # PowerShell will expand $Username before passing to bash
        $sudoersCmd = "echo '$Username ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$Username > /dev/null && sudo chmod 0440 /etc/sudoers.d/$Username"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $sudoersCmd -PrintCommand $false -Silent $true

        # Warn user about NOPASSWD sudo security implications
        Write-Warning @"
NOPASSWD sudo has been configured for user '$Username' in distribution '$DistroName'.

This allows running commands as root without password prompt. This is convenient for development environments but reduces security.

For production systems, consider:
- Limiting NOPASSWD to specific commands only
- Requiring password for sensitive operations
- Using role-based access controls
"@

        # Step 5: Set default user in wsl.conf and ensure systemd is configured
        # Check if systemd is running
        $systemdRunning = Test-WslSystemd -DistroName $DistroName

        # Build wsl.conf content
        if ($systemdRunning) {
            # If systemd is running, ensure it's configured in wsl.conf
            $wslConfContent = "[boot]`nsystemd=true`n`n[user]`ndefault=$Username"
        }
        else {
            # Just set the user
            $wslConfContent = "[user]`ndefault=$Username"
        }

        # Write to wsl.conf
        $wslConfCmd = "echo '$wslConfContent' | sudo tee /etc/wsl.conf > /dev/null"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $wslConfCmd -PrintCommand $false -Silent $true

        # Restart the distribution to apply wsl.conf changes (especially systemd)
        Write-Output "Restarting distribution to apply wsl.conf changes ..."
        wsl.exe --terminate $DistroName
        Start-Sleep -Seconds 2

        Write-Output "Successfully created user '$Username' in '$DistroName'."
    }
}

function Get-WslDefaultUser {
    <#
    .SYNOPSIS
        Reads the default user from a WSL distribution's wsl.conf file.

    .DESCRIPTION
        Reads the /etc/wsl.conf file in a WSL distribution and extracts the default
        user configured in the [user] section. Returns the username if configured,
        or $null if wsl.conf doesn't exist or no default user is set.

    .PARAMETER DistroName
        The name of the WSL distribution to query.

    .OUTPUTS
        System.String
        Returns the default username, or $null if not configured.

    .EXAMPLE
        $user = Get-WslDefaultUser -DistroName "Debian"
        if ($user) {
            Write-Host "Default user: $user"
        } else {
            Write-Host "No default user configured"
        }

    .NOTES
        This function is used to check if a distribution has been configured with
        a default user (typically via New-WslUser or manual wsl.conf editing).
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

    # Try to read wsl.conf
    try {
        $wslConfContent = Invoke-WslDistroCommand -DistroName $DistroName -Command "cat /etc/wsl.conf" -StopAtError $false -PrintCommand $false -PassThru

        # If command failed or returned empty, wsl.conf doesn't exist or is empty
        if ([string]::IsNullOrWhiteSpace($wslConfContent)) {
            return $null
        }

        # Parse the content to find [user] section and default= line
        $inUserSection = $false
        $lines = $wslConfContent -split "`n"

        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()

            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith('#')) {
                continue
            }

            # Check for [user] section
            if ($trimmedLine -match '^\[user\]') {
                $inUserSection = $true
                continue
            }

            # Check for new section (stop looking in [user])
            if ($trimmedLine -match '^\[.*\]') {
                $inUserSection = $false
                continue
            }

            # If in [user] section, look for default= line
            if ($inUserSection -and $trimmedLine -match '^default\s*=\s*(.+)$') {
                $username = $matches[1].Trim()
                return $username
            }
        }

        # No default user found
        return $null
    }
    catch {
        # wsl.conf doesn't exist or other error - return null
        return $null
    }
}

function Test-WslSystemdConfigured {
    <#
    .SYNOPSIS
        Checks if systemd is configured in a WSL distribution's wsl.conf file.

    .DESCRIPTION
        Reads the /etc/wsl.conf file in a WSL distribution and checks if systemd
        is enabled in the [boot] section. Returns $true if systemd=true is configured,
        or $false if wsl.conf doesn't exist, [boot] section is missing, or systemd
        is not set to true.

    .PARAMETER DistroName
        The name of the WSL distribution to query.

    .OUTPUTS
        System.Boolean
        Returns $true if systemd=true is configured, $false otherwise.

    .EXAMPLE
        $configured = Test-WslSystemdConfigured -DistroName "Debian"
        if ($configured) {
            Write-Host "Systemd is configured"
        } else {
            Write-Host "Systemd is not configured in wsl.conf"
        }

    .NOTES
        This function only checks the configuration in wsl.conf. Use Test-WslSystemd
        to check if systemd is actually running. Both checks may be needed:
        - Test-WslSystemdConfigured: Checks wsl.conf configuration
        - Test-WslSystemd: Checks if systemd is actually running
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

    # Try to read wsl.conf
    try {
        $wslConfContent = Invoke-WslDistroCommand -DistroName $DistroName -Command "cat /etc/wsl.conf" -StopAtError $false -PrintCommand $false -PassThru

        # If command failed or returned empty, wsl.conf doesn't exist or is empty
        if ([string]::IsNullOrWhiteSpace($wslConfContent)) {
            return $false
        }

        # Parse the content to find [boot] section and systemd=true line
        $inBootSection = $false
        $lines = $wslConfContent -split "`n"

        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()

            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith('#')) {
                continue
            }

            # Check for [boot] section
            if ($trimmedLine -match '^\[boot\]') {
                $inBootSection = $true
                continue
            }

            # Check for new section (stop looking in [boot])
            if ($trimmedLine -match '^\[.*\]') {
                $inBootSection = $false
                continue
            }

            # If in [boot] section, look for systemd=true line
            if ($inBootSection -and $trimmedLine -match '^systemd\s*=\s*(.+)$') {
                $value = $matches[1].Trim().ToLower()
                return $value -eq "true"
            }
        }

        # No systemd=true found in [boot] section
        return $false
    }
    catch {
        # wsl.conf doesn't exist or other error - return false
        return $false
    }
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
        # 1. Remove old Docker versions
        Write-Information "  -> Removing old Docker versions"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get remove -y docker docker-engine docker.io containerd runc" -StopAtError $false -PrintCommand $false -Silent $true -PassThru | Out-Null

        # 2. Update and install prerequisites
        Write-Information "  -> Installing prerequisites"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get update" -PrintCommand $false -Silent $true -PassThru | Out-Null
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get install -y ca-certificates curl gnupg lsb-release" -PrintCommand $false -Silent $true -PassThru | Out-Null

        # 3. Add Docker's official GPG key
        Write-Information "  -> Adding Docker GPG key"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo mkdir -p /etc/apt/keyrings" -PrintCommand $false -Silent $true -PassThru | Out-Null

        # Get distribution info by sourcing /etc/os-release and echoing variables
        # Use backtick-escaped $ so PowerShell doesn't expand, but bash does (since we use double quotes in Invoke-WslDistroCommand)
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

        # Download and add Docker's GPG key
        $gpgUrl = "https://download.docker.com/linux/$distroId/gpg"
        $gpgCommand = "curl -fsSL $gpgUrl | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $gpgCommand -PrintCommand $false -Silent $true -PassThru | Out-Null

        # 4. Set up Docker repository
        Write-Information "  -> Configuring Docker repository"
        $repoUrl = "https://download.docker.com/linux/$distroId"
        $repoLine = "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] $repoUrl $distroCodename stable"
        $repoCommand = "echo '$repoLine' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $repoCommand -PrintCommand $false -Silent $true -PassThru | Out-Null

        # 5. Install Docker Engine
        Write-Information "  -> Installing Docker packages"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get update" -PrintCommand $false -Silent $true -PassThru | Out-Null
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" -PrintCommand $false -Silent $true -PassThru | Out-Null

        # 6. Add user to docker group
        Write-Information "  -> Adding user '$Username' to docker group"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo usermod -aG docker $Username" -PrintCommand $false -Silent $true -PassThru | Out-Null

        # 7. Enable and start Docker service
        Write-Information "  -> Enabling Docker service"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo systemctl enable docker" -PrintCommand $false -Silent $true -PassThru | Out-Null

        Write-Information "  -> Starting Docker service"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo systemctl start docker" -PrintCommand $false -Silent $true -PassThru | Out-Null

        # Post-installation verification
        Write-Information ""
        Write-Information "Verifying installation ..."

        # Check Docker Engine version
        Write-Information "  -> Checking Docker Engine version"
        $dockerVersion = Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo docker --version" -PrintCommand $false -PassThru
        Write-Information "    Docker Engine: $dockerVersion"

        # Check Docker Compose plugin version
        Write-Information "  -> Checking Docker Compose version"
        $composeVersion = Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo docker compose version" -PrintCommand $false -PassThru
        Write-Information "    Docker Compose: $composeVersion"

        # Check Docker service status
        Write-Information "  -> Checking Docker service status"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo systemctl status docker --no-pager" -PrintCommand $false -Silent $true -PassThru | Out-Null
        Write-Information "    Docker service: active (running)"

        # Run hello-world container (end-to-end test)
        Write-Information "  -> Running hello-world test"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo docker run hello-world" -PrintCommand $false -Silent $true -PassThru | Out-Null
        Write-Information "    Hello-world test: passed"

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
    catch {
        Write-Error "Docker installation failed: $_"
        return $false
    }
}
