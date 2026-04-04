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

# Dependency declaration (SC-033): each tool owns its dependency list
$script:Dependencies = @(
    @{ Name = 'PwshSpectreConsole'; Type = 'PSModule'; MinVersion = '2.0'; Repository = 'PSGallery' }
)

function Install-WslManagerDependency {
    <#
    .SYNOPSIS
        Installs all declared dependencies for WSL Manager.
    .DESCRIPTION
        Iterates over $script:Dependencies and installs any missing PSModule dependencies.
        Called by wsl-manager.ps1 -InstallDeps or by the auto-detect prompt.
    #>
    [CmdletBinding()]
    param()

    foreach ($dep in $script:Dependencies) {
        if ($dep.Type -eq 'PSModule') {
            if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
                Write-Status "Installing NuGet package provider..."
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
            }
            if (Get-InstalledModule -Name $dep.Name -MinimumVersion $dep.MinVersion -ErrorAction SilentlyContinue) {
                Write-Status "$($dep.Name) is already installed"
            }
            else {
                Write-Status "Installing $($dep.Name)..."
                Install-Module -Name $dep.Name -Repository $dep.Repository -Scope CurrentUser -Force -MinimumVersion $dep.MinVersion -SkipPublisherCheck
                Write-Success "$($dep.Name) installed"
            }
        }
    }
}

# Import PwshSpectreConsole for TUI primitives (SC-016)
# Skip in CI/test environments where the module is mocked
if (-not (Test-RunningInCIorTestEnvironment)) {
    # Enable UTF-8 encoding for Spectre.Console (avoids "Western European (DOS)" warning)
    $OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

    if (-not (Get-Module -Name PwshSpectreConsole -ListAvailable)) {
        $install = Get-UserConfirmation -message "PwshSpectreConsole module is missing. Install now?"
        if ($install) {
            Install-WslManagerDependency
        }
        else {
            throw "PwshSpectreConsole module is required. Run bin/install.ps1 or relaunch and accept the install prompt."
        }
    }
    Import-Module PwshSpectreConsole -ErrorAction Stop
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
        "Setup proxy (corporate)"       = "setup-proxy"
        "Remove distribution"           = "remove"
        "Terminate distribution"        = "terminate"
        "Shutdown WSL"                  = "shutdown"
        "Configure .wslconfig defaults" = "configure-wsl"
        "Quit"                          = "quit"
    }

    $selection = Read-SpectreSelection -Message "Select command" -Choices $menuChoices.Keys -PageSize 14 -EnableSearch

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
        "[cyan]WSL Manager[/]" | Format-SpectrePanel -Border Rounded

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

        $command = Show-WslMenu

        if ($null -eq $command -or $command -eq "quit") {
            $continue = $false
        }
        else {
            if ($PSCmdlet.ShouldProcess($command, "Execute WSL command")) {
                try {
                    Invoke-WslCommand -Command $command -Distros $menuDistros
                }
                catch {
                    Write-ErrorMsg "$_"
                }
                Read-Host -Prompt "Press Enter to continue"
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
