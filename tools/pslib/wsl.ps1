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
        Queries 'wsl.exe --list --online' to get available distributions.
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
        $output = wsl.exe --list --online 2>&1

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
        Write-Output "Creating WSL distribution '$Name'..."
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

    # Set locale to English for consistent output
    $originalLcAll = $env:LC_ALL
    $env:LC_ALL = "en_US.UTF-8"

    try {
        $distros = wsl.exe --list --quiet | ForEach-Object {
            # Clean up WSL output: remove null chars (UTF-16), carriage returns, and trim whitespace
            $_.Trim() -replace '\x00', '' -replace '\r', ''
        } | Where-Object { $_ -ne "" }

        if ($null -eq $distros) {
            return @()
        }

        return $distros
    }
    finally {
        # Restore original locale
        if ($null -ne $originalLcAll) {
            $env:LC_ALL = $originalLcAll
        }
        else {
            Remove-Item Env:\LC_ALL -ErrorAction SilentlyContinue
        }
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

    # Ask for confirmation using ShouldProcess
    if ($PSCmdlet.ShouldProcess($Name, "Remove WSL distribution")) {
        Write-Output "Removing WSL distribution '$Name'..."
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
            Invoke-CommandLine -CommandLine "wsl.exe --export $SourceName `"$tempTarFile`""

            # Import as new distribution
            Write-Output "Importing as '$TargetName'..."
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

    .PARAMETER Silent
        If $true, suppresses command output display (but still returns it).
        If $false (default), displays output in real-time.

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
        [bool]$PrintCommand = $true,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false
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

    # Execute the command and capture output
    $capturedOutput = Invoke-CommandLine -CommandLine $wslCommand -StopAtError $StopAtError -PrintCommand $PrintCommand -Silent $Silent

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
    Invoke-WslDistroCommand -DistroName $DistroName -Command "echo warmup" -PrintCommand $false -StopAtError $false -Silent $true | Out-Null

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
        $userExists = Invoke-WslDistroCommand -DistroName $DistroName -Command $checkUserCmd -PrintCommand $false -StopAtError $false -Silent $true

        if (-not [string]::IsNullOrWhiteSpace($userExists)) {
            throw "User '$Username' already exists in distribution '$DistroName'."
        }

        Write-Output "Creating user '$Username' in distribution '$DistroName'..."

        # Step 1: Create user with home directory
        $createUserCmd = "sudo useradd -m -s /bin/bash $Username"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $createUserCmd

        # Step 2: Set password
        $setPasswordCmd = "echo `"$Username`:$plainPassword`" | sudo chpasswd"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $setPasswordCmd -PrintCommand $false -Silent $true

        # Step 3: Add user to sudo group
        $addSudoCmd = "sudo usermod -aG sudo $Username"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $addSudoCmd

        # Step 4: Configure NOPASSWD in sudoers.d
        # Use single quotes around echo content to avoid PowerShell interpretation issues
        # PowerShell will expand $Username before passing to bash
        $sudoersCmd = "echo '$Username ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/$Username > /dev/null && sudo chmod 0440 /etc/sudoers.d/$Username"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $sudoersCmd -PrintCommand $false -Silent $true

        # Step 5: Set default user in wsl.conf
        # Use single quotes around echo content
        $wslConfCmd = "echo '[user]' | sudo tee /etc/wsl.conf > /dev/null && echo 'default=$Username' | sudo tee -a /etc/wsl.conf > /dev/null"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $wslConfCmd -PrintCommand $false -Silent $true

        Write-Output "Successfully created user '$Username' in '$DistroName'."
        Write-Output ""
        Write-Output "To apply the default user change, restart the distribution with:"
        Write-Output "  wsl.exe --terminate $DistroName"
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
        $wslConfContent = Invoke-WslDistroCommand -DistroName $DistroName -Command "cat /etc/wsl.conf" -StopAtError $false -PrintCommand $false

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
        $output = Invoke-WslDistroCommand -DistroName $DistroName -Command "systemctl --version" -StopAtError $false -PrintCommand $false

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

    # Set locale to English for consistent output
    $originalLcAll = $env:LC_ALL
    $env:LC_ALL = "en_US.UTF-8"

    try {
        # Get WSL version list
        $output = wsl.exe --list --verbose

        # Parse the output to find the distribution and its version
        $lines = $output -split "`n"
        foreach ($line in $lines) {
            # Clean up line (remove null chars, carriage returns, asterisk, trim)
            $cleanLine = $line -replace '\x00', '' -replace '\r', '' -replace '\*', '' | ForEach-Object { $_.Trim() }

            # Skip empty lines and headers
            if ([string]::IsNullOrWhiteSpace($cleanLine) -or $cleanLine -match '^NAME\s+STATE\s+VERSION') {
                continue
            }

            # Split by whitespace to get fields
            $fields = $cleanLine -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

            # Need at least 3 fields: NAME, STATE, VERSION
            if ($fields.Count -ge 3) {
                $name = $fields[0]
                $version = $fields[2]

                # Check if this is our distribution
                if ($name -eq $DistroName) {
                    if ($version -eq "2") {
                        return $true
                    }
                    else {
                        return $false
                    }
                }
            }
        }

        # Distribution not found in output (shouldn't happen since we validated existence)
        return $false
    }
    finally {
        # Restore original locale
        if ($null -ne $originalLcAll) {
            $env:LC_ALL = $originalLcAll
        }
        else {
            Remove-Item Env:\LC_ALL -ErrorAction SilentlyContinue
        }
    }
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
        $output = Invoke-WslDistroCommand -DistroName $DistroName -Command "docker --version" -StopAtError $false -PrintCommand $false

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

    # 4. Check systemd support
    if (-not (Test-WslSystemd -DistroName $DistroName)) {
        throw @"
Distribution '$DistroName' does not support systemd.
Docker Engine requires systemd for service management.
Enable systemd in /etc/wsl.conf:
  [boot]
  systemd=true

Then restart the distribution:
  wsl.exe --terminate $DistroName
  wsl.exe --distribution $DistroName
"@
    }

    # 5. Check distribution type (Debian/Ubuntu only)
    $distroType = Get-WslDistroType -DistroName $DistroName
    if ($distroType -notin @("debian", "ubuntu")) {
        throw "Distribution '$DistroName' is not a Debian or Ubuntu distribution (detected: $distroType). Only Debian and Ubuntu distributions are currently supported for Docker setup."
    }

    # 6. Detect or validate username
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

    # 7. Check if Docker already installed
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

    Write-Information "Installing Docker Engine in '$DistroName'..."

    # Docker installation workflow

    try {
        # 1. Remove old Docker versions
        Write-Information "  -> Removing old Docker versions"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get remove -y docker docker-engine docker.io containerd runc" -StopAtError $false -PrintCommand $false -Silent $true | Out-Null

        # 2. Update and install prerequisites
        Write-Information "  -> Installing prerequisites"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get update" -PrintCommand $false -Silent $true | Out-Null
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get install -y ca-certificates curl gnupg lsb-release" -PrintCommand $false -Silent $true | Out-Null

        # 3. Add Docker's official GPG key
        Write-Information "  -> Adding Docker GPG key"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo mkdir -p /etc/apt/keyrings" -PrintCommand $false -Silent $true | Out-Null

        # Get distribution info by sourcing /etc/os-release and echoing variables
        # Use backtick-escaped $ so PowerShell doesn't expand, but bash does (since we use double quotes in Invoke-WslDistroCommand)
        $getDistroInfoCmd = ". /etc/os-release && echo `$ID && echo `$VERSION_CODENAME && dpkg --print-architecture"
        $distroInfo = Invoke-WslDistroCommand -DistroName $DistroName -Command $getDistroInfoCmd -PrintCommand $false
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
        Invoke-WslDistroCommand -DistroName $DistroName -Command $gpgCommand -PrintCommand $false -Silent $true | Out-Null

        # 4. Set up Docker repository
        Write-Information "  -> Configuring Docker repository"
        $repoUrl = "https://download.docker.com/linux/$distroId"
        $repoLine = "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.gpg] $repoUrl $distroCodename stable"
        $repoCommand = "echo '$repoLine' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $repoCommand -PrintCommand $false -Silent $true | Out-Null

        # 5. Install Docker Engine
        Write-Information "  -> Installing Docker packages"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get update" -PrintCommand $false -Silent $true | Out-Null
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" -PrintCommand $false -Silent $true | Out-Null

        # 6. Add user to docker group
        Write-Information "  -> Adding user '$Username' to docker group"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo usermod -aG docker $Username" -PrintCommand $false -Silent $true | Out-Null

        # 7. Enable and start Docker service
        Write-Information "  -> Enabling Docker service"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo systemctl enable docker" -PrintCommand $false -Silent $true | Out-Null

        Write-Information "  -> Starting Docker service"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo systemctl start docker" -PrintCommand $false -Silent $true | Out-Null

        # Post-installation verification
        Write-Information ""
        Write-Information "Verifying installation..."

        # Check Docker Engine version
        Write-Information "  -> Checking Docker Engine version"
        $dockerVersion = Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo docker --version" -PrintCommand $false
        Write-Information "    Docker Engine: $dockerVersion"

        # Check Docker Compose plugin version
        Write-Information "  -> Checking Docker Compose version"
        $composeVersion = Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo docker compose version" -PrintCommand $false
        Write-Information "    Docker Compose: $composeVersion"

        # Check Docker service status
        Write-Information "  -> Checking Docker service status"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo systemctl status docker --no-pager" -PrintCommand $false -Silent $true | Out-Null
        Write-Information "    Docker service: active (running)"

        # Run hello-world container (end-to-end test)
        Write-Information "  -> Running hello-world test"
        Invoke-WslDistroCommand -DistroName $DistroName -Command "sudo docker run hello-world" -PrintCommand $false -Silent $true | Out-Null
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
