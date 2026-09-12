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


. "$PSScriptRoot\spectre.ps1"

function Get-WslManagerPanel {
    <#
    .SYNOPSIS
        Builds the WSL Manager panel with the distro table inside.

    .DESCRIPTION
        Wraps the distribution table content in a full-width Spectre.Console panel
        with a dark blue rounded border and "WSL Manager" as the header text.

    .PARAMETER DistroContent
        A Spectre renderable or markup string for the distribution table.

    .OUTPUTS
        A Spectre renderable panel written to the host.

    .EXAMPLE
        $table = Show-WslDistroTable -Distros $distros
        Get-WslManagerPanel -DistroContent $table
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $DistroContent
    )

    $DistroContent |
        Format-SpectrePanel -Header "[bold deepskyblue1]WSL Manager[/]" -Border Rounded -Color DarkBlue -Expand
}

function Show-WslMenu {
    <#
    .SYNOPSIS
        Displays the main menu using Read-SpectreSelection and returns the selected command.
    .OUTPUTS
        The command string (e.g. "install", "remove") or $null if the user cancels (Ctrl+C).
    #>
    [CmdletBinding()]
    param()

    # Menu choices: label -> command mapping
    $menuChoices = [ordered]@{
        "Install new distribution"      = "install"
        "Clone distribution"            = "clone"
        "Update distribution"           = "update"
        "Setup user account"            = "setup-user"
        "Setup Docker"                  = "setup-docker"
        "Setup Podman"                  = "setup-podman"
        "Setup DevPod"                  = "setup-devpod"
        "Sync SSH Config"               = "sync-ssh-config"
        "Setup proxy (corporate)"       = "setup-proxy"
        "Remove distribution"           = "remove"
        "Terminate distribution"        = "terminate"
        "Shutdown WSL"                  = "shutdown"
        "Configure .wslconfig defaults" = "configure-wsl"
        "Quit"                          = "quit"
    }

    $selection = Read-SpectreSelection -Message "Select command" -Choices $menuChoices.Keys -PageSize 15 -EnableSearch

    if ($null -eq $selection) {
        return $null
    }

    return $menuChoices[$selection]
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

    $continue = $true
    while ($continue) {
        Clear-Host

        # Fetch current distributions once per loop iteration.
        # The fetched list is passed to action functions so they use consistent numbering
        # and do not re-fetch or reprint the table.
        $menuDistros = $null
        try {
            $menuDistros = @(Get-WslDistroList -Detailed)
        }
        catch {
            Write-ErrorMsg "$_"
        }

        # Build single panel: branding header + distro table
        $distroContent = if ($null -ne $menuDistros) {
            Show-WslDistroTable -Distros $menuDistros
        } else {
            "[yellow]Could not load distributions.[/]"
        }
        Get-WslManagerPanel -DistroContent $distroContent

        $command = Show-WslMenu

        if ($null -eq $command -or $command -eq "quit") {
            $continue = $false
        }
        else {
            if ($PSCmdlet.ShouldProcess($command, "Execute WSL command")) {
                $script:WslPickerWentBack = $false
                try {
                    Invoke-WslCommand -Command $command -Distros $menuDistros
                }
                catch {
                    Write-ErrorMsg "$_"
                }
                # No pause when the user backed out of a distro picker: there is no output to read
                if (-not $script:WslPickerWentBack) {
                    Read-Host -Prompt "Press Enter to continue"
                }
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Passed through to Invoke-WslCommand for non-interactive WSL user creation.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Username and Password are passed through to Invoke-WslCommand for non-interactive WSL user creation.')]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet("list", "install", "clone", "remove", "update", "setup-user", "setup-proxy", "setup-docker", "setup-podman", "setup-devpod", "sync-ssh-config", "repair-interop", "terminate", "shutdown", "configure-wsl", "")]
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
