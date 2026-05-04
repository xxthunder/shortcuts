<#
.DESCRIPTION
    WSL user management functions for creating users and querying default users.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

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

        The distribution is automatically terminated after creation so the default user
        change takes effect on the next launch.

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
        The distribution is automatically terminated after user creation so wsl.conf
        changes (default user, systemd) take effect on the next launch.
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

    # Trim inputs
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
    Assert-WslDistroExists -DistroName $DistroName

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

        # Build sections to configure
        $sectionsToSet = @{
            user = @{default = $Username }
        }

        if ($systemdRunning) {
            # If systemd is running, ensure it's configured in wsl.conf
            $sectionsToSet.boot = @{systemd = "true" }
        }

        # Update wsl.conf using Set-WslConf to preserve existing sections
        Set-WslConf -DistroName $DistroName -Sections $sectionsToSet -Confirm:$false

        # Restart the distribution to apply wsl.conf changes (especially systemd)
        Write-Output "Restarting distribution to apply wsl.conf changes ..."
        Stop-WslDistro -Name $DistroName -Confirm:$false | Out-Null

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

    # Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

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
