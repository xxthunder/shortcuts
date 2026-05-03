<#
.DESCRIPTION
    WSL distribution operations for updating, copying, and removing distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

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

    # Check if distribution exists
    Assert-WslDistroExists -DistroName $Name

    # Auto-terminate if running (must be stopped for removal)
    if (Test-WslDistroRunning -DistroName $Name) {
        Stop-WslDistro -Name $Name -Confirm:$false | Out-Null
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

    # Check if source distribution exists
    Assert-WslDistroExists -DistroName $SourceName

    # Check if target name already exists
    Assert-WslDistroNotExists -DistroName $TargetName

    # Trim names for use in commands below
    $SourceName = $SourceName.Trim()
    $TargetName = $TargetName.Trim()

    # Auto-terminate source if running (must be stopped for export)
    if (Test-WslDistroRunning -DistroName $SourceName) {
        Stop-WslDistro -Name $SourceName -Confirm:$false | Out-Null
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

function Stop-WslSubsystem {
    <#
    .SYNOPSIS
        Shuts down the entire WSL subsystem including all running distributions.

    .DESCRIPTION
        Executes 'wsl.exe --shutdown' to stop the entire WSL 2 lightweight VM and all
        running distributions. Unlike Stop-WslDistro (which terminates a single distro),
        this stops WSL completely. Use this to apply changes to %USERPROFILE%\.wslconfig.

    .EXAMPLE
        Stop-WslSubsystem
        Shuts down all of WSL after displaying a warning with running distributions.

    .EXAMPLE
        Stop-WslSubsystem -WhatIf
        Shows what would happen without actually shutting down.

    .NOTES
        This operation is idempotent — safe to run when no distributions are running.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param()

    # List running distributions to warn the user
    $allDistros = @(Get-WslDistroList -Detailed)
    $runningDistros = @($allDistros | Where-Object { $_.State -eq "Running" })

    if ($runningDistros.Count -gt 0) {
        $runningNames = ($runningDistros | ForEach-Object { $_.Name }) -join ", "
        Write-Warning "The following running distributions will be stopped: $runningNames"
    }
    else {
        Write-Output "No distributions are currently running."
    }

    if ($PSCmdlet.ShouldProcess("WSL subsystem", "Shutdown all distributions and the WSL2 VM")) {
        Write-Output "Shutting down WSL subsystem ..."
        Invoke-CommandLine -CommandLine "wsl.exe --shutdown"

        # Poll until all distributions are actually stopped.
        # wsl.exe --shutdown returns before the VM has fully terminated,
        # causing race conditions if callers proceed immediately.
        $maxWaitSeconds = 30
        $elapsed = 0
        while ($elapsed -lt $maxWaitSeconds) {
            $still = @(Get-WslDistroList -Detailed | Where-Object { $_.State -eq 'Running' })
            if ($still.Count -eq 0) { break }
            Start-Sleep -Seconds 1
            $elapsed++
        }

        if ($elapsed -ge $maxWaitSeconds) {
            $names = ($still | ForEach-Object { $_.Name }) -join ', '
            throw "WSL shutdown timed out after ${maxWaitSeconds}s. Still running: $names"
        }

        Write-Output "WSL subsystem has been shut down."
    }
    else {
        Write-Output "Shutdown cancelled."
    }
}

function Merge-WslConfig {
    <#
    .SYNOPSIS
        Merges default key-value pairs into the [wsl2] section of a .wslconfig file.

    .DESCRIPTION
        Processes lines of a .wslconfig INI file and ensures each default key is present
        in the [wsl2] section. Existing user values are never overwritten. For the
        special 'kernelCommandLine' key, missing parameters are appended to the existing
        value rather than replacing it. If the [wsl2] section is absent, it is appended.

    .PARAMETER Lines
        The current content of the .wslconfig file as an array of strings.

    .PARAMETER Defaults
        An ordered dictionary of key/value pairs that must be present in [wsl2].

    .OUTPUTS
        A hashtable with:
          Lines   - The updated content as a string array.
          Changed - $true if any modification was made, $false if already up to date.

    .EXAMPLE
        $result = Merge-WslConfig -Lines @('[wsl2]', 'networkingMode=mirrored') -Defaults $defaults
        $result.Changed  # $false (key already there with the expected value)
    #>
    param(
        [string[]]$Lines,
        [System.Collections.Specialized.OrderedDictionary]$Defaults
    )

    $result = [System.Collections.Generic.List[string]]::new()
    $inWsl2 = $false
    $wsl2Found = $false
    $wsl2KeysFound = @{}
    $changed = $false

    foreach ($line in $Lines) {
        # Detect section headers
        if ($line -match '^\s*\[(\w+)\]\s*$') {
            $sectionName = $Matches[1]

            if ($inWsl2 -and $sectionName -ne 'wsl2') {
                # Leaving [wsl2] section — insert any missing defaults before the next section
                foreach ($key in $Defaults.Keys) {
                    if (-not $wsl2KeysFound.ContainsKey($key)) {
                        $result.Add("$key = $($Defaults[$key])")
                        $changed = $true
                    }
                }
                $inWsl2 = $false
            }

            if ($sectionName -eq 'wsl2') {
                $inWsl2 = $true
                $wsl2Found = $true
            }

            $result.Add($line)
            continue
        }

        # Inside [wsl2]: intercept key=value pairs
        if ($inWsl2 -and $line -match '^\s*(\w+)\s*=\s*(.*)\s*$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $wsl2KeysFound[$key] = $value

            # kernelCommandLine: append any missing parameters instead of skipping the key
            if ($key -eq 'kernelCommandLine' -and $Defaults.Contains('kernelCommandLine')) {
                $defaultParams = @($Defaults['kernelCommandLine'] -split '\s+' | Where-Object { $_ })
                $existingParams = @($value -split '\s+' | Where-Object { $_ })
                $missingParams = @($defaultParams | Where-Object { $existingParams -notcontains $_ })

                if ($missingParams.Count -gt 0) {
                    $newValue = (($existingParams + $missingParams) -join ' ')
                    $result.Add("$key = $newValue")
                    $changed = $true
                    continue
                }
            }
        }

        $result.Add($line)
    }

    # End of file while still inside [wsl2] — append missing keys
    if ($inWsl2) {
        foreach ($key in $Defaults.Keys) {
            if (-not $wsl2KeysFound.ContainsKey($key)) {
                $result.Add("$key = $($Defaults[$key])")
                $changed = $true
            }
        }
    }

    # [wsl2] section was never found — append the whole section
    if (-not $wsl2Found) {
        if ($result.Count -gt 0 -and $result[$result.Count - 1] -ne '') {
            $result.Add('')
        }
        $result.Add('[wsl2]')
        foreach ($key in $Defaults.Keys) {
            $result.Add("$key = $($Defaults[$key])")
        }
        $changed = $true
    }

    return @{
        Lines   = $result.ToArray()
        Changed = $changed
    }
}

function Invoke-ConfigureWsl {
    <#
    .SYNOPSIS
        Applies default WSL global settings to %USERPROFILE%\.wslconfig (idempotent).

    .DESCRIPTION
        Ensures the following keys are present in the [wsl2] section of .wslconfig.
        Existing values are never overwritten.

        kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
        networkingMode    = mirrored
        dnsTunneling      = true
        autoProxy         = true

        For 'kernelCommandLine', missing parameters are appended to any existing value.
        A timestamped backup is created before any modification.
        After applying changes, the WSL subsystem is automatically shut down so the new
        global settings take effect on the next launch.

    .EXAMPLE
        Invoke-ConfigureWsl
        Applies default .wslconfig settings idempotently.

    .EXAMPLE
        Invoke-ConfigureWsl -WhatIf
        Shows what would change without writing the file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"

    $defaults = [ordered]@{
        kernelCommandLine = "cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1"
        networkingMode    = "mirrored"
        dnsTunneling      = "true"
        autoProxy         = "true"
    }

    # Read existing content
    $existingLines = @()
    if (Test-Path $wslConfigPath) {
        $existingLines = @(Get-Content -Path $wslConfigPath -Encoding UTF8)
    }

    # Merge defaults
    $mergeResult = Merge-WslConfig -Lines $existingLines -Defaults $defaults

    if (-not $mergeResult.Changed) {
        Write-Output ".wslconfig already has all required defaults. No changes needed."
        return
    }

    if (-not $PSCmdlet.ShouldProcess($wslConfigPath, "Apply default WSL global settings")) {
        return
    }

    # Create timestamped backup
    if (Test-Path $wslConfigPath) {
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $backupPath = "$wslConfigPath.bak.$timestamp"
        Copy-Item -Path $wslConfigPath -Destination $backupPath
        Write-Output "Backup created: $backupPath"
    }

    # Write updated content
    $mergeResult.Lines | Set-Content -Path $wslConfigPath -Encoding UTF8

    Write-Output "Applied default settings to $wslConfigPath"

    # Auto-shutdown the WSL subsystem so the new global settings take effect.
    # Stop-WslSubsystem already lists running distributions in a warning before stopping.
    Stop-WslSubsystem -Confirm:$false | Out-Null
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

    # Check if distribution exists
    Assert-WslDistroExists -DistroName $Name

    # Trim name for use in commands below
    $Name = $Name.Trim()

    # Auto-terminate if running (must be stopped for update)
    if (Test-WslDistroRunning -DistroName $Name) {
        Stop-WslDistro -Name $Name -Confirm:$false | Out-Null
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
