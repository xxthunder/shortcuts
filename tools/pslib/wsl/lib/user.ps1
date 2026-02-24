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
        wsl.exe --terminate $DistroName
        Start-Sleep -Seconds 2

        Write-Output "Successfully created user '$Username' in '$DistroName'."
    }
}

function Set-WslConf {
    <#
    .SYNOPSIS
        Sets configuration values in a WSL distribution's wsl.conf file by merging sections.

    .DESCRIPTION
        Reads the existing /etc/wsl.conf file (if it exists), merges new configuration
        sections with existing ones, and writes the result back. Existing sections and
        keys not specified in the Sections parameter are preserved.

        This function:
        - Preserves comments and unmodified sections
        - Creates backup of existing wsl.conf before modification
        - Merges new settings with existing configuration
        - Overwrites values for keys that are specified

    .PARAMETER DistroName
        The name of the WSL distribution to configure.

    .PARAMETER Sections
        A hashtable of sections to merge. Each key is a section name (e.g., 'boot', 'user')
        and each value is a hashtable of key-value pairs for that section.

    .EXAMPLE
        Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true"}}
        Sets systemd=true in the [boot] section, preserving other sections.

    .EXAMPLE
        Set-WslConf -DistroName "Debian" -Sections @{
            boot = @{systemd = "true"}
            interop = @{enabled = "true"; appendWindowsPath = "true"}
        }
        Configures multiple sections at once.

    .NOTES
        A backup is created at /etc/wsl.conf.backup.TIMESTAMP if wsl.conf exists.
        The distribution should be restarted after configuration changes.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$Sections
    )

    # Trim input
    $DistroName = $DistroName.Trim()

    # Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        throw "Distribution '$DistroName' does not exist."
    }

    # Validate at least one section provided
    if ($Sections.Count -eq 0) {
        throw "At least one section must be provided."
    }

    if ($PSCmdlet.ShouldProcess("/etc/wsl.conf in $DistroName", "Merge configuration sections")) {
        # Read existing wsl.conf
        $existingContent = ""
        $wslConfExists = $false
        try {
            $existingContent = Invoke-WslDistroCommand -DistroName $DistroName -Command "cat /etc/wsl.conf" -StopAtError $false -PrintCommand $false -PassThru
            if (-not [string]::IsNullOrWhiteSpace($existingContent)) {
                $wslConfExists = $true
            }
        }
        catch {
            # wsl.conf doesn't exist - will create new (expected error, not a problem)
            Write-Verbose "wsl.conf does not exist yet, will create new file"
        }

        # Parse existing content into hashtable structure
        $existingSections = @{}
        $existingComments = @()
        $sectionComments = @{}  # Track comments for each section
        if ($wslConfExists) {
            $currentSection = $null
            $currentSectionComments = @()
            $lines = $existingContent -split "`n"

            foreach ($line in $lines) {
                $trimmedLine = $line.Trim()

                # Preserve comments at file level (before first section)
                if ($null -eq $currentSection -and ($trimmedLine.StartsWith('#') -or [string]::IsNullOrWhiteSpace($trimmedLine))) {
                    $existingComments += $line
                    continue
                }

                # Collect comments within sections
                if ($trimmedLine.StartsWith('#')) {
                    $currentSectionComments += $line
                    continue
                }

                # Skip empty lines within sections
                if ([string]::IsNullOrWhiteSpace($trimmedLine)) {
                    continue
                }

                # Check for section header
                if ($trimmedLine -match '^\[([^\]]+)\]') {
                    $currentSection = $matches[1].Trim().ToLower()
                    if (-not $existingSections.ContainsKey($currentSection)) {
                        $existingSections[$currentSection] = @{}
                        $sectionComments[$currentSection] = @()
                    }
                    # Add any comments that were before this section
                    if ($currentSectionComments.Count -gt 0) {
                        $sectionComments[$currentSection] += $currentSectionComments
                        $currentSectionComments = @()
                    }
                    continue
                }

                # Parse key=value within a section
                if ($null -ne $currentSection -and $trimmedLine -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    # Add any comments that were before this key
                    if ($currentSectionComments.Count -gt 0) {
                        $sectionComments[$currentSection] += $currentSectionComments
                        $currentSectionComments = @()
                    }
                    $existingSections[$currentSection][$key] = $value
                }
            }
        }

        # Merge new sections with existing
        foreach ($sectionName in $Sections.Keys) {
            $sectionNameLower = $sectionName.ToLower()
            if (-not $existingSections.ContainsKey($sectionNameLower)) {
                $existingSections[$sectionNameLower] = @{}
            }

            foreach ($key in $Sections[$sectionName].Keys) {
                $existingSections[$sectionNameLower][$key] = $Sections[$sectionName][$key]
            }
        }

        # Build new wsl.conf content
        $newContent = ""

        # Add preserved comments
        if ($existingComments.Count -gt 0) {
            $newContent = ($existingComments -join "`n") + "`n`n"
        }

        # Write sections
        $sectionNames = $existingSections.Keys | Sort-Object
        foreach ($sectionName in $sectionNames) {
            # Add section comments if any
            if ($sectionComments.ContainsKey($sectionName) -and $sectionComments[$sectionName].Count -gt 0) {
                foreach ($comment in $sectionComments[$sectionName]) {
                    $newContent += "$comment`n"
                }
            }
            $newContent += "[$sectionName]`n"
            $keys = $existingSections[$sectionName].Keys | Sort-Object
            foreach ($key in $keys) {
                $value = $existingSections[$sectionName][$key]
                $newContent += "$key=$value`n"
            }
            $newContent += "`n"
        }

        # Create backup if wsl.conf exists
        if ($wslConfExists) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $backupCmd = "sudo cp /etc/wsl.conf /etc/wsl.conf.backup.$timestamp"
            Invoke-WslDistroCommand -DistroName $DistroName -Command $backupCmd -PrintCommand $false -Silent $true
            Write-Information "Created backup: /etc/wsl.conf.backup.$timestamp"
        }

        # Write new wsl.conf
        $escapedContent = $newContent -replace "'", "'\\''"
        $writeCmd = "echo '$escapedContent' | sudo tee /etc/wsl.conf > /dev/null"
        Invoke-WslDistroCommand -DistroName $DistroName -Command $writeCmd -PrintCommand $false -Silent $true

        Write-Information "Successfully updated /etc/wsl.conf in '$DistroName'."
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

