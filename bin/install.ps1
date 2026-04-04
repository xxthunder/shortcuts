#Requires -Version 5.1

<#
.SYNOPSIS
    Installation of Shortcuts - self-contained, two-mode installer.

.DESCRIPTION
    Installs the Shortcuts toolkit on Windows. Operates in two modes:

    Remote mode (irm .../install.ps1 | iex):
        Bootstraps Scoop and git inline, clones the repo, then delegates to local mode.

    Local mode (.\install.ps1 -InPlace):
        Sources lib utilities, installs Scoop dependencies, mandatory and optional
        tools, and configures Keypirinha.

    Can be dot-sourced (. .\install.ps1) to expose functions without running main logic.

.PARAMETER InPlace
    Run in local mode without cloning/updating the repository.
    Used by remote mode to delegate to the cloned script.

.PARAMETER Branch
    Branch to clone/pull in remote mode. Defaults to "develop".
    Used by CI to test feature branches via remote mode.

.PARAMETER SkipAdminCheck
    Skip the administrator-privilege check. Used by CI runners that always run elevated.

.EXAMPLE
    irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex

.EXAMPLE
    $tmp = Join-Path $Env:TEMP "install.ps1"; irm $url | Set-Content $tmp; & $tmp -Branch "feature/my-branch"; Remove-Item $tmp

.EXAMPLE
    .\bin\install.ps1 -InPlace
#>

# Suppress linter warnings for necessary patterns
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Invoke-Expression is required for Scoop installer which returns a script string')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host is required for colored console output in remote mode')]
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = 'Install in place without cloning/updating the repository.')]
    [switch]$InPlace = $false,

    [Parameter(Mandatory = $false, HelpMessage = 'Branch to clone/pull in remote mode. Defaults to develop.')]
    [string]$Branch = "develop",

    [Parameter(Mandatory = $false, HelpMessage = 'Skip the administrator-privilege check. Used by CI runners that always run elevated.')]
    [switch]$SkipAdminCheck = $false
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

#region Shared Functions (available in both modes)

function Test-AdminPrivilege {
    <#
    .SYNOPSIS
        Tests whether the current session is running with administrator privileges.
    #>
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Copy-Config {
    <#
    .SYNOPSIS
        Copies a configuration directory tree to a destination using robocopy.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$source,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$destination
    )
    if ($PSCmdlet.ShouldProcess($destination, "Copy config from '$source'")) {
        robocopy $source $destination /E /IS /IT
        if ($LASTEXITCODE -ge 8) {
            Write-Error "Copying config to '$destination' failed"
        }
    }
}

function New-Shortcut {
    <#
    .SYNOPSIS
        Creates a Windows shortcut (.lnk) at the target path pointing to the given path.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$target,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$path
    )
    if ($PSCmdlet.ShouldProcess($target, "Create shortcut")) {
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($target)
        $Shortcut.TargetPath = $path
        $Shortcut.Save()
    }
}

function New-StartupShortcut {
    <#
    .SYNOPSIS
        Creates a shortcut in the Windows Startup folder.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$name,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$path
    )
    if ($PSCmdlet.ShouldProcess($name, "Create startup shortcut")) {
        $startupPath = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Windows\Start Menu\Programs\Startup"
        New-Shortcut -target (Join-Path -Path $startupPath -ChildPath "$name.lnk") -path $path
    }
}

#endregion

