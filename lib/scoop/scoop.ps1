<#
.DESCRIPTION
    Scoop update helper functions.
    This file is meant to be dot-sourced into other scripts.
#>

# Suppress PSAvoidUsingWriteHost for colored console output functions
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive tool requires colored console output')]
param()

# DO NOT use Set-StrictMode in dot-sourced files
$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

function Get-ScoopUpdatableApp {
    <#
    .SYNOPSIS
        Gets a list of Scoop apps that have updates available.

    .DESCRIPTION
        Runs 'scoop status' and parses the output to return a list of apps
        with their installed and latest versions.

    .OUTPUTS
        Array of PSCustomObject with Name, InstalledVersion, and LatestVersion properties.
        Returns an empty array if no updates are available.
    #>
    [CmdletBinding()]
    param()

    Write-Status "Checking for updatable apps..."

    # Capture scoop status output
    $statusOutput = Invoke-CommandLine -CommandLine "scoop status" -StopAtError $false -PrintCommand $false
    if ($null -eq $statusOutput) {
        return @()
    }

    $apps = @()

    # Check if output is structured objects (modern scoop) or text (legacy)
    $firstItem = @($statusOutput) | Select-Object -First 1
    if ($null -ne $firstItem -and $null -ne $firstItem.PSObject.Properties.Match('Name') -and $firstItem.PSObject.Properties.Match('Name').Count -gt 0) {
        # Modern scoop: output is PSCustomObject array
        foreach ($item in @($statusOutput)) {
            $apps += [PSCustomObject]@{
                Name             = $item.Name
                InstalledVersion = $item."Installed Version"
                LatestVersion    = $item."Latest Version"
            }
        }
    } else {
        # Legacy scoop: parse text table output
        $lines = @($statusOutput) | ForEach-Object { "$_" }
        $headerFound = $false
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -match '^\s*-+\s+-+') {
                $headerFound = $true
                continue
            }
            if (-not $headerFound) { continue }
            $parts = $line.Trim() -split '\s{2,}'
            if ($parts.Count -ge 3) {
                $apps += [PSCustomObject]@{
                    Name             = $parts[0]
                    InstalledVersion = $parts[1]
                    LatestVersion    = $parts[2]
                }
            }
        }
    }

    return $apps
}

function Show-ScoopUpdatableApp {
    <#
    .SYNOPSIS
        Displays a numbered list of updatable Scoop apps.

    .PARAMETER Apps
        Array of app objects from Get-ScoopUpdatableApp.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Apps
    )

    Write-Host ""
    Write-Host "Updatable Apps:" -ForegroundColor Cyan
    Write-Host "-----------------------------" -ForegroundColor Cyan

    $index = 1
    foreach ($app in $Apps) {
        Write-Host "  $index. " -NoNewline -ForegroundColor White
        Write-Host "$($app.Name) " -NoNewline -ForegroundColor White
        Write-Host "($($app.InstalledVersion) -> $($app.LatestVersion))" -ForegroundColor Yellow
        $index++
    }
    Write-Host ""
}

function Select-ScoopApp {
    <#
    .SYNOPSIS
        Prompts the user to select apps to update.

    .DESCRIPTION
        Displays a selection prompt. User can enter 'A' for all, or
        comma-separated numbers to select specific apps.

    .PARAMETER Apps
        Array of app objects from Get-ScoopUpdatableApp.

    .OUTPUTS
        Array of app names selected for update.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Apps
    )

    if (Test-RunningInCIorTestEnvironment) {
        # In CI, update all by default
        return @($Apps | ForEach-Object { $_.Name })
    }

    $selection = Read-Host "Enter app number(s) comma-separated, or [A] for all"

    if ($selection -match '^[Aa]$') {
        return @($Apps | ForEach-Object { $_.Name })
    }

    $indices = $selection -split ',' | ForEach-Object { $_.Trim() }
    $selectedApps = @()

    foreach ($idx in $indices) {
        if ($idx -match '^\d+$') {
            $num = [int]$idx
            if ($num -ge 1 -and $num -le $Apps.Count) {
                $selectedApps += $Apps[$num - 1].Name
            }
            else {
                Write-WarningMsg "Invalid number: $idx (must be 1-$($Apps.Count))"
            }
        }
        else {
            Write-WarningMsg "Invalid input: '$idx' (enter numbers or 'A')"
        }
    }

    return $selectedApps
}

function Update-ScoopApp {
    <#
    .SYNOPSIS
        Updates the specified Scoop apps.

    .PARAMETER AppNames
        Array of app names to update.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$AppNames
    )

    foreach ($appName in $AppNames) {
        if (-not $PSCmdlet.ShouldProcess($appName, "Update Scoop app")) {
            continue
        }
        Write-Status "Updating $appName..."
        Invoke-CommandLine -CommandLine "scoop update $appName" -StopAtError $false
        if ($LASTEXITCODE -eq 0) {
            Write-Success "$appName updated successfully"
        }
        else {
            Write-ErrorMsg "Failed to update $appName"
        }
    }
}

function Invoke-ScoopUpdate {
    <#
    .SYNOPSIS
        Main entry point for the interactive Scoop update helper.

    .DESCRIPTION
        Refreshes Scoop, checks for updatable apps, displays a numbered list,
        and lets the user select which apps to update.
    #>
    [CmdletBinding()]
    param()

    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Scoop Update Helper" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""

    # Check if Scoop is installed
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Scoop is not installed. Please install Scoop first."
        return
    }

    # Refresh Scoop and bucket info
    Write-Status "Refreshing Scoop..."
    Invoke-CommandLine -CommandLine "scoop update" -StopAtError $false -PrintCommand $false

    # Get updatable apps
    $apps = @(Get-ScoopUpdatableApp)

    if ($apps.Count -eq 0) {
        Write-Success "All apps are up to date!"
        return
    }

    # Display updatable apps
    Show-ScoopUpdatableApp -Apps $apps

    # Select apps to update
    $selectedApps = @(Select-ScoopApp -Apps $apps)

    if ($selectedApps.Count -eq 0) {
        Write-WarningMsg "No apps selected for update."
        return
    }

    Write-Host ""
    Write-Status "Updating $($selectedApps.Count) app(s)..."
    Write-Host ""

    # Update selected apps
    Update-ScoopApp -AppNames $selectedApps

    Write-Host ""
    Write-Success "Update complete!"
}
