#Requires -Version 5.1

<#
.SYNOPSIS
    WSL Manager - Manage Windows Subsystem for Linux distributions.

.DESCRIPTION
    Interactive tool for managing WSL distributions. Supports listing,
    creating, and removing distributions.

.PARAMETER Command
    The command to execute: list, create, clone, remove.
    If not specified, enters interactive mode.

.PARAMETER Name
    The name of the distribution (used with create and clone commands).
    For create: supports any distribution available from 'wsl.exe --list --online'.
    For clone: the source distribution name to clone from.
    Examples: Debian, Ubuntu, Ubuntu-22.04, Ubuntu-24.04, kali-linux.

.PARAMETER TargetName
    The target name for the cloned distribution (used with clone command).

.EXAMPLE
    .\wsl-manager.ps1
    Starts interactive mode.

.EXAMPLE
    .\wsl-manager.ps1 list
    Lists all installed WSL distributions.

.EXAMPLE
    .\wsl-manager.ps1 create Debian
    Creates a new Debian WSL distribution.

.EXAMPLE
    .\wsl-manager.ps1 create Ubuntu-22.04
    Creates an Ubuntu 22.04 LTS distribution.

.EXAMPLE
    .\wsl-manager.ps1 clone Debian MyProject
    Clones the Debian distribution to a new distribution named MyProject.
#>

# Suppress PSAvoidUsingWriteHost - Write-Host is required for colored interactive console output
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive tool requires colored console output')]
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("list", "create", "clone", "remove", "update", "setup-user", "setup-docker", "")]
    [string]$Command = "",

    [Parameter(Position = 1)]
    [string]$Name = "",

    [Parameter(Position = 2)]
    [string]$TargetName = ""
)

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

# Source dependencies
. "$PSScriptRoot\..\pslib\utils.ps1"
. "$PSScriptRoot\..\pslib\wsl.ps1"

#region Functions

function Show-WslDistroList {
    <#
    .SYNOPSIS
        Displays a list of installed WSL distributions.
    #>
    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    $distros = @(Get-WslDistroList)

    Write-Host ""
    Write-Host "Installed WSL Distributions:" -ForegroundColor Cyan
    Write-Host "-----------------------------" -ForegroundColor Cyan

    if ($distros.Count -eq 0) {
        Write-Host "  No WSL distributions found." -ForegroundColor Yellow
    }
    else {
        $index = 1
        foreach ($distro in $distros) {
            Write-Host "  $index. $distro" -ForegroundColor White
            $index++
        }
    }
    Write-Host ""
}

function Invoke-CreateDistro {
    <#
    .SYNOPSIS
        Handles the create distribution workflow.
    .PARAMETER Name
        The name of the distribution to create. If empty, prompts the user.
    #>
    [CmdletBinding()]
    param(
        [string]$Name = ""
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Get available distributions dynamically
    $availableDistros = Get-WslAvailableDistro

    # If Name is not provided, prompt for it
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host ""
        Write-Host "Available distributions:" -ForegroundColor Cyan

        # Show available distributions with numbers
        $index = 1
        foreach ($distro in $availableDistros) {
            Write-Host "  $index. $distro" -ForegroundColor White
            $index++
        }
        Write-Host ""

        $selection = Read-Host "Enter number or name of the distribution to create"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            Write-WarningMsg "No selection provided. Cancelling."
            return
        }

        # Check if selection is a number
        if ($selection -match '^\d+$') {
            $selectionNum = [int]$selection
            if ($selectionNum -ge 1 -and $selectionNum -le $availableDistros.Count) {
                $Name = $availableDistros[$selectionNum - 1]
            }
            else {
                Write-ErrorMsg "Invalid selection number. Must be between 1 and $($availableDistros.Count)."
                return
            }
        }
        else {
            $Name = $selection
        }
    }

    # Validate the distribution name
    if ($Name -notin $availableDistros) {
        Write-ErrorMsg "Distribution '$Name' is not available."
        Write-Host ""
        Write-Host "Available distributions:" -ForegroundColor Yellow
        foreach ($distro in $availableDistros) {
            Write-Host "  - $distro" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Run 'wsl.exe --list --online' to see all available distributions." -ForegroundColor Yellow
        return
    }

    # Create the distribution (skip confirmation since we're handling it interactively)
    New-WslDistro -Name $Name -Confirm:$false
}