function Test-WslInteropConfigured {
    <#
    .SYNOPSIS
        Checks if Windows interop is configured in a WSL distribution's wsl.conf file.

    .DESCRIPTION
        Reads the /etc/wsl.conf file in a WSL distribution and checks if Windows interop
        is enabled in the [interop] section. Returns $true if both enabled=true and
        appendWindowsPath=true are configured, or $false if wsl.conf doesn't exist,
        [interop] section is missing, or the settings are not properly configured.

    .PARAMETER DistroName
        The name of the WSL distribution to query.

    .OUTPUTS
        System.Boolean
        Returns $true if Windows interop is fully configured, $false otherwise.

    .EXAMPLE
        $configured = Test-WslInteropConfigured -DistroName "Debian"
        if ($configured) {
            Write-Host "Windows interop is configured"
        } else {
            Write-Host "Windows interop is not configured in wsl.conf"
        }

    .NOTES
        This function checks for both enabled=true and appendWindowsPath=true
        in the [interop] section. Both must be present and set to true for
        the function to return $true.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

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

        # Parse the content to find [interop] section
        $inInteropSection = $false
        $enabledFound = $false
        $appendWindowsPathFound = $false
        $lines = $wslConfContent -split "`n"

        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()

            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith('#')) {
                continue
            }

            # Check for [interop] section
            if ($trimmedLine -match '^\[interop\]') {
                $inInteropSection = $true
                continue
            }

            # Check for new section (stop looking in [interop])
            if ($trimmedLine -match '^\[.*\]') {
                $inInteropSection = $false
                continue
            }

            # If in [interop] section, look for enabled and appendWindowsPath
            if ($inInteropSection) {
                if ($trimmedLine -match '^enabled\s*=\s*(.+)$') {
                    $value = $matches[1].Trim().ToLower()
                    $enabledFound = ($value -eq "true")
                }
                if ($trimmedLine -match '^appendWindowsPath\s*=\s*(.+)$') {
                    $value = $matches[1].Trim().ToLower()
                    $appendWindowsPathFound = ($value -eq "true")
                }
            }
        }

        # Both settings must be present and set to true
        return ($enabledFound -and $appendWindowsPathFound)
    }
    catch {
        # wsl.conf doesn't exist or other error - return false
        return $false
    }
}
