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

    # Execute the command and capture output
    # Invoke-CommandLine displays output in real-time via Invoke-Expression
    # and returns the output to the pipeline for capture
    $capturedOutput = Invoke-CommandLine -CommandLine $wslCommand -StopAtError $StopAtError -PrintCommand $PrintCommand

    # Return captured output as a joined string
    if ($capturedOutput) {
        return ($capturedOutput -join "`n")
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
    Invoke-WslDistroCommand -DistroName $DistroName -Command "echo warmup" -PrintCommand $false -StopAtError $false | Out-Null

    # Read ID field from /etc/os-release using simpler command without complex quoting
    $command = 'cat /etc/os-release | grep ^ID= | head -1 | cut -d= -f2'
    $result = Invoke-WslDistroCommand -DistroName $DistroName -Command $command -PrintCommand $false -StopAtError $false

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

        After creation, the distribution must be restarted with 'wsl --terminate <DistroName>'
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
        wsl --terminate <DistroName>
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
        $userExists = Invoke-WslDistroCommand -DistroName $DistroName -Command $checkUserCmd -PrintCommand $false -StopAtError $false

        if (-not [string]::IsNullOrWhiteSpace($userExists)) {
            throw "User '$Username' already exists in distribution '$DistroName'."
        }

        Write-Output "Creating user '$Username' in distribution '$DistroName'..."

        # Step 1: Create user with home directory
        $createUserCmd = "sudo useradd -m -s /bin/bash $Username"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $createUserCmd

        # Step 2: Set password
        $setPasswordCmd = "echo `"$Username`:$plainPassword`" | sudo chpasswd"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $setPasswordCmd -PrintCommand $false

        # Step 3: Add user to sudo group
        $addSudoCmd = "sudo usermod -aG sudo $Username"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $addSudoCmd

        # Step 4: Configure NOPASSWD in sudoers.d
        # Use single quotes in bash to avoid PowerShell interpreting the parentheses
        $sudoersCmd = "echo '$Username ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$Username > /dev/null && sudo chmod 0440 /etc/sudoers.d/$Username"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $sudoersCmd -PrintCommand $false

        # Step 5: Set default user in wsl.conf
        # Use printf with literal strings to write both lines
        $wslConfCmd = "printf '`[user`]\n' | sudo tee /etc/wsl.conf > /dev/null && printf 'default=$Username\n' | sudo tee -a /etc/wsl.conf > /dev/null"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $wslConfCmd -PrintCommand $false

        Write-Output "Successfully created user '$Username' in '$DistroName'."
        Write-Output ""
        Write-Output "To apply the default user change, restart the distribution with:"
        Write-Output "  wsl --terminate $DistroName"
    }
}