function Invoke-RemoveDistro {
    <#
    .SYNOPSIS
        Handles the remove distribution workflow.
    #>
    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    $distros = @(Get-WslDistroList)

    if ($distros.Count -eq 0) {
        Write-WarningMsg "No WSL distributions found to remove."
        return
    }

    # Show available distributions
    Write-Host ""
    Write-Host "Available distributions:" -ForegroundColor Cyan
    $index = 1
    foreach ($distro in $distros) {
        Write-Host "  $index. $distro" -ForegroundColor White
        $index++
    }
    Write-Host ""

    # Prompt for distribution selection (number or name)
    $selection = Read-Host "Enter number or name of the distribution to remove"

    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-WarningMsg "No selection provided. Cancelling."
        return
    }

    # Check if selection is a number
    $selectedName = $null
    if ($selection -match '^\d+$') {
        $selectionNum = [int]$selection
        if ($selectionNum -ge 1 -and $selectionNum -le $distros.Count) {
            $selectedName = $distros[$selectionNum - 1]
        }
        else {
            Write-ErrorMsg "Invalid selection number. Must be between 1 and $($distros.Count)."
            return
        }
    }
    else {
        $selectedName = $selection
    }

    # Remove the distribution (skip confirmation since we're handling it interactively)
    Remove-WslDistro -Name $selectedName -Confirm:$false
}

function Invoke-UpdateDistro {
    <#
    .SYNOPSIS
        Handles the update distribution workflow.
    #>
    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    $distros = @(Get-WslDistroList)

    if ($distros.Count -eq 0) {
        Write-WarningMsg "No WSL distributions found to update."
        return
    }

    # Show available distributions
    Write-Host ""
    Write-Host "Available distributions:" -ForegroundColor Cyan
    $index = 1
    foreach ($distro in $distros) {
        Write-Host "  $index. $distro" -ForegroundColor White
        $index++
    }
    Write-Host ""

    # Prompt for distribution selection (number or name)
    $selection = Read-Host "Enter number or name of the distribution to update"

    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-WarningMsg "No selection provided. Cancelling."
        return
    }

    # Check if selection is a number
    $selectedName = $null
    if ($selection -match '^\d+$') {
        $selectionNum = [int]$selection
        if ($selectionNum -ge 1 -and $selectionNum -le $distros.Count) {
            $selectedName = $distros[$selectionNum - 1]
        }
        else {
            Write-ErrorMsg "Invalid selection number. Must be between 1 and $($distros.Count)."
            return
        }
    }
    else {
        $selectedName = $selection
    }

    # Update the distribution (skip confirmation since we're handling it interactively)
    Update-WslDistro -Name $selectedName -Confirm:$false
}

function Invoke-SetupUser {
    <#
    .SYNOPSIS
        Handles the user setup workflow interactively.
    .PARAMETER DistroName
        The name of the distribution to create a user in.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    # Skip in CI environment
    if (Test-RunningInCIorTestEnvironment) {
        Write-Host "Skipping user setup in CI/test environment." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Setting up user account in '$DistroName' ..." -ForegroundColor Cyan
    Write-Host ""

    # Prompt for username
    $username = Read-Host "Enter username"

    if ([string]::IsNullOrWhiteSpace($username)) {
        Write-WarningMsg "No username provided. Cancelling user setup."
        return
    }

    # Prompt for password securely
    $securePassword = Read-Host "Enter password" -AsSecureString

    # Convert SecureString to plain text for chpasswd
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    try {
        # Create the user (skip confirmation since we're handling it interactively)
        New-WslUser -DistroName $DistroName -Username $username -Password $passwordPlain -Confirm:$false

        Write-Host ""
        Write-Success "Successfully created user '$username' in '$DistroName'."
        Write-Host ""
        Write-Host "To apply the default user change, restart the distribution with:" -ForegroundColor Yellow
        Write-Host "  wsl.exe --terminate $DistroName" -ForegroundColor Yellow
    }
    finally {
        # Clear the plain text password from memory
        $passwordPlain = $null
    }
}

function Invoke-SetupDocker {
    <#
    .SYNOPSIS
        Handles the Docker setup workflow for a WSL distribution.
    .PARAMETER DistroName
        The name of the distribution to install Docker in.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    Write-Host ""
    Write-Host "Setting up Docker in '$DistroName' ..." -ForegroundColor Cyan
    Write-Host ""

    try {
        # Install Docker Engine (skip confirmation since we're handling it interactively)
        $result = Install-WslDockerEngine -DistroName $DistroName -Confirm:$false

        if ($result) {
            Write-Host ""
            Write-Success "Successfully installed Docker in '$DistroName'."
            Write-Host ""
            Write-Host "To apply group membership changes, restart the distribution with:" -ForegroundColor Yellow
            Write-Host "  wsl.exe --terminate $DistroName" -ForegroundColor Yellow
            Write-Host "  wsl.exe --distribution $DistroName" -ForegroundColor Yellow
        }
    }
    catch {
        throw $_
    }
}

function Invoke-SetupUserInteractive {
    <#
    .SYNOPSIS
        Handles the user setup workflow interactively by prompting for distribution name.
    #>
    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    $distros = @(Get-WslDistroList)

    if ($distros.Count -eq 0) {
        Write-WarningMsg "No WSL distributions found."
        return
    }

    # Show available distributions
    Write-Host ""
    Write-Host "Available distributions:" -ForegroundColor Cyan
    $index = 1
    foreach ($distro in $distros) {
        Write-Host "  $index. $distro" -ForegroundColor White
        $index++
    }
    Write-Host ""

    # Prompt for distribution selection (number or name)
    $selection = Read-Host "Enter number or name of the distribution to setup user in"

    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-WarningMsg "No selection provided. Cancelling."
        return
    }

    # Check if selection is a number
    $selectedName = $null
    if ($selection -match '^\d+$') {
        $selectionNum = [int]$selection
        if ($selectionNum -ge 1 -and $selectionNum -le $distros.Count) {
            $selectedName = $distros[$selectionNum - 1]
        }
        else {
            Write-ErrorMsg "Invalid selection number. Must be between 1 and $($distros.Count)."
            return
        }
    }
    else {
        $selectedName = $selection
    }

    # Setup user in the selected distribution
    Invoke-SetupUser -DistroName $selectedName
}

