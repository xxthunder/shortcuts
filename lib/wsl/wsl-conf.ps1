<#
.DESCRIPTION
    WSL wsl.conf management functions for reading, writing, and checking
    configuration in per-distro /etc/wsl.conf files.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

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

    # Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

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

    # Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

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

    # Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

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

function Test-WslAutomountConfigured {
    <#
    .SYNOPSIS
        Checks if automount metadata is configured in a WSL distribution's wsl.conf file.

    .DESCRIPTION
        Reads the /etc/wsl.conf file in a WSL distribution and checks if the [automount]
        section has an options key containing "metadata". Returns $true if metadata is
        present in the options value, or $false if wsl.conf doesn't exist, [automount]
        section is missing, or options doesn't contain metadata.

    .PARAMETER DistroName
        The name of the WSL distribution to query.

    .OUTPUTS
        System.Boolean
        Returns $true if automount metadata is configured, $false otherwise.

    .EXAMPLE
        $configured = Test-WslAutomountConfigured -DistroName "Debian"
        if (-not $configured) {
            Write-Host "Automount metadata is not configured in wsl.conf"
        }

    .NOTES
        This function checks that the [automount] options value contains "metadata".
        It does not require an exact match, so user-customized values like
        "metadata,umask=077" will still return $true.
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
            return $false
        }

        # Parse the content to find [automount] section and options key
        $inAutomountSection = $false
        $lines = $wslConfContent -split "`n"

        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()

            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith('#')) {
                continue
            }

            # Check for [automount] section
            if ($trimmedLine -match '^\[automount\]') {
                $inAutomountSection = $true
                continue
            }

            # Check for new section (stop looking in [automount])
            if ($trimmedLine -match '^\[.*\]') {
                $inAutomountSection = $false
                continue
            }

            # If in [automount] section, look for options key containing metadata
            if ($inAutomountSection -and $trimmedLine -match '^options\s*=\s*(.+)$') {
                $value = $matches[1].Trim().ToLower()
                return $value -match 'metadata'
            }
        }

        # No automount options with metadata found
        return $false
    }
    catch {
        # wsl.conf doesn't exist or other error - return false
        return $false
    }
}
