<#
.DESCRIPTION
    WSL Manager orchestration — CLI entry point and interactive menu.
    This file is dot-sourced by wsl-manager.ps1 after commands.ps1.
#>

# Suppress PSAvoidUsingWriteHost - Write-Host is required for colored interactive console output
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive tool requires colored console output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Passed through to Invoke-WslCommand for non-interactive WSL user creation.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Username and Password are passed through to Invoke-WslCommand for non-interactive WSL user creation.')]
param()

function Start-InteractiveMode {
    <#
    .SYNOPSIS
        Displays the interactive menu and handles user input.
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
        "X" = "setup-proxy"
        "R" = "remove"
        "T" = "terminate"
        "H" = "shutdown"
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
        Write-Host "  [D] Setup/Repair Docker (idempotent, includes systemd/interop)" -ForegroundColor White
        Write-Host "  [P] Setup Podman (rootless, includes systemd/interop)" -ForegroundColor White
        Write-Host "  [X] Setup proxy (corporate)" -ForegroundColor White
        Write-Host "  [R] Remove distribution" -ForegroundColor White
        Write-Host "  [T] Terminate distribution" -ForegroundColor White
        Write-Host "  [H] Shutdown WSL" -ForegroundColor White
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
        [ValidateSet("list", "install", "clone", "remove", "update", "setup-user", "setup-proxy", "setup-docker", "setup-podman", "repair-interop", "terminate", "shutdown", "")]
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
