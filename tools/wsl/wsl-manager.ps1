#Requires -Version 5.1

<#
.SYNOPSIS
    WSL Manager - Manage Windows Subsystem for Linux distributions.

.DESCRIPTION
    Interactive tool for managing WSL distributions. Supports listing,
    creating, and removing distributions.

.PARAMETER Command
    The command to execute: list, create, remove.
    If not specified, enters interactive mode.

.PARAMETER Name
    The name of the distribution (used with create command).
    Supported values: Debian, Ubuntu.

.EXAMPLE
    .\wsl-manager.ps1
    Starts interactive mode.

.EXAMPLE
    .\wsl-manager.ps1 list
    Lists all installed WSL distributions.

.EXAMPLE
    .\wsl-manager.ps1 create Debian
    Creates a new Debian WSL distribution.
#>

# Suppress PSAvoidUsingWriteHost - Write-Host is required for colored interactive console output
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive tool requires colored console output')]
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("list", "create", "remove", "")]
    [string]$Command = "",

    [Parameter(Position = 1)]
    [string]$Name = ""
)

# Source dependencies
. "$PSScriptRoot\..\pslib\utils.ps1"
. "$PSScriptRoot\..\pslib\wsl.ps1"

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

    # If Name is not provided, prompt for it
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host ""
        Write-Host "Supported distributions:" -ForegroundColor Cyan
        Write-Host "  1. Debian" -ForegroundColor White
        Write-Host "  2. Ubuntu" -ForegroundColor White
        Write-Host ""

        $selection = Read-Host "Enter number or name of the distribution to create"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            Write-WarningMsg "No selection provided. Cancelling."
            return
        }

        # Check if selection is a number
        if ($selection -match '^\d+$') {
            $selectionNum = [int]$selection
            switch ($selectionNum) {
                1 { $Name = "Debian" }
                2 { $Name = "Ubuntu" }
                default {
                    Write-ErrorMsg "Invalid selection number. Must be 1 or 2."
                    return
                }
            }
        }
        else {
            $Name = $selection
        }
    }

    # Validate the distribution name
    if ($Name -notin @("Debian", "Ubuntu")) {
        Write-ErrorMsg "Unsupported distribution: $Name"
        Write-WarningMsg "Supported distributions: Debian, Ubuntu"
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
        Write-Host "  [C] Create new distribution" -ForegroundColor White
        Write-Host "  [R] Remove distribution" -ForegroundColor White
        Write-Host "  [Q] Quit" -ForegroundColor White
        Write-Host ""

        $choice = Read-Host "Select command"

        switch ($choice.ToUpper()) {
            "C" {
                try {
                    Invoke-CreateDistro
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
        [string]$Name = ""
    )

    switch ($Command.ToLower()) {
        "list" {
            Show-WslDistroList
        }
        "create" {
            Invoke-CreateDistro -Name $Name
        }
        "remove" {
            Invoke-RemoveDistro
        }
        default {
            Show-InteractiveMenu
        }
    }
}

# Main execution - only run if script is executed directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WslManager -Command $Command -Name $Name
}
