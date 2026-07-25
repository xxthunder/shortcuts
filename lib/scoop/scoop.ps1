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

function Read-ScoopMenuChoice {
    <#
    .SYNOPSIS
        Prompts for a menu choice and returns a structured action.

    .DESCRIPTION
        Reads a single interactive menu line and maps it to an action:
        'update' (with the list of selected app names), 'refresh', or 'quit'.
        Number(s) and 'A' are only meaningful when apps are updatable; when the
        app list is empty only [R]efresh and [Q]uit are offered.

    .PARAMETER Apps
        Array of updatable app objects from Get-ScoopUpdatableApp. May be empty.

    .OUTPUTS
        Hashtable with keys:
          Action - one of 'update', 'refresh', 'quit'
          Apps   - array of selected app names (empty unless Action is 'update')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Apps
    )

    if ($Apps.Count -gt 0) {
        $prompt = "Enter number(s) comma-separated, [A]ll, [R]efresh, [Q]uit"
    }
    else {
        $prompt = "[R]efresh, [Q]uit"
    }

    $selection = Read-Host $prompt

    if ($selection -match '^[Qq]$') {
        return @{ Action = 'quit'; Apps = @() }
    }
    if ($selection -match '^[Rr]$') {
        return @{ Action = 'refresh'; Apps = @() }
    }
    if ($selection -match '^[Aa]$') {
        return @{ Action = 'update'; Apps = @($Apps | ForEach-Object { $_.Name }) }
    }

    $indices = $selection -split ',' | ForEach-Object { $_.Trim() }
    $selectedApps = @()

    foreach ($idx in $indices) {
        if ([string]::IsNullOrWhiteSpace($idx)) { continue }
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
            Write-WarningMsg "Invalid input: '$idx' (enter numbers, 'A', 'R', or 'Q')"
        }
    }

    return @{ Action = 'update'; Apps = $selectedApps }
}

function Get-ScoopHostRawUi {
    <#
    .SYNOPSIS
        Returns the raw UI of the current host (thin, mockable console seam).

    .DESCRIPTION
        $Host is a read-only automatic variable and cannot be shadowed, so the
        lookup is isolated here: tests mock this function to hand back a stub
        raw UI and therefore never block on a real key press.
    #>
    [CmdletBinding()]
    param()

    return $Host.UI.RawUI
}

function Wait-ScoopKeyPress {
    <#
    .SYNOPSIS
        Pauses until the user presses a key so command output can be read
        before the menu is redrawn.

    .DESCRIPTION
        Skipped in CI/test environments (there is nothing to wait on, and a
        blocking read would hang the build) and tolerant of hosts with no
        interactive console: the read is best-effort, never fatal.
    #>
    [CmdletBinding()]
    param()

    if (Test-RunningInCIorTestEnvironment) {
        return
    }

    Write-Host ""
    Write-Host "Press any key to continue..."
    try {
        $null = (Get-ScoopHostRawUi).ReadKey("NoEcho,IncludeKeyDown")
    }
    catch {
        # No interactive console (redirected input, non-interactive host):
        # there is nothing to wait on, so continue without failing.
        Write-Verbose "Key read skipped: $_"
    }
}

function Invoke-ScoopBucketRefresh {
    <#
    .SYNOPSIS
        Refreshes Scoop and its bucket metadata ('scoop update').

    .DESCRIPTION
        Non-fatal: a failure is logged and control continues, so the helper
        never exits because a refresh failed.
    #>
    [CmdletBinding()]
    param()

    Write-Status "Refreshing Scoop..."
    Invoke-CommandLine -CommandLine "scoop update" -StopAtError $false -PrintCommand $false
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
        Refreshes Scoop once at startup, then loops: lists updatable apps and
        lets the user select apps to update, refresh the buckets ('R'), or quit
        ('Q'). Each iteration is resilient: a Scoop failure is printed and
        control returns to the menu, so the session never exits on error. This
        lets the user close a locked application (e.g. Windows Terminal or pwsh),
        press 'R', and retry within the same session.

        In CI / test environments (Test-RunningInCIorTestEnvironment) it performs
        exactly one update-all pass and returns, so it never blocks on input.
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

    # Refresh Scoop and bucket info once at startup
    Invoke-ScoopBucketRefresh

    if (Test-RunningInCIorTestEnvironment) {
        # Non-interactive: single update-all pass, no prompts, no loop
        $apps = @(Get-ScoopUpdatableApp)
        if ($apps.Count -eq 0) {
            Write-Success "All apps are up to date!"
            return
        }
        Show-ScoopUpdatableApp -Apps $apps
        Update-ScoopApp -AppNames @($apps | ForEach-Object { $_.Name })
        Write-Success "Update complete!"
        return
    }

    # Interactive loop until the user quits
    while ($true) {
        try {
            $apps = @(Get-ScoopUpdatableApp)
            if ($apps.Count -eq 0) {
                Write-Success "All apps are up to date!"
            }
            else {
                Show-ScoopUpdatableApp -Apps $apps
            }

            $choice = Read-ScoopMenuChoice -Apps $apps

            switch ($choice.Action) {
                'quit' {
                    return
                }
                'refresh' {
                    Invoke-ScoopBucketRefresh
                }
                'update' {
                    if (@($choice.Apps).Count -eq 0) {
                        Write-WarningMsg "No apps selected for update."
                    }
                    else {
                        Write-Host ""
                        Write-Status "Updating $(@($choice.Apps).Count) app(s)..."
                        Write-Host ""
                        Update-ScoopApp -AppNames $choice.Apps
                        Write-Host ""
                        Write-Success "Update complete!"
                        Wait-ScoopKeyPress
                    }
                }
            }
        }
        catch {
            Write-ErrorMsg "Error: $_"
        }
    }
}