function Invoke-SetupDockerInteractive {
    <#
    .SYNOPSIS
        Handles the Docker setup workflow interactively by prompting for distribution name.
    #>
    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    $distros = @(Get-WslDistroList)

    if ($distros.Count -eq 0) {
        Write-WarningMsg "No WSL distributions found."
        return
    }

    # Show available distributions
    Write-Host ""
    Write-Host "Available distributions:" -ForegroundColor Cyan
    $index = 1
    foreach ($distro in $distros) {
        Write-Host "  $index. $distro" -ForegroundColor White
        $index++
    }
    Write-Host ""

    # Prompt for distribution selection (number or name)
    $selection = Read-Host "Enter number or name of the distribution to setup Docker in"

    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-WarningMsg "No selection provided. Cancelling."
        return
    }

    # Check if selection is a number
    $selectedName = $null
    if ($selection -match '^\d+$') {
        $selectionNum = [int]$selection
        if ($selectionNum -ge 1 -and $selectionNum -le $distros.Count) {
            $selectedName = $distros[$selectionNum - 1]
        }
        else {
            Write-ErrorMsg "Invalid selection number. Must be between 1 and $($distros.Count)."
            return
        }
    }
    else {
        $selectedName = $selection
    }

    # Setup Docker in the selected distribution
    Invoke-SetupDocker -DistroName $selectedName
}

function Invoke-CloneDistro {
    <#
    .SYNOPSIS
        Handles the clone distribution workflow.
    .PARAMETER SourceName
        The source distribution to clone from. If empty, prompts the user.
    .PARAMETER TargetName
        The target name for the cloned distribution. If empty, prompts the user.
    #>
    [CmdletBinding()]
    param(
        [string]$SourceName = "",
        [string]$TargetName = ""
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    $distros = @(Get-WslDistroList)

    if ($distros.Count -eq 0) {
        Write-WarningMsg "No WSL distributions found to clone."
        return
    }

    # If SourceName is not provided, prompt for it
    if ([string]::IsNullOrWhiteSpace($SourceName)) {
        Write-Host ""
        Write-Host "Available distributions:" -ForegroundColor Cyan

        # Show available distributions with numbers
        $index = 1
        foreach ($distro in $distros) {
            Write-Host "  $index. $distro" -ForegroundColor White
            $index++
        }
        Write-Host ""

        $selection = Read-Host "Enter number or name of the source distribution to clone"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            Write-WarningMsg "No selection provided. Cancelling."
            return
        }

        # Check if selection is a number
        if ($selection -match '^\d+$') {
            $selectionNum = [int]$selection
            if ($selectionNum -ge 1 -and $selectionNum -le $distros.Count) {
                $SourceName = $distros[$selectionNum - 1]
            }
            else {
                Write-ErrorMsg "Invalid selection number. Must be between 1 and $($distros.Count)."
                return
            }
        }
        else {
            $SourceName = $selection
        }
    }

    # If TargetName is not provided, prompt for it
    if ([string]::IsNullOrWhiteSpace($TargetName)) {
        Write-Host ""
        $targetInput = Read-Host "Enter the target name for the cloned distribution"

        if ([string]::IsNullOrWhiteSpace($targetInput)) {
            Write-WarningMsg "No target name provided. Cancelling."
            return
        }

        $TargetName = $targetInput
    }

    # Clone the distribution (skip confirmation since we're handling it interactively)
    Copy-WslDistro -SourceName $SourceName -TargetName $TargetName -Confirm:$false
}

