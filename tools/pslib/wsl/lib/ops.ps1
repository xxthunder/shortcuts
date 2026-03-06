<#
.DESCRIPTION
    WSL distribution operations for updating, copying, and removing distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\..\utils\utils.ps1"

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

    # Check if source distribution exists
    Assert-WslDistroExists -DistroName $SourceName

    # Check if target name already exists
    Assert-WslDistroNotExists -DistroName $TargetName

    # Trim names for use in commands below
    $SourceName = $SourceName.Trim()
    $TargetName = $TargetName.Trim()

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
        Write-Output "WSL subsystem has been shut down."
    }
    else {
        Write-Output "Shutdown cancelled."
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

    # Check if distribution exists
    Assert-WslDistroExists -DistroName $Name

    # Trim name for use in commands below
    $Name = $Name.Trim()

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
