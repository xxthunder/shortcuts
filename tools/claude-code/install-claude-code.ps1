#Requires -Version 5.1

<#
.SYNOPSIS
    Installs or updates Claude Code CLI using the native installation method.

.DESCRIPTION
    This script installs Claude Code CLI using Anthropic's official installation script.
    Uses Invoke-RestMethod to download and Invoke-Expression to execute the installer.
    Works in both interactive and CI environments.

.EXAMPLE
    .\install-claude-code.ps1

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File install-claude-code.ps1
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification='Official Anthropic installation method requires Invoke-Expression to execute the downloaded installer script from https://claude.ai/install.ps1')]
param()

Set-StrictMode -Version Latest

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

# Source utils library
. "$PSScriptRoot\..\pslib\utils\utils.ps1"

#region Main Logic

try {
    Write-Status "Installing Claude Code CLI..."
    Write-Information "Using Anthropic's native installation method"
    Write-Information ""

    # Download and execute the installation script
    $installUrl = "https://claude.ai/install.ps1"
    Write-Status "Downloading installer from: $installUrl"

    $installScript = Invoke-RestMethod -Uri $installUrl -UseBasicParsing

    if ([string]::IsNullOrWhiteSpace($installScript)) {
        throw "Failed to download installation script from $installUrl"
    }

    Write-Status "Executing installation script..."
    # Using Invoke-Expression as per official Anthropic installation method
    # The script is downloaded from the trusted Anthropic domain (https://claude.ai)
    Invoke-Expression $installScript

    Write-Information ""
    Write-Success "Installation complete!"
    Write-Information ""
    Write-Information "You can now run: claude"
    Write-Information ""
    Write-Information "Remember to refresh Keypirinha catalog:"
    Write-Information "  Press Win+Alt+Space and type 'Refresh catalog'"

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
