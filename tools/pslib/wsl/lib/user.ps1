<#
.DESCRIPTION
    WSL user management functions for creating users, querying default users,
    and checking systemd configuration in wsl.conf.
#>

# Source dependencies
. "$PSScriptRoot\..\..\utils\utils.ps1"

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