function Show-InteractiveMenu {
    <#
    .SYNOPSIS
        Displays the interactive menu and handles user input.
    .OUTPUTS
        Returns $true if the menu completed successfully, $false if skipped.
    #>
    if (Test-RunningInCIorTestEnvironment) {
        Write-WarningMsg "Interactive mode is not available in CI environment."
        Write-WarningMsg "Use command-line arguments instead: .\wsl-manager.ps1 list"
        return $false
    }

    $continue = $true
    while ($continue) {
        Clear-Host
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  WSL Manager" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan

        # Show current distributions
        try {
            Show-WslDistroList
        }
        catch {
            Write-ErrorMsg "$_"
            Write-Host ""
        }

        # Show menu
        Write-Host "Commands:" -ForegroundColor Cyan
        Write-Host "  [I] Install new distribution" -ForegroundColor White
        Write-Host "  [C] Clone distribution" -ForegroundColor White
        Write-Host "  [U] Update distribution" -ForegroundColor White
        Write-Host "  [S] Setup user account" -ForegroundColor White
        Write-Host "  [D] Setup Docker" -ForegroundColor White
        Write-Host "  [R] Remove distribution" -ForegroundColor White
        Write-Host "  [Q] Quit" -ForegroundColor White
        Write-Host ""

        $choice = Read-Host "Select command"

        switch ($choice.ToUpper()) {
            "I" {
                try {
                    Invoke-CreateDistro
                }
                catch {
                    Write-ErrorMsg "$_"
                }
                Read-Host -Prompt "Press Enter to continue ..."
            }
            "C" {
                try {
                    Invoke-CloneDistro
                }
                catch {
                    Write-ErrorMsg "$_"
                }
                Read-Host -Prompt "Press Enter to continue ..."
            }
            "U" {
                try {
                    Invoke-UpdateDistro
                }
                catch {
                    Write-ErrorMsg "$_"
                }
                Read-Host -Prompt "Press Enter to continue ..."
            }
            "S" {
                try {
                    Invoke-SetupUserInteractive
                }
                catch {
                    Write-ErrorMsg "$_"
                }
                Read-Host -Prompt "Press Enter to continue ..."
            }
            "D" {
                try {
                    Invoke-SetupDockerInteractive
                }
                catch {
                    Write-ErrorMsg "$_"
                }
                Read-Host -Prompt "Press Enter to continue ..."
            }
            "R" {
                try {
                    Invoke-RemoveDistro
                }
                catch {
                    Write-ErrorMsg "$_"
                }
                Read-Host -Prompt "Press Enter to continue ..."
            }
            "Q" {
                $continue = $false
            }
            default {
                Write-ErrorMsg "Invalid option. Please try again."
                Start-Sleep -Seconds 1
            }
        }
    }

    return $true
}

function Invoke-WslManager {
    <#
    .SYNOPSIS
        Main entry point for WSL Manager.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Command = "",

        [Parameter(Position = 1)]
        [string]$Name = "",

        [Parameter(Position = 2)]
        [string]$TargetName = ""
    )

    switch ($Command.ToLower()) {
        "list" {
            Show-WslDistroList
        }
        "create" {
            Invoke-CreateDistro -Name $Name
        }
        "clone" {
            Invoke-CloneDistro -SourceName $Name -TargetName $TargetName
        }
        "remove" {
            Invoke-RemoveDistro
        }
        "update" {
            Invoke-UpdateDistro
        }
        "setup-user" {
            Invoke-SetupUser -DistroName $Name
        }
        "setup-docker" {
            if ([string]::IsNullOrWhiteSpace($Name)) {
                Invoke-SetupDockerInteractive
            }
            else {
                Invoke-SetupDocker -DistroName $Name
            }
        }
        default {
            Show-InteractiveMenu
        }
    }
}

#endregion

#region  Main execution - only run if script is executed directly (not dot-sourced)

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WslManager -Command $Command -Name $Name -TargetName $TargetName
}

#endregion
