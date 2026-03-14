#Requires -Version 5.1

<#
.SYNOPSIS
    Installs Flow Launcher as a standalone optional tool.

.DESCRIPTION
    This script installs Flow Launcher via Scoop as an optional, standalone
    launcher alternative. It configures the Program plugin to index shortcut
    files from the shortcuts directories.

    Flow Launcher is not required by the shortcuts project - it is an optional
    tool for users who prefer it.

.EXAMPLE
    .\install-flow-launcher.ps1

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File install-flow-launcher.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

# Source utils library
. "$PSScriptRoot\..\..\lib\utils\utils.ps1"

#region Main Logic

try {
    Write-Status "Installing Flow Launcher (standalone optional tool)..."
    Write-Information ""

    # Check Scoop is available
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        throw "Scoop is not installed. Please install Scoop first: https://scoop.sh"
    }

    # Ensure extras bucket is available (idempotent: scoop prints a message if already added)
    Write-Status "Ensuring extras bucket is available..."
    Invoke-CommandLine -CommandLine "scoop bucket add extras" -StopAtError $false

    # Check if Flow Launcher is already installed (scoop list returns non-zero when not found)
    Invoke-CommandLine -CommandLine "scoop list flow-launcher" -StopAtError $false
    if ($global:LASTEXITCODE -ne 0) {
        Write-Status "Installing Flow Launcher via Scoop..."
        Invoke-CommandLine -CommandLine "scoop install flow-launcher" -StopAtError $true
    } else {
        Write-Information "Flow Launcher is already installed"
    }

    # Stop any running Flow Launcher instances before configuring
    # (Flow Launcher overwrites persist folder settings on exit)
    Write-Status "Stopping any running Flow Launcher instances..."
    Stop-Process -Name "Flow.Launcher" -ErrorAction SilentlyContinue

    # Configure the Program plugin to index shortcut files
    Write-Status "Configuring Program plugin..."
    . "$PSScriptRoot\configure-program-plugin.ps1"

    $directories = @(
        (Join-Path $env:USERPROFILE "shortcuts"),
        (Join-Path $env:USERPROFILE "shortcuts_private")
    )
    Update-ProgramPluginConfig -Directories $directories

    # Start Flow Launcher (not on PATH, use full Scoop path)
    $flowLauncherExe = Join-Path $env:USERPROFILE "scoop\apps\flow-launcher\current\Flow.Launcher.exe"
    Write-Status "Starting Flow Launcher..."
    Start-Process $flowLauncherExe

    Write-Information ""
    Write-Success "Installation complete!"
    Write-Information ""
    Write-Information "Press Alt+Space to open Flow Launcher"
    Write-Information ""

} catch {
    Write-ErrorMsg "Installation failed: $_"
    exit 1
} finally {
    if (-not (Test-RunningInCIorTestEnvironment)) {
        Write-Information ""
        Write-Information "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    Write-Information ""
}

#endregion