if (-not $InPlace) {
    #region Remote Mode - inline bootstrap, clone, delegate

    Set-StrictMode -Version Latest

    $repoUrl = "https://github.com/xxthunder/shortcuts.git"
    $shortcutsDir = "$Env:USERPROFILE\shortcuts"
    $branch = $Branch

    # Admin guard
    if (-not $SkipAdminCheck -and (Test-AdminPrivilege)) {
        Write-Host "ERROR: This script should not be run with administrator privileges. Please run it from a normal PowerShell console." -ForegroundColor Red
        exit 1
    }

    # Install Scoop if not present
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "==> Installing Scoop..." -ForegroundColor Cyan
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        # Refresh PATH so scoop is available
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    # Install git if not present
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "==> Installing git..." -ForegroundColor Cyan
        scoop install git
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    # Clone or pull repository
    if (Test-Path $shortcutsDir) {
        Write-Host "==> Updating repository..." -ForegroundColor Cyan
        Push-Location $shortcutsDir
        try {
            git fetch origin $branch
            git checkout $branch
            git pull origin $branch
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "==> Cloning repository..." -ForegroundColor Cyan
        git clone -b $branch $repoUrl $shortcutsDir
    }

    # Delegate to local mode (pass through SkipAdminCheck if set)
    $delegateArgs = @{ InPlace = $true }
    if ($SkipAdminCheck) { $delegateArgs['SkipAdminCheck'] = $true }
    Write-Host "==> Running local installer..." -ForegroundColor Cyan
    & "$shortcutsDir\bin\install.ps1" @delegateArgs
    exit

    #endregion
} else {
    #region Local Mode - full installation with dot-sourceable functions

    # Resolve repo root from script location
    $script:repoRoot = Split-Path $PSScriptRoot -Parent

    # Source lib utilities
    . "$script:repoRoot\lib\utils\utils.ps1"

    #region Exposed Functions

    function Install-Scoop {
        <#
        .SYNOPSIS
            Installs Scoop package manager if not already present. Idempotent.
        #>
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            Write-Status "Scoop is already installed"
            return
        }

        Write-Status "Installing Scoop..."
        $installer = Invoke-RestMethod -Uri https://get.scoop.sh
        Invoke-Expression $installer
        Initialize-EnvPath
        Write-Success "Scoop installed"
    }

    function Install-ScoopDependency {
        <#
        .SYNOPSIS
            Installs Scoop's own prerequisites in the correct dependency order.
        #>
        $deps = @('lessmsi', '7zip', 'innounp', 'dark')
        foreach ($dep in $deps) {
            Write-Status "Installing Scoop dependency: $dep"
            Invoke-CommandLine -CommandLine "scoop install $dep" -StopAtError $false
        }
    }

    function Install-Git {
        <#
        .SYNOPSIS
            Installs git via Scoop if not already available in PATH. Idempotent.
        #>
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Write-Status "git is already installed"
            return
        }

        Write-Status "Installing git..."
        Invoke-CommandLine -CommandLine "scoop install git" -StopAtError $true
        Initialize-EnvPath
        Write-Success "git installed"
    }

    function Install-MandatoryToolset {
        <#
        .SYNOPSIS
            Installs mandatory tools from scoop_mandatory.json (keypirinha + extras bucket).
        #>
        $mandatoryJson = Join-Path $script:repoRoot 'scoop_mandatory.json'
        Write-Status "Installing mandatory tools..."
        Invoke-CommandLine -CommandLine "scoop import `"$mandatoryJson`"" -StopAtError $true
        Write-Success "Mandatory tools installed"
    }

    function Install-OptionalToolset {
        <#
        .SYNOPSIS
            Installs optional tools from scoop_optional.json.
            Prompts in interactive mode, skips in CI, installs unconditionally with -Force.

        .PARAMETER Force
            Install without prompting.
        #>
        param(
            [switch]$Force
        )

        $optionalJson = Join-Path $script:repoRoot 'scoop_optional.json'

        if ($Force) {
            Write-Status "Installing optional tools (forced)..."
            Invoke-CommandLine -CommandLine "scoop import `"$optionalJson`"" -StopAtError $true
            Write-Success "Optional tools installed"
            return
        }

        if (Test-RunningInCIorTestEnvironment) {
            Write-Status "CI environment detected - skipping optional tools"
            return
        }

        $install = Get-UserConfirmation -message "Install optional tools (windows-terminal, ditto, winmerge, sysinternals, vscode, autohotkey)?"
        if ($install) {
            Write-Status "Installing optional tools..."
            Invoke-CommandLine -CommandLine "scoop import `"$optionalJson`"" -StopAtError $true
            Write-Success "Optional tools installed"
        } else {
            Write-Status "Skipping optional tools"
        }
    }

    function Install-PwshSpectreDependency {
        <#
        .SYNOPSIS
            Installs PwshSpectreConsole for TUI-based shortcut tools.
        .DESCRIPTION
            Several shortcut tools use PwshSpectreConsole for their terminal UI.
            Cannot delegate to individual tools because install.ps1 must run
            under PS 5.1 while tool scripts require PS 7.4.
        #>

        # Ensure NuGet provider is available
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Write-Status "Installing NuGet package provider..."
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
        }

        # PwshSpectreConsole v2 (TUI primitives for shortcut tools)
        if (Get-InstalledModule -Name PwshSpectreConsole -MinimumVersion 2.0 -ErrorAction SilentlyContinue) {
            Write-Status "PwshSpectreConsole is already installed"
        }
        else {
            Write-Status "Installing PwshSpectreConsole..."
            Install-Module -Name PwshSpectreConsole -Repository PSGallery -Scope CurrentUser -Force -MinimumVersion 2.0 -SkipPublisherCheck
            Write-Success "PwshSpectreConsole installed"
        }
    }

    #endregion

    #region Main Execution (guarded - not triggered by dot-sourcing)

    if ($MyInvocation.InvocationName -ne '.') {
        Set-StrictMode -Version Latest

        # Admin guard
        if (-not $SkipAdminCheck -and (Test-AdminPrivilege)) {
            Write-Host "ERROR: This script should not be run with administrator privileges. Please run it from a normal PowerShell console." -ForegroundColor Red
            exit 1
        }

        $shortcutsDir = $script:repoRoot

        try {
            Install-Scoop
            Install-ScoopDependency
            Install-Git
            Install-MandatoryToolset
            Install-PwshSpectreDependency
            Install-OptionalToolset

            # Post-install: Keypirinha config
            Copy-Config (Join-Path $shortcutsDir "config\keypirinha\portable\Profile") "$Env:USERPROFILE\scoop\apps\keypirinha\current\portable\Profile"

            # Post-install: private shortcuts directory
            New-Directory "$Env:USERPROFILE\shortcuts_private"

            # Post-install: AutoHotkey startup shortcut (only if autohotkey is installed)
            if (Get-Command autohotkey -ErrorAction SilentlyContinue) {
                New-StartupShortcut -name "shortcuts_hotkeys" -path "$shortcutsDir\tools\AutoHotKey\hotkeys.cmd"
            }

            # Start Keypirinha (skip in CI — headless runners cannot launch GUI apps)
            if (-not (Test-RunningInCIorTestEnvironment)) {
                & "$Env:USERPROFILE\scoop\apps\keypirinha\current\keypirinha.exe"
            }

            Write-Output "Installation/Update of Shortcuts was successful."
        } finally {
            if (-not (Test-RunningInCIorTestEnvironment)) {
                Read-Host -Prompt "Press Enter to continue ..."
            }
        }
    }

    #endregion
}
