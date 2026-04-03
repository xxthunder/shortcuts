<#
.DESCRIPTION
    WSL Manager orchestration — CLI entry point and TUI.
    This file is dot-sourced by wsl-manager.ps1 and sources commands.ps1 for action functions.
#>

# Suppress PSAvoidUsingWriteHost - Write-Host is required for colored interactive console output
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive tool requires colored console output')]
param()

# Source dependencies
. "$PSScriptRoot\commands.ps1"

# Import PwshSpectreConsole for TUI primitives (SC-016)
# Skip in CI/test environments where the module is mocked
if (-not (Test-RunningInCIorTestEnvironment)) {
    if (-not (Get-Module -Name PwshSpectreConsole -ListAvailable)) {
        throw "PwshSpectreConsole module is not installed. Run bin/install.ps1 to set up dependencies."
    }
    Import-Module PwshSpectreConsole -ErrorAction Stop
}

function Start-InteractiveMode {
    <#
    .SYNOPSIS
        Displays the TUI and handles user input.
    .OUTPUTS
        Returns $true if the menu completed successfully, $false if skipped.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (Test-RunningInCIorTestEnvironment) {
        Write-WarningMsg "Interactive mode is not available in CI environment."
        Write-WarningMsg "Use command-line arguments instead: .\wsl-manager.ps1 list"
        return $false
    }

    # Map menu keys to command names
    $menuKeyMap = @{
        "I" = "install"
        "C" = "clone"
        "U" = "update"
        "S" = "setup-user"
        "D" = "setup-docker"
        "P" = "setup-podman"
        "V" = "setup-devpod"
        "X" = "setup-proxy"
        "R" = "remove"
        "T" = "terminate"
        "H" = "shutdown"
        "W" = "configure-wsl"
    }

    $continue = $true
    while ($continue) {
        Clear-Host
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  WSL Manager" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan

        # Fetch current distributions once per loop iteration and display the table.
        # The fetched list is passed to action functions so they use consistent numbering
        # and do not re-fetch or reprint the table.
        $menuDistros = $null
        try {
            $menuDistros = @(Get-WslDistroList -Detailed)
            Show-WslDistroList -Distros $menuDistros
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
        Write-Host "  [P] Setup Podman" -ForegroundColor White
        Write-Host "  [V] Setup DevPod" -ForegroundColor White
        Write-Host "  [X] Setup proxy (corporate)" -ForegroundColor White
        Write-Host "  [R] Remove distribution" -ForegroundColor White
        Write-Host "  [T] Terminate distribution" -ForegroundColor White
        Write-Host "  [H] Shutdown WSL" -ForegroundColor White
        Write-Host "  [W] Configure .wslconfig defaults" -ForegroundColor White
        Write-Host "  [Q] Quit" -ForegroundColor White
        Write-Host ""

        $choice = Read-Host "Select command"
        $key = $choice.ToUpper()

        if ($key -eq "Q") {
            $continue = $false
        }
        elseif ($menuKeyMap.ContainsKey($key)) {
            $command = $menuKeyMap[$key]
            if ($PSCmdlet.ShouldProcess($command, "Execute WSL command")) {
                try {
                    Invoke-WslCommand -Command $command -Distros $menuDistros
                }
                catch {
                    Write-ErrorMsg "$_"
                }
            }
            Read-Host -Prompt "Press Enter to continue ..."
        }
        else {
            Write-ErrorMsg "Invalid option. Please try again."
            Start-Sleep -Seconds 1
        }
    }

    return $true
}

function Invoke-WslManager {
    <#
    .SYNOPSIS
        Main entry point for WSL Manager.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Passed through to Invoke-WslCommand for non-interactive WSL user creation.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Username and Password are passed through to Invoke-WslCommand for non-interactive WSL user creation.')]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet("list", "install", "clone", "remove", "update", "setup-user", "setup-proxy", "setup-docker", "setup-podman", "setup-devpod", "repair-interop", "terminate", "shutdown", "configure-wsl", "")]
        [string]$Command = "",

        [Parameter(Position = 1)]
        [string]$Name = "",

        [Parameter(Position = 2)]
        [string]$TargetName = "",

        [string]$Username = "",
        [string]$Password = ""
    )

    Assert-Wsl2Installed

    if ([string]::IsNullOrWhiteSpace($Command)) {
        Start-InteractiveMode
        return
    }

    Invoke-WslCommand -Command $Command -Name $Name -TargetName $TargetName -Username $Username -Password $Password
}
